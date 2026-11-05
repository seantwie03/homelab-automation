"""Building the images in images/."""

from typing import NewType

from imgman.checkout import Checkout
from imgman.hosts import Flavor
from imgman.output import log, step
from imgman.process import Runner, run

# Podman's content-derived image ID: a rebuild with any change gets a new one.
ImageId = NewType("ImageId", str)


def image_ref(flavor: Flavor) -> str:
    """Returns the local name of FLAVOR's image."""
    return f"localhost/workstation-{flavor}"


def build(flavor: Flavor, checkout: Checkout, *, verbose: bool, runner: Runner = run) -> None:
    """Builds FLAVOR's image. Its Containerfile ends with bootc container lint.

    Without VERBOSE, Podman's output is captured and shown only if the build fails.
    """
    containerfile = checkout.containerfile(flavor)
    log(f"building {image_ref(flavor)} from {containerfile.relative_to(checkout.root)}")
    with step(f"build {flavor}"):
        runner(
            ["podman", "build", "-f", containerfile, "-t", image_ref(flavor), checkout.images],
            capture=not verbose,
        )


def image_id(flavor: Flavor, *, runner: Runner = run) -> ImageId | None:
    """Returns the ID of FLAVOR's built image, or None if it has not been built."""
    result = runner(
        ["podman", "image", "inspect", "--format", "{{.Id}}", image_ref(flavor)],
        capture=True,
        check=False,
    )
    return ImageId(result.stdout.strip()) if result.returncode == 0 else None
