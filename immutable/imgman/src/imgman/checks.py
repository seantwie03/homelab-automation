"""test image's checks, run in a host's VM over SSH."""

import json
import sys
from collections.abc import Callable
from dataclasses import dataclass
from functools import partial
from pathlib import Path

from imgman import registry
from imgman.errors import ImgmanError, StepFailed
from imgman.hosts import Flavor, HostName
from imgman.installer import Inputs
from imgman.output import log
from imgman.process import Result, Runner, run
from imgman.vm import ssh_args

# Each check is a description and a shell command that succeeds when it holds.
type Case = tuple[str, str]

SNAPSHOT_TEST = """\
runuser -u sean -- sh -c 'echo x > ~/.cache/imgman-test'
btrfs subvolume snapshot -r /var/home /var/home/.imgman-snapshot >/dev/null
test ! -e /var/home/.imgman-snapshot/sean/.cache/imgman-test
status=$?
btrfs subvolume delete /var/home/.imgman-snapshot >/dev/null
rm -f /var/home/sean/.cache/imgman-test
exit $status"""

LUKS_TEST = """\
source=$(findmnt -no SOURCE /sysroot | sed 's/\\[.*//')
cryptsetup status "$source" | grep -q 'type: *LUKS2'"""


@dataclass(slots=True)
class Checks:
    """Runs checks, prints PASS or FAIL for each, and counts them."""

    passed: int = 0
    failed: int = 0

    def expect(self, description: str, check: Callable[[], bool]) -> None:
        try:
            ok = check()
        except (ImgmanError, OSError, ValueError, KeyError) as error:
            ok = False
            description = f"{description} ({error})"
        if ok:
            self.passed += 1
            log(f"PASS: {description}")
        else:
            self.failed += 1
            print(f"FAIL: {description}", file=sys.stderr, flush=True)


def layout_cases(*, encrypted: bool) -> list[Case]:
    """Returns the checks of the image's file system layout and the kickstart's disk layout."""
    cases: list[Case] = [
        ("/usr is read-only", "touch /usr/.imgman-test 2>&1 | grep -q 'Read-only file system'"),
        ("/etc is writable", "touch /etc/.imgman-test && rm /etc/.imgman-test"),
        ("/var is writable", "touch /var/.imgman-test && rm /var/.imgman-test"),
        ("/opt links to /var/opt", 'test "$(readlink /opt)" = var/opt && test -d /opt/'),
        ("/srv links to /var/srv", 'test "$(readlink /srv)" = var/srv && test -d /srv/'),
        (
            "/usr/local links to /var/usrlocal",
            'test "$(readlink /usr/local)" = ../var/usrlocal && test -d /usr/local/',
        ),
        ("Secure Boot is enabled", "mokutil --sb-state | grep -qx 'SecureBoot enabled'"),
        (
            "the home subvolume is mounted at /var/home",
            "findmnt -no OPTIONS /var/home | grep -q 'subvol=/home'",
        ),
        ("sean has UID 1000", 'test "$(id -u sean)" = 1000'),
        ("a file in ~/.cache is absent from a snapshot of home", SNAPSHOT_TEST),
        (
            "the boot reached graphical.target with the display manager active",
            "systemctl is-active --quiet graphical.target display-manager.service",
        ),
    ]
    if encrypted:
        cases.append(("the root file system is on a LUKS2 device", LUKS_TEST))
    return cases


def upgrade_check_command() -> str:
    """Returns a command that trusts the plain-HTTP test registry and checks for an update."""
    conf = f'[[registry]]\\nlocation = "{registry.GUEST_ADDRESS}"\\ninsecure = true\\n'
    return (
        "mkdir -p /etc/containers/registries.conf.d && "
        f"printf '{conf}' >/etc/containers/registries.conf.d/50-imgman.conf && "
        "bootc upgrade --check"
    )


def _field(value: object, key: str) -> object:
    """Returns KEY of a parsed JSON object, raising StepFailed if VALUE is not one."""
    if not isinstance(value, dict):
        raise StepFailed(f"bootc status has no {key!r}")
    return value.get(key)


def booted(status_json: str) -> tuple[str, str]:
    """Returns the booted image and digest from `bootc status --format json`."""
    image = _field(_field(_field(json.loads(status_json), "status"), "booted"), "image")
    name, digest = _field(_field(image, "image"), "image"), _field(image, "imageDigest")
    if not isinstance(name, str) or not isinstance(digest, str):
        raise StepFailed("bootc status reports no booted image")
    return name, digest


class Guest:
    """Runs shell commands as root in a host's running VM."""

    def __init__(self, run_dir: Path, *, runner: Runner = run) -> None:
        self.run_dir = run_dir
        self.runner = runner

    def execute(self, command: str) -> Result:
        args = ssh_args(self.run_dir, ["sh", "-c", command], tty=False)
        return self.runner(args, capture=True, check=False)

    def succeeds(self, command: str) -> bool:
        return self.execute(command).returncode == 0


def check_no_failed_units(guest: Guest, checks: Checks) -> None:
    """Waits for startup to finish, then expects no failed units, showing any that failed."""
    state = guest.execute("systemctl is-system-running --wait").stdout.strip()
    checks.expect(
        f"no unit failed (system is {state or 'unreachable'})", lambda: state == "running"
    )
    if state == "degraded":
        details = guest.execute(
            "systemctl --failed --no-legend --plain; "
            "for unit in $(systemctl --failed --no-legend --plain | cut -d' ' -f1); do "
            'echo "--- $unit"; journalctl -b -u "$unit" -n 10 --no-pager; done'
        ).stdout
        print(details.rstrip(), file=sys.stderr, flush=True)


def check_image(
    guest: Guest,
    *,
    host: HostName,
    flavor: Flavor,
    inputs: Inputs,
    encrypted: bool,
) -> Checks:
    """Runs test image's checks in GUEST and returns the counts."""
    checks = Checks()
    check_no_failed_units(guest, checks)
    expected_image = registry.install_ref(registry.GUEST_ADDRESS, host, flavor)
    status = guest.execute("bootc status --format json").stdout
    checks.expect(
        f"bootc status reports {expected_image} at the installed digest",
        lambda: booted(status) == (expected_image, inputs.digest),
    )
    for description, command in layout_cases(encrypted=encrypted):
        checks.expect(description, partial(guest.succeeds, command))
    checks.expect(
        "bootc upgrade --check reaches the test registry",
        lambda: guest.succeeds(upgrade_check_command()),
    )
    return checks
