import json
from pathlib import Path

import pytest

from imgman import installer
from imgman.cache import Cache
from imgman.checkout import Checkout
from imgman.errors import BadInput, MissingPrerequisite, StepFailed
from imgman.hosts import Flavor, HostConfig, HostName, Hosts, Size
from imgman.installer import (
    Inputs,
    console_tail,
    fedora_version,
    find_iso,
    inject,
    install,
    install_args,
    kernel_cmdline,
    newc_archive,
    parse_inputs,
    volume_label,
    watch,
)
from imgman.process import Result
from tests.fakes import OK, FakeClock, FakeProcess, FakeRunner

D22 = HostName("desktop22")
KDE = Flavor("kde")
ISO_NAME = "Fedora-Everything-netinst-x86_64-44-1.7.iso"


def parse_newc(archive: bytes) -> list[tuple[str, int, bytes]]:
    """Reads ARCHIVE back as (name, mode, data) entries, checking 4-byte alignment."""
    entries: list[tuple[str, int, bytes]] = []
    offset = 0
    while True:
        assert archive[offset : offset + 6] == b"070701"
        fields = [int(archive[offset + 6 + 8 * i : offset + 14 + 8 * i], 16) for i in range(13)]
        mode, size, namesize = fields[1], fields[6], fields[11]
        name_start = offset + 110
        name = archive[name_start : name_start + namesize - 1].decode()
        data_start = name_start + namesize
        data_start += -data_start % 4
        data = archive[data_start : data_start + size]
        entries.append((name, mode, data))
        offset = data_start + size
        offset += -offset % 4
        if name == "TRAILER!!!":
            assert offset == len(archive)
            return entries


def test_newc_archive_holds_one_file_and_a_trailer() -> None:
    archive = newc_archive("ks.cfg", b"text\n")
    assert len(archive) % 4 == 0
    assert parse_newc(archive) == [("ks.cfg", 0o100644, b"text\n"), ("TRAILER!!!", 0, b"")]


def test_inject_appends_the_kickstart_after_padding(tmp_path: Path) -> None:
    initrd, dest = tmp_path / "initrd.img", tmp_path / "out.img"
    initrd.write_bytes(b"12345")
    inject(initrd, b"kickstart", dest)
    written = dest.read_bytes()
    assert written[:8] == b"12345\0\0\0"
    assert parse_newc(written[8:])[0] == ("ks.cfg", 0o100644, b"kickstart")


def test_fedora_version(tmp_path: Path) -> None:
    containerfile = tmp_path / "Containerfile.kde"
    containerfile.write_text(
        "ARG FEDORA_MAJOR_VERSION=44\n\nFROM quay.io/x:${FEDORA_MAJOR_VERSION}\n"
    )
    assert fedora_version(containerfile) == 44
    containerfile.write_text("FROM scratch\n")
    with pytest.raises(BadInput, match="sets no ARG FEDORA_MAJOR_VERSION"):
        fedora_version(containerfile)


def test_find_iso(tmp_path: Path) -> None:
    with pytest.raises(MissingPrerequisite) as missing:
        find_iso(tmp_path, 44)
    assert "releases/44/Everything/x86_64/iso/" in str(missing.value)
    (tmp_path / ISO_NAME).touch()
    (tmp_path / "Fedora-Everything-netinst-x86_64-45-1.2.iso").touch()
    assert find_iso(tmp_path, 44) == tmp_path / ISO_NAME
    (tmp_path / "Fedora-Everything-netinst-x86_64-44-1.8.iso").touch()
    with pytest.raises(BadInput, match="keep one"):
        find_iso(tmp_path, 44)


def test_volume_label() -> None:
    output = "xorriso 1.5\nVolume Id    : Fedora-E-dvd-x86_64-44\nApp Id       : Fedora\n"
    runner = FakeRunner(lambda _: Result(returncode=0, stdout=output, stderr=""))
    assert volume_label(Path("x.iso"), runner=runner) == "Fedora-E-dvd-x86_64-44"
    with pytest.raises(StepFailed, match="no volume ID"):
        volume_label(Path("x.iso"), runner=FakeRunner())


def test_kernel_cmdline() -> None:
    assert kernel_cmdline("LABEL-44", "10.0.2.2:5000/desktop22/workstation-kde:test").split() == [
        "inst.ks=file:/ks.cfg",
        "inst.stage2=hd:LABEL=LABEL-44",
        "inst.text",
        "console=ttyS0",
        "imgman.url=10.0.2.2:5000/desktop22/workstation-kde:test",
        "imgman.disk=vda",
        "imgman.insecure-registry=10.0.2.2:5000",
        "imgman.luks-passphrase=imgman",
    ]


def test_install_args_use_the_hosts_resources_and_data_disks() -> None:
    config = HostConfig(flavor=KDE, data_disks=(Size("10G"),), memory=Size("6G"), cpus=4)
    args = install_args(
        config=config,
        vars_file=Path("/w/VARS.fd"),
        disk=Path("/c/disk.qcow2"),
        data_disks=[Path("/w/data1.qcow2")],
        iso=Path("/i.iso"),
        kernel=Path("/w/vmlinuz"),
        initrd=Path("/w/initrd-ks.img"),
        cmdline="inst.text",
        console=Path("/w/console.log"),
    )
    assert args[args.index("-m") + 1] == "6G"
    assert args[args.index("-smp") + 1] == "4"
    drives = [args[i + 1] for i, arg in enumerate(args) if arg == "-drive"]
    assert drives[2:] == [
        "if=virtio,format=qcow2,file=/c/disk.qcow2",
        "if=virtio,format=qcow2,file=/w/data1.qcow2",
        "media=cdrom,readonly=on,file=/i.iso",
    ]
    assert "secboot" not in " ".join(args)
    assert args[-1] == "-no-reboot"


def test_watch_returns_when_the_installer_exits_cleanly(tmp_path: Path) -> None:
    clock = FakeClock()
    process = FakeProcess(code=0, polls=3)
    watch(process, tmp_path / "console.log", clock=clock, sleep=clock.sleep)
    assert not process.killed


def test_watch_reports_a_nonzero_exit(tmp_path: Path) -> None:
    with pytest.raises(StepFailed, match="exited with status 1"):
        watch(FakeProcess(code=1), tmp_path / "console.log")


def test_watch_stops_the_vm_when_the_installer_reports_an_error(tmp_path: Path) -> None:
    console = tmp_path / "console.log"
    console.write_text("\x1b[0mrunning\r\npyanaconda.errors.ScriptError\nsystem disk missing\n")
    process = FakeProcess(code=None)
    with pytest.raises(StepFailed, match=r"reported an error \(ScriptError\)") as raised:
        watch(process, console)
    assert process.killed
    assert "    system disk missing" in str(raised.value)


def test_watch_times_out(tmp_path: Path) -> None:
    clock = FakeClock()
    process = FakeProcess(code=None)
    with pytest.raises(StepFailed, match="did not finish within 30 minutes"):
        watch(process, tmp_path / "console.log", clock=clock, sleep=clock.sleep)
    assert process.killed


def test_console_tail_drops_escapes_and_blank_lines(tmp_path: Path) -> None:
    console = tmp_path / "console.log"
    console.write_text("\x1b[1mone\x1b[0m\r\n\n" + "\n".join(f"line{i}" for i in range(40)))
    tail = console_tail(console).splitlines()
    assert tail[0] == "    line10" and tail[-1] == "    line39"
    assert console_tail(tmp_path / "missing.log") == "(no console output)"


def test_inputs_round_trip() -> None:
    inputs = Inputs(
        image_id=installer.images.ImageId("sha256:id"),
        kickstart_sha256="abc",
        digest=installer.registry.Digest("sha256:digest"),
    )
    assert parse_inputs(inputs.to_json()) == inputs
    assert parse_inputs("not json") is None
    assert parse_inputs(json.dumps({"image_id": "x"})) is None


# A whole install, with every external command faked.


def respond(argv: list[str]) -> Result:
    """Answers the commands an install runs, creating the files they would."""
    match argv[:3]:
        case ["podman", "image", "inspect"]:
            return Result(returncode=0, stdout="sha256:image\n", stderr="")
        case ["podman", "push", *_]:
            Path(argv[argv.index("--digestfile") + 1]).write_text("sha256:digest\n")
        case ["xorriso", "-indev", _]:
            return Result(returncode=0, stdout="Volume Id : FEDORA-44\n", stderr="")
        case ["xorriso", "-osirrox", _]:
            for i, arg in enumerate(argv):
                if arg == "-extract":
                    Path(argv[i + 2]).write_bytes(b"boot")
        case ["qemu-img", "create", *_]:
            Path(argv[-2]).touch()
        case _:
            pass
    return OK


@pytest.fixture
def setup(checkout: Checkout, tmp_path: Path) -> tuple[Checkout, Cache]:
    checkout.containerfile(KDE).write_text("ARG FEDORA_MAJOR_VERSION=44\n")
    kickstart = checkout.kickstart(D22)
    kickstart.parent.mkdir()
    kickstart.write_text("text\n")
    cache = Cache(root=tmp_path / "cache")
    cache.iso_dir.mkdir(parents=True)
    (cache.iso_dir / ISO_NAME).touch()
    return checkout, cache


def run_install(
    setup: tuple[Checkout, Cache], hosts: Hosts, runner: FakeRunner, tmp_path: Path
) -> list[list[str]]:
    checkout, cache = setup
    spawned: list[list[str]] = []

    def spawner(args: object) -> FakeProcess:
        assert isinstance(args, list)
        spawned.append([str(arg) for arg in args])
        return FakeProcess(code=0)

    vars_file = tmp_path / "OVMF_VARS.fd"
    vars_file.write_bytes(b"vars")
    install(
        host=D22,
        config=hosts[D22],
        flavor=KDE,
        cache=cache,
        checkout=checkout,
        command_line="imgman machine init",
        runner=runner,
        spawner=spawner,
        ovmf_vars=vars_file,
        registry_ready=lambda: True,
    )
    return spawned


def test_install_runs_the_installer_and_records_its_inputs(
    setup: tuple[Checkout, Cache], hosts: Hosts, tmp_path: Path
) -> None:
    _, cache = setup
    runner = FakeRunner(respond)
    [qemu] = run_install(setup, hosts, runner, tmp_path)
    # The fixture created the cache, so ensure_cache has nothing to do.
    assert runner.commands() == [
        "podman image",
        "podman container",
        "podman start",
        "podman push",
        "xorriso -indev",
        "xorriso -osirrox",
        "qemu-img create",
        "qemu-img create",
    ]
    assert (
        "imgman.url=10.0.2.2:5000/desktop22/workstation-kde:test" in qemu[qemu.index("-append") + 1]
    )
    assert cache.disk(D22, KDE).exists()
    inputs = parse_inputs(cache.inputs(D22, KDE).read_text())
    assert inputs is not None
    assert (inputs.image_id, inputs.digest) == ("sha256:image", "sha256:digest")
    # Only the console log stays behind; the boot files and data disks are removed.
    assert sorted(path.name for path in cache.install_dir(D22).iterdir()) == []


def test_install_needs_the_built_image(
    setup: tuple[Checkout, Cache], hosts: Hosts, tmp_path: Path
) -> None:
    _, cache = setup

    def no_image(argv: list[str]) -> Result:
        return (
            Result(returncode=125, stdout="", stderr="") if argv[:2] == ["podman", "image"] else OK
        )

    with pytest.raises(MissingPrerequisite, match="imgman image build kde"):
        run_install(setup, hosts, FakeRunner(no_image), tmp_path)
    assert not cache.inputs(D22, KDE).exists()


def test_install_checks_for_the_iso_before_running_anything(
    setup: tuple[Checkout, Cache], hosts: Hosts, tmp_path: Path
) -> None:
    _, cache = setup
    (cache.iso_dir / ISO_NAME).unlink()
    runner = FakeRunner(respond)
    with pytest.raises(MissingPrerequisite, match="netinst ISO"):
        run_install(setup, hosts, runner, tmp_path)
    assert runner.calls == []
