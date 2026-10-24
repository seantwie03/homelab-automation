"""What each command needs from the machine that runs imgman."""

import os
import shutil
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from imgman.errors import MissingPrerequisite
from imgman.process import run

OVMF_CODE = Path("/usr/share/edk2/ovmf/OVMF_CODE.fd")
OVMF_VARS = Path("/usr/share/edk2/ovmf/OVMF_VARS.fd")
KVM = Path("/dev/kvm")
VHOST_VSOCK = Path("/dev/vhost-vsock")
LOW_SPACE_GB = 25


@dataclass(frozen=True, slots=True, kw_only=True)
class Requirements:
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


BUILD = Requirements(commands=("podman",), disk_space=True)
INSTALL = Requirements(
    commands=("podman", "qemu-system-x86_64", "qemu-img", "xorriso", "cpio"),
    files=(OVMF_CODE, OVMF_VARS),
    devices=(KVM,),
    disk_space=True,
)
SSH = Requirements(commands=("ssh",), vsock_ssh=True)
BOOT = (
    Requirements(
        commands=("qemu-system-x86_64", "qemu-img", "ssh-keygen"),
        files=(OVMF_CODE, OVMF_VARS),
        devices=(KVM, VHOST_VSOCK),
        disk_space=True,
    )
    | SSH
)
VIEWER = Requirements(commands=("remote-viewer",))
REGISTRY = Requirements(commands=("podman",))


def vsock_ssh_configured() -> bool:
    """Reports whether ssh sends vsock/ hosts through systemd-ssh-proxy."""
    result = run(["ssh", "-G", "vsock/1"], capture=True, check=False)
    return result.returncode == 0 and any(
        line.startswith("proxycommand ") and "systemd-ssh-proxy" in line
        for line in result.stdout.splitlines()
    )


def missing(
    requirements: Requirements,
    *,
    which: Callable[[str], str | None] = shutil.which,
    access: Callable[[Path, int], bool] = os.access,
    vsock_ssh: Callable[[], bool] = vsock_ssh_configured,
) -> list[str]:
    """Lists everything in REQUIREMENTS that this machine lacks."""
    found = [f"the {name} command" for name in requirements.commands if not which(name)]
    found += [str(path) for path in requirements.files if not access(path, os.R_OK)]
    found += [
        f"read and write access to {path}"
        for path in requirements.devices
        if not access(path, os.R_OK | os.W_OK)
    ]
    if requirements.vsock_ssh and which("ssh") and not vsock_ssh():
        found.append("an ssh configuration that sends vsock/ hosts through systemd-ssh-proxy")
    return found


def check(requirements: Requirements) -> None:
    """Raises MissingPrerequisite listing everything REQUIREMENTS needs that is missing."""
    absent = missing(requirements)
    if absent:
        raise MissingPrerequisite(
            "\n".join(["missing prerequisites:", *(f"    {item}" for item in absent)])
        )


def existing_ancestor(path: Path) -> Path:
    while not path.is_dir():
        path = path.parent
    return path


def free_gb(
    path: Path, measure: Callable[[Path], int] = lambda p: shutil.disk_usage(p).free
) -> int:
    """Returns the free space, in GiB, on the file system that holds PATH."""
    return measure(existing_ancestor(path)) // 2**30
