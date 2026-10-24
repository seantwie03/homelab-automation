"""Where imgman finds the repository checkout and its cache."""

import os
from dataclasses import dataclass
from pathlib import Path

from imgman.errors import MissingPrerequisite
from imgman.hosts import Flavor, HostName

PACKAGE_DIR = Path(__file__).resolve().parent


@dataclass(frozen=True, slots=True, kw_only=True)
class Checkout:
    """The repository checkout imgman was installed from, editable."""

    root: Path

    @property
    def images(self) -> Path:
        return self.root / "images"

    @property
    def hosts_file(self) -> Path:
        return self.images / "hosts.toml"

    def containerfile(self, flavor: Flavor) -> Path:
        return self.images / f"Containerfile.{flavor}"

    def kickstart(self, host: HostName) -> Path:
        return self.images / "kickstart" / f"{host}.ks"

    def flavors(self) -> frozenset[Flavor]:
        """Returns the flavors that have a Containerfile.FLAVOR."""
        return frozenset(
            Flavor(path.name.removeprefix("Containerfile."))
            for path in self.images.glob("Containerfile.*")
        )


def find_checkout(package_dir: Path = PACKAGE_DIR) -> Checkout:
    """Returns the checkout that contains PACKAGE_DIR, which is SRC/imgman in imgman/.

    imgman reads the checkout it was installed from, so it works only from an
    editable install.
    """
    root = package_dir.parents[2]
    checkout = Checkout(root=root)
    if not checkout.images.is_dir():
        raise MissingPrerequisite(
            f"no images/ directory in {root}; install imgman from a repository "
            "checkout with 'uv tool install --editable imgman'"
        )
    return checkout


def default_cache_dir() -> Path:
    base = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    return Path(base) / "homelab-images"
