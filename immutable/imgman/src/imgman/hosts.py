"""The hosts imgman can run as VMs, parsed from images/hosts.toml."""

import re
import tomllib
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType
from typing import NewType

from imgman.errors import BadInput

HostName = NewType("HostName", str)
Flavor = NewType("Flavor", str)
# A size in QEMU notation, such as 6G.
Size = NewType("Size", str)

DEFAULT_MEMORY = Size("6G")
DEFAULT_CPUS = 4

HOST_NAME = re.compile(r"[a-z0-9][a-z0-9-]*")
SIZE = re.compile(r"[1-9][0-9]*[KMGT]")
KEYS = frozenset({"flavor", "data_disks", "memory", "cpus"})


@dataclass(frozen=True, slots=True, kw_only=True)
class HostConfig:
    flavor: Flavor
    # Blank disks attached after the system disk, standing in for data disks
    # the kickstart must leave alone.
    data_disks: tuple[Size, ...]
    memory: Size
    cpus: int


type Hosts = Mapping[HostName, HostConfig]


def parse_hosts(text: str, *, source: Path, flavors: frozenset[Flavor]) -> Hosts:
    """Parses hosts.toml TEXT. FLAVORS are the flavors that have a Containerfile.

    Raises BadInput listing every problem, each naming its host and key.
    """
    try:
        document: dict[str, object] = tomllib.loads(text)
    except tomllib.TOMLDecodeError as invalid:
        raise BadInput(f"{source}: {invalid}") from invalid
    problems: list[str] = []
    hosts: dict[HostName, HostConfig] = {}
    for name, table in document.items():
        if not HOST_NAME.fullmatch(name):
            problems.append(f"[{name}]: not a valid host name")
        elif not isinstance(table, dict):
            problems.append(f"{name}: must be a table, [{name}]")
        else:
            config = _parse_host(name, table, flavors, problems)
            if config is not None:
                hosts[HostName(name)] = config
    if problems:
        raise BadInput("\n".join([f"{source} is invalid:", *(f"    {p}" for p in problems)]))
    if not hosts:
        raise BadInput(f"{source} lists no hosts")
    return MappingProxyType(hosts)


def _parse_host(
    host: str, table: dict[str, object], flavors: frozenset[Flavor], problems: list[str]
) -> HostConfig | None:
    """Returns HOST's config, or None after appending what is wrong to PROBLEMS."""
    count = len(problems)
    problems.extend(f"[{host}] {key}: unknown key" for key in sorted(table.keys() - KEYS))

    flavor = table.get("flavor")
    if flavor is None:
        problems.append(f"[{host}] flavor: missing")
    elif not isinstance(flavor, str):
        problems.append(f"[{host}] flavor: must be a string")
    elif flavor not in flavors:
        problems.append(f"[{host}] flavor: no Containerfile.{flavor}")

    data_disks = _sizes(host, "data_disks", table.get("data_disks", []), problems)
    memory = _size(host, "memory", table.get("memory", DEFAULT_MEMORY), problems)

    cpus = table.get("cpus", DEFAULT_CPUS)
    # bool is a subclass of int, so true would otherwise mean one vCPU.
    if isinstance(cpus, bool) or not isinstance(cpus, int) or cpus < 1:
        problems.append(f"[{host}] cpus: must be a whole number of at least 1")

    if len(problems) > count or not isinstance(flavor, str) or not isinstance(cpus, int):
        return None
    return HostConfig(
        flavor=Flavor(flavor),
        data_disks=data_disks,
        memory=memory,
        cpus=cpus,
    )


def _size(host: str, key: str, value: object, problems: list[str]) -> Size:
    if isinstance(value, str) and SIZE.fullmatch(value):
        return Size(value)
    problems.append(f'[{host}] {key}: must be a size such as "10G", got {value!r}')
    # A recorded problem discards the whole host, so this value is never used.
    return DEFAULT_MEMORY


def _sizes(host: str, key: str, value: object, problems: list[str]) -> tuple[Size, ...]:
    if not isinstance(value, list):
        problems.append(f'[{host}] {key}: must be a list of sizes such as ["10G"]')
        return ()
    items: list[object] = value
    return tuple(_size(host, key, item, problems) for item in items)


def load_hosts(path: Path, *, flavors: frozenset[Flavor]) -> Hosts:
    try:
        text = path.read_text()
    except OSError as unreadable:
        raise BadInput(f"cannot read {path}: {unreadable.strerror}") from unreadable
    return parse_hosts(text, source=path, flavors=flavors)
