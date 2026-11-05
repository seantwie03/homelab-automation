"""machine init: installing a host's VM disk with Anaconda and the host's kickstart."""

import hashlib
import json
import re
import shutil
import time
from collections.abc import Callable, Sequence
from dataclasses import asdict, dataclass
from pathlib import Path

from imgman import images, registry
from imgman.cache import Cache, ensure_cache
from imgman.checkout import Checkout
from imgman.console import console_tail
from imgman.errors import BadInput, MissingPrerequisite, StepFailed
from imgman.hosts import Flavor, HostConfig, HostName, Size
from imgman.lock import host_lock
from imgman.output import log, step
from imgman.prerequisites import OVMF_CODE, OVMF_VARS
from imgman.process import Process, Runner, Spawner, run, spawn
from imgman.vm import TEST_PASSPHRASE, running_pid

ISO_GLOB = "Fedora-Everything-netinst-x86_64-{version}-*.iso"
ISO_URL = (
    "https://download.fedoraproject.org/pub/fedora/linux/releases/{version}/Everything/x86_64/iso/"
)
DISK_SIZE = Size("40G")
INSTALL_TIMEOUT_SECONDS = 30 * 60
POLL_SECONDS = 5.0
# Anaconda prints these when an install fails, then waits forever at its error screen.
FAILURE_MARKERS = ("ScriptError", "An error occurred", "Traceback (most recent call last)")


@dataclass(frozen=True, slots=True, kw_only=True)
class Inputs:
    """What a disk was installed from, recorded next to it.

    The image ID and kickstart hash decide staleness. The digest is what
    bootc status reports on the installed VM.
    """

    image_id: images.ImageId
    kickstart_sha256: str
    digest: registry.Digest

    def to_json(self) -> str:
        return json.dumps(asdict(self), indent=2) + "\n"


def parse_inputs(text: str) -> Inputs | None:
    """Parses an .inputs file, or returns None if it is not one."""
    try:
        record: object = json.loads(text)
    except json.JSONDecodeError:
        return None
    if not isinstance(record, dict):
        return None
    image_id, sha, digest = (
        record.get("image_id"),
        record.get("kickstart_sha256"),
        record.get("digest"),
    )
    if not (isinstance(image_id, str) and isinstance(sha, str) and isinstance(digest, str)):
        return None
    return Inputs(
        image_id=images.ImageId(image_id),
        kickstart_sha256=sha,
        digest=registry.Digest(digest),
    )


def fedora_version(containerfile: Path) -> int:
    """Returns the FEDORA_MAJOR_VERSION a Containerfile builds on."""
    match = re.search(r"^ARG FEDORA_MAJOR_VERSION=(\d+)$", containerfile.read_text(), re.MULTILINE)
    if match is None:
        raise BadInput(f"{containerfile} sets no ARG FEDORA_MAJOR_VERSION")
    return int(match.group(1))


def find_iso(iso_dir: Path, version: int) -> Path:
    """Returns the one Fedora VERSION netinst ISO in ISO_DIR.

    imgman never downloads it: you download, verify, and place it yourself.
    """
    pattern = ISO_GLOB.format(version=version)
    found = sorted(iso_dir.glob(pattern)) if iso_dir.is_dir() else []
    if not found:
        raise MissingPrerequisite(
            "\n".join(
                [
                    "missing prerequisites:",
                    f"    the Fedora {version} netinst ISO in {iso_dir}/",
                    f"        Download {pattern} and its CHECKSUM file from",
                    f"        {ISO_URL.format(version=version)}",
                    (
                        '        then verify and place it as described in "Installer ISO" '
                        "in imgman/README.md."
                    ),
                ]
            )
        )
    if len(found) > 1:
        names = ", ".join(path.name for path in found)
        raise BadInput(f"more than one Fedora {version} ISO in {iso_dir}; keep one: {names}")
    return found[0]


def volume_label(iso: Path, *, runner: Runner = run) -> str:
    """Returns the ISO's volume ID, which the installer finds its stage 2 by."""
    output = runner(["xorriso", "-indev", iso, "-pvd_info"], capture=True).stdout
    match = re.search(r"^Volume Id\s*:\s*(\S+)\s*$", output, re.MULTILINE)
    if match is None:
        raise StepFailed(f"xorriso reported no volume ID for {iso}")
    return match.group(1)


def extract_boot_files(iso: Path, dest: Path, *, runner: Runner = run) -> tuple[Path, Path]:
    """Extracts the installer's kernel and initrd from ISO into DEST."""
    kernel, initrd = dest / "vmlinuz", dest / "initrd.img"
    runner(
        [
            "xorriso", "-osirrox", "on", "-indev", iso,
            "-extract", "/images/pxeboot/vmlinuz", kernel,
            "-extract", "/images/pxeboot/initrd.img", initrd,
        ],
        capture=True,
    )  # fmt: skip
    # xorriso keeps the ISO's read-only modes, which would stop later cleanup.
    for path in (kernel, initrd):
        path.chmod(0o644)
    return kernel, initrd


def _newc_entry(name: bytes, data: bytes, *, ino: int, mode: int) -> bytes:
    fields = (ino, mode, 0, 0, 1, 0, len(data), 0, 0, 0, 0, len(name) + 1, 0)
    entry = b"070701" + b"".join(f"{field:08X}".encode() for field in fields) + name + b"\0"
    entry += b"\0" * (-len(entry) % 4)
    return entry + data + b"\0" * (-len(data) % 4)


def newc_archive(name: str, data: bytes) -> bytes:
    """Returns a cpio archive in the kernel's initramfs format holding one regular file."""
    return _newc_entry(name.encode(), data, ino=1, mode=0o100644) + _newc_entry(
        b"TRAILER!!!", b"", ino=0, mode=0
    )


def inject(initrd: Path, kickstart: bytes, dest: Path) -> None:
    """Writes INITRD with KICKSTART appended as /ks.cfg to DEST, as virt-install --initrd-inject does.

    The kernel unpacks concatenated archives in order and skips zero padding between them.
    """
    shutil.copyfile(initrd, dest)
    with dest.open("ab") as out:
        out.write(b"\0" * (-dest.stat().st_size % 4))
        out.write(newc_archive("ks.cfg", kickstart))


def kernel_cmdline(label: str, image_ref: str) -> str:
    """Returns the installer's kernel command line for a VM install from the test registry."""
    return " ".join(
        [
            "inst.ks=file:/ks.cfg",
            f"inst.stage2=hd:LABEL={label}",
            "inst.text",
            "console=ttyS0",
            f"imgman.url={image_ref}",
            "imgman.disk=vda",
            f"imgman.insecure-registry={registry.GUEST_ADDRESS}",
            f"imgman.luks-passphrase={TEST_PASSPHRASE}",
        ]
    )


def install_args(
    *,
    config: HostConfig,
    vars_file: Path,
    disk: Path,
    data_disks: Sequence[Path],
    iso: Path,
    kernel: Path,
    initrd: Path,
    cmdline: str,
    console: Path,
) -> list[str]:
    """Returns QEMU's arguments for an install.

    The installer boots with the standard firmware: firmware enforcing Secure
    Boot accepts only Microsoft's keys for a kernel passed with -kernel, and
    Fedora's kernel is signed by Fedora, which only shim trusts. -no-reboot
    turns the kickstart's final reboot into QEMU exiting.
    """
    data = [arg for path in data_disks for arg in ("-drive", f"if=virtio,format=qcow2,file={path}")]
    return [
        "qemu-system-x86_64",
        "-machine", "q35,accel=kvm", "-cpu", "host",
        "-smp", str(config.cpus), "-m", config.memory,
        "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF_CODE}",
        "-drive", f"if=pflash,format=raw,file={vars_file}",
        "-drive", f"if=virtio,format=qcow2,file={disk}",
        *data,
        "-drive", f"media=cdrom,readonly=on,file={iso}",
        "-netdev", "user,id=net0", "-device", "virtio-net-pci,netdev=net0",
        "-kernel", str(kernel), "-initrd", str(initrd), "-append", cmdline,
        "-display", "none", "-serial", f"file:{console}", "-no-reboot",
    ]  # fmt: skip


def is_blank(image: Path, *, runner: Runner = run) -> bool:
    """Reports whether no block of the qcow2 IMAGE holds data."""
    output = runner(["qemu-img", "map", "--output=json", image], capture=True).stdout
    extents: object = json.loads(output)
    if not isinstance(extents, list):
        raise StepFailed(f"qemu-img map printed no extent list for {image}")
    items: list[object] = extents
    return not any(isinstance(extent, dict) and extent.get("data") is True for extent in items)


def watch(
    process: Process,
    console: Path,
    *,
    timeout: float = INSTALL_TIMEOUT_SECONDS,
    clock: Callable[[], float] = time.monotonic,
    sleep: Callable[[float], None] = time.sleep,
) -> None:
    """Waits for the installer VM to exit after a successful install.

    Anaconda waits forever at an error, so a failure marker in CONSOLE stops
    QEMU at once, and the timeout catches a hang that prints none.
    """
    deadline = clock() + timeout
    while True:
        code = process.poll()
        try:
            text = console.read_text(errors="replace")
        except OSError:
            text = ""
        marker = next((m for m in FAILURE_MARKERS if m in text), None)
        if marker is not None:
            process.kill()
            process.wait()
            raise StepFailed(
                f"the installer reported an error ({marker}); last console lines:\n"
                + console_tail(console)
            )
        if code is not None:
            if code != 0:
                raise StepFailed(
                    f"the installer VM exited with status {code}; last console lines:\n"
                    + console_tail(console)
                )
            return
        if clock() >= deadline:
            process.kill()
            process.wait()
            raise StepFailed(
                f"the install did not finish within {timeout / 60:.0f} minutes; "
                "last console lines:\n" + console_tail(console)
            )
        sleep(POLL_SECONDS)


def install(
    *,
    host: HostName,
    config: HostConfig,
    flavor: Flavor,
    cache: Cache,
    checkout: Checkout,
    command_line: str,
    runner: Runner = run,
    spawner: Spawner = spawn,
    ovmf_vars: Path = OVMF_VARS,
    registry_ready: Callable[[], bool] = registry.answers,
) -> None:
    """Installs HOST's VM disk for FLAVOR with the host's kickstart, holding the host's lock."""
    ensure_cache(cache, runner=runner)
    with host_lock(cache.host_dir(host), host, command=command_line):
        install_holding_lock(
            host=host,
            config=config,
            flavor=flavor,
            cache=cache,
            checkout=checkout,
            runner=runner,
            spawner=spawner,
            ovmf_vars=ovmf_vars,
            registry_ready=registry_ready,
        )


def install_holding_lock(
    *,
    host: HostName,
    config: HostConfig,
    flavor: Flavor,
    cache: Cache,
    checkout: Checkout,
    runner: Runner = run,
    spawner: Spawner = spawn,
    ovmf_vars: Path = OVMF_VARS,
    registry_ready: Callable[[], bool] = registry.answers,
) -> None:
    """Installs HOST's VM disk. The caller holds the host's lock."""
    kickstart_path = checkout.kickstart(host)
    kickstart = kickstart_path.read_bytes()
    iso = find_iso(cache.iso_dir, fedora_version(checkout.containerfile(flavor)))
    if running_pid(cache.run_dir(host)) is not None:
        raise MissingPrerequisite(
            f"{host}'s VM is running; stop it with 'imgman machine rm {host}'"
        )
    image = images.image_ref(flavor)
    image_id = images.image_id(flavor, runner=runner)
    if image_id is None:
        raise MissingPrerequisite(f"no image {image}; build it with 'imgman image build {flavor}'")
    inputs_file = cache.inputs(host, flavor)
    # Written only after a successful install, so an interrupted one leaves the disk stale.
    inputs_file.unlink(missing_ok=True)

    with step("push to the test registry"):
        registry.start(cache, runner=runner, ready=registry_ready)
        digest = registry.push(
            image, registry.install_ref(registry.HOST_ADDRESS, host, flavor), runner=runner
        )

    work = cache.install_dir(host)
    shutil.rmtree(work, ignore_errors=True)
    work.mkdir(parents=True)
    with step("prepare the installer"):
        label = volume_label(iso, runner=runner)
        kernel, initrd = extract_boot_files(iso, work, runner=runner)
        initrd_ks = work / "initrd-ks.img"
        inject(initrd, kickstart, initrd_ks)
        initrd.unlink()
        vars_file = work / "OVMF_VARS.fd"
        shutil.copyfile(ovmf_vars, vars_file)
        vars_file.chmod(0o644)
        data_disks = [work / f"data{n}.qcow2" for n in range(1, len(config.data_disks) + 1)]
        disk = cache.disk(host, flavor)
        disk.unlink(missing_ok=True)
        for path, size in [(disk, DISK_SIZE), *zip(data_disks, config.data_disks, strict=True)]:
            runner(["qemu-img", "create", "-q", "-f", "qcow2", path, size], capture=True)

    console = work / "console.log"
    log(
        f"installing {host} ({flavor}) with {kickstart_path.relative_to(checkout.root)}, "
        f"about 7 minutes; the installer's console is {console}"
    )
    args = install_args(
        config=config,
        vars_file=vars_file,
        disk=disk,
        data_disks=data_disks,
        iso=iso,
        kernel=kernel,
        initrd=initrd_ks,
        cmdline=kernel_cmdline(label, registry.install_ref(registry.GUEST_ADDRESS, host, flavor)),
        console=console,
    )
    with step(f"install {host}"):
        watch(spawner(args), console)
    for path in data_disks:
        if not is_blank(path, runner=runner):
            raise StepFailed(f"the install wrote to {path.name}, a data disk it must leave alone")

    for leftover in (kernel, initrd_ks, vars_file, *data_disks):
        leftover.unlink()
    inputs = Inputs(
        image_id=image_id,
        kickstart_sha256=hashlib.sha256(kickstart).hexdigest(),
        digest=digest,
    )
    inputs_file.write_text(inputs.to_json())


def disk_is_stale(
    *,
    host: HostName,
    flavor: Flavor,
    cache: Cache,
    checkout: Checkout,
    runner: Runner = run,
) -> bool:
    """Reports whether HOST's disk for FLAVOR is missing or was installed from other inputs.

    Inputs are the image ID and the kickstart's content, never file timestamps.
    """
    try:
        recorded = parse_inputs(cache.inputs(host, flavor).read_text())
    except OSError:
        return True
    if recorded is None or not cache.disk(host, flavor).exists():
        return True
    sha = hashlib.sha256(checkout.kickstart(host).read_bytes()).hexdigest()
    image = images.image_id(flavor, runner=runner)
    return recorded.image_id != image or recorded.kickstart_sha256 != sha
