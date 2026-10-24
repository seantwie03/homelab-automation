from pathlib import Path

import pytest

from imgman.errors import BadInput
from imgman.hosts import (
    DEFAULT_CPUS,
    DEFAULT_MEMORY,
    Flavor,
    HostConfig,
    HostName,
    Hosts,
    Size,
    parse_hosts,
)
from tests.conftest import FLAVORS


def parse(text: str) -> Hosts:
    return parse_hosts(text, source=Path("hosts.toml"), flavors=FLAVORS)


def test_parses_hosts_and_applies_defaults(hosts: Hosts) -> None:
    assert dict(hosts) == {
        HostName("desktop22"): HostConfig(
            flavor=Flavor("kde"),
            data_disks=(Size("10G"),),
            memory=DEFAULT_MEMORY,
            cpus=DEFAULT_CPUS,
        ),
        HostName("desktop25"): HostConfig(
            flavor=Flavor("kde"), data_disks=(), memory=Size("8G"), cpus=2
        ),
    }


@pytest.mark.parametrize(
    ("text", "problem"),
    [
        ('[desktop22]\nflavour = "kde"\n', "[desktop22] flavour: unknown key"),
        ("[desktop22]\n", "[desktop22] flavor: missing"),
        ("[desktop22]\nflavor = 1\n", "[desktop22] flavor: must be a string"),
        ('[desktop22]\nflavor = "gnome"\n', "[desktop22] flavor: no Containerfile.gnome"),
        ('[desktop22]\nflavor = "kde"\nmemory = "8 GB"\n', "[desktop22] memory: must be a size"),
        ('[desktop22]\nflavor = "kde"\nmemory = 8\n', "[desktop22] memory: must be a size"),
        ('[desktop22]\nflavor = "kde"\ndata_disks = "10G"\n', "[desktop22] data_disks: must be"),
        ('[desktop22]\nflavor = "kde"\ndata_disks = [10]\n', "[desktop22] data_disks: must be"),
        ('[desktop22]\nflavor = "kde"\ncpus = 0\n', "[desktop22] cpus: must be a whole number"),
        ('[desktop22]\nflavor = "kde"\ncpus = true\n', "[desktop22] cpus: must be a whole number"),
        ('[desktop22]\nflavor = "kde"\ncpus = "4"\n', "[desktop22] cpus: must be a whole number"),
        ('desktop22 = "kde"\n', "desktop22: must be a table"),
        ('[Desktop_22]\nflavor = "kde"\n', "[Desktop_22]: not a valid host name"),
    ],
)
def test_rejects_invalid_hosts(text: str, problem: str) -> None:
    with pytest.raises(BadInput) as raised:
        parse(text)
    assert problem in str(raised.value)


def test_reports_every_problem_at_once() -> None:
    with pytest.raises(BadInput) as raised:
        parse('[desktop22]\nflavour = "kde"\n\n[desktop25]\nflavor = "kde"\ncpus = 0\n')
    message = str(raised.value)
    assert "[desktop22] flavour: unknown key" in message
    assert "[desktop22] flavor: missing" in message
    assert "[desktop25] cpus" in message


def test_rejects_invalid_toml() -> None:
    with pytest.raises(BadInput, match="hosts.toml"):
        parse("[desktop22\n")


def test_rejects_a_file_with_no_hosts() -> None:
    with pytest.raises(BadInput, match="lists no hosts"):
        parse("")
