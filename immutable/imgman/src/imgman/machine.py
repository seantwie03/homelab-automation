"""machine run, machine rm, and test image: booting, stopping, and testing hosts' VMs."""

from imgman import images, installer, playbook
from imgman.cache import Cache
from imgman.checkout import Checkout
from imgman.checks import Guest, check_image
from imgman.errors import StepFailed
from imgman.hosts import Flavor, HostConfig, HostName
from imgman.lock import host_lock
from imgman.output import log, step, warn
from imgman.process import Runner, run
from imgman.vm import RunDir, boot, running_pid, stop, wait_for_boot


def run_machine(
    *,
    host: HostName,
    config: HostConfig,
    flavor: Flavor,
    gui: bool,
    cache: Cache,
    checkout: Checkout,
    command_line: str,
    runner: Runner = run,
) -> None:
    """Boots HOST's VM from a fresh overlay and leaves it running.

    Installs the disk first only if it is missing. A stale disk only gets a
    warning: test image reinstalls it.
    """
    with host_lock(cache.host_dir(host), host, command=command_line):
        _boot_fresh(
            host=host,
            config=config,
            flavor=flavor,
            gui=gui,
            cache=cache,
            checkout=checkout,
            runner=runner,
        )
    viewer = f", 'imgman machine gui {host}' shows its display" if gui else ""
    log(f"{host} is running: 'imgman machine ssh {host}' opens a root shell{viewer}")


def _boot_fresh(
    *,
    host: HostName,
    config: HostConfig,
    flavor: Flavor,
    gui: bool,
    cache: Cache,
    checkout: Checkout,
    runner: Runner = run,
) -> None:
    """Boots HOST's VM from a fresh overlay, replacing a running one. The caller holds the lock.

    Installs the disk first only if it is missing. A stale disk only gets a
    warning: test image reinstalls it.
    """
    run_dir = cache.run_dir(host)
    if running_pid(run_dir) is not None:
        log(f"stopping {host}'s running VM")
    stop(run_dir)
    disk = cache.disk(host, flavor)
    if not disk.exists():
        log(f"{host} has no {flavor} disk yet; installing it first")
        installer.install_holding_lock(
            host=host, config=config, flavor=flavor, cache=cache, checkout=checkout
        )
    elif installer.disk_is_stale(
        host=host, flavor=flavor, cache=cache, checkout=checkout, runner=runner
    ):
        warn(
            f"{host}'s {flavor} disk is older than the latest build or kickstart; "
            f"'imgman test image {host}' reinstalls it"
        )
    log(f"booting {host}; its console is {RunDir(path=run_dir).console}")
    with step(f"boot {host}"):
        boot(host=host, config=config, disk=disk, run_dir=run_dir, gui=gui, runner=runner)
        wait_for_boot(run_dir, runner=runner)


def test_playbook(
    *,
    host: HostName,
    config: HostConfig,
    flavor: Flavor,
    gui: bool,
    remove: bool,
    cache: Cache,
    checkout: Checkout,
    command_line: str,
    verbose: bool,
) -> None:
    """Runs HOST's playbook from the working tree in its VM, booting one if none runs.

    A running VM is reused, so repeated runs are fast; machine run gives a fresh one.
    """
    run_dir = cache.run_dir(host)
    with host_lock(cache.host_dir(host), host, command=command_line):
        if running_pid(run_dir) is None:
            _boot_fresh(
                host=host, config=config, flavor=flavor, gui=gui, cache=cache, checkout=checkout
            )
        else:
            log(f"using {host}'s running VM")
        playbook.converge_twice(host=host, run_dir=run_dir, checkout=checkout, verbose=verbose)
        if remove:
            stop(run_dir)
    log(f"test playbook {host}: converged, and a second run changed nothing")


def remove_machine(*, host: HostName, cache: Cache, command_line: str) -> None:
    """Stops HOST's VM, if it runs, and removes its overlay and run directory."""
    with host_lock(cache.host_dir(host), host, command=command_line):
        if stop(cache.run_dir(host)):
            log(f"stopped {host}'s VM")
        else:
            log(f"{host}'s VM is not running")


def test_image(
    *,
    host: HostName,
    config: HostConfig,
    flavor: Flavor,
    gui: bool,
    remove: bool,
    cache: Cache,
    checkout: Checkout,
    command_line: str,
    verbose: bool,
) -> None:
    """Builds FLAVOR, reinstalls HOST's disk if it is stale, boots it fresh, and checks it.

    Records the image ID as passed on HOST when every check passes.
    """
    images.build(flavor, checkout, verbose=verbose)
    run_dir = cache.run_dir(host)
    with host_lock(cache.host_dir(host), host, command=command_line):
        if running_pid(run_dir) is not None:
            log(f"stopping {host}'s running VM")
        stop(run_dir)
        if installer.disk_is_stale(host=host, flavor=flavor, cache=cache, checkout=checkout):
            log(f"{host}'s {flavor} disk is missing or stale; reinstalling it")
            installer.install_holding_lock(
                host=host, config=config, flavor=flavor, cache=cache, checkout=checkout
            )
        inputs = installer.parse_inputs(cache.inputs(host, flavor).read_text())
        if inputs is None:
            raise StepFailed(f"{cache.inputs(host, flavor)} is not a valid inputs record")
        disk = cache.disk(host, flavor)
        log(f"booting {host}; its console is {RunDir(path=run_dir).console}")
        with step(f"boot {host}"):
            boot(host=host, config=config, disk=disk, run_dir=run_dir, gui=gui)
            wait_for_boot(run_dir)
        encrypted = "--encrypted" in checkout.kickstart(host).read_text()
        checks = check_image(
            Guest(run_dir), host=host, flavor=flavor, inputs=inputs, encrypted=encrypted
        )
        if checks.failed == 0:
            passed = cache.host_dir(host) / "passed"
            passed.mkdir(exist_ok=True)
            (passed / inputs.image_id).touch()
        if remove:
            stop(run_dir)
    if checks.failed:
        raise StepFailed(
            f"test image {host}: {checks.failed} of {checks.passed + checks.failed} checks failed"
        )
    log(f"test image {host}: all {checks.passed} checks passed")
    if not remove:
        log(f"{host}'s VM is still running: 'imgman machine ssh {host}' opens a root shell")
