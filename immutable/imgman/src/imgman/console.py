"""Reading a VM's serial console log."""

import re
from pathlib import Path

ANSI_ESCAPE = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
CONSOLE_LINES = 30


def console_tail(console: Path, lines: int = CONSOLE_LINES) -> str:
    """Returns the last LINES of a console log, without terminal escape sequences."""
    try:
        text = console.read_text(errors="replace")
    except OSError:
        return "(no console output)"
    clean = ANSI_ESCAPE.sub("", text.replace("\r", ""))
    return "\n".join(f"    {line}" for line in clean.splitlines()[-lines:] if line.strip())
