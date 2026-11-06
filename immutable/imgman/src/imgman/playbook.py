"""test playbook: running a host's playbook from the working tree in its VM."""

import re
import shlex
from dataclasses import dataclass
from pathlib import Path

from imgman.checkout import Checkout
from imgman.errors import StepFailed
from imgman.hosts import HostName
from imgman.output import log, step
from imgman.process import Runner, run
from imgman.vm import RunDir, ssh_args

# Where hosts keep the repository checkout.
GUEST_CHECKOUT = "/opt/homelab-automation"
SSH_PROXY = "/usr/lib/systemd/systemd-ssh-proxy"
RECAP = re.compile(
    r"^localhost\s+:\s+ok=(\d+)\s+changed=(\d+)\s+unreachable=(\d+)\s+failed=(\d+)", re.MULTILINE
)
OUTPUT_LINES = 30


@dataclass(frozen=True, slots=True, kw_only=True)
class Recap:
    ok: int
    changed: int
    unreachable: int
    failed: int


def parse_recap(output: str) -> Recap | None:
    """Returns the last play recap in ansible-playbook's OUTPUT, if there is one."""
    matches = RECAP.findall(output)
    if not matches:
        return None
    ok, changed, unreachable, failed = (int(value) for value in matches[-1])
    return Recap(ok=ok, changed=changed, unreachable=unreachable, failed=failed)


def repository_root(checkout: Checkout, *, runner: Runner = run) -> Path:
    """Returns the top of the git repository the checkout is in."""
    output = runner(
        ["git", "-C", checkout.root, "rev-parse", "--show-toplevel"], capture=True
    ).stdout
    return Path(output.strip())


def playbook_paths(checkout: Checkout, host: HostName, repository: Path) -> tuple[str, str]:
    """Returns the host's playbook and Ansible configuration, relative to the repository.

    Both sit at the checkout's root, which is the repository's root or a
    directory in it, as the ansible_pull role expects.
    """
    playbook = (checkout.root / f"{host}.yml").relative_to(repository)
    config = (checkout.root / "ansible.cfg").relative_to(repository)
    return str(playbook), str(config)


def rsync_args(run_dir: Path, source: Path) -> list[str]:
    """Returns rsync's arguments for copying SOURCE's working tree into the VM's checkout.

    rsync reads vsock/CID:/path as a local path, because a slash comes before
    the colon, so it gets a placeholder host, and ssh reaches the VM through
    systemd-ssh-proxy, as the host's ssh configuration does for vsock/ hosts.
    """
    files = RunDir(path=run_dir)
    cid = files.cid_file.read_text().strip()
    ssh = shlex.join(
        [
            "ssh", "-i", str(files.key),
            "-o", "BatchMode=yes",
            "-o", "LogLevel=ERROR",
            "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null",
            "-o", f"ProxyCommand={SSH_PROXY} vsock/{cid} %p",
            "-o", "ProxyUseFdpass=yes",
        ]
    )  # fmt: skip
    return [
        "rsync", "--archive", "--delete", "--quiet",
        # Uncommitted and untracked changes are copied; .git and ignored files are not.
        "--exclude=.git", "--filter=:- .gitignore",
        "--rsh", ssh,
        f"{source}/", f"root@imgman-vm:{GUEST_CHECKOUT}/",
    ]  # fmt: skip


def playbook_command(playbook: str, config: str) -> list[str]:
    """Returns the command that runs the playbook in the VM, as the ansible_pull unit does."""
    return [
        "env", f"ANSIBLE_CONFIG={GUEST_CHECKOUT}/{config}", "PYTHONUNBUFFERED=True",
        "ansible-playbook", "--inventory", "localhost,", "--limit", "localhost",
        "--diff", f"{GUEST_CHECKOUT}/{playbook}",
    ]  # fmt: skip


def _tail(output: str) -> str:
    return "\n".join(f"    {line}" for line in output.strip().splitlines()[-OUTPUT_LINES:])


def run_playbook(
    run_dir: Path, playbook: str, config: str, *, verbose: bool, runner: Runner = run
) -> Recap:
    """Runs the playbook in the VM once and returns its recap. Raises StepFailed if it fails.

    The output is captured so its recap can be read; VERBOSE prints all of it after the run.
    """
    remote = [
        "sh",
        "-c",
        f"cd {GUEST_CHECKOUT} && {shlex.join(playbook_command(playbook, config))}",
    ]
    result = runner(ssh_args(run_dir, remote, tty=False), capture=True, check=False)
    if verbose:
        print(result.stdout, end="", flush=True)
    if result.returncode != 0:
        raise StepFailed(
            f"the playbook failed with exit status {result.returncode}; last lines:\n"
            + _tail(result.stdout)
        )
    recap = parse_recap(result.stdout)
    if recap is None:
        raise StepFailed(f"the playbook printed no play recap; last lines:\n{_tail(result.stdout)}")
    return recap


def converge_twice(
    *,
    host: HostName,
    run_dir: Path,
    checkout: Checkout,
    verbose: bool,
    runner: Runner = run,
) -> None:
    """Syncs the working tree into HOST's running VM and runs its playbook twice.

    The first run must converge; the second must change nothing.
    """
    repository = repository_root(checkout, runner=runner)
    playbook, config = playbook_paths(checkout, host, repository)
    with step("sync the working tree"):
        runner(rsync_args(run_dir, repository), capture=True)
    with step(f"converge {playbook}"):
        first = run_playbook(run_dir, playbook, config, verbose=verbose, runner=runner)
    log(f"first run: ok={first.ok} changed={first.changed}")
    with step(f"rerun {playbook}"):
        second = run_playbook(run_dir, playbook, config, verbose=verbose, runner=runner)
    if second.changed != 0:
        raise StepFailed(
            f"the second run changed {second.changed} tasks; a converged playbook changes none"
        )
    log(f"second run: ok={second.ok} changed=0")
