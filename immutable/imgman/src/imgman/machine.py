"""machine run and machine rm: booting and stopping hosts' VMs."""

from imgman import installer
from imgman.cache import Cache
from imgman.checkout import Checkout
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
    run_dir = cache.run_dir(host)
    with host_lock(cache.host_dir(host), host, command=command_line):
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
    viewer = f", 'imgman machine gui {host}' shows its display" if gui else ""
    log(f"{host} is running: 'imgman machine ssh {host}' opens a root shell{viewer}")


def remove_machine(*, host: HostName, cache: Cache, command_line: str) -> None:
    """Stops HOST's VM, if it runs, and removes its overlay and run directory."""
    with host_lock(cache.host_dir(host), host, command=command_line):
        if stop(cache.run_dir(host)):
            log(f"stopped {host}'s VM")
        else:
            log(f"{host}'s VM is not running")
