"""Stand-ins for external commands, so no test runs Podman, QEMU, or xorriso."""

from collections.abc import Callable, Sequence
from pathlib import Path

from imgman.errors import StepFailed
from imgman.process import Result

OK = Result(returncode=0, stdout="", stderr="")


class FakeRunner:
    """Records each command instead of running it.

    RESPOND returns the result for a command, as a list of strings, and may
    act on it, such as creating a file the command would. A nonzero result
    with check raises StepFailed, as run() does.
    """

    def __init__(self, respond: Callable[[list[str]], Result] | None = None) -> None:
        self.respond = respond
        self.calls: list[list[str]] = []
        self.captured: list[bool] = []

    def __call__(
        self,
        args: Sequence[str | Path],
        *,
        input: str | None = None,
        capture: bool = False,
        check: bool = True,
    ) -> Result:
        argv = [str(arg) for arg in args]
        self.calls.append(argv)
        self.captured.append(capture)
        result = self.respond(argv) if self.respond is not None else OK
        if check and result.returncode != 0:
            raise StepFailed(f"{argv[0]} failed with exit status {result.returncode}")
        return result

    def commands(self) -> list[str]:
        """Returns the first two words of each command, such as 'podman push'."""
        return [" ".join(argv[:2]) for argv in self.calls]


class FakeProcess:
    """A background command that exits with CODE after POLLS polls, or never."""

    def __init__(self, *, code: int | None = 0, polls: int = 1) -> None:
        self.code = code
        self.polls = polls
        self.killed = False

    def poll(self) -> int | None:
        self.polls -= 1
        return self.code if self.polls <= 0 else None

    def kill(self) -> None:
        self.killed = True

    def wait(self) -> int:
        return self.code if self.code is not None else -9


class FakeClock:
    """A clock that sleeping advances, so timeouts pass without waiting."""

    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now

    def sleep(self, seconds: float) -> None:
        self.now += seconds
