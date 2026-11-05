from collections.abc import Sequence
from pathlib import Path

import pytest

from imgman.checkout import Checkout
from imgman.errors import StepFailed
from imgman.hosts import Flavor
from imgman.images import build, image_ref
from imgman.process import Result

KDE = Flavor("kde")


class FakeRunner:
    """Records each command instead of running it, and fails if FAIL is set."""

    def __init__(self, *, fail: bool = False) -> None:
        self.fail = fail
        self.calls: list[tuple[list[str], bool]] = []

    def __call__(
        self,
        args: Sequence[str | Path],
        *,
        input: str | None = None,
        capture: bool = False,
        check: bool = True,
    ) -> Result:
        self.calls.append(([str(arg) for arg in args], capture))
        if self.fail and check:
            raise StepFailed("podman build failed with exit status 1")
        return Result(returncode=0, stdout="", stderr="")


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
        (
            [
                "podman", "build",
                "-f", str(images / "Containerfile.kde"),
                "-t", "localhost/workstation-kde",
                str(images),
            ],
            capture,
        )
    ]  # fmt: skip
    out = capsys.readouterr().out.splitlines()
    assert out[0] == "building localhost/workstation-kde from images/Containerfile.kde"
    assert out[1].startswith("build kde: done in ")


def test_a_failed_build_raises(checkout: Checkout) -> None:
    with pytest.raises(StepFailed, match="podman build failed"):
        build(KDE, checkout, verbose=False, runner=FakeRunner(fail=True))
