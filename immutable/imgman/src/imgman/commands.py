"""The commands imgman runs, each a typed value parsed from the command line."""

from dataclasses import dataclass
from typing import ClassVar, assert_never

from imgman import images, installer, machine, prerequisites, vm
from imgman.cache import Cache
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
    cache: Cache
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
            # It installs the disk first if it is missing.
            return prerequisites.BOOT | prerequisites.INSTALL
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
        case ImageBuild():
            for flavor in command.flavors:
                images.build(flavor, context.checkout, verbose=context.verbose)
        case MachineInit():
            for target in command.targets:
                installer.install(
                    host=target.host,
                    config=target.config,
                    flavor=target.flavor,
                    cache=context.cache,
                    checkout=context.checkout,
                    command_line=context.command_line,
                )
        case MachineRun():
            for target in command.targets:
                machine.run_machine(
                    host=target.host,
                    config=target.config,
                    flavor=target.flavor,
                    gui=command.gui,
                    cache=context.cache,
                    checkout=context.checkout,
                    command_line=context.command_line,
                )
        case MachineSsh():
            vm.ssh(command.host, context.cache.run_dir(command.host), command.command)
        case MachineGui():
            vm.gui(command.host, context.cache.run_dir(command.host))
        case MachineRm():
            for host in command.hosts:
                machine.remove_machine(
                    host=host, cache=context.cache, command_line=context.command_line
                )
        case TestImage():
            failures: list[str] = []
            for target in command.targets:
                try:
                    machine.test_image(
                        host=target.host,
                        config=target.config,
                        flavor=target.flavor,
                        gui=command.gui,
                        remove=command.remove,
                        cache=context.cache,
                        checkout=context.checkout,
                        command_line=context.command_line,
                        verbose=context.verbose,
                    )
                except StepFailed as failure:
                    # With --all, test every host, then report all failures together.
                    if len(command.targets) == 1:
                        raise
                    failures.append(str(failure))
            if failures:
                raise StepFailed("\n".join(failures))
        case SystemPrune():
            raise StepFailed(f"{command.name} is not implemented yet")
        case _:
            assert_never(command)
