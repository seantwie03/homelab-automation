from pathlib import Path

import pytest

from imgman import commands
from imgman.checkout import Checkout
from imgman.cli import build_parser, resolve, run_cli
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
)
from imgman.errors import BadInput, ExitCode, MissingPrerequisite, StepFailed
from imgman.hosts import Flavor, HostName, Hosts
from imgman.prerequisites import Requirements
from tests.conftest import FLAVORS

D22 = HostName("desktop22")
D25 = HostName("desktop25")
KDE = Flavor("kde")
NIRI = Flavor("niri")


def parse(argv: list[str], hosts: Hosts, hostname: str = "desktop22") -> Command:
    namespace = build_parser().parse_args(argv)
    return resolve(namespace, hosts=hosts, flavors=FLAVORS, hostname=hostname)


def target(hosts: Hosts, host: HostName, flavor: Flavor = KDE) -> Target:
    return Target(host=host, config=hosts[host], flavor=flavor)


def test_host_defaults_to_this_machine(hosts: Hosts) -> None:
    assert parse(["machine", "init"], hosts) == MachineInit(targets=(target(hosts, D22),))


def test_named_host(hosts: Hosts) -> None:
    assert parse(["machine", "rm", "desktop25"], hosts) == MachineRm(hosts=(D25,))


def test_all_targets_every_host(hosts: Hosts) -> None:
    assert parse(["machine", "rm", "--all"], hosts) == MachineRm(hosts=(D22, D25))


def test_flavor_overrides_the_hosts_flavor(hosts: Hosts) -> None:
    assert parse(["machine", "run", "--flavor", "niri", "--no-gui"], hosts) == MachineRun(
        targets=(target(hosts, D22, NIRI),), gui=False
    )


def test_test_image_options(hosts: Hosts) -> None:
    assert parse(["test", "image", "-a", "--rm"], hosts) == commands.TestImage(
        targets=(target(hosts, D22), target(hosts, D25)), remove=True, gui=True
    )


def test_gui(hosts: Hosts) -> None:
    assert parse(["machine", "gui", "desktop25"], hosts) == MachineGui(host=D25)


@pytest.mark.parametrize(
    ("words", "expected"),
    [
        ([], MachineSsh(host=D22, command=())),
        (["nvim", "--version"], MachineSsh(host=D22, command=("nvim", "--version"))),
        (["desktop25"], MachineSsh(host=D25, command=())),
        (["desktop25", "bootc", "status"], MachineSsh(host=D25, command=("bootc", "status"))),
    ],
)
def test_ssh_takes_a_host_only_when_the_first_word_names_one(
    hosts: Hosts, words: list[str], expected: MachineSsh
) -> None:
    assert parse(["machine", "ssh", *words], hosts) == expected


@pytest.mark.parametrize(
    ("argv", "flavors"),
    [
        (["image", "build"], (KDE,)),
        (["image", "build", "niri"], (NIRI,)),
        (["image", "build", "--all"], (KDE, NIRI)),
    ],
)
def test_image_build_flavors(hosts: Hosts, argv: list[str], flavors: tuple[Flavor, ...]) -> None:
    assert parse(argv, hosts) == ImageBuild(flavors=flavors)


def test_prune(hosts: Hosts) -> None:
    assert parse(["system", "prune"], hosts) == SystemPrune(
        hosts=(D22,), everything=False, disks=False
    )
    assert parse(["system", "prune", "-a", "-d"], hosts) == SystemPrune(
        hosts=(D22, D25), everything=True, disks=True
    )


@pytest.mark.parametrize(
    ("argv", "hostname", "message"),
    [
        (["machine", "init"], "laptop", "this machine, laptop, is not in hosts.toml"),
        (["machine", "init", "laptop"], "desktop22", "unknown host laptop"),
        (["machine", "rm", "desktop22", "--all"], "desktop22", "a host or --all, not both"),
        (["machine", "run", "--flavor", "gnome"], "desktop22", "no Containerfile.gnome"),
        (["image", "build"], "laptop", "name a flavor or pass --all"),
        (["image", "build", "gnome"], "desktop22", "no Containerfile.gnome"),
        (["image", "build", "kde", "--all"], "desktop22", "a flavor or --all, not both"),
        (["machine", "ssh", "ls"], "laptop", "this machine, laptop, is not in hosts.toml"),
    ],
)
def test_resolve_rejects_bad_input(
    hosts: Hosts, argv: list[str], hostname: str, message: str
) -> None:
    with pytest.raises(BadInput, match=message):
        parse(argv, hosts, hostname)


@pytest.mark.parametrize(
    "argv", [[], ["machine"], ["machine", "launch"], ["machine", "rm", "--disks"]]
)
def test_usage_errors_exit_1(argv: list[str]) -> None:
    with pytest.raises(SystemExit) as raised:
        build_parser().parse_args(argv)
    assert raised.value.code == ExitCode.BAD_INPUT


def test_help_exits_0() -> None:
    with pytest.raises(SystemExit) as raised:
        build_parser().parse_args(["--help"])
    assert raised.value.code == 0


class Recorder:
    """Stands in for commands.execute, recording what it was asked to run."""

    def __init__(self, failure: Exception | None = None) -> None:
        self.failure = failure
        self.calls: list[tuple[Command, Context]] = []

    def __call__(self, command: Command, context: Context) -> None:
        self.calls.append((command, context))
        if self.failure is not None:
            raise self.failure


def cli(
    checkout: Checkout,
    argv: list[str],
    execute: Recorder,
    check: list[Requirements] | None = None,
) -> ExitCode:
    needs = check if check is not None else []
    return run_cli(
        argv,
        find=lambda: checkout,
        hostname=lambda: "desktop22",
        execute=execute,
        check=needs.append,
    )


def test_runs_the_resolved_command(
    checkout: Checkout, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path / "cache"))
    execute = Recorder()
    checked: list[Requirements] = []
    assert cli(checkout, ["-v", "machine", "rm", "desktop25"], execute, checked) == 0
    [(command, context)] = execute.calls
    assert command == MachineRm(hosts=(D25,))
    assert context.verbose
    assert context.command_line == "imgman -v machine rm desktop25"
    assert context.cache_dir == tmp_path / "cache/homelab-images"
    assert checked == [Requirements()]


@pytest.mark.parametrize(
    ("failure", "code"),
    [
        (BadInput("bad"), ExitCode.BAD_INPUT),
        (MissingPrerequisite("missing"), ExitCode.MISSING_PREREQUISITE),
        (StepFailed("failed"), ExitCode.STEP_FAILED),
        (KeyboardInterrupt(), ExitCode.INTERRUPTED),
    ],
)
def test_failures_map_to_exit_codes(
    checkout: Checkout, capsys: pytest.CaptureFixture[str], failure: Exception, code: ExitCode
) -> None:
    assert cli(checkout, ["machine", "rm"], Recorder(failure)) == code
    if not isinstance(failure, KeyboardInterrupt):
        assert capsys.readouterr().err == f"imgman: {failure}\n"


def test_invalid_hosts_toml_exits_1(checkout: Checkout, capsys: pytest.CaptureFixture[str]) -> None:
    checkout.hosts_file.write_text('[desktop22]\nflavour = "kde"\n')
    assert cli(checkout, ["machine", "rm"], Recorder()) == ExitCode.BAD_INPUT
    assert "flavour: unknown key" in capsys.readouterr().err


def test_missing_prerequisites_exit_2_before_running(checkout: Checkout) -> None:
    execute = Recorder()

    def lacking(_: Requirements) -> None:
        raise MissingPrerequisite("missing prerequisites:\n    the podman command")

    code = run_cli(
        ["image", "build"],
        find=lambda: checkout,
        hostname=lambda: "desktop22",
        execute=execute,
        check=lacking,
    )
    assert code == ExitCode.MISSING_PREREQUISITE
    assert execute.calls == []
