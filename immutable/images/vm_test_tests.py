#!/usr/bin/env -S uv run --script
"""Unit tests for vm_test.py. They never start a VM or run podman.

Run them with ./vm_test_tests.py from this directory.
"""

# This file has no inline script metadata block on purpose: ty checks a file
# that has one in an isolated environment, where `import vm_test` fails.

from __future__ import annotations

import base64
import contextlib
import io
import json
import os
import signal
import subprocess
import sys
import tempfile
import unittest
from collections.abc import Callable, Generator, Sequence
from pathlib import Path
from unittest import mock

import vm_test

GUEST_REF = "10.0.2.2:5000/workstation-kde:test"


def completed(
    returncode: int = 0, stdout: str = "", stderr: str = ""
) -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(args=[], returncode=returncode, stdout=stdout, stderr=stderr)


def bootc_status(image: str, digest: str) -> str:
    return json.dumps(
        {"status": {"booted": {"image": {"image": {"image": image}, "imageDigest": digest}}}}
    )


@contextlib.contextmanager
def captured_output() -> Generator[tuple[io.StringIO, io.StringIO]]:
    """Captures standard output and standard error."""
    stdout, stderr = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
        yield stdout, stderr


def command(name: str) -> vm_test.CommandSpec:
    """Returns the COMMANDS row named NAME."""
    return next(spec for spec in vm_test.COMMANDS if spec.name == name)


def args_for(
    name: str, *, keep: bool = False, remote_command: tuple[str, ...] = ()
) -> vm_test.Args:
    return vm_test.Args(command(name), keep=keep, remote_command=remote_command)


class TempDirTestCase(unittest.TestCase):
    """Provides a script directory with Containerfile.kde and an empty cache."""

    def setUp(self) -> None:
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.temp = Path(temp.name)
        self.script_dir = self.temp / "images"
        self.script_dir.mkdir()
        (self.script_dir / "Containerfile.kde").write_text("FROM scratch\n")
        self.cache_dir = self.temp / "cache" / "homelab-images"
        self.flavor = vm_test.Flavor("kde", self.script_dir, self.cache_dir)


class FakeGuest:
    """A vm_test.Guest whose commands all succeed. Records each command."""

    def __init__(self, image: str = GUEST_REF) -> None:
        self.image = image
        self.digest = "sha256:original"
        self.commands: list[str] = []

    def execute(
        self, command: str, *, input: str | None = None, capture: bool = True
    ) -> subprocess.CompletedProcess[str]:
        self.commands.append(command)
        return completed()

    def succeeds(self, command: str) -> bool:
        return self.execute(command).returncode == 0

    def output(self, command: str) -> str:
        return self.execute(command).stdout

    def run_visible(self, command: str) -> None:
        self.execute(command)

    def write(self, path: str, content: str) -> None:
        self.commands.append(f"write {path}")

    def booted(self) -> vm_test.BootedImage:
        return vm_test.BootedImage(self.image, self.digest)

    def reboot(self) -> None:
        self.commands.append("reboot")


class FakeLayoutGuest(FakeGuest):
    """Has a read-only /usr. Commands listed in FAILING fail."""

    def __init__(self, failing: Sequence[str] = (), image: str = GUEST_REF) -> None:
        super().__init__(image)
        self.failing = failing

    def execute(
        self, command: str, *, input: str | None = None, capture: bool = True
    ) -> subprocess.CompletedProcess[str]:
        self.commands.append(command)
        if command == "touch /usr/.vm-test":
            return completed(1, stderr="touch: cannot touch: Read-only file system")
        return completed(1 if command in self.failing else 0)


class FakeUpgradeGuest(FakeGuest):
    """Simulates bootc upgrade and rollback: files, staged digests, and reboots."""

    def __init__(self, rollback_keeps_marker: bool = False) -> None:
        super().__init__()
        self.files: set[str] = set()
        self.staged: tuple[str, bool] | None = None
        self.rollback_keeps_marker = rollback_keeps_marker
        self.registries_conf = ""

    def output(self, command: str) -> str:
        self.commands.append(command)
        self.files |= {"/etc/homelab-vm-test", "/var/lib/homelab-vm-test"}
        return ""

    def write(self, path: str, content: str) -> None:
        super().write(path, content)
        self.registries_conf = content

    def run_visible(self, command: str) -> None:
        self.commands.append(command)
        if command == "bootc upgrade":
            self.staged = ("sha256:upgrade", True)
        elif command == "bootc rollback":
            self.staged = ("sha256:original", self.rollback_keeps_marker)

    def reboot(self) -> None:
        super().reboot()
        assert self.staged is not None
        self.digest, marker = self.staged
        if marker:
            self.files.add(vm_test.UPGRADE_MARKER)
        else:
            self.files.discard(vm_test.UPGRADE_MARKER)

    def succeeds(self, command: str) -> bool:
        if command.startswith("test -f "):
            return command.removeprefix("test -f ") in self.files
        if command.startswith("test ! -e "):
            return command.removeprefix("test ! -e ") not in self.files
        raise AssertionError(f"unexpected command: {command}")


class FlavorTests(TempDirTestCase):
    def test_names_and_paths(self) -> None:
        flavor = self.flavor
        self.assertEqual(flavor.containerfile, self.script_dir / "Containerfile.kde")
        self.assertEqual(flavor.image, "localhost/workstation-kde")
        self.assertEqual(flavor.upgrade_image, "localhost/workstation-kde:upgrade-test")
        self.assertEqual(flavor.disk, self.cache_dir / "workstation-kde.qcow2")
        self.assertEqual(flavor.run_dir, self.cache_dir / "run")
        self.assertEqual(flavor.host_ref, "127.0.0.1:5000/workstation-kde:test")
        self.assertEqual(flavor.guest_ref, GUEST_REF)

    def test_default_cache_dir_follows_xdg(self) -> None:
        with mock.patch.dict(os.environ, {"XDG_CACHE_HOME": "/xdg"}):
            self.assertEqual(vm_test.default_cache_dir(), Path("/xdg/homelab-images"))
        with mock.patch.dict(os.environ, {"XDG_CACHE_HOME": "", "HOME": "/home/test"}):
            self.assertEqual(vm_test.default_cache_dir(), Path("/home/test/.cache/homelab-images"))


class ParseArgsTests(TempDirTestCase):
    def parse(self, *argv: str) -> vm_test.Args:
        return vm_test.parse_args(list(argv), script_dir=self.script_dir)

    def test_defaults(self) -> None:
        self.assertEqual(self.parse("build"), vm_test.Args(command("build")))
        self.assertEqual(self.parse("stop"), vm_test.Args(command("stop")))

    def test_keep_and_flavor(self) -> None:
        (self.script_dir / "Containerfile.niri").write_text("FROM scratch\n")
        self.assertEqual(
            self.parse("all", "--keep", "--flavor", "niri"),
            vm_test.Args(command("all"), flavor="niri", keep=True),
        )

    def test_ssh_passes_everything_after_it_to_the_vm(self) -> None:
        self.assertEqual(
            self.parse("ssh", "bootc", "status", "--format", "json"),
            args_for("ssh", remote_command=("bootc", "status", "--format", "json")),
        )
        self.assertEqual(self.parse("ssh"), args_for("ssh"))

    def test_every_command_parses_to_its_row(self) -> None:
        for spec in vm_test.COMMANDS:
            with self.subTest(command=spec.name):
                self.assertIs(self.parse(spec.name).command, spec)

    def test_usage_errors_exit_2(self) -> None:
        for argv in (
            [],
            ["bogus"],
            ["--nope", "check"],
            ["build", "--keep"],
            ["check", "extra"],
            ["build", "--flavor"],
            ["build", "--flavor", "../etc"],
            ["build", "--flavor", "gnome"],
        ):
            with self.subTest(argv=argv), captured_output(), self.assertRaises(SystemExit) as exit:
                self.parse(*argv)
            self.assertEqual(exit.exception.code, 2)

    def test_flavors_come_from_containerfiles(self) -> None:
        (self.script_dir / "Containerfile.niri").write_text("FROM scratch\n")
        self.assertEqual(vm_test.available_flavors(self.script_dir), ["kde", "niri"])
        with captured_output() as (_, stderr), self.assertRaises(SystemExit):
            self.parse("build", "--flavor", "gnome")
        self.assertIn("invalid choice: 'gnome'", stderr.getvalue())
        self.assertIn("'niri'", stderr.getvalue())

    def test_default_flavor_needs_a_containerfile(self) -> None:
        (self.script_dir / "Containerfile.kde").unlink()
        with captured_output() as (_, stderr), self.assertRaises(SystemExit) as exit:
            self.parse("stop")
        self.assertEqual(exit.exception.code, 2)
        self.assertIn("no Containerfile.kde", stderr.getvalue())

    def test_help_exits_0(self) -> None:
        with captured_output() as (stdout, _), self.assertRaises(SystemExit) as exit:
            self.parse("--help")
        self.assertEqual(exit.exception.code, 0)
        self.assertIn("Exit status", stdout.getvalue())


class PrerequisiteTests(unittest.TestCase):
    def missing(
        self,
        requirements: vm_test.Requirements,
        *,
        absent: Sequence[str] = (),
        denied: Sequence[Path] = (),
        vsock: bool = True,
        vsock_check: Callable[[], bool] | None = None,
    ) -> list[str]:
        def which(name: str) -> str | None:
            return None if name in absent else f"/usr/bin/{name}"

        def access(path: Path, mode: int) -> bool:
            return path not in denied

        return vm_test.missing_prerequisites(
            requirements,
            which=which,
            access=access,
            vsock_ssh=vsock_check or (lambda: vsock),
        )

    def test_union_keeps_order_without_duplicates(self) -> None:
        combined = vm_test.Requirements(commands=("a", "b")) | vm_test.Requirements(
            commands=("b", "c"), vsock_ssh=True, disk_space=True
        )
        self.assertEqual(combined.commands, ("a", "b", "c"))
        self.assertTrue(combined.vsock_ssh)
        self.assertTrue(combined.disk_space)

    def test_all_needs_what_build_disk_and_check_need(self) -> None:
        requirements = command("all").requirements
        for name in ("podman", "bcvk", "qemu-system-x86_64", "qemu-img", "ssh", "ssh-keygen"):
            self.assertIn(name, requirements.commands)
        self.assertEqual(set(requirements.devices), {vm_test.KVM, vm_test.VHOST_VSOCK})
        self.assertTrue(requirements.vsock_ssh)

    def test_nothing_missing(self) -> None:
        self.assertEqual(self.missing(command("all").requirements), [])

    def test_stop_needs_nothing(self) -> None:
        self.assertEqual(
            self.missing(command("stop").requirements, absent=("ssh", "podman"), vsock=False), []
        )

    def test_lists_every_missing_item(self) -> None:
        missing = self.missing(
            command("all").requirements,
            absent=("bcvk",),
            denied=(vm_test.OVMF_VARS, vm_test.VHOST_VSOCK),
            vsock=False,
        )
        self.assertEqual(
            missing,
            [
                "the bcvk command",
                str(vm_test.OVMF_VARS),
                f"read and write access to {vm_test.VHOST_VSOCK}",
                "an ssh configuration that sends vsock/ hosts through systemd-ssh-proxy",
            ],
        )

    def test_vsock_configuration_is_not_probed_without_ssh(self) -> None:
        probe = mock.Mock(return_value=True)
        missing = self.missing(command("ssh").requirements, absent=("ssh",), vsock_check=probe)
        self.assertIn("the ssh command", missing)
        self.assertEqual(len(missing), 2)
        probe.assert_not_called()

    def test_vsock_ssh_configured_reads_ssh_config(self) -> None:
        proxy = "user root\nproxycommand /usr/lib/systemd/systemd-ssh-proxy %h %p\n"
        for result, expected in (
            (completed(stdout=proxy), True),
            (completed(stdout="user root\nproxycommand none\n"), False),
            (completed(255, stdout=proxy), False),
        ):
            with (
                self.subTest(expected=expected),
                mock.patch("vm_test.subprocess.run", return_value=result),
            ):
                self.assertEqual(vm_test.vsock_ssh_configured(), expected)


class PreconditionTests(TempDirTestCase):
    def test_disk_needs_a_built_image(self) -> None:
        with (
            mock.patch("vm_test.image_exists", return_value=False),
            mock.patch("vm_test.install_disk") as install_disk,
            self.assertRaisesRegex(vm_test.StepError, f"run: {vm_test.PROG} build"),
        ):
            vm_test.cmd_disk(args_for("disk"), self.flavor)
        install_disk.assert_not_called()

    def test_check_needs_a_disk_and_a_test_image(self) -> None:
        with (
            mock.patch("vm_test.image_exists", return_value=True),
            self.assertRaisesRegex(vm_test.StepError, "no disk at"),
        ):
            vm_test.cmd_check(args_for("check"), self.flavor)
        self.cache_dir.mkdir(parents=True)
        self.flavor.disk.write_text("")
        with (
            mock.patch("vm_test.image_exists", return_value=False),
            self.assertRaisesRegex(vm_test.StepError, "no test image"),
        ):
            vm_test.cmd_check(args_for("check"), self.flavor)

    def test_ssh_needs_a_running_vm(self) -> None:
        with (
            mock.patch("vm_test.VirtualMachine") as vm_class,
            mock.patch("vm_test.os.execvp") as execvp,
            self.assertRaisesRegex(vm_test.StepError, "check --keep"),
        ):
            vm_class.return_value.running.return_value = False
            vm_test.cmd_ssh(args_for("ssh"), self.flavor)
        execvp.assert_not_called()


class FreeSpaceTests(TempDirTestCase):
    def test_existing_ancestor(self) -> None:
        self.assertEqual(vm_test.existing_ancestor(self.temp / "a" / "b"), self.temp)

    def test_free_gb_measures_the_existing_ancestor(self) -> None:
        measure = mock.Mock(return_value=20 * 2**30 + 5)
        self.assertEqual(vm_test.free_gb(self.cache_dir, measure=measure), 20)
        measure.assert_called_once_with(self.temp)

    def test_free_bytes(self) -> None:
        self.assertGreater(vm_test.free_bytes(self.temp), 0)

    def test_warns_only_when_space_is_low(self) -> None:
        for free, warned in ((3, True), (vm_test.LOW_SPACE_GB, False)):
            with (
                self.subTest(free=free),
                mock.patch("vm_test.free_gb", return_value=free),
                captured_output() as (_, stderr),
            ):
                vm_test.warn_if_low_space(self.cache_dir)
            self.assertEqual("only 3 GB free" in stderr.getvalue(), warned)


class RunTests(unittest.TestCase):
    def python(self, code: str) -> list[str]:
        return [sys.executable, "-c", code]

    def test_returns_output_when_capturing(self) -> None:
        self.assertEqual(vm_test.run(self.python("print('hi')"), capture=True), "hi\n")

    def test_passes_input(self) -> None:
        code = "import sys; print(sys.stdin.read().upper())"
        self.assertEqual(vm_test.run(self.python(code), input="abc", capture=True), "ABC\n")

    def test_failure_raises_step_error(self) -> None:
        with self.assertRaisesRegex(vm_test.StepError, "exit status 3"):
            vm_test.run(self.python("import sys; sys.exit(3)"))

    def test_succeeds(self) -> None:
        self.assertTrue(vm_test.succeeds(self.python("pass")))
        self.assertFalse(vm_test.succeeds(self.python("import sys; sys.exit(1)")))


class HostCommandTests(TempDirTestCase):
    def test_build_image_and_image_exists(self) -> None:
        with mock.patch("vm_test.run") as run:
            vm_test.build_image(self.flavor)
        self.assertEqual(
            run.call_args.args[0],
            [
                "podman", "build",
                "-f", self.flavor.containerfile,
                "-t", "localhost/workstation-kde",
                self.script_dir,
            ],
        )  # fmt: skip
        with mock.patch("vm_test.succeeds", return_value=True) as succeeds:
            self.assertTrue(vm_test.image_exists(GUEST_REF))
        succeeds.assert_called_once_with(["podman", "image", "exists", GUEST_REF])

    def test_build_test_image_enables_sshd(self) -> None:
        with mock.patch("vm_test.run") as run:
            vm_test.build_test_image(self.flavor)
        args, kwargs = run.call_args
        self.assertEqual(args[0], ["podman", "build", "-q", "-t", GUEST_REF, "-"])
        self.assertEqual(
            kwargs["input"], "FROM localhost/workstation-kde\nRUN systemctl enable sshd.service\n"
        )

    def test_install_disk(self) -> None:
        with mock.patch("vm_test.run") as run:
            vm_test.install_disk(self.flavor)
        self.assertTrue(self.cache_dir.is_dir())
        argv = run.call_args.args[0]
        self.assertEqual(argv[:2], ["bcvk", "to-disk"])
        self.assertEqual(argv[-2:], [GUEST_REF, self.flavor.disk])

    def test_start_registry_creates_it_once(self) -> None:
        for exists, expected in ((False, ["create", "start"]), (True, ["start"])):
            with (
                self.subTest(exists=exists),
                mock.patch("vm_test.succeeds", return_value=exists),
                mock.patch("vm_test.run") as run,
            ):
                vm_test.start_registry(self.flavor)
                self.assertEqual([call.args[0][1] for call in run.call_args_list], expected)

    def test_push_upgrade_image_returns_the_digest(self) -> None:
        def fake_run(argv: Sequence[str | Path], **kwargs: object) -> str:
            if "--digestfile" in argv:
                Path(argv[list(argv).index("--digestfile") + 1]).write_text("sha256:pushed\n")
            return ""

        with (
            mock.patch("vm_test.start_registry") as start_registry,
            mock.patch("vm_test.run", side_effect=fake_run) as run,
            captured_output(),
        ):
            self.assertEqual(vm_test.push_upgrade_image(self.flavor), "sha256:pushed")
        start_registry.assert_called_once_with(self.flavor)
        build = run.call_args_list[0]
        self.assertIn(f"FROM {GUEST_REF}\n", build.kwargs["input"])
        self.assertIn(vm_test.UPGRADE_MARKER, build.kwargs["input"])
        self.assertIn(f"docker://{self.flavor.host_ref}", run.call_args_list[1].args[0])


class CredentialTests(unittest.TestCase):
    def test_tmpfiles_credential_installs_the_key_under_var_roothome(self) -> None:
        key = "ssh-ed25519 AAAAtest vm-test\n"
        config = base64.b64decode(vm_test.tmpfiles_credential(key)).decode().splitlines()
        self.assertEqual(config[0], "d /var/roothome 0700 root root -")
        self.assertEqual(config[1], "d /var/roothome/.ssh 0700 root root -")
        prefix = "f+~ /var/roothome/.ssh/authorized_keys 0600 root root - "
        self.assertTrue(config[2].startswith(prefix))
        self.assertEqual(base64.b64decode(config[2].removeprefix(prefix)).decode(), key)

    def test_parse_booted(self) -> None:
        booted = vm_test.parse_booted(bootc_status(GUEST_REF, "sha256:abc"))
        self.assertEqual(booted, vm_test.BootedImage(GUEST_REF, "sha256:abc"))
        with self.assertRaises(KeyError):
            vm_test.parse_booted('{"status": {}}')


class VirtualMachineTests(TempDirTestCase):
    def setUp(self) -> None:
        super().setUp()
        self.proc = self.temp / "proc"
        self.vm = vm_test.VirtualMachine(self.flavor, proc=self.proc)
        self.vm.run_dir.mkdir(parents=True)
        self.vm.cid_file.write_text("4242\n")

    def fake_process(self, pid: int, cmdline: bytes) -> None:
        (self.proc / str(pid)).mkdir(parents=True)
        (self.proc / str(pid) / "cmdline").write_bytes(cmdline)
        self.vm.pid_file.write_text(f"{pid}\n")

    def test_pid(self) -> None:
        self.assertIsNone(self.vm.pid())
        self.vm.pid_file.write_text("garbage\n")
        self.assertIsNone(self.vm.pid())
        self.vm.pid_file.write_text("123\n")
        self.assertIsNone(self.vm.pid(), "no such process")
        self.fake_process(123, b"bash\0-c\0sleep\0")
        self.assertIsNone(self.vm.pid(), "stale PID file naming another process")
        self.fake_process(
            456, b"qemu-system-x86_64\0-drive\0file=" + bytes(self.vm.overlay) + b"\0"
        )
        self.assertEqual(self.vm.pid(), 456)
        self.assertTrue(self.vm.running())

    def test_ssh_args(self) -> None:
        args = self.vm.ssh_args(["uptime"], ["-n"])
        self.assertEqual(args[:2], ["ssh", "-n"])
        self.assertIn(str(self.vm.key), args)
        self.assertEqual(args[-2:], ["vsock/4242", "uptime"])

    def test_execute_closes_input_unless_it_has_some(self) -> None:
        with mock.patch("vm_test.subprocess.run", return_value=completed()) as run:
            self.vm.execute("true")
            self.assertEqual(run.call_args.args[0][1], "-n")
            self.vm.write("/etc/a file", "content")
            self.assertEqual(run.call_args.args[0][1], "-T")
            self.assertEqual(run.call_args.args[0][-1], "cat >'/etc/a file'")
            self.assertEqual(run.call_args.kwargs["input"], "content")

    def test_output_and_failures(self) -> None:
        with mock.patch.object(self.vm, "execute", return_value=completed(stdout="out\n")):
            self.assertEqual(self.vm.output("echo out"), "out\n")
            self.vm.run_visible("true")
            self.vm.write("/etc/x", "x")
        failing_calls: list[Callable[[], object]] = [
            lambda: self.vm.output("false"),
            lambda: self.vm.run_visible("false"),
            lambda: self.vm.write("/etc/x", "x"),
        ]
        with mock.patch.object(self.vm, "execute", return_value=completed(2, stderr="boom")):
            for call in failing_calls:
                with self.assertRaises(vm_test.StepError):
                    call()

    def test_succeeds(self) -> None:
        with mock.patch.object(self.vm, "execute", side_effect=[completed(0), completed(1)]):
            self.assertTrue(self.vm.succeeds("true"))
            self.assertFalse(self.vm.succeeds("false"))

    def test_boot_id(self) -> None:
        for result, expected in (
            (completed(stdout="abc\n"), "abc"),
            (completed(stdout="\n"), None),
            (completed(255), None),
        ):
            with mock.patch.object(self.vm, "execute", return_value=result):
                self.assertEqual(self.vm.boot_id(), expected)

    def test_booted(self) -> None:
        status = completed(stdout=bootc_status(GUEST_REF, "sha256:abc"))
        with mock.patch.object(self.vm, "execute", return_value=status):
            self.assertEqual(self.vm.booted().digest, "sha256:abc")

    def test_qemu_args(self) -> None:
        args = self.vm.qemu_args(4242, "Y3JlZA==")
        self.assertEqual(args[0], "qemu-system-x86_64")
        self.assertIn("vhost-vsock-pci,guest-cid=4242", args)
        self.assertIn(f"if=virtio,format=qcow2,file={self.vm.overlay}", args)
        self.assertIn("type=11,value=io.systemd.credential.binary:tmpfiles.extra=Y3JlZA==", args)
        self.assertEqual(args[-2:], ["-pidfile", str(self.vm.pid_file)])

    def test_wait_for_boot_returns_on_a_new_boot_id(self) -> None:
        sleeps: list[float] = []
        with mock.patch.object(self.vm, "boot_id", side_effect=[None, "old", "new"]):
            self.vm.wait_for_boot("old", clock=lambda: 0, sleep=sleeps.append)
        self.assertEqual(len(sleeps), 2)

    def test_wait_for_boot_times_out_with_the_console_tail(self) -> None:
        self.vm.console_log.write_text("".join(f"line {n}\n" for n in range(1, 41)))
        ticks = iter(range(1000))
        with (
            mock.patch.object(self.vm, "boot_id", return_value=None),
            self.assertRaises(vm_test.StepError) as error,
        ):
            self.vm.wait_for_boot(timeout=5, clock=lambda: next(ticks), sleep=lambda _: None)
        self.assertIn("line 40", str(error.exception))
        self.assertNotIn("line 10\n", str(error.exception))

    def test_wait_for_boot_times_out_without_a_console_log(self) -> None:
        ticks = iter(range(1000))
        with (
            mock.patch.object(self.vm, "boot_id", return_value=None),
            self.assertRaisesRegex(vm_test.StepError, "did not come up"),
        ):
            self.vm.wait_for_boot(timeout=2, clock=lambda: next(ticks), sleep=lambda _: None)

    def test_reboot_waits_for_a_different_boot(self) -> None:
        with (
            mock.patch.object(self.vm, "boot_id", return_value="old"),
            mock.patch.object(self.vm, "execute") as execute,
            mock.patch.object(self.vm, "wait_for_boot") as wait,
        ):
            self.vm.reboot()
        execute.assert_called_once_with("systemctl reboot")
        wait.assert_called_once_with("old")

    def test_stop_kills_qemu_and_removes_its_files(self) -> None:
        self.fake_process(456, bytes(self.vm.overlay))

        def kill(pid: int, sig: int) -> None:
            for path in (self.proc / str(pid)).iterdir():
                path.unlink()
            (self.proc / str(pid)).rmdir()

        with mock.patch("vm_test.os.kill", side_effect=kill) as kill_mock:
            self.vm.stop()
        kill_mock.assert_called_once_with(456, signal.SIGTERM)
        self.assertFalse(self.vm.run_dir.exists())

    def test_stop_gives_up_waiting_for_qemu(self) -> None:
        self.fake_process(456, bytes(self.vm.overlay))
        clock = iter(range(0, 1000, 10))
        with (
            mock.patch("vm_test.os.kill") as kill,
            mock.patch("vm_test.time.monotonic", side_effect=lambda: next(clock)),
            mock.patch("vm_test.time.sleep") as sleep,
        ):
            self.vm.stop()
        kill.assert_called_once_with(456, signal.SIGTERM)
        sleep.assert_called()
        self.assertFalse(self.vm.run_dir.exists())

    def test_stop_without_a_vm_only_removes_files(self) -> None:
        with mock.patch("vm_test.os.kill") as kill:
            self.vm.stop()
        kill.assert_not_called()
        self.assertFalse(self.vm.run_dir.exists())

    def test_start(self) -> None:
        def fake_run(argv: Sequence[str | Path], **kwargs: object) -> str:
            if argv[0] == "ssh-keygen":
                self.vm.key.with_suffix(".pub").write_text("ssh-ed25519 AAAA vm-test\n")
            return ""

        self.vm.run_dir.joinpath("leftover").write_text("")
        with (
            mock.patch("vm_test.run", side_effect=fake_run) as run,
            mock.patch("vm_test.shutil.copyfile") as copyfile,
            mock.patch("vm_test.random.randint", return_value=4321),
            mock.patch.object(self.vm, "wait_for_boot") as wait,
        ):
            self.vm.start()
        self.assertFalse(self.vm.run_dir.joinpath("leftover").exists())
        self.assertEqual(
            [call.args[0][0] for call in run.call_args_list],
            ["ssh-keygen", "qemu-img", "qemu-system-x86_64"],
        )
        self.assertIn("vhost-vsock-pci,guest-cid=4321", run.call_args_list[-1].args[0])
        self.assertEqual(self.vm.cid_file.read_text(), "4321\n")
        copyfile.assert_called_once_with(vm_test.OVMF_VARS, self.vm.ovmf_vars)
        wait.assert_called_once_with()


class ChecksTests(unittest.TestCase):
    def test_counts_failures(self) -> None:
        def raises() -> bool:
            vm_test.parse_booted("{}")
            return True

        checks = vm_test.Checks()
        with captured_output() as (stdout, stderr):
            checks.expect("passes", lambda: True)
            checks.expect("fails", lambda: False)
            checks.expect("raises", raises)
        self.assertEqual(checks.failures, 2)
        self.assertIn("PASS: passes", stdout.getvalue())
        self.assertIn("FAIL: fails", stderr.getvalue())
        self.assertIn("FAIL: raises ('status')", stderr.getvalue())


class LayoutCheckTests(TempDirTestCase):
    def run_checks(self, vm: FakeLayoutGuest) -> vm_test.Checks:
        checks = vm_test.Checks()
        with captured_output():
            vm_test.check_layout(vm, self.flavor, checks)
        return checks

    def test_usr_is_read_only(self) -> None:
        for result, expected in (
            (completed(1, stderr="touch: Read-only file system"), True),
            (completed(0), False),
            (completed(1, stderr="touch: Permission denied"), False),
        ):
            vm = FakeGuest()
            with mock.patch.object(vm, "execute", return_value=result):
                self.assertEqual(vm_test.usr_is_read_only(vm), expected)

    def test_every_case_runs_and_passes(self) -> None:
        vm = FakeLayoutGuest()
        self.assertEqual(self.run_checks(vm).failures, 0)
        for _, command in vm_test.layout_cases():
            self.assertIn(command, vm.commands)

    def test_failures_are_counted(self) -> None:
        failing = next(command for name, command in vm_test.layout_cases() if "/srv" in name)
        self.assertEqual(self.run_checks(FakeLayoutGuest(failing=(failing,))).failures, 1)
        self.assertEqual(self.run_checks(FakeLayoutGuest(image="other")).failures, 1)

    def test_layout_cases_cover_every_collection(self) -> None:
        names = [name for name, _ in vm_test.layout_cases()]
        for collection in vm_test.COLLECTIONS:
            self.assertIn(f"collection {collection} is installed", names)


class UpgradeCheckTests(TempDirTestCase):
    def run_checks(self, vm: FakeUpgradeGuest) -> vm_test.Checks:
        checks = vm_test.Checks()

        def upgrade_digest() -> str:
            vm.commands.append("upgrade digest")
            return "sha256:upgrade"

        with captured_output():
            vm_test.check_upgrade_and_rollback(vm, self.flavor, checks, upgrade_digest)
        return checks

    def test_upgrade_and_rollback_pass(self) -> None:
        vm = FakeUpgradeGuest()
        self.assertEqual(self.run_checks(vm).failures, 0)
        self.assertEqual(
            vm.commands[1:],
            [
                "write /etc/containers/registries.conf.d/50-vm-test.conf",
                "upgrade digest",
                "bootc upgrade",
                "reboot",
                "bootc rollback",
                "reboot",
            ],
        )
        self.assertIn('location = "10.0.2.2:5000"', vm.registries_conf)

    def test_rollback_that_keeps_upgrade_content_fails(self) -> None:
        vm = FakeUpgradeGuest(rollback_keeps_marker=True)
        self.assertEqual(self.run_checks(vm).failures, 1)


class CommandTests(TempDirTestCase):
    def ready_for_check(self) -> None:
        """Creates the disk that cmd_check requires."""
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.flavor.disk.write_text("")

    def test_build(self) -> None:
        with mock.patch("vm_test.build_image") as build_image, captured_output():
            vm_test.cmd_build(args_for("build"), self.flavor)
        build_image.assert_called_once_with(self.flavor)

    def test_disk_builds_the_test_image_before_installing(self) -> None:
        order: list[str] = []
        with (
            mock.patch("vm_test.image_exists", return_value=True),
            mock.patch(
                "vm_test.build_test_image", side_effect=lambda _: order.append("test image")
            ),
            mock.patch("vm_test.install_disk", side_effect=lambda _: order.append("disk")),
            captured_output(),
        ):
            vm_test.cmd_disk(args_for("disk"), self.flavor)
        self.assertEqual(order, ["test image", "disk"])

    def test_check_stops_the_vm(self) -> None:
        self.ready_for_check()
        with (
            mock.patch("vm_test.image_exists", return_value=True),
            mock.patch("vm_test.VirtualMachine") as vm_class,
            mock.patch("vm_test.push_upgrade_image", return_value="sha256:d"),
            mock.patch("vm_test.check_layout"),
            mock.patch("vm_test.check_upgrade_and_rollback") as upgrade,
            captured_output() as (stdout, _),
        ):
            vm_test.cmd_check(args_for("check"), self.flavor)
            self.assertEqual(upgrade.call_args.args[3](), "sha256:d")
        vm_class.return_value.stop.assert_called_once_with()
        self.assertIn("All checks passed.", stdout.getvalue())

    def test_check_keeps_the_vm_and_reports_failures(self) -> None:
        def fail(vm: vm_test.Guest, flavor: vm_test.Flavor, checks: vm_test.Checks) -> None:
            checks.failures = 2

        self.ready_for_check()
        with (
            mock.patch("vm_test.image_exists", return_value=True),
            mock.patch("vm_test.VirtualMachine") as vm_class,
            mock.patch("vm_test.push_upgrade_image", return_value="sha256:d"),
            mock.patch("vm_test.check_layout", side_effect=fail),
            mock.patch("vm_test.check_upgrade_and_rollback"),
            captured_output() as (stdout, _),
            self.assertRaisesRegex(vm_test.StepError, "2 check"),
        ):
            vm_class.return_value.running.return_value = True
            vm_test.cmd_check(args_for("check", keep=True), self.flavor)
        vm_class.return_value.stop.assert_not_called()
        self.assertIn("still running", stdout.getvalue())

    def test_check_stops_the_vm_when_boot_fails(self) -> None:
        self.ready_for_check()
        with (
            mock.patch("vm_test.image_exists", return_value=True),
            mock.patch("vm_test.VirtualMachine") as vm_class,
            mock.patch("vm_test.push_upgrade_image", return_value="sha256:d"),
            captured_output(),
            self.assertRaises(vm_test.StepError),
        ):
            vm_class.return_value.start.side_effect = vm_test.StepError("no boot")
            vm_test.cmd_check(args_for("check"), self.flavor)
        vm_class.return_value.stop.assert_called_once_with()

    def test_wait_for_reports_waiting_only_when_needed(self) -> None:
        done = mock.Mock(done=mock.Mock(return_value=True), result=mock.Mock(return_value="d"))
        pending = mock.Mock(done=mock.Mock(return_value=False), result=mock.Mock(return_value="d"))
        with captured_output() as (stdout, _):
            self.assertEqual(vm_test.wait_for(done), "d")
            self.assertEqual(stdout.getvalue(), "")
            self.assertEqual(vm_test.wait_for(pending), "d")
        self.assertIn("Waiting", stdout.getvalue())

    def test_all_builds_installs_and_checks_in_order(self) -> None:
        order: list[str] = []
        args = args_for("all", keep=True)

        def record(name: str) -> Callable[[vm_test.Args, vm_test.Flavor], None]:
            def handler(received: vm_test.Args, flavor: vm_test.Flavor) -> None:
                self.assertIs(received, args)
                order.append(name)

            return handler

        with (
            mock.patch("vm_test.cmd_build", side_effect=record("build")),
            mock.patch("vm_test.cmd_disk", side_effect=record("disk")),
            mock.patch("vm_test.cmd_check", side_effect=record("check")),
        ):
            vm_test.cmd_all(args, self.flavor)
        self.assertEqual(order, ["build", "disk", "check"])

    def test_ssh_replaces_the_process_with_ssh(self) -> None:
        with (
            mock.patch("vm_test.VirtualMachine") as vm_class,
            mock.patch("vm_test.os.execvp") as execvp,
        ):
            vm_class.return_value.running.return_value = True
            vm_class.return_value.ssh_args.return_value = ["ssh", "vsock/1", "uptime"]
            vm_test.cmd_ssh(args_for("ssh", remote_command=("uptime",)), self.flavor)
        vm_class.return_value.ssh_args.assert_called_once_with(("uptime",))
        execvp.assert_called_once_with("ssh", ["ssh", "vsock/1", "uptime"])

    def test_stop(self) -> None:
        with mock.patch("vm_test.VirtualMachine") as vm_class:
            vm_test.cmd_stop(args_for("stop"), self.flavor)
        vm_class.return_value.stop.assert_called_once_with()

    def test_clean(self) -> None:
        self.cache_dir.mkdir(parents=True)
        with mock.patch("vm_test.VirtualMachine") as vm_class, mock.patch("vm_test.run") as run:
            vm_test.cmd_clean(args_for("clean"), self.flavor)
        vm_class.return_value.stop.assert_called_once_with()
        self.assertEqual(len(run.call_args_list), 2)
        self.assertFalse(self.cache_dir.exists())

    def test_clean_refuses_an_unexpected_cache_directory(self) -> None:
        flavor = vm_test.Flavor("kde", self.script_dir, self.temp)
        with (
            mock.patch("vm_test.VirtualMachine"),
            mock.patch("vm_test.run"),
            self.assertRaises(vm_test.StepError),
        ):
            vm_test.cmd_clean(args_for("clean"), flavor)
        self.assertTrue(self.temp.exists())


class MainTests(TempDirTestCase):
    """Runs main against a two-row COMMANDS table whose handlers are a mock."""

    def setUp(self) -> None:
        super().setUp()
        self.missing = self.patch("vm_test.missing_prerequisites", return_value=[])
        self.free_gb = self.patch("vm_test.free_gb", return_value=100)
        self.patch("vm_test.default_cache_dir", return_value=self.cache_dir)
        self.handler = mock.Mock()
        commands = (
            vm_test.CommandSpec(
                "build",
                "build it",
                self.handler,
                requirements=vm_test.Requirements(disk_space=True),
                options=("flavor",),
            ),
            vm_test.CommandSpec("stop", "stop it", self.handler),
        )
        patcher = mock.patch("vm_test.COMMANDS", new=commands)
        self.addCleanup(patcher.stop)
        patcher.start()

    def patch(self, target: str, return_value: object) -> mock.MagicMock:
        patcher = mock.patch(target, return_value=return_value)
        self.addCleanup(patcher.stop)
        started: mock.MagicMock = patcher.start()
        return started

    def main(self, *argv: str) -> tuple[int, str, str]:
        with captured_output() as (stdout, stderr):
            status = vm_test.main(list(argv))
        return status, stdout.getvalue(), stderr.getvalue()

    def test_runs_the_command_handler(self) -> None:
        self.assertEqual(self.main("build")[0], 0)
        args, flavor = self.handler.call_args.args
        self.assertEqual(args.command.name, "build")
        self.assertEqual(flavor.name, "kde")

    def test_missing_prerequisites_exit_1(self) -> None:
        self.missing.return_value = ["the bcvk command"]
        status, _, stderr = self.main("build")
        self.assertEqual(status, 1)
        self.assertIn("    the bcvk command", stderr)
        self.handler.assert_not_called()

    def test_step_error_exits_1(self) -> None:
        self.handler.side_effect = vm_test.StepError("2 failed")
        status, _, stderr = self.main("build")
        self.assertEqual((status, stderr), (1, f"{vm_test.PROG}: 2 failed\n"))

    def test_interrupt_exits_130(self) -> None:
        self.handler.side_effect = KeyboardInterrupt
        self.assertEqual(self.main("build")[0], 130)

    def test_warns_about_low_space_only_for_commands_that_need_it(self) -> None:
        self.free_gb.return_value = 3
        self.assertIn("only 3 GB free", self.main("build")[2])
        self.assertNotIn("only 3 GB free", self.main("stop")[2])


if __name__ == "__main__":
    unittest.main()
