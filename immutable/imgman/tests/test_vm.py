from pathlib import Path

from imgman.vm import running_pid


def write_proc(proc: Path, pid: int, cmdline: str) -> None:
    (proc / str(pid)).mkdir(parents=True)
    (proc / str(pid) / "cmdline").write_bytes(cmdline.replace(" ", "\0").encode())


def test_running_pid(tmp_path: Path) -> None:
    run_dir, proc = tmp_path / "run", tmp_path / "proc"
    assert running_pid(run_dir, proc=proc) is None
    run_dir.mkdir()
    (run_dir / "qemu.pid").write_text("42\n")
    assert running_pid(run_dir, proc=proc) is None
    write_proc(proc, 42, f"qemu-system-x86_64 -drive file={run_dir / 'overlay.qcow2'}")
    assert running_pid(run_dir, proc=proc) == 42


def test_a_stale_pid_naming_another_process_is_not_running(tmp_path: Path) -> None:
    run_dir, proc = tmp_path / "run", tmp_path / "proc"
    run_dir.mkdir()
    (run_dir / "qemu.pid").write_text("42\n")
    write_proc(proc, 42, "bash")
    assert running_pid(run_dir, proc=proc) is None
