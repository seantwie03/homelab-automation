"""The one way imgman runs external commands."""

import shlex
import subprocess
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path

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
