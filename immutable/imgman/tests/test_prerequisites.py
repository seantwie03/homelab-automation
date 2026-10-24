import os
from pathlib import Path

import pytest

from imgman.prerequisites import (
    BOOT,
    BUILD,
    Requirements,
    existing_ancestor,
    free_gb,
    missing,
)

DEVICE = Path("/dev/kvm")
FILE = Path("/usr/share/edk2/ovmf/OVMF_CODE.fd")


def present(_: str) -> str | None:
    return "/usr/bin/x"


def absent(_: str) -> str | None:
    return None


def test_nothing_missing() -> None:
    requirements = Requirements(commands=("podman",), files=(FILE,), devices=(DEVICE,))
    assert missing(requirements, which=present, access=lambda _p, _m: True) == []


def test_lists_everything_missing_at_once() -> None:
    requirements = Requirements(
        commands=("podman", "xorriso"), files=(FILE,), devices=(DEVICE,), vsock_ssh=True
    )
    assert missing(requirements, which=absent, access=lambda _p, _m: False) == [
        "the podman command",
        "the xorriso command",
        str(FILE),
        f"read and write access to {DEVICE}",
    ]


def test_devices_need_read_and_write() -> None:
    modes: list[int] = []

    def access(_: Path, mode: int) -> bool:
        modes.append(mode)
        return True

    missing(Requirements(devices=(DEVICE,)), which=present, access=access)
    assert modes == [os.R_OK | os.W_OK]


@pytest.mark.parametrize("configured", [True, False])
def test_vsock_ssh(configured: bool) -> None:
    result = missing(Requirements(vsock_ssh=True), which=present, vsock_ssh=lambda: configured)
    expected: list[str] = (
        []
        if configured
        else ["an ssh configuration that sends vsock/ hosts through systemd-ssh-proxy"]
    )
    assert result == expected


def test_union_keeps_one_of_each() -> None:
    combined = BUILD | BOOT
    assert combined.commands.count("podman") == 1
    assert combined.commands.count("qemu-img") == 1
    assert combined.disk_space
    assert combined.vsock_ssh


def test_free_space_measures_the_nearest_existing_directory(tmp_path: Path) -> None:
    measured: list[Path] = []

    def measure(path: Path) -> int:
        measured.append(path)
        return 30 * 2**30

    assert free_gb(tmp_path / "not" / "yet", measure) == 30
    assert measured == [tmp_path]
    assert existing_ancestor(tmp_path / "a" / "b") == tmp_path
