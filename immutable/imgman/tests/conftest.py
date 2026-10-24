from pathlib import Path

import pytest

from imgman.checkout import Checkout
from imgman.hosts import Flavor, Hosts, parse_hosts

HOSTS_TOML = """\
[desktop22]
flavor = "kde"
data_disks = ["10G"]

[desktop25]
flavor = "kde"
memory = "8G"
cpus = 2
"""

FLAVORS = frozenset({Flavor("kde"), Flavor("niri")})


@pytest.fixture
def hosts() -> Hosts:
    return parse_hosts(HOSTS_TOML, source=Path("hosts.toml"), flavors=FLAVORS)


@pytest.fixture
def checkout(tmp_path: Path) -> Checkout:
    """A checkout with Containerfile.kde, Containerfile.niri, and HOSTS_TOML."""
    images = tmp_path / "images"
    images.mkdir()
    for flavor in sorted(FLAVORS):
        (images / f"Containerfile.{flavor}").write_text("FROM scratch\n")
    (images / "hosts.toml").write_text(HOSTS_TOML)
    return Checkout(root=tmp_path)
