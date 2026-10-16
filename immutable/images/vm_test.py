#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Build a workstation image and test it in a VM installed from that image.

The checks cover the filesystem layout, the Ansible bootstrap, and an upgrade
followed by a rollback. Runs without root.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import random
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from collections.abc import Callable, Generator, Sequence
from concurrent.futures import Future, ThreadPoolExecutor
from contextlib import contextmanager
from dataclasses import dataclass, field
from functools import partial
from pathlib import Path
from typing import Literal, NamedTuple, Protocol

PROG = Path(__file__).name
SCRIPT_DIR = Path(__file__).resolve().parent

REGISTRY_CONTAINER = "homelab-image-registry"
REGISTRY_IMAGE = "docker.io/library/registry:3.1.2"
OVMF_CODE = Path("/usr/share/edk2/ovmf/OVMF_CODE.fd")
OVMF_VARS = Path("/usr/share/edk2/ovmf/OVMF_VARS.fd")
KVM = Path("/dev/kvm")
VHOST_VSOCK = Path("/dev/vhost-vsock")
BOOT_TIMEOUT_SECONDS = 300
STOP_TIMEOUT_SECONDS = 30
LOW_SPACE_GB = 15

# Collections that scripts/ansible.sh installs from Fedora packages.
COLLECTIONS = ("ansible.posix",)

# Of the images the VM runs, only the upgrade image contains this file.
UPGRADE_MARKER = "/usr/share/homelab-vm-test"

DEFAULT_FLAVOR = "kde"


class StepError(Exception):
    """A step failed. The message says what failed and, if possible, why."""


def log(message: str) -> None:
    print(message, flush=True)


def warn(message: str) -> None:
    print(f"{PROG}: warning: {message}", file=sys.stderr, flush=True)


@contextmanager
def step(name: str) -> Generator[None]:
    """Logs the start and duration of a step."""
    log(f"==> {name}")
    started = time.monotonic()
    yield
    log(f"==> {name}: done in {time.monotonic() - started:.0f}s")


def default_cache_dir() -> Path:
    base = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    return Path(base) / "homelab-images"


@dataclass(frozen=True)
class Flavor:
    """An image flavor: its image names and the files the harness uses for it."""

    name: str
    script_dir: Path = SCRIPT_DIR
    cache_dir: Path = field(default_factory=default_cache_dir)

    @property
    def _image_name(self) -> str:
        return f"workstation-{self.name}"

    @property
    def containerfile(self) -> Path:
        return self.script_dir / f"Containerfile.{self.name}"

    @property
    def image(self) -> str:
        return f"localhost/{self._image_name}"

    @property
    def upgrade_image(self) -> str:
        return f"{self.image}:upgrade-test"

    @property
    def disk(self) -> Path:
        return self.cache_dir / f"{self._image_name}.qcow2"

    @property
    def run_dir(self) -> Path:
        return self.cache_dir / "run"

    @property
    def registry_dir(self) -> Path:
        return self.cache_dir / "registry"

    # QEMU user networking forwards the VM's connections to 10.0.2.2 to the
    # host's loopback interface, so the registry is reachable from the VM
    # without listening on the LAN.
    @property
    def host_ref(self) -> str:
        return f"127.0.0.1:5000/{self._image_name}:test"

    @property
    def guest_ref(self) -> str:
        return f"10.0.2.2:5000/{self._image_name}:test"


# Prerequisites


@dataclass(frozen=True)
class Requirements:
    """What a command needs from the host."""

    commands: tuple[str, ...] = ()
    files: tuple[Path, ...] = ()
    devices: tuple[Path, ...] = ()
    vsock_ssh: bool = False
    # Warn when the file system that holds the cache is low on space.
    disk_space: bool = False

    def __or__(self, other: Requirements) -> Requirements:
        return Requirements(
            commands=tuple(dict.fromkeys(self.commands + other.commands)),
            files=tuple(dict.fromkeys(self.files + other.files)),
            devices=tuple(dict.fromkeys(self.devices + other.devices)),
            vsock_ssh=self.vsock_ssh or other.vsock_ssh,
            disk_space=self.disk_space or other.disk_space,
        )


BUILD_REQUIREMENTS = Requirements(commands=("podman",), disk_space=True)
DISK_REQUIREMENTS = Requirements(commands=("podman", "bcvk"), devices=(KVM,), disk_space=True)
VM_REQUIREMENTS = Requirements(
    commands=("podman", "qemu-system-x86_64", "qemu-img", "ssh", "ssh-keygen"),
    files=(OVMF_CODE, OVMF_VARS),
    devices=(KVM, VHOST_VSOCK),
    vsock_ssh=True,
)


def vsock_ssh_configured() -> bool:
    """Reports whether ssh sends vsock/ hosts through systemd-ssh-proxy."""
    result = subprocess.run(["ssh", "-G", "vsock/1"], capture_output=True, text=True, check=False)
    return result.returncode == 0 and any(
        line.startswith("proxycommand ") and "systemd-ssh-proxy" in line
        for line in result.stdout.splitlines()
    )


def missing_prerequisites(
    requirements: Requirements,
    *,
    which: Callable[[str], str | None] = shutil.which,
    access: Callable[[Path, int], bool] = os.access,
    vsock_ssh: Callable[[], bool] = vsock_ssh_configured,
) -> list[str]:
    """Lists everything in REQUIREMENTS that the host lacks."""
    missing = [f"the {name} command" for name in requirements.commands if not which(name)]
    missing += [str(path) for path in requirements.files if not access(path, os.R_OK)]
    missing += [
        f"read and write access to {path}"
        for path in requirements.devices
        if not access(path, os.R_OK | os.W_OK)
    ]
    if requirements.vsock_ssh and (not which("ssh") or not vsock_ssh()):
        missing.append("an ssh configuration that sends vsock/ hosts through systemd-ssh-proxy")
    return missing


def existing_ancestor(path: Path) -> Path:
    while not path.is_dir():
        path = path.parent
    return path


def free_bytes(path: Path) -> int:
    return shutil.disk_usage(path).free


def free_gb(path: Path, measure: Callable[[Path], int] = free_bytes) -> int:
    """Returns the free space, in GiB, on the file system that holds PATH."""
    return measure(existing_ancestor(path)) // 2**30


def warn_if_low_space(cache_dir: Path) -> None:
    free = free_gb(cache_dir)
    if free < LOW_SPACE_GB:
        warn(
            f"only {free} GB free under {existing_ancestor(cache_dir)}; "
            f"'{PROG} clean' removes the test disk and registry"
        )


# Arguments


def available_flavors(script_dir: Path) -> list[str]:
    """Returns the flavors that have a Containerfile.FLAVOR in SCRIPT_DIR."""
    return sorted(
        path.name.removeprefix("Containerfile.") for path in script_dir.glob("Containerfile.*")
    )


# The option groups a command can take: --flavor, --keep, or a command to run in the VM.
Option = Literal["flavor", "keep", "remote"]


class CommandSpec(NamedTuple):
    """One subcommand: its name, help text, handler, host requirements, and options.

    COMMANDS lists them all. The parser and main both read that table, so a
    command cannot exist in one without the other.
    """

    name: str
    help_text: str
    run: Callable[[Args, Flavor], None]
    requirements: Requirements = Requirements()
    options: tuple[Option, ...] = ()


@dataclass(frozen=True)
class Args:
    """The parsed and validated command line."""

    command: CommandSpec
    flavor: str = DEFAULT_FLAVOR
    keep: bool = False
    remote_command: tuple[str, ...] = ()


def build_parser(valid_flavors: Sequence[str]) -> argparse.ArgumentParser:
    """Returns the parser for COMMANDS. --flavor accepts only VALID_FLAVORS."""
    parser = argparse.ArgumentParser(
        prog=PROG,
        description=__doc__,
        epilog="Exit status: 0 on success, 1 if a step or check fails, 2 on a usage error.",
    )
    # Commands without these options still get the attributes.
    parser.set_defaults(flavor=DEFAULT_FLAVOR, keep=False, remote_command=[])

    flavor_group = argparse.ArgumentParser(add_help=False)
    flavor_group.add_argument(
        "--flavor",
        choices=valid_flavors,
        default=DEFAULT_FLAVOR,
        help=f"image flavor; builds Containerfile.FLAVOR (default: {DEFAULT_FLAVOR})",
    )
    keep_group = argparse.ArgumentParser(add_help=False)
    keep_group.add_argument(
        "--keep", action="store_true", help="leave the VM running afterwards, for investigation"
    )
    remote_group = argparse.ArgumentParser(add_help=False)
    remote_group.add_argument("remote_command", nargs=argparse.REMAINDER, metavar="CMD")
    option_groups: dict[Option, argparse.ArgumentParser] = {
        "flavor": flavor_group,
        "keep": keep_group,
        "remote": remote_group,
    }

    subparsers = parser.add_subparsers(dest="command_name", required=True, metavar="COMMAND")
    for command in COMMANDS:
        subparser = subparsers.add_parser(
            command.name,
            help=command.help_text,
            parents=[option_groups[option] for option in command.options],
        )
        subparser.set_defaults(command=command)
    return parser


def parse_args(argv: Sequence[str] | None = None, script_dir: Path = SCRIPT_DIR) -> Args:
    """Parses and validates the arguments. Exits with status 2 on an error."""
    valid_flavors = available_flavors(script_dir)
    parser = build_parser(valid_flavors)
    namespace = parser.parse_args(argv)
    args = Args(
        command=namespace.command,
        flavor=namespace.flavor,
        keep=namespace.keep,
        remote_command=tuple(namespace.remote_command),
    )
    # argparse checks only the flavors given on the command line, not the default.
    if args.flavor not in valid_flavors:
        parser.error(f"no Containerfile.{args.flavor} in {script_dir}")
    return args


# Commands on the host


def run(args: Sequence[str | Path], *, input: str | None = None, capture: bool = False) -> str:
    """Runs a command and returns its output if CAPTURE. Raises StepError."""
    argv = [str(arg) for arg in args]
    try:
        result = subprocess.run(
            argv,
            input=input,
            text=True,
            check=True,
            stdout=subprocess.PIPE if capture else None,
        )
    except subprocess.CalledProcessError as error:
        raise StepError(f"{shlex.join(argv)} failed with exit status {error.returncode}") from error
    return result.stdout if capture else ""


def succeeds(args: Sequence[str | Path]) -> bool:
    result = subprocess.run(
        [str(arg) for arg in args],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def image_exists(ref: str) -> bool:
    return succeeds(["podman", "image", "exists", ref])


def build_image(flavor: Flavor) -> None:
    run(["podman", "build", "-f", flavor.containerfile, "-t", flavor.image, flavor.script_dir])


def build_test_image(flavor: Flavor) -> None:
    # bcvk runs the installer in a VM booted from the image and reaches it over
    # SSH on TCP, but workstation images leave sshd.service disabled, so
    # install a test image that enables it. bcvk installs the image under its
    # local name, so the tag is the name the VM pulls updates from.
    run(
        ["podman", "build", "-q", "-t", flavor.guest_ref, "-"],
        input=f"FROM {flavor.image}\nRUN systemctl enable sshd.service\n",
        capture=True,
    )


def install_disk(flavor: Flavor) -> None:
    flavor.cache_dir.mkdir(parents=True, exist_ok=True)
    run(
        [
            "bcvk", "to-disk",
            "--format", "qcow2",
            "--filesystem", "btrfs",
            "--disk-size", "40G",
            flavor.guest_ref, flavor.disk,
        ]
    )  # fmt: skip


def start_registry(flavor: Flavor) -> None:
    if not succeeds(["podman", "container", "exists", REGISTRY_CONTAINER]):
        flavor.registry_dir.mkdir(parents=True, exist_ok=True)
        run(
            [
                "podman", "create", "--quiet",
                "--name", REGISTRY_CONTAINER,
                "-p", "127.0.0.1:5000:5000",
                "-v", f"{flavor.registry_dir}:/var/lib/registry:Z",
                REGISTRY_IMAGE,
            ],
            capture=True,
        )  # fmt: skip
    run(["podman", "start", REGISTRY_CONTAINER], capture=True)


def push_upgrade_image(flavor: Flavor) -> str:
    """Pushes the test image plus the upgrade marker to the tag the VM tracks.

    Returns the pushed manifest digest.
    """
    with step("Pushing the upgrade image in the background"), tempfile.TemporaryDirectory() as temp:
        start_registry(flavor)
        run(
            ["podman", "build", "-q", "-t", flavor.upgrade_image, "-"],
            input=f"FROM {flavor.guest_ref}\nRUN echo upgrade >{UPGRADE_MARKER}\n",
            capture=True,
        )
        digest_file = Path(temp) / "digest"
        run(
            [
                "podman", "push", "-q", "--tls-verify=false",
                "--digestfile", digest_file,
                flavor.upgrade_image, f"docker://{flavor.host_ref}",
            ]
        )  # fmt: skip
        return digest_file.read_text().strip()


# The VM


def tmpfiles_credential(public_key: str) -> str:
    """Returns a base64 tmpfiles.extra credential that authorizes PUBLIC_KEY.

    It writes to /var/roothome because /root is a link to it that does not
    resolve until systemd-tmpfiles creates the directory.
    """
    key = base64.b64encode(public_key.encode()).decode()
    config = (
        "d /var/roothome 0700 root root -\n"
        "d /var/roothome/.ssh 0700 root root -\n"
        f"f+~ /var/roothome/.ssh/authorized_keys 0600 root root - {key}\n"
    )
    return base64.b64encode(config.encode()).decode()


@dataclass(frozen=True)
class BootedImage:
    image: str
    digest: str


def parse_booted(status_json: str) -> BootedImage:
    """Extracts the booted deployment from `bootc status --format json`."""
    image = json.loads(status_json)["status"]["booted"]["image"]
    return BootedImage(image=image["image"]["image"], digest=image["imageDigest"])


class VirtualMachine:
    """A QEMU VM booted from a throwaway overlay of the installed disk.

    The VM is reached over SSH on vsock: the vsock/ host pattern uses
    systemd-ssh-proxy from the host's ssh configuration, and the guest's
    systemd-ssh-generator listens on vsock.
    """

    def __init__(self, flavor: Flavor, proc: Path = Path("/proc")) -> None:
        self.flavor = flavor
        self.proc = proc
        self.run_dir = flavor.run_dir
        self.pid_file = self.run_dir / "qemu.pid"
        self.cid_file = self.run_dir / "cid"
        self.key = self.run_dir / "id_ed25519"
        self.overlay = self.run_dir / "overlay.qcow2"
        self.ovmf_vars = self.run_dir / "OVMF_VARS.fd"
        self.console_log = self.run_dir / "console.log"

    def pid(self) -> int | None:
        """Returns the PID of the VM's QEMU process, if it is still running."""
        try:
            pid = int(self.pid_file.read_text().strip())
            cmdline = (self.proc / str(pid) / "cmdline").read_bytes()
        except (OSError, ValueError):
            return None
        # A stale PID file can name an unrelated process, so match our overlay.
        return pid if str(self.overlay).encode() in cmdline else None

    def running(self) -> bool:
        return self.pid() is not None

    def ssh_args(self, remote: Sequence[str], options: Sequence[str] = ()) -> list[str]:
        cid = self.cid_file.read_text().strip()
        return [
            "ssh", *options,
            "-i", str(self.key),
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=5",
            "-o", "LogLevel=ERROR",
            f"vsock/{cid}",
            *remote,
        ]  # fmt: skip

    def execute(
        self, command: str, *, input: str | None = None, capture: bool = True
    ) -> subprocess.CompletedProcess[str]:
        """Runs a shell command as root in the VM and returns the result."""
        return subprocess.run(
            self.ssh_args([command], ["-T" if input is not None else "-n"]),
            input=input,
            text=True,
            capture_output=capture,
            check=False,
        )

    def succeeds(self, command: str) -> bool:
        return self.execute(command).returncode == 0

    def output(self, command: str) -> str:
        """Runs a shell command in the VM and returns its output."""
        result = self.execute(command)
        if result.returncode != 0:
            raise StepError(
                f"{command!r} failed in the VM with exit status "
                f"{result.returncode}: {result.stderr.strip()}"
            )
        return result.stdout

    def run_visible(self, command: str) -> None:
        """Runs a shell command in the VM, showing its output."""
        result = self.execute(command, capture=False)
        if result.returncode != 0:
            raise StepError(f"{command!r} failed in the VM with exit status {result.returncode}")

    def write(self, path: str, content: str) -> None:
        result = self.execute(f"cat >{shlex.quote(path)}", input=content)
        if result.returncode != 0:
            raise StepError(f"writing {path} in the VM failed: {result.stderr.strip()}")

    def boot_id(self) -> str | None:
        """Returns the VM's boot ID, or None if it does not answer."""
        result = self.execute("cat /proc/sys/kernel/random/boot_id")
        if result.returncode != 0:
            return None
        return result.stdout.strip() or None

    def booted(self) -> BootedImage:
        return parse_booted(self.output("bootc status --format json"))

    def qemu_args(self, cid: int, credential: str) -> list[str]:
        return [
            "qemu-system-x86_64",
            "-machine", "q35,accel=kvm", "-cpu", "host", "-smp", "4", "-m", "4G",
            "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF_CODE}",
            "-drive", f"if=pflash,format=raw,file={self.ovmf_vars}",
            "-drive", f"if=virtio,format=qcow2,file={self.overlay}",
            "-netdev", "user,id=net0", "-device", "virtio-net-pci,netdev=net0",
            "-device", f"vhost-vsock-pci,guest-cid={cid}",
            "-smbios",
            f"type=11,value=io.systemd.credential.binary:tmpfiles.extra={credential}",
            "-display", "none", "-serial", f"file:{self.console_log}",
            "-daemonize", "-pidfile", str(self.pid_file),
        ]  # fmt: skip

    def start(self) -> None:
        self.stop()
        self.run_dir.mkdir(parents=True)
        run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-C", "vm-test", "-f", self.key])
        # Boot from a throwaway overlay so the installed disk stays pristine.
        disk = self.flavor.disk
        run(["qemu-img", "create", "-q", "-f", "qcow2", "-b", disk, "-F", "qcow2", self.overlay])
        shutil.copyfile(OVMF_VARS, self.ovmf_vars)
        # Guest context IDs are shared by every VM on the host.
        cid = random.randint(1000, 60999)
        self.cid_file.write_text(f"{cid}\n")
        credential = tmpfiles_credential(self.key.with_suffix(".pub").read_text())
        run(self.qemu_args(cid, credential))
        self.wait_for_boot()

    def wait_for_boot(
        self,
        previous: str | None = None,
        *,
        timeout: float = BOOT_TIMEOUT_SECONDS,
        clock: Callable[[], float] = time.monotonic,
        sleep: Callable[[float], None] = time.sleep,
    ) -> None:
        """Waits until the VM accepts SSH with a boot ID other than PREVIOUS."""
        deadline = clock() + timeout
        while clock() < deadline:
            current = self.boot_id()
            if current and current != previous:
                return
            sleep(3)
        try:
            console = self.console_log.read_text(errors="replace").splitlines()[-30:]
        except OSError:
            console = []
        raise StepError("the VM did not come up; last console lines:\n" + "\n".join(console))

    def reboot(self) -> None:
        previous = self.boot_id()
        self.execute("systemctl reboot")
        self.wait_for_boot(previous)

    def stop(self) -> None:
        pid = self.pid()
        if pid is not None:
            os.kill(pid, signal.SIGTERM)
            # Wait for QEMU to exit before removing its files.
            deadline = time.monotonic() + STOP_TIMEOUT_SECONDS
            while (self.proc / str(pid)).exists() and time.monotonic() < deadline:
                time.sleep(0.2)
        shutil.rmtree(self.run_dir, ignore_errors=True)


# Checks


class Guest(Protocol):
    """What the checks need from a VM. VirtualMachine provides it."""

    def execute(
        self, command: str, *, input: str | None = None, capture: bool = True
    ) -> subprocess.CompletedProcess[str]: ...
    def succeeds(self, command: str) -> bool: ...
    def output(self, command: str) -> str: ...
    def run_visible(self, command: str) -> None: ...
    def write(self, path: str, content: str) -> None: ...
    def booted(self) -> BootedImage: ...
    def reboot(self) -> None: ...


class Checks:
    """Runs checks, prints PASS or FAIL for each, and counts the failures."""

    def __init__(self) -> None:
        self.failures = 0

    def expect(self, description: str, check: Callable[[], bool]) -> None:
        try:
            passed = check()
        except (StepError, OSError, ValueError, KeyError, TypeError) as error:
            passed = False
            description = f"{description} ({error})"
        if passed:
            log(f"PASS: {description}")
        else:
            print(f"FAIL: {description}", file=sys.stderr, flush=True)
            self.failures += 1


def usr_is_read_only(vm: Guest) -> bool:
    result = vm.execute("touch /usr/.vm-test")
    return result.returncode != 0 and "Read-only file system" in result.stderr


def expect_commands(vm: Guest, checks: Checks, cases: Sequence[tuple[str, str]]) -> None:
    """Checks that each (description, shell command) pair succeeds in the VM."""
    for description, command in cases:
        checks.expect(description, partial(vm.succeeds, command))


def layout_cases() -> list[tuple[str, str]]:
    cases = [
        ("/etc is writable", "touch /etc/.vm-test && rm /etc/.vm-test"),
        ("/var is writable", "touch /var/.vm-test && rm /var/.vm-test"),
        ("/opt links to /var/opt", 'test "$(readlink /opt)" = var/opt && test -d /opt/'),
        ("/srv links to /var/srv", 'test "$(readlink /srv)" = var/srv && test -d /srv/'),
        (
            "/usr/local links to /var/usrlocal",
            'test "$(readlink /usr/local)" = ../var/usrlocal && test -d /usr/local/',
        ),
        ("ansible-pull runs", "ansible-pull --version"),
    ]
    cases += [
        (
            f"collection {name} is installed",
            f"ansible-galaxy collection list {name} | grep -q '^{name} '",
        )
        for name in COLLECTIONS
    ]
    return cases


def check_layout(vm: Guest, flavor: Flavor, checks: Checks) -> None:
    checks.expect(
        f"booted image is {flavor.guest_ref}", lambda: vm.booted().image == flavor.guest_ref
    )
    checks.expect("/usr is read-only", lambda: usr_is_read_only(vm))
    expect_commands(vm, checks, layout_cases())


def registries_conf(flavor: Flavor) -> str:
    """Returns a registries.conf drop-in that trusts the plain HTTP registry."""
    registry = flavor.guest_ref.split("/", 1)[0]
    return f'[[registry]]\nlocation = "{registry}"\ninsecure = true\n'


def check_upgrade_and_rollback(
    vm: Guest, flavor: Flavor, checks: Checks, upgrade_digest: Callable[[], str]
) -> None:
    original_digest = vm.booted().digest
    vm.output("echo vm-test >/etc/homelab-vm-test && echo vm-test >/var/lib/homelab-vm-test")
    vm.write("/etc/containers/registries.conf.d/50-vm-test.conf", registries_conf(flavor))
    digest = upgrade_digest()

    vm.run_visible("bootc upgrade")
    vm.reboot()
    checks.expect("upgrade boots the pushed image", lambda: vm.booted().digest == digest)
    expect_commands(
        vm,
        checks,
        [
            ("upgrade adds the new /usr content", f"test -f {UPGRADE_MARKER}"),
            ("/etc changes survive the upgrade", "test -f /etc/homelab-vm-test"),
            ("/var data survives the upgrade", "test -f /var/lib/homelab-vm-test"),
        ],
    )

    vm.run_visible("bootc rollback")
    vm.reboot()
    checks.expect(
        "rollback boots the original image", lambda: vm.booted().digest == original_digest
    )
    expect_commands(
        vm,
        checks,
        [
            ("rollback removes the new /usr content", f"test ! -e {UPGRADE_MARKER}"),
            ("/etc changes survive the rollback", "test -f /etc/homelab-vm-test"),
            ("/var data survives the rollback", "test -f /var/lib/homelab-vm-test"),
        ],
    )


# Commands


def cmd_build(args: Args, flavor: Flavor) -> None:
    with step(f"Building {flavor.image}"):
        build_image(flavor)


def cmd_disk(args: Args, flavor: Flavor) -> None:
    if not image_exists(flavor.image):
        raise StepError(f"no image {flavor.image}; run: {PROG} build")
    with step(f"Building the test image {flavor.guest_ref}"):
        build_test_image(flavor)
    with step(f"Installing {flavor.disk}"):
        install_disk(flavor)


def cmd_check(args: Args, flavor: Flavor) -> None:
    """Boots the disk and runs the checks.

    The upgrade image is built and pushed in the background while the VM boots
    and the layout checks run. Pushing during the bcvk install instead gave no
    speedup: both read the whole image from local storage and slowed each
    other down.
    """
    if not flavor.disk.is_file():
        raise StepError(f"no disk at {flavor.disk}; run: {PROG} disk")
    if not image_exists(flavor.guest_ref):
        raise StepError(f"no test image {flavor.guest_ref}; run: {PROG} disk")
    vm = VirtualMachine(flavor)
    checks = Checks()
    with ThreadPoolExecutor(max_workers=1) as pool:
        upgrade = pool.submit(push_upgrade_image, flavor)
        try:
            with step("Booting the VM"):
                vm.start()
            with step("Checking the layout"):
                check_layout(vm, flavor, checks)
            with step("Checking upgrade and rollback"):
                check_upgrade_and_rollback(vm, flavor, checks, lambda: wait_for(upgrade))
        finally:
            if args.keep and vm.running():
                log(f"The VM is still running. Use: {PROG} ssh [CMD...], then {PROG} stop")
            else:
                vm.stop()
    if checks.failures:
        raise StepError(f"{checks.failures} check(s) failed")
    log("All checks passed.")


def wait_for(upgrade: Future[str]) -> str:
    if not upgrade.done():
        log("Waiting for the upgrade image push to finish")
    return upgrade.result()


def cmd_all(args: Args, flavor: Flavor) -> None:
    cmd_build(args, flavor)
    cmd_disk(args, flavor)
    cmd_check(args, flavor)


def cmd_ssh(args: Args, flavor: Flavor) -> None:
    vm = VirtualMachine(flavor)
    if not vm.running():
        raise StepError(f"no VM is running; start one with: {PROG} check --keep")
    ssh = vm.ssh_args(args.remote_command)
    os.execvp(ssh[0], ssh)


def cmd_stop(args: Args, flavor: Flavor) -> None:
    VirtualMachine(flavor).stop()


def cmd_clean(args: Args, flavor: Flavor) -> None:
    VirtualMachine(flavor).stop()
    run(["podman", "rm", "--force", "--ignore", REGISTRY_CONTAINER], capture=True)
    run(["podman", "rmi", "--ignore", flavor.guest_ref, flavor.upgrade_image], capture=True)
    if flavor.cache_dir.name != "homelab-images":
        raise StepError(f"refusing to remove unexpected cache directory {flavor.cache_dir}")
    shutil.rmtree(flavor.cache_dir, ignore_errors=True)


COMMANDS = (
    CommandSpec(
        "build",
        "build localhost/workstation-FLAVOR",
        cmd_build,
        requirements=BUILD_REQUIREMENTS,
        options=("flavor",),
    ),
    CommandSpec(
        "disk",
        "install the built image to a VM disk",
        cmd_disk,
        requirements=DISK_REQUIREMENTS,
        options=("flavor",),
    ),
    CommandSpec(
        "check",
        "boot the disk and run the checks",
        cmd_check,
        requirements=VM_REQUIREMENTS,
        options=("flavor", "keep"),
    ),
    CommandSpec(
        "all",
        "run build, disk, and check",
        cmd_all,
        requirements=BUILD_REQUIREMENTS | DISK_REQUIREMENTS | VM_REQUIREMENTS,
        options=("flavor", "keep"),
    ),
    CommandSpec(
        "ssh",
        "run a command as root in the VM that --keep left running, or open a shell there",
        cmd_ssh,
        requirements=Requirements(commands=("ssh",), vsock_ssh=True),
        options=("remote",),
    ),
    CommandSpec("stop", "stop the VM that --keep left running", cmd_stop),
    CommandSpec(
        "clean",
        "stop the VM and remove the test registry, disks, and test images",
        cmd_clean,
        requirements=Requirements(commands=("podman",)),
        options=("flavor",),
    ),
)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    flavor = Flavor(args.flavor)
    requirements = args.command.requirements
    try:
        missing = missing_prerequisites(requirements)
        if missing:
            lines = [f"{PROG}: missing prerequisites:", *(f"    {item}" for item in missing)]
            lines.append(f'See "Requirements" in {flavor.script_dir / "README.md"}.')
            print("\n".join(lines), file=sys.stderr)
            return 1
        if requirements.disk_space:
            warn_if_low_space(flavor.cache_dir)
        args.command.run(args, flavor)
    except StepError as error:
        print(f"{PROG}: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
