"""A per-host lock, so two commands never change the same host's VM or disks at once."""

import fcntl
import json
import os
import time
from collections.abc import Callable, Generator
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path

from imgman.errors import MissingPrerequisite
from imgman.hosts import HostName


@dataclass(frozen=True, slots=True, kw_only=True)
class Holder:
    """The command holding a host's lock, as it recorded itself in the lock file."""

    command: str
    pid: int
    started: float

    def describe(self) -> str:
        started = time.strftime("%H:%M", time.localtime(self.started))
        return f"{self.command} (pid {self.pid}), started {started}"


class HostBusy(MissingPrerequisite):
    """Another imgman command holds the host's lock."""


def parse_holder(text: str) -> Holder | None:
    """Parses a lock file's contents, or returns None if they are not a holder record."""
    try:
        record: object = json.loads(text)
    except json.JSONDecodeError:
        return None
    if not isinstance(record, dict):
        return None
    command, pid, started = record.get("command"), record.get("pid"), record.get("started")
    if (
        not isinstance(command, str)
        or isinstance(pid, bool)
        or not isinstance(pid, int)
        or isinstance(started, bool)
        or not isinstance(started, int | float)
    ):
        return None
    return Holder(command=command, pid=pid, started=float(started))


@contextmanager
def host_lock(
    host_dir: Path,
    host: HostName,
    *,
    command: str,
    clock: Callable[[], float] = time.time,
) -> Generator[None]:
    """Holds HOST's lock, in HOST_DIR, while the block runs.

    Raises HostBusy, naming the holder, if another command holds it. The kernel
    releases a flock when its process exits, even after a crash, so a dead
    command never blocks the next one. The lock file stays behind; deleting it
    would let two commands lock different files.
    """
    host_dir.mkdir(parents=True, exist_ok=True)
    fd = os.open(host_dir / "lock", os.O_RDWR | os.O_CREAT, 0o644)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            holder = parse_holder(os.pread(fd, 4096, 0).decode(errors="replace"))
            by = holder.describe() if holder else "another imgman command"
            raise HostBusy(f"{host} is busy: {by}") from None
        record = {"command": command, "pid": os.getpid(), "started": clock()}
        os.ftruncate(fd, 0)
        os.pwrite(fd, json.dumps(record).encode(), 0)
        yield
    finally:
        os.close(fd)
