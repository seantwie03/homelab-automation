"""Where imgman keeps the installer ISO, the test registry, and each host's disks and VM."""

from dataclasses import dataclass
from pathlib import Path

from imgman.hosts import Flavor, HostName
from imgman.process import Runner, run


@dataclass(frozen=True, slots=True, kw_only=True)
class Cache:
    root: Path

    @property
    def iso_dir(self) -> Path:
        return self.root / "iso"

    @property
    def registry_dir(self) -> Path:
        return self.root / "registry"

    def host_dir(self, host: HostName) -> Path:
        return self.root / host

    def disk(self, host: HostName, flavor: Flavor) -> Path:
        return self.host_dir(host) / f"workstation-{flavor}.qcow2"

    def inputs(self, host: HostName, flavor: Flavor) -> Path:
        return self.disk(host, flavor).with_suffix(".inputs")

    def install_dir(self, host: HostName) -> Path:
        return self.host_dir(host) / "install"

    def run_dir(self, host: HostName) -> Path:
        return self.host_dir(host) / "run"


def ensure_cache(cache: Cache, *, runner: Runner = run) -> None:
    """Creates the cache directory with chattr +C if it does not exist.

    Files created in it inherit +C, so disk images rewritten in place skip
    btrfs copy-on-write and compression. On another file system, chattr fails
    and the cache works without it.
    """
    if cache.root.exists():
        return
    cache.root.mkdir(parents=True)
    runner(["chattr", "+C", cache.root], capture=True, check=False)
