from pathlib import Path

import pytest

from imgman.checkout import Checkout
from imgman.errors import StepFailed
from imgman.hosts import HostName
from imgman.playbook import (
    Recap,
    converge_twice,
    parse_recap,
    playbook_command,
    playbook_paths,
    rsync_args,
    run_playbook,
)
from imgman.process import Result
from tests.fakes import OK, FakeRunner

X1 = HostName("x1carbon23")


def recap_line(changed: int, failed: int = 0) -> str:
    return (
        f"PLAY RECAP ****\nlocalhost : ok=12 changed={changed} unreachable=0 "
        f"failed={failed} skipped=3 rescued=0 ignored=0\n"
    )


def test_parse_recap_takes_the_last_recap() -> None:
    output = recap_line(4) + "more\n" + recap_line(0)
    assert parse_recap(output) == Recap(ok=12, changed=0, unreachable=0, failed=0)
    assert parse_recap("no recap here") is None


@pytest.mark.parametrize(
    ("subdirectory", "expected"),
    [
        ("immutable", ("immutable/x1carbon23.yml", "immutable/ansible.cfg")),
        ("", ("x1carbon23.yml", "ansible.cfg")),
    ],
)
def test_playbook_paths_follow_the_checkout(
    tmp_path: Path, subdirectory: str, expected: tuple[str, str]
) -> None:
    checkout = Checkout(root=tmp_path / subdirectory if subdirectory else tmp_path)
    assert playbook_paths(checkout, X1, tmp_path) == expected


def test_rsync_reaches_the_vm_through_the_ssh_proxy(tmp_path: Path) -> None:
    (tmp_path / "cid").write_text("1234\n")
    args = rsync_args(tmp_path, Path("/repo"))
    assert args[-2:] == ["/repo/", "root@imgman-vm:/opt/homelab-automation/"]
    assert "--exclude=.git" in args and "--filter=:- .gitignore" in args
    rsh = args[args.index("--rsh") + 1]
    assert "'ProxyCommand=/usr/lib/systemd/systemd-ssh-proxy vsock/1234 %p'" in rsh
    assert "ProxyUseFdpass=yes" in rsh


def test_playbook_command_uses_the_overlay_configuration() -> None:
    command = playbook_command("immutable/x1carbon23.yml", "immutable/ansible.cfg")
    assert command[:2] == ["env", "ANSIBLE_CONFIG=/opt/homelab-automation/immutable/ansible.cfg"]
    assert command[-1] == "/opt/homelab-automation/immutable/x1carbon23.yml"


def vm_dir(tmp_path: Path) -> Path:
    (tmp_path / "cid").write_text("1234\n")
    return tmp_path


def test_run_playbook_reports_a_failure_with_its_output(tmp_path: Path) -> None:
    failed = FakeRunner(lambda _: Result(returncode=2, stdout="TASK [x]\nfatal: boom\n", stderr=""))
    with pytest.raises(StepFailed, match="exit status 2") as raised:
        run_playbook(vm_dir(tmp_path), "p.yml", "a.cfg", verbose=False, runner=failed)
    assert "    fatal: boom" in str(raised.value)


def test_run_playbook_needs_a_recap(tmp_path: Path) -> None:
    silent = FakeRunner(lambda _: Result(returncode=0, stdout="", stderr=""))
    with pytest.raises(StepFailed, match="no play recap"):
        run_playbook(vm_dir(tmp_path), "p.yml", "a.cfg", verbose=False, runner=silent)


def playbook_runner(repository: Path, changes: list[int]) -> FakeRunner:
    """Answers git with REPOSITORY, rsync with success, and each playbook run with CHANGES."""
    runs = iter(changes)

    def respond(argv: list[str]) -> Result:
        if argv[0] == "git":
            return Result(returncode=0, stdout=f"{repository}\n", stderr="")
        if argv[0] == "ssh":
            return Result(returncode=0, stdout=recap_line(next(runs)), stderr="")
        return OK

    return FakeRunner(respond)


def test_test_playbook_converges_then_changes_nothing(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    checkout = Checkout(root=tmp_path / "immutable")
    runner = playbook_runner(tmp_path, [5, 0])
    converge_twice(
        host=X1, run_dir=vm_dir(tmp_path), checkout=checkout, verbose=False, runner=runner
    )
    assert [argv[0] for argv in runner.calls] == ["git", "rsync", "ssh", "ssh"]
    out = capsys.readouterr().out
    assert "first run: ok=12 changed=5" in out
    assert "second run: ok=12 changed=0" in out


def test_test_playbook_fails_when_the_second_run_changes_something(tmp_path: Path) -> None:
    checkout = Checkout(root=tmp_path / "immutable")
    runner = playbook_runner(tmp_path, [5, 2])
    with pytest.raises(StepFailed, match="second run changed 2 tasks"):
        converge_twice(
            host=X1, run_dir=vm_dir(tmp_path), checkout=checkout, verbose=False, runner=runner
        )
