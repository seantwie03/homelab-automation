"""Checks the real hosts.toml and kickstarts in this checkout."""

import warnings

import pytest
from pykickstart.parser import KickstartParser
from pykickstart.version import makeVersion, stringToVersion

from imgman.checkout import Checkout, find_checkout
from imgman.hosts import HostName, load_hosts

CHECKOUT = find_checkout()
HOSTS = load_hosts(CHECKOUT.hosts_file, flavors=CHECKOUT.flavors())
INCLUDE = "%include /tmp/target.ks"

# The two targets %pre writes to /tmp/target.ks. ksvalidator cannot run %pre,
# so the tests fill in the include with each.
TARGETS = {
    "hardware": (
        "ostreecontainer --url=ghcr.io/example/workstation:tag --no-signature-verification\n"
        "ignoredisk --only-use=disk/by-id/example"
    ),
    "vm": (
        "ostreecontainer --url=10.0.2.2:5000/host/workstation:test --no-signature-verification\n"
        "ignoredisk --only-use=vda"
    ),
}


def kickstarts(checkout: Checkout) -> set[str]:
    return {path.stem for path in (checkout.images / "kickstart").glob("*.ks")}


def test_every_host_has_a_kickstart_and_every_kickstart_a_host() -> None:
    assert kickstarts(CHECKOUT) == set(HOSTS)


@pytest.mark.parametrize("target", sorted(TARGETS))
@pytest.mark.parametrize("host", sorted(HOSTS))
def test_kickstart_is_valid_for_both_targets(host: HostName, target: str) -> None:
    text = CHECKOUT.kickstart(host).read_text()
    assert text.count(INCLUDE) == 1
    parser = KickstartParser(makeVersion(stringToVersion("F44")))
    with warnings.catch_warnings():
        # ksvalidator reports deprecated or ignored commands as warnings.
        warnings.simplefilter("error")
        parser.readKickstartFromString(text.replace(INCLUDE, TARGETS[target]))
