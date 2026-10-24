import os
import time
from pathlib import Path

import pytest

from imgman.errors import ExitCode
from imgman.hosts import HostName
from imgman.lock import Holder, HostBusy, host_lock, parse_holder

HOST = HostName("desktop22")


def test_a_second_command_on_a_busy_host_fails_and_names_the_holder(tmp_path: Path) -> None:
    started = time.mktime((2026, 10, 23, 10, 42, 0, 0, 0, -1))
    with (
        host_lock(tmp_path, HOST, command="imgman test image", clock=lambda: started),
        pytest.raises(HostBusy) as raised,
        host_lock(tmp_path, HOST, command="imgman rm"),
    ):
        pass
    assert str(raised.value) == (
        f"desktop22 is busy: imgman test image (pid {os.getpid()}), started 10:42"
    )
    assert raised.value.exit_code == ExitCode.MISSING_PREREQUISITE


def test_the_lock_is_released_when_the_block_ends(tmp_path: Path) -> None:
    with host_lock(tmp_path, HOST, command="first"):
        pass
    with host_lock(tmp_path, HOST, command="second"):
        assert parse_holder((tmp_path / "lock").read_text()) is not None


def test_the_lock_is_released_when_the_block_raises(tmp_path: Path) -> None:
    with pytest.raises(RuntimeError), host_lock(tmp_path, HOST, command="first"):
        raise RuntimeError
    with host_lock(tmp_path, HOST, command="second"):
        pass


def test_hosts_do_not_block_each_other(tmp_path: Path) -> None:
    with (
        host_lock(tmp_path / "desktop22", HOST, command="a"),
        host_lock(tmp_path / "desktop25", HostName("desktop25"), command="b"),
    ):
        pass


def test_an_unreadable_holder_is_described_generically(tmp_path: Path) -> None:
    with host_lock(tmp_path, HOST, command="first"):
        (tmp_path / "lock").write_text("garbage")
        with (
            pytest.raises(HostBusy, match="busy: another imgman command"),
            host_lock(tmp_path, HOST, command="second"),
        ):
            pass


@pytest.mark.parametrize(
    ("text", "holder"),
    [
        (
            '{"command": "imgman x", "pid": 7, "started": 1.5}',
            Holder(command="imgman x", pid=7, started=1.5),
        ),
        ('{"command": "imgman x", "pid": true, "started": 1}', None),
        ('{"command": "imgman x", "pid": 7}', None),
        ("[1, 2]", None),
        ("", None),
    ],
)
def test_parse_holder(text: str, holder: Holder | None) -> None:
    assert parse_holder(text) == holder
