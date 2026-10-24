"""Exit codes and the expected failures that map to them."""

from enum import IntEnum
from typing import ClassVar


class ExitCode(IntEnum):
    SUCCESS = 0
    BAD_INPUT = 1
    MISSING_PREREQUISITE = 2
    STEP_FAILED = 3
    INTERRUPTED = 130


class ImgmanError(Exception):
    """An expected failure. main prints its message, without a traceback, and exits."""

    exit_code: ClassVar[ExitCode] = ExitCode.STEP_FAILED


class BadInput(ImgmanError):
    """The arguments, hosts.toml, or other configuration are invalid."""

    exit_code: ClassVar[ExitCode] = ExitCode.BAD_INPUT


class MissingPrerequisite(ImgmanError):
    """Something must exist or finish before the command can run."""

    exit_code: ClassVar[ExitCode] = ExitCode.MISSING_PREREQUISITE


class StepFailed(ImgmanError):
    """A step or check failed. The message says what failed and, if possible, why."""

    exit_code: ClassVar[ExitCode] = ExitCode.STEP_FAILED
