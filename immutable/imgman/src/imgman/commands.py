"""The commands imgman runs, each a typed value parsed from the command line."""

from dataclasses import dataclass
from pathlib import Path
from typing import ClassVar, assert_never

from imgman import prerequisites
from imgman.checkout import Checkout
from imgman.errors import StepFailed
from imgman.hosts import Flavor, HostConfig, HostName
from imgman.prerequisites import Requirements


@dataclass(frozen=True, slots=True, kw_only=True)
class Target:
    """A host and the flavor its VM runs: the host's own, or one --flavor names."""

    host: HostName
    config: HostConfig
    flavor: Flavor


@dataclass(frozen=True, slots=True, kw_only=True)
class ImageBuild:
    name: ClassVar[str] = "image build"
    flavors: tuple[Flavor, ...]


@dataclass(frozen=True, slots=True, kw_only=True)
class MachineInit:
    name: ClassVar[str] = "machine init"
    targets: tuple[Target, ...]


@dataclass(frozen=True, slots=True, kw_only=True)
class MachineRun:
    name: ClassVar[str] = "machine run"
    targets: tuple[Target, ...]
    gui: bool


@dataclass(frozen=True, slots=True, kw_only=True)
class MachineGui:
    name: ClassVar[str] = "machine gui"
    host: HostName


@dataclass(frozen=True, slots=True, kw_only=True)
class MachineSsh:
    name: ClassVar[str] = "machine ssh"
    host: HostName
    # Empty for an interactive shell.
    command: tuple[str, ...]


@dataclass(frozen=True, slots=True, kw_only=True)
class MachineRm:
    name: ClassVar[str] = "machine rm"
    hosts: tuple[HostName, ...]


@dataclass(frozen=True, slots=True, kw_only=True)
class TestImage:
    name: ClassVar[str] = "test image"
    targets: tuple[Target, ...]
    remove: bool
    gui: bool


@dataclass(frozen=True, slots=True, kw_only=True)
class SystemPrune:
    name: ClassVar[str] = "system prune"
    hosts: tuple[HostName, ...]
    # --all: also the shared registry, when no VM is running.
    everything: bool
    disks: bool


type Command = (
    ImageBuild
    | MachineInit
    | MachineRun
    | MachineGui
    | MachineSsh
    | MachineRm
    | TestImage
    | SystemPrune
)


@dataclass(frozen=True, slots=True, kw_only=True)
class Context:
    """What every command runs with, besides its own arguments."""

    checkout: Checkout
    cache_dir: Path
    verbose: bool
    # The command line as typed, recorded in host locks.
    command_line: str


def requirements(command: Command) -> Requirements:
    match command:
        case ImageBuild():
            return prerequisites.BUILD
        case MachineInit():
            return prerequisites.BUILD | prerequisites.INSTALL
        case MachineRun():
            return prerequisites.BOOT
        case MachineGui():
            return prerequisites.VIEWER
        case MachineSsh():
            return prerequisites.SSH
        case MachineRm():
            return Requirements()
        case TestImage():
            return prerequisites.BUILD | prerequisites.INSTALL | prerequisites.BOOT
        case SystemPrune():
            return prerequisites.REGISTRY
        case _:
            assert_never(command)


def execute(command: Command, context: Context) -> None:
    """Runs COMMAND. Raises an ImgmanError subclass on an expected failure."""
    match command:
        case (
            ImageBuild()
            | MachineInit()
            | MachineRun()
            | MachineGui()
            | MachineSsh()
            | MachineRm()
            | TestImage()
            | SystemPrune()
        ):
            raise StepFailed(f"{command.name} is not implemented yet")
        case _:
            assert_never(command)
