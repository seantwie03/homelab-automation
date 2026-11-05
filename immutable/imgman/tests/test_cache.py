from pathlib import Path

from imgman.cache import Cache, ensure_cache
from imgman.hosts import Flavor, HostName
from tests.fakes import FakeRunner

D22 = HostName("desktop22")


def test_paths(tmp_path: Path) -> None:
    cache = Cache(root=tmp_path)
    assert cache.disk(D22, Flavor("kde")) == tmp_path / "desktop22/workstation-kde.qcow2"
    assert cache.inputs(D22, Flavor("kde")) == tmp_path / "desktop22/workstation-kde.inputs"
    assert cache.install_dir(D22) == tmp_path / "desktop22/install"
    assert cache.run_dir(D22) == tmp_path / "desktop22/run"


def test_ensure_cache_sets_no_copy_on_write_only_when_creating_it(tmp_path: Path) -> None:
    runner = FakeRunner()
    cache = Cache(root=tmp_path / "homelab-images")
    ensure_cache(cache, runner=runner)
    assert cache.root.is_dir()
    assert runner.calls == [["chattr", "+C", str(cache.root)]]
    ensure_cache(cache, runner=runner)
    assert len(runner.calls) == 1
