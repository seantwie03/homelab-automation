from pathlib import Path

import pytest

from imgman.checkout import Checkout, default_cache_dir, find_checkout
from imgman.errors import MissingPrerequisite
from imgman.hosts import Flavor, HostName


def test_finds_the_checkout_two_levels_above_the_package(tmp_path: Path) -> None:
    (tmp_path / "images").mkdir()
    package = tmp_path / "imgman" / "src" / "imgman"
    assert find_checkout(package) == Checkout(root=tmp_path)


def test_requires_an_images_directory(tmp_path: Path) -> None:
    with pytest.raises(MissingPrerequisite, match="uv tool install --editable"):
        find_checkout(tmp_path / "imgman" / "src" / "imgman")


def test_lists_flavors_and_paths(checkout: Checkout) -> None:
    assert checkout.flavors() == {Flavor("kde"), Flavor("niri")}
    assert checkout.containerfile(Flavor("kde")) == checkout.root / "images/Containerfile.kde"
    assert checkout.kickstart(HostName("desktop22")) == (
        checkout.root / "images/kickstart/desktop22.ks"
    )


def test_cache_dir_follows_xdg(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path))
    assert default_cache_dir() == tmp_path / "homelab-images"
    monkeypatch.delenv("XDG_CACHE_HOME")
    assert default_cache_dir() == Path.home() / ".cache/homelab-images"
