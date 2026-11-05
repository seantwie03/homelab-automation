"""A host's VM, booted from a throwaway overlay in the host's run directory."""

from pathlib import Path

PROC = Path("/proc")


def running_pid(run_dir: Path, *, proc: Path = PROC) -> int | None:
    """Returns the PID of the QEMU process booted from RUN_DIR, if it still runs."""
    try:
        pid = int((run_dir / "qemu.pid").read_text().strip())
        cmdline = (proc / str(pid) / "cmdline").read_bytes()
    except OSError, ValueError:
        return None
    # A stale PID file can name an unrelated process, so match the overlay.
    return pid if str(run_dir / "overlay.qcow2").encode() in cmdline else None
