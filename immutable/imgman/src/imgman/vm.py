"""A host's VM, booted from a throwaway overlay in the host's run directory."""

import base64
import os
import random
import shlex
import shutil
import signal
import time
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from pathlib import Path

from imgman.console import console_tail
from imgman.errors import MissingPrerequisite, StepFailed
from imgman.hosts import HostConfig, HostName
from imgman.prerequisites import OVMF_CODE_SECBOOT, OVMF_VARS_SECBOOT
from imgman.process import Runner, Spawner, run, spawn

PROC = Path("/proc")
BOOT_TIMEOUT_SECONDS = 300.0
STOP_TIMEOUT_SECONDS = 30.0
CID_ATTEMPTS = 5
# Guest context IDs are shared by every VM on the machine, including VMs imgman did not start.
CID_RANGE = (1000, 60999)
# A throwaway passphrase: machine init installs encrypted VM disks with it, and
# machine run unlocks them with it. Real hosts' passphrases never enter the repository.
TEST_PASSPHRASE = "imgman"
# The ansible-pull timer still fires in the VM, but the service is skipped,
# so it never replaces a tree test playbook synced.
ANSIBLE_PULL_DROPIN = "[Unit]\nConditionVirtualization=!vm\n"


@dataclass(frozen=True, slots=True, kw_only=True)
class RunDir:
    """The files of one running VM. machine run recreates the directory each boot."""

    path: Path

    @property
    def pid_file(self) -> Path:
        return self.path / "qemu.pid"

    @property
    def cid_file(self) -> Path:
        return self.path / "cid"

    @property
    def key(self) -> Path:
        return self.path / "id_ed25519"

    @property
    def overlay(self) -> Path:
        return self.path / "overlay.qcow2"

    @property
    def vars_file(self) -> Path:
        return self.path / "OVMF_VARS.fd"

    @property
    def console(self) -> Path:
        return self.path / "console.log"

    @property
    def spice(self) -> Path:
        return self.path / "spice.sock"


def running_pid(run_dir: Path, *, proc: Path = PROC) -> int | None:
    """Returns the PID of the QEMU process booted from RUN_DIR, if it still runs."""
    files = RunDir(path=run_dir)
    try:
        pid = int(files.pid_file.read_text().strip())
        cmdline = (proc / str(pid) / "cmdline").read_bytes()
    except OSError, ValueError:
        return None
    # A stale PID file can name an unrelated process, so match the overlay.
    return pid if str(files.overlay).encode() in cmdline else None


def stop(
    run_dir: Path,
    *,
    proc: Path = PROC,
    kill: Callable[[int, int], None] = os.kill,
    clock: Callable[[], float] = time.monotonic,
    sleep: Callable[[float], None] = time.sleep,
) -> bool:
    """Stops the VM booted from RUN_DIR, if any, and removes the directory.

    Returns whether a VM was running. QEMU gets SIGTERM, then SIGKILL after a
    timeout; the guest does not shut down cleanly, which a throwaway overlay
    does not need.
    """
    pid = running_pid(run_dir, proc=proc)
    if pid is not None:
        kill(pid, signal.SIGTERM)
        deadline = clock() + STOP_TIMEOUT_SECONDS
        while (proc / str(pid)).exists():
            if clock() >= deadline:
                kill(pid, signal.SIGKILL)
                break
            sleep(0.2)
    shutil.rmtree(run_dir, ignore_errors=True)
    return pid is not None


def _credential(name: str, value: str) -> list[str]:
    """Returns QEMU arguments passing a systemd credential through SMBIOS."""
    encoded = base64.b64encode(value.encode()).decode()
    return ["-smbios", f"type=11,value=io.systemd.credential.binary:{name}={encoded}"]


def root_key_tmpfiles(public_key: str) -> str:
    """Returns a tmpfiles.d configuration that authorizes PUBLIC_KEY for root.

    It writes to /var/roothome because /root is a link to it that does not
    resolve until systemd-tmpfiles creates the directory.
    """
    key = base64.b64encode(public_key.encode()).decode()
    return (
        "d /var/roothome 0700 root root -\n"
        "d /var/roothome/.ssh 0700 root root -\n"
        f"f+~ /var/roothome/.ssh/authorized_keys 0600 root root - {key}\n"
    )


def boot_args(
    *,
    host: HostName,
    config: HostConfig,
    files: RunDir,
    data_disks: Sequence[Path],
    cid: int,
    public_key: str,
    gui: bool,
) -> list[str]:
    """Returns QEMU's arguments for booting a host's VM with Secure Boot enforced.

    smm=on and a secure flash device keep the guest from changing the Secure
    Boot keys, as on real hardware.
    """
    data = [arg for path in data_disks for arg in ("-drive", f"if=virtio,format=qcow2,file={path}")]
    display = (
        [
            "-spice", f"unix=on,addr={files.spice},disable-ticketing=on",
            "-device", "virtio-serial",
            "-chardev", "spicevmc,id=vdagent,name=vdagent",
            "-device", "virtserialport,chardev=vdagent,name=com.redhat.spice.0",
        ]
        if gui
        else []
    )  # fmt: skip
    return [
        "qemu-system-x86_64",
        "-machine", "q35,accel=kvm,smm=on", "-cpu", "host",
        "-smp", str(config.cpus), "-m", config.memory,
        "-global", "driver=cfi.pflash01,property=secure,value=on",
        "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF_CODE_SECBOOT}",
        "-drive", f"if=pflash,format=raw,file={files.vars_file}",
        "-drive", f"if=virtio,format=qcow2,file={files.overlay}",
        *data,
        "-netdev", "user,id=net0", "-device", "virtio-net-pci,netdev=net0",
        "-device", f"vhost-vsock-pci,guest-cid={cid}",
        # virtio-vga stays without --no-gui, so the display manager still starts.
        "-device", "virtio-vga",
        *display,
        *_credential("tmpfiles.extra", root_key_tmpfiles(public_key)),
        *_credential("system.hostname", host),
        *_credential("cryptsetup.passphrase", TEST_PASSPHRASE),
        *_credential("systemd.unit-dropin.ansible-pull.service", ANSIBLE_PULL_DROPIN),
        "-display", "none", "-serial", f"file:{files.console}",
        "-daemonize", "-pidfile", str(files.pid_file),
    ]  # fmt: skip


def ssh_args(run_dir: Path, remote: Sequence[str], *, tty: bool) -> list[str]:
    """Returns ssh's arguments for running REMOTE as root in the VM over vsock.

    The host's ssh configuration sends vsock/ hosts through systemd-ssh-proxy.
    The guest's host key changes every install, so it is not recorded.
    """
    files = RunDir(path=run_dir)
    cid = files.cid_file.read_text().strip()
    command = [shlex.join(remote)] if remote else []
    return [
        "ssh", "-t" if tty else "-T",
        "-i", str(files.key),
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=5",
        "-o", "LogLevel=ERROR",
        "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=/dev/null",
        f"vsock/{cid}",
        *command,
    ]  # fmt: skip


def boot(
    *,
    host: HostName,
    config: HostConfig,
    disk: Path,
    run_dir: Path,
    gui: bool,
    runner: Runner = run,
    choose_cid: Callable[[], int] = lambda: random.randint(*CID_RANGE),
    ovmf_vars: Path = OVMF_VARS_SECBOOT,
) -> None:
    """Boots DISK through a fresh overlay in RUN_DIR and returns once QEMU is running.

    A CID another VM uses makes QEMU fail at startup, so another is tried.
    """
    files = RunDir(path=run_dir)
    shutil.rmtree(run_dir, ignore_errors=True)
    run_dir.mkdir(mode=0o700, parents=True)
    runner(
        ["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-C", f"imgman-{host}", "-f", files.key],
        capture=True,
    )
    runner(
        ["qemu-img", "create", "-q", "-f", "qcow2", "-b", disk, "-F", "qcow2", files.overlay],
        capture=True,
    )
    data_disks = [run_dir / f"data{n}.qcow2" for n in range(1, len(config.data_disks) + 1)]
    for path, size in zip(data_disks, config.data_disks, strict=True):
        runner(["qemu-img", "create", "-q", "-f", "qcow2", path, size], capture=True)
    shutil.copyfile(ovmf_vars, files.vars_file)
    files.vars_file.chmod(0o600)
    public_key = files.key.with_suffix(".pub").read_text()
    for _ in range(CID_ATTEMPTS):
        cid = choose_cid()
        files.cid_file.write_text(f"{cid}\n")
        args = boot_args(
            host=host,
            config=config,
            files=files,
            data_disks=data_disks,
            cid=cid,
            public_key=public_key,
            gui=gui,
        )
        result = runner(args, capture=True, check=False)
        if result.returncode == 0:
            return
        if "Address already in use" not in result.stderr:
            raise StepFailed(f"QEMU did not start: {result.stderr.strip()}")
    raise StepFailed(f"no free vsock context ID after {CID_ATTEMPTS} tries")


def boot_id(run_dir: Path, *, runner: Runner = run) -> str | None:
    """Returns the VM's boot ID, or None if it does not answer over SSH yet."""
    remote = ["cat", "/proc/sys/kernel/random/boot_id"]
    result = runner(ssh_args(run_dir, remote, tty=False), capture=True, check=False)
    if result.returncode != 0:
        return None
    return result.stdout.strip() or None


def wait_for_boot(
    run_dir: Path,
    *,
    previous: str | None = None,
    runner: Runner = run,
    timeout: float = BOOT_TIMEOUT_SECONDS,
    clock: Callable[[], float] = time.monotonic,
    sleep: Callable[[float], None] = time.sleep,
) -> None:
    """Waits until the VM answers over SSH with a boot ID other than PREVIOUS."""
    deadline = clock() + timeout
    while True:
        current = boot_id(run_dir, runner=runner)
        if current is not None and current != previous:
            return
        if clock() >= deadline:
            raise StepFailed(
                f"the VM did not answer over SSH within {timeout:.0f}s; last console lines:\n"
                + console_tail(RunDir(path=run_dir).console)
            )
        sleep(3)


def require_running(host: HostName, run_dir: Path, *, proc: Path = PROC) -> None:
    if running_pid(run_dir, proc=proc) is None:
        raise MissingPrerequisite(
            f"{host}'s VM is not running; start it with 'imgman machine run {host}'"
        )


def ssh(
    host: HostName,
    run_dir: Path,
    command: Sequence[str],
    *,
    runner: Runner = run,
    proc: Path = PROC,
) -> None:
    """Runs COMMAND as root in HOST's running VM, or opens a shell if COMMAND is empty."""
    require_running(host, run_dir, proc=proc)
    result = runner(ssh_args(run_dir, command, tty=not command), check=False)
    if result.returncode != 0:
        raise StepFailed(f"the command in {host}'s VM exited with status {result.returncode}")


def gui(host: HostName, run_dir: Path, *, spawner: Spawner = spawn, proc: Path = PROC) -> None:
    """Opens remote-viewer on HOST's running VM. It keeps running after imgman exits."""
    require_running(host, run_dir, proc=proc)
    socket = RunDir(path=run_dir).spice
    if not socket.exists():
        raise MissingPrerequisite(
            f"{host}'s VM runs without a display; restart it without --no-gui"
        )
    spawner(["remote-viewer", f"spice+unix://{socket}"])
