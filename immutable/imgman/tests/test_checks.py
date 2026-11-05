import json
from pathlib import Path

import pytest

from imgman.checks import Checks, Guest, booted, check_image, layout_cases, upgrade_check_command
from imgman.errors import StepFailed
from imgman.hosts import Flavor, HostName
from imgman.images import ImageId
from imgman.installer import Inputs
from imgman.process import Result
from imgman.registry import Digest
from tests.fakes import FakeRunner

D22 = HostName("desktop22")
INPUTS = Inputs(image_id=ImageId("sha256:id"), kickstart_sha256="abc", digest=Digest("sha256:d"))
STATUS = json.dumps(
    {
        "status": {
            "booted": {
                "image": {
                    "image": {"image": "10.0.2.2:5000/desktop22/workstation-kde:test"},
                    "imageDigest": "sha256:d",
                }
            }
        }
    }
)


def test_checks_count_passes_and_failures(capsys: pytest.CaptureFixture[str]) -> None:
    checks = Checks()
    checks.expect("holds", lambda: True)
    checks.expect("does not hold", lambda: False)

    def broken() -> bool:
        raise StepFailed("no answer")

    checks.expect("raises", broken)
    assert (checks.passed, checks.failed) == (1, 2)
    captured = capsys.readouterr()
    assert captured.out == "PASS: holds\n"
    assert captured.err == "FAIL: does not hold\nFAIL: raises (no answer)\n"


def test_only_an_encrypting_kickstart_gets_the_luks_check() -> None:
    plain = [description for description, _ in layout_cases(encrypted=False)]
    encrypted = [description for description, _ in layout_cases(encrypted=True)]
    assert encrypted == [*plain, "the root file system is on a LUKS2 device"]


def test_booted() -> None:
    assert booted(STATUS) == ("10.0.2.2:5000/desktop22/workstation-kde:test", "sha256:d")
    with pytest.raises(StepFailed):
        booted(json.dumps({"status": {"booted": None}}))


def test_upgrade_check_trusts_only_the_test_registry() -> None:
    command = upgrade_check_command()
    assert 'location = "10.0.2.2:5000"' in command
    assert command.endswith("bootc upgrade --check")


def guest(tmp_path: Path, respond: FakeRunner) -> Guest:
    (tmp_path / "cid").write_text("1234\n")
    return Guest(tmp_path, runner=respond)


def answer(state: str) -> FakeRunner:
    """Answers every command in the VM with success, and systemctl with STATE."""

    def respond(argv: list[str]) -> Result:
        remote = argv[-1]
        if "is-system-running" in remote:
            return Result(returncode=0, stdout=f"{state}\n", stderr="")
        if "bootc status" in remote:
            return Result(returncode=0, stdout=STATUS, stderr="")
        if "systemctl --failed" in remote:
            return Result(returncode=0, stdout="bad.service failed\n", stderr="")
        return Result(returncode=0, stdout="", stderr="")

    return FakeRunner(respond)


def test_check_image_passes_a_healthy_vm(tmp_path: Path) -> None:
    checks = check_image(
        guest(tmp_path, answer("running")),
        host=D22,
        flavor=Flavor("kde"),
        inputs=INPUTS,
        encrypted=True,
    )
    assert (checks.passed, checks.failed) == (len(layout_cases(encrypted=True)) + 3, 0)


def test_check_image_shows_failed_units(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    checks = check_image(
        guest(tmp_path, answer("degraded")),
        host=D22,
        flavor=Flavor("kde"),
        inputs=INPUTS,
        encrypted=False,
    )
    assert checks.failed == 1
    err = capsys.readouterr().err
    assert "FAIL: no unit failed (system is degraded)" in err
    assert "bad.service failed" in err
