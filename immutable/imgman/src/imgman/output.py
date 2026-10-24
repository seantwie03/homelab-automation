"""Output for a person at a terminal: progress on stdout, warnings and errors on stderr."""

import sys
import time
from collections.abc import Callable, Generator
from contextlib import contextmanager

PROG = "imgman"


def log(message: str) -> None:
    print(message, flush=True)


def warn(message: str) -> None:
    print(f"{PROG}: warning: {message}", file=sys.stderr, flush=True)


def error(message: str) -> None:
    print(f"{PROG}: {message}", file=sys.stderr, flush=True)


@contextmanager
def step(name: str, *, clock: Callable[[], float] = time.monotonic) -> Generator[None]:
    """Prints one line with NAME and its duration when the step finishes."""
    started = clock()
    yield
    log(f"{name}: done in {clock() - started:.0f}s")
