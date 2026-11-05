"""The one way imgman runs external commands."""

import shlex
import subprocess
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

from imgman.errors import StepFailed

# How many lines of a failed command's captured error output its StepFailed shows.
ERROR_LINES = 20


@dataclass(frozen=True, slots=True, kw_only=True)
class Result:
    returncode: int
    # Empty unless the command ran with capture.
    stdout: str
    stderr: str


def run(
    args: Sequence[str | Path],
    *,
    input: str | None = None,
    capture: bool = False,
    check: bool = True,
) -> Result:
    """Runs a command without a shell.

    With CAPTURE, collects its standard output and error instead of showing them.
    With CHECK, a nonzero exit status raises StepFailed, which ends with the
    last lines of the captured error output.
    """
    argv = [str(arg) for arg in args]
    pipe = subprocess.PIPE if capture else None
    try:
        completed = subprocess.run(
            argv, input=input, text=True, check=False, stdout=pipe, stderr=pipe
        )
    except FileNotFoundError as missing:
        raise StepFailed(f"{argv[0]} is not installed") from missing
    result = Result(
        returncode=completed.returncode,
        stdout=completed.stdout or "",
        stderr=completed.stderr or "",
    )
    if check and result.returncode != 0:
        message = f"{shlex.join(argv)} failed with exit status {result.returncode}"
        tail = result.stderr.strip().splitlines()[-ERROR_LINES:]
        raise StepFailed("\n".join([message, *(f"    {line}" for line in tail)]))
    return result


class Runner(Protocol):
    """Anything that runs commands as run() does. Tests pass a fake that records them."""

    def __call__(
        self,
        args: Sequence[str | Path],
        *,
        input: str | None = None,
        capture: bool = False,
        check: bool = True,
    ) -> Result: ...


class Process(Protocol):
    """A command running in the background."""

    def poll(self) -> int | None: ...

    def kill(self) -> None: ...

    def wait(self) -> int: ...


class Spawner(Protocol):
    """Anything that starts commands as spawn() does. Tests pass a fake."""

    def __call__(self, args: Sequence[str | Path]) -> Process: ...


def spawn(args: Sequence[str | Path]) -> Process:
    """Starts a command without a shell and returns without waiting for it.

    For long-running commands, such as an install, that imgman watches while
    they run. Its output goes to the terminal; it reads nothing.
    """
    argv = [str(arg) for arg in args]
    try:
        return subprocess.Popen(argv, stdin=subprocess.DEVNULL)
    except FileNotFoundError as missing:
        raise StepFailed(f"{argv[0]} is not installed") from missing
