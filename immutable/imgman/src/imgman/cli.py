"""The command line: parsing, resolving hosts and flavors, and exit codes."""

import argparse
import shlex
import socket
import sys
from collections.abc import Callable, Sequence
from typing import NoReturn, override

from imgman import commands, output, prerequisites
from imgman.checkout import Checkout, default_cache_dir, find_checkout
from imgman.commands import (
    Command,
    Context,
    ImageBuild,
    MachineGui,
    MachineInit,
    MachineRm,
    MachineRun,
    MachineSsh,
    SystemPrune,
    Target,
    TestImage,
)
from imgman.errors import BadInput, ExitCode, ImgmanError
from imgman.hosts import Flavor, HostName, Hosts, load_hosts

EPILOG = """\
exit status:
    0    success
    1    bad input: arguments, hosts.toml, or other configuration
    2    missing prerequisite
    3    a step or check failed
    130  interrupted
"""


class Parser(argparse.ArgumentParser):
    """An argument parser whose usage errors exit 1, imgman's code for bad input."""

    @override
    def error(self, message: str) -> NoReturn:
        self.print_usage(sys.stderr)
        self.exit(ExitCode.BAD_INPUT, f"{self.prog}: error: {message}\n")


def build_parser() -> Parser:
    parser = Parser(
        prog=output.PROG,
        description="Build bootc images and test them in VMs that stand in for hosts.",
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="stream the output of every command"
    )
    domains = parser.add_subparsers(dest="domain", required=True, metavar="DOMAIN")

    image = domains.add_parser("image", help="build images").add_subparsers(
        dest="action", required=True, metavar="COMMAND"
    )
    build = image.add_parser("build", help="build and lint an image")
    build.add_argument("flavor", nargs="?", help="flavor to build (default: this host's)")
    _all(build, "every flavor with a Containerfile")

    machine = domains.add_parser("machine", help="manage VMs").add_subparsers(
        dest="action", required=True, metavar="COMMAND"
    )
    init = machine.add_parser("init", help="install a host's VM disk with its kickstart")
    _host(init)
    _all(init, "every host")
    _flavor(init)
    run = machine.add_parser("run", help="boot a host's VM from a fresh overlay")
    _host(run)
    _all(run, "every host")
    _flavor(run)
    _no_gui(run)
    gui = machine.add_parser("gui", help="open a running VM's display")
    _host(gui)
    ssh = machine.add_parser(
        "ssh",
        help="run a command as root in a running VM, or open a shell",
        description="If the first word names a host in hosts.toml, it selects the host; "
        "otherwise every word is the command, run on this machine's host.",
    )
    ssh.add_argument("words", nargs=argparse.REMAINDER, metavar="[HOST] [COMMAND ...]")
    rm = machine.add_parser("rm", help="stop a host's VM and remove its overlay")
    _host(rm)
    _all(rm, "every host")

    test = domains.add_parser("test", help="test images and hosts").add_subparsers(
        dest="action", required=True, metavar="COMMAND"
    )
    test_image = test.add_parser("image", help="install a host's VM and check it boots correctly")
    _host(test_image)
    _all(test_image, "every host")
    _flavor(test_image)
    test_image.add_argument("--rm", action="store_true", help="stop the VM when the test ends")
    _no_gui(test_image)

    system = domains.add_parser("system", help="housekeeping").add_subparsers(
        dest="action", required=True, metavar="COMMAND"
    )
    prune = system.add_parser("prune", help="remove leftovers without touching running VMs")
    _host(prune)
    _all(prune, "every host, and the shared registry when no VM is running")
    prune.add_argument(
        "-d", "--disks", action="store_true", help="also remove disks of hosts with no VM running"
    )
    return parser


def _host(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("host", nargs="?", help="host in hosts.toml (default: this machine's)")


def _all(parser: argparse.ArgumentParser, what: str) -> None:
    parser.add_argument("-a", "--all", action="store_true", help=f"target {what}")


def _flavor(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--flavor", dest="flavor_override", metavar="NAME", help="use this flavor, not the host's"
    )


def _no_gui(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--no-gui", dest="no_gui", action="store_true", help="run without a SPICE display"
    )


# Resolving the parsed strings into a typed command


def _text(namespace: argparse.Namespace, name: str) -> str | None:
    value: object = getattr(namespace, name, None)
    return value if isinstance(value, str) else None


def _flag(namespace: argparse.Namespace, name: str) -> bool:
    value: object = getattr(namespace, name, False)
    return value is True


def _words(namespace: argparse.Namespace, name: str) -> tuple[str, ...]:
    value: object = getattr(namespace, name, [])
    if not isinstance(value, list):
        return ()
    items: list[object] = value
    return tuple(item for item in items if isinstance(item, str))


def _known(hosts: Hosts) -> str:
    return ", ".join(sorted(hosts))


def _one_host(host: str | None, hosts: Hosts, hostname: str) -> HostName:
    if host is None:
        if hostname in hosts:
            return HostName(hostname)
        raise BadInput(
            f"this machine, {hostname}, is not in hosts.toml; name a host: {_known(hosts)}"
        )
    if host in hosts:
        return HostName(host)
    raise BadInput(f"unknown host {host}; hosts.toml lists {_known(hosts)}")


def _hosts(namespace: argparse.Namespace, hosts: Hosts, hostname: str) -> tuple[HostName, ...]:
    host = _text(namespace, "host")
    if _flag(namespace, "all"):
        if host is not None:
            raise BadInput("give a host or --all, not both")
        return tuple(sorted(hosts))
    return (_one_host(host, hosts, hostname),)


def _flavor_override(namespace: argparse.Namespace, flavors: frozenset[Flavor]) -> Flavor | None:
    name = _text(namespace, "flavor_override")
    if name is None:
        return None
    if name not in flavors:
        raise BadInput(f"no Containerfile.{name}")
    return Flavor(name)


def _targets(
    namespace: argparse.Namespace, hosts: Hosts, flavors: frozenset[Flavor], hostname: str
) -> tuple[Target, ...]:
    override = _flavor_override(namespace, flavors)
    return tuple(
        Target(host=host, config=hosts[host], flavor=override or hosts[host].flavor)
        for host in _hosts(namespace, hosts, hostname)
    )


def _build_flavors(
    namespace: argparse.Namespace, hosts: Hosts, flavors: frozenset[Flavor], hostname: str
) -> tuple[Flavor, ...]:
    name = _text(namespace, "flavor")
    if _flag(namespace, "all"):
        if name is not None:
            raise BadInput("give a flavor or --all, not both")
        return tuple(sorted(flavors))
    if name is not None:
        if name not in flavors:
            raise BadInput(f"no Containerfile.{name}")
        return (Flavor(name),)
    if hostname in hosts:
        return (hosts[HostName(hostname)].flavor,)
    raise BadInput(f"this machine, {hostname}, is not in hosts.toml; name a flavor or pass --all")


def _ssh(namespace: argparse.Namespace, hosts: Hosts, hostname: str) -> MachineSsh:
    words = _words(namespace, "words")
    if words and words[0] in hosts:
        return MachineSsh(host=HostName(words[0]), command=words[1:])
    return MachineSsh(host=_one_host(None, hosts, hostname), command=words)


def resolve(
    namespace: argparse.Namespace, *, hosts: Hosts, flavors: frozenset[Flavor], hostname: str
) -> Command:
    """Turns the parsed strings into a typed command, checked against hosts.toml."""
    gui = not _flag(namespace, "no_gui")
    match _text(namespace, "domain"), _text(namespace, "action"):
        case "image", "build":
            return ImageBuild(flavors=_build_flavors(namespace, hosts, flavors, hostname))
        case "machine", "init":
            return MachineInit(targets=_targets(namespace, hosts, flavors, hostname))
        case "machine", "run":
            return MachineRun(targets=_targets(namespace, hosts, flavors, hostname), gui=gui)
        case "machine", "gui":
            return MachineGui(host=_one_host(_text(namespace, "host"), hosts, hostname))
        case "machine", "ssh":
            return _ssh(namespace, hosts, hostname)
        case "machine", "rm":
            return MachineRm(hosts=_hosts(namespace, hosts, hostname))
        case "test", "image":
            return TestImage(
                targets=_targets(namespace, hosts, flavors, hostname),
                remove=_flag(namespace, "rm"),
                gui=gui,
            )
        case "system", "prune":
            return SystemPrune(
                hosts=_hosts(namespace, hosts, hostname),
                everything=_flag(namespace, "all"),
                disks=_flag(namespace, "disks"),
            )
        case domain, action:
            raise BadInput(f"unknown command: {domain} {action}")


def short_hostname() -> str:
    return socket.gethostname().split(".", 1)[0]


def warn_if_low_space(context: Context) -> None:
    free = prerequisites.free_gb(context.cache_dir)
    if free < prerequisites.LOW_SPACE_GB:
        output.warn(
            f"only {free} GB free under {prerequisites.existing_ancestor(context.cache_dir)}; "
            "'imgman system prune --all --disks' removes disks of hosts with no VM running"
        )


def run_cli(
    argv: Sequence[str],
    *,
    find: Callable[[], Checkout] = find_checkout,
    hostname: Callable[[], str] = short_hostname,
    execute: Callable[[Command, Context], None] = commands.execute,
    check: Callable[[prerequisites.Requirements], None] = prerequisites.check,
) -> ExitCode:
    """Parses ARGV and runs the command, returning imgman's exit code.

    argparse itself exits 0 after --help and 1 on a usage error.
    """
    namespace = build_parser().parse_args(argv)
    try:
        checkout = find()
        flavors = checkout.flavors()
        hosts = load_hosts(checkout.hosts_file, flavors=flavors)
        command = resolve(namespace, hosts=hosts, flavors=flavors, hostname=hostname())
        needs = commands.requirements(command)
        check(needs)
        context = Context(
            checkout=checkout,
            cache_dir=default_cache_dir(),
            verbose=_flag(namespace, "verbose"),
            command_line=shlex.join([output.PROG, *argv]),
        )
        if needs.disk_space:
            warn_if_low_space(context)
        execute(command, context)
    except ImgmanError as failure:
        output.error(str(failure))
        return failure.exit_code
    except KeyboardInterrupt:
        return ExitCode.INTERRUPTED
    return ExitCode.SUCCESS


def main() -> int:
    return run_cli(sys.argv[1:])
