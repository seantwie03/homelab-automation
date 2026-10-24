import pytest

from imgman.errors import StepFailed
from imgman.process import run


def test_captures_output_and_error() -> None:
    result = run(["sh", "-c", "echo out; echo err >&2"], capture=True)
    assert (result.returncode, result.stdout, result.stderr) == (0, "out\n", "err\n")


def test_passes_input() -> None:
    assert run(["cat"], input="hello", capture=True).stdout == "hello"


def test_failure_names_the_command_and_shows_the_last_error_lines() -> None:
    script = "for i in $(seq 1 30); do echo line$i >&2; done; exit 4"
    with pytest.raises(StepFailed) as raised:
        run(["sh", "-c", script], capture=True)
    lines = str(raised.value).splitlines()
    assert lines[0] == f"sh -c '{script}' failed with exit status 4"
    assert lines[1:] == [f"    line{i}" for i in range(11, 31)]


def test_unchecked_failure_returns_the_status() -> None:
    assert run(["sh", "-c", "exit 4"], capture=True, check=False).returncode == 4


def test_missing_command() -> None:
    with pytest.raises(StepFailed, match="no-such-imgman-command is not installed"):
        run(["no-such-imgman-command"])
