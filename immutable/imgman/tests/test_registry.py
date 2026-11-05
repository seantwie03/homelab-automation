from pathlib import Path

import pytest

from imgman.cache import Cache
from imgman.errors import StepFailed
from imgman.hosts import Flavor, HostName
from imgman.process import Result
from imgman.registry import install_ref, push, start, wait_until_ready
from tests.fakes import OK, FakeClock, FakeRunner

FAILED = Result(returncode=1, stdout="", stderr="name in use")


def test_install_ref_has_a_repository_per_host_and_flavor() -> None:
    ref = install_ref("10.0.2.2:5000", HostName("desktop22"), Flavor("kde"))
    assert ref == "10.0.2.2:5000/desktop22/workstation-kde:test"


def test_wait_until_ready_polls_until_the_registry_answers() -> None:
    clock = FakeClock()
    answers = iter([False, False, True])
    wait_until_ready(lambda: next(answers), clock=clock, sleep=clock.sleep)
    assert clock.now == 1.0


def test_wait_until_ready_times_out() -> None:
    clock = FakeClock()
    with pytest.raises(StepFailed, match="did not answer"):
        wait_until_ready(lambda: False, clock=clock, sleep=clock.sleep)


def test_start_reuses_an_existing_container(tmp_path: Path) -> None:
    runner = FakeRunner()
    start(Cache(root=tmp_path), runner=runner, ready=lambda: True)
    assert runner.commands() == ["podman container", "podman start"]


def test_start_creates_a_missing_container(tmp_path: Path) -> None:
    def respond(argv: list[str]) -> Result:
        return FAILED if argv[:3] == ["podman", "container", "exists"] else OK

    runner = FakeRunner(respond)
    start(Cache(root=tmp_path), runner=runner, ready=lambda: True)
    assert runner.commands() == ["podman container", "podman create", "podman start"]
    assert (tmp_path / "registry").is_dir()


def test_start_tolerates_another_command_creating_it_first(tmp_path: Path) -> None:
    exists = iter([FAILED, OK])

    def respond(argv: list[str]) -> Result:
        if argv[:3] == ["podman", "container", "exists"]:
            return next(exists)
        return FAILED if argv[:2] == ["podman", "create"] else OK

    start(Cache(root=tmp_path), runner=FakeRunner(respond), ready=lambda: True)


def test_start_reports_a_failed_create(tmp_path: Path) -> None:
    def respond(argv: list[str]) -> Result:
        return FAILED if argv[:2] in (["podman", "container"], ["podman", "create"]) else OK

    with pytest.raises(StepFailed, match="could not create homelab-image-registry: name in use"):
        start(Cache(root=tmp_path), runner=FakeRunner(respond), ready=lambda: True)


def test_push_returns_the_digest() -> None:
    def respond(argv: list[str]) -> Result:
        Path(argv[argv.index("--digestfile") + 1]).write_text("sha256:abc\n")
        return OK

    runner = FakeRunner(respond)
    assert (
        push("localhost/workstation-kde", "127.0.0.1:5000/h/w:test", runner=runner) == "sha256:abc"
    )
    assert runner.calls[0][-1] == "docker://127.0.0.1:5000/h/w:test"
