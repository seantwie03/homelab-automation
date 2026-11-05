import base64
import signal
from collections.abc import Sequence
from pathlib import Path

import pytest

from imgman.cache import Cache
from imgman.errors import MissingPrerequisite, StepFailed
from imgman.hosts import Flavor, HostConfig, HostName, Size
from imgman.machine import remove_machine
from imgman.process import Result
from imgman.vm import (
    RunDir,
    boot,
    boot_args,
    gui,
    root_key_tmpfiles,
    running_pid,
    ssh,
    ssh_args,
    stop,
    wait_for_boot,
)
from tests.fakes import OK, FakeClock, FakeProcess, FakeRunner

D22 = HostName("desktop22")
CONFIG = HostConfig(flavor=Flavor("kde"), data_disks=(Size("10G"),), memory=Size("6G"), cpus=4)


def write_proc(proc: Path, pid: int, cmdline: str) -> None:
    (proc / str(pid)).mkdir(parents=True)
    (proc / str(pid) / "cmdline").write_bytes(cmdline.replace(" ", "\0").encode())


def start_fake_vm(run_dir: Path, proc: Path, pid: int = 42) -> None:
    """Makes RUN_DIR look like a VM that is running as PID."""
    run_dir.mkdir(exist_ok=True)
    (run_dir / "qemu.pid").write_text(f"{pid}\n")
    (run_dir / "cid").write_text("1234\n")
    write_proc(proc, pid, f"qemu-system-x86_64 -drive file={run_dir / 'overlay.qcow2'}")


def test_running_pid(tmp_path: Path) -> None:
    run_dir, proc = tmp_path / "run", tmp_path / "proc"
    assert running_pid(run_dir, proc=proc) is None
    start_fake_vm(run_dir, proc)
    assert running_pid(run_dir, proc=proc) == 42


def test_a_stale_pid_naming_another_process_is_not_running(tmp_path: Path) -> None:
    run_dir, proc = tmp_path / "run", tmp_path / "proc"
    run_dir.mkdir()
    (run_dir / "qemu.pid").write_text("42\n")
    write_proc(proc, 42, "bash")
    assert running_pid(run_dir, proc=proc) is None


def credentials(args: list[str]) -> dict[str, str]:
    """Decodes the systemd credentials in QEMU's -smbios arguments."""
    found: dict[str, str] = {}
    for i, arg in enumerate(args):
        if arg == "-smbios":
            name, value = args[i + 1].split("io.systemd.credential.binary:", 1)[1].split("=", 1)
            found[name] = base64.b64decode(value).decode()
    return found


@pytest.mark.parametrize("gui_on", [True, False])
def test_boot_args(tmp_path: Path, gui_on: bool) -> None:
    files = RunDir(path=tmp_path)
    args = boot_args(
        host=D22,
        config=CONFIG,
        files=files,
        data_disks=[tmp_path / "data1.qcow2"],
        cid=1234,
        public_key="ssh-ed25519 KEY imgman",
        gui=gui_on,
    )
    joined = " ".join(args)
    assert "q35,accel=kvm,smm=on" in joined
    assert "driver=cfi.pflash01,property=secure,value=on" in joined
    assert "OVMF_CODE.secboot.fd" in joined
    assert f"file={tmp_path / 'data1.qcow2'}" in joined
    assert "vhost-vsock-pci,guest-cid=1234" in joined
    assert "virtio-vga" in args
    assert ("-spice" in args) == gui_on
    assert credentials(args) == {
        "tmpfiles.extra": root_key_tmpfiles("ssh-ed25519 KEY imgman"),
        "system.hostname": "desktop22",
        "cryptsetup.passphrase": "imgman",
        "systemd.unit-dropin.ansible-pull.service": "[Unit]\nConditionVirtualization=!vm\n",
    }


def test_root_key_tmpfiles_writes_the_key_under_var_roothome() -> None:
    lines = root_key_tmpfiles("ssh-ed25519 KEY").splitlines()
    assert lines[-1].startswith("f+~ /var/roothome/.ssh/authorized_keys 0600 root root - ")
    assert base64.b64decode(lines[-1].split()[-1]) == b"ssh-ed25519 KEY"


def test_ssh_args(tmp_path: Path) -> None:
    (tmp_path / "cid").write_text("1234\n")
    args = ssh_args(tmp_path, ["echo", "a b"], tty=False)
    assert args[:2] == ["ssh", "-T"]
    assert args[-2:] == ["vsock/1234", "echo 'a b'"]
    assert ssh_args(tmp_path, [], tty=True)[1] == "-t"
    assert ssh_args(tmp_path, [], tty=True)[-1] == "vsock/1234"


def test_stop_terminates_qemu_and_removes_the_run_directory(tmp_path: Path) -> None:
    run_dir, proc = tmp_path / "run", tmp_path / "proc"
    start_fake_vm(run_dir, proc)
    signals: list[tuple[int, int]] = []

    def kill(pid: int, sig: int) -> None:
        signals.append((pid, sig))
        (proc / str(pid) / "cmdline").unlink()
        (proc / str(pid)).rmdir()

    assert stop(run_dir, proc=proc, kill=kill)
    assert signals == [(42, signal.SIGTERM)]
    assert not run_dir.exists()


def test_stop_kills_qemu_that_ignores_sigterm(tmp_path: Path) -> None:
    run_dir, proc = tmp_path / "run", tmp_path / "proc"
    start_fake_vm(run_dir, proc)
    signals: list[int] = []
    clock = FakeClock()
    stop(
        run_dir, proc=proc, kill=lambda _, sig: signals.append(sig), clock=clock, sleep=clock.sleep
    )
    assert signals == [signal.SIGTERM, signal.SIGKILL]


def test_stop_without_a_vm_removes_leftovers(tmp_path: Path) -> None:
    run_dir = tmp_path / "run"
    run_dir.mkdir()
    assert not stop(run_dir, proc=tmp_path / "proc")
    assert not run_dir.exists()


def boot_runner(qemu_results: list[Result]) -> FakeRunner:
    """Answers boot's commands, creating the key, and QEMU with each of QEMU_RESULTS in turn."""
    results = iter(qemu_results)

    def respond(argv: list[str]) -> Result:
        if argv[0] == "ssh-keygen":
            key = Path(argv[argv.index("-f") + 1])
            key.write_text("private")
            key.with_suffix(".pub").write_text("ssh-ed25519 KEY")
        if argv[0] == "qemu-system-x86_64":
            return next(results)
        return OK

    return FakeRunner(respond)


def run_boot(tmp_path: Path, runner: FakeRunner, cids: list[int]) -> Path:
    vars_file = tmp_path / "VARS.secboot.fd"
    vars_file.write_bytes(b"vars")
    run_dir = tmp_path / "run"
    remaining = iter(cids)
    boot(
        host=D22,
        config=CONFIG,
        disk=tmp_path / "disk.qcow2",
        run_dir=run_dir,
        gui=True,
        runner=runner,
        choose_cid=lambda: next(remaining),
        ovmf_vars=vars_file,
    )
    return run_dir


IN_USE = Result(returncode=1, stdout="", stderr="unable to set guest cid: Address already in use")


def test_boot_tries_another_cid_when_one_is_in_use(tmp_path: Path) -> None:
    runner = boot_runner([IN_USE, OK])
    run_dir = run_boot(tmp_path, runner, [1111, 2222])
    assert runner.commands() == [
        "ssh-keygen -q",
        "qemu-img create",
        "qemu-img create",
        "qemu-system-x86_64 -machine",
        "qemu-system-x86_64 -machine",
    ]
    assert (run_dir / "cid").read_text() == "2222\n"
    assert (run_dir / "OVMF_VARS.fd").stat().st_mode & 0o777 == 0o600


def test_boot_reports_other_qemu_errors(tmp_path: Path) -> None:
    failed = Result(returncode=1, stdout="", stderr="could not open disk")
    with pytest.raises(StepFailed, match="QEMU did not start: could not open disk"):
        run_boot(tmp_path, boot_runner([failed]), [1111])


def test_boot_gives_up_after_five_cids(tmp_path: Path) -> None:
    with pytest.raises(StepFailed, match="no free vsock context ID after 5 tries"):
        run_boot(tmp_path, boot_runner([IN_USE] * 5), [1, 2, 3, 4, 5])


def test_wait_for_boot_waits_for_a_new_boot_id(tmp_path: Path) -> None:
    (tmp_path / "cid").write_text("1234\n")
    answers = iter(
        [
            Result(returncode=255, stdout="", stderr=""),
            Result(returncode=0, stdout="old\n", stderr=""),
            Result(returncode=0, stdout="new\n", stderr=""),
        ]
    )
    clock = FakeClock()
    wait_for_boot(
        tmp_path,
        previous="old",
        runner=FakeRunner(lambda _: next(answers)),
        clock=clock,
        sleep=clock.sleep,
    )
    assert clock.now == 6


def test_wait_for_boot_times_out_with_the_console(tmp_path: Path) -> None:
    (tmp_path / "cid").write_text("1234\n")
    (tmp_path / "console.log").write_text("Booting\nKernel panic\n")
    clock = FakeClock()
    unanswered = FakeRunner(lambda _: Result(returncode=255, stdout="", stderr=""))
    with pytest.raises(StepFailed, match="did not answer over SSH") as raised:
        wait_for_boot(tmp_path, runner=unanswered, clock=clock, sleep=clock.sleep)
    assert "    Kernel panic" in str(raised.value)


def test_ssh_needs_a_running_vm(tmp_path: Path) -> None:
    with pytest.raises(MissingPrerequisite, match="imgman machine run desktop22"):
        ssh(D22, tmp_path / "run", [], proc=tmp_path / "proc")


def test_ssh_runs_the_command_and_reports_its_failure(tmp_path: Path) -> None:
    run_dir, proc = tmp_path / "run", tmp_path / "proc"
    start_fake_vm(run_dir, proc)
    runner = FakeRunner()
    ssh(D22, run_dir, ["bootc", "status"], runner=runner, proc=proc)
    assert runner.calls[0][-1] == "bootc status"
    failing = FakeRunner(lambda _: Result(returncode=2, stdout="", stderr=""))
    with pytest.raises(StepFailed, match="exited with status 2"):
        ssh(D22, run_dir, ["false"], runner=failing, proc=proc)


def test_gui_opens_the_spice_socket(tmp_path: Path) -> None:
    run_dir, proc = tmp_path / "run", tmp_path / "proc"
    start_fake_vm(run_dir, proc)
    spawned: list[list[str]] = []

    def spawner(args: Sequence[str | Path]) -> FakeProcess:
        spawned.append([str(arg) for arg in args])
        return FakeProcess(code=None)

    with pytest.raises(MissingPrerequisite, match="without --no-gui"):
        gui(D22, run_dir, spawner=spawner, proc=proc)
    (run_dir / "spice.sock").touch()
    gui(D22, run_dir, spawner=spawner, proc=proc)
    assert spawned == [["remote-viewer", f"spice+unix://{run_dir / 'spice.sock'}"]]


def test_remove_machine_without_a_vm(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    remove_machine(host=D22, cache=Cache(root=tmp_path), command_line="imgman machine rm")
    assert capsys.readouterr().out == "desktop22's VM is not running\n"
