import pytest

from imgman.checkout import Checkout
from imgman.errors import StepFailed
from imgman.hosts import Flavor
from imgman.images import build, image_id, image_ref
from imgman.process import Result
from tests.fakes import FakeRunner

KDE = Flavor("kde")


def test_image_ref() -> None:
    assert image_ref(KDE) == "localhost/workstation-kde"


@pytest.mark.parametrize(("verbose", "capture"), [(False, True), (True, False)])
def test_build_runs_podman_with_the_flavors_containerfile(
    checkout: Checkout, capsys: pytest.CaptureFixture[str], verbose: bool, capture: bool
) -> None:
    runner = FakeRunner()
    build(KDE, checkout, verbose=verbose, runner=runner)
    images = checkout.images
    assert runner.calls == [
        [
            "podman", "build",
            "-f", str(images / "Containerfile.kde"),
            "-t", "localhost/workstation-kde",
            str(images),
        ]
    ]  # fmt: skip
    assert runner.captured == [capture]
    out = capsys.readouterr().out.splitlines()
    assert out[0] == "building localhost/workstation-kde from images/Containerfile.kde"
    assert out[1].startswith("build kde: done in ")


def test_a_failed_build_raises(checkout: Checkout) -> None:
    runner = FakeRunner(lambda _: Result(returncode=1, stdout="", stderr=""))
    with pytest.raises(StepFailed, match="podman failed"):
        build(KDE, checkout, verbose=False, runner=runner)


@pytest.mark.parametrize(("code", "expected"), [(0, "sha256:abc"), (125, None)])
def test_image_id(code: int, expected: str | None) -> None:
    runner = FakeRunner(lambda _: Result(returncode=code, stdout="sha256:abc\n", stderr=""))
    assert image_id(KDE, runner=runner) == expected
