"""The test registry: a local registry container the VMs install and upgrade from."""

import tempfile
import time
import urllib.request
from collections.abc import Callable
from pathlib import Path
from typing import NewType

from imgman.cache import Cache
from imgman.errors import StepFailed
from imgman.hosts import Flavor, HostName
from imgman.process import Runner, run

Digest = NewType("Digest", str)

CONTAINER = "homelab-image-registry"
IMAGE = "docker.io/library/registry:3.1.2"
# The registry listens only on loopback. QEMU user networking forwards the
# VM's connections to 10.0.2.2 there, so VMs reach it without the LAN.
HOST_ADDRESS = "127.0.0.1:5000"
GUEST_ADDRESS = "10.0.2.2:5000"
READY_TIMEOUT_SECONDS = 30.0


def install_ref(address: str, host: HostName, flavor: Flavor) -> str:
    """Returns the tag a host's VM installs from: one repository per host and flavor."""
    return f"{address}/{host}/workstation-{flavor}:test"


def answers() -> bool:
    """Reports whether the registry answers on its API endpoint."""
    try:
        with urllib.request.urlopen(f"http://{HOST_ADDRESS}/v2/", timeout=2) as response:
            return response.status == 200
    except OSError:
        return False


def wait_until_ready(
    ready: Callable[[], bool] = answers,
    *,
    timeout: float = READY_TIMEOUT_SECONDS,
    clock: Callable[[], float] = time.monotonic,
    sleep: Callable[[float], None] = time.sleep,
) -> None:
    deadline = clock() + timeout
    while not ready():
        if clock() >= deadline:
            raise StepFailed(
                f"the test registry did not answer on http://{HOST_ADDRESS}/v2/ "
                f"within {timeout:.0f}s"
            )
        sleep(0.5)


def _exists(runner: Runner) -> bool:
    return runner(["podman", "container", "exists", CONTAINER], check=False).returncode == 0


def start(cache: Cache, *, runner: Runner = run, ready: Callable[[], bool] = answers) -> None:
    """Starts the shared registry container, creating it if needed, and waits until it answers.

    A push right after the container starts can otherwise fail with a reset connection.
    """
    if not _exists(runner):
        cache.registry_dir.mkdir(parents=True, exist_ok=True)
        created = runner(
            [
                "podman", "create", "--quiet",
                "--name", CONTAINER,
                "-p", f"{HOST_ADDRESS}:5000",
                "-v", f"{cache.registry_dir}:/var/lib/registry:Z",
                IMAGE,
            ],
            capture=True,
            check=False,
        )  # fmt: skip
        # Another imgman command may have created it at the same moment.
        if created.returncode != 0 and not _exists(runner):
            raise StepFailed(f"could not create {CONTAINER}: {created.stderr.strip()}")
    runner(["podman", "start", CONTAINER], capture=True)
    wait_until_ready(ready)


def push(image: str, ref: str, *, runner: Runner = run) -> Digest:
    """Pushes IMAGE to REF in the test registry and returns the manifest digest."""
    with tempfile.TemporaryDirectory() as temp:
        digest_file = Path(temp) / "digest"
        runner(
            [
                "podman", "push", "--quiet", "--tls-verify=false",
                "--digestfile", digest_file,
                image, f"docker://{ref}",
            ],
            capture=True,
        )  # fmt: skip
        return Digest(digest_file.read_text().strip())
