# imgman

Builds this repository's bootc images and tests them in VMs that stand in for
the hosts in `images/hosts.toml`. Each VM's disk is installed by Anaconda with
the host's own kickstart, the same file that installs the host's hardware, so
the VM has the hardware's disk layout, encryption, and user accounts. imgman
runs without root.

## Installing

From the repository root:

```sh
uv tool install --editable imgman
```

This puts `imgman` on `PATH` in `~/.local/bin`. imgman reads the checkout it
was installed from, so it works only from an editable install, and changes to
its source take effect without reinstalling.

## Commands

```text
imgman image build [FLAVOR] [--all]                 build and lint an image
imgman machine init [HOST] [--all] [--flavor NAME]  install a host's VM disk with its kickstart
imgman machine run  [HOST] [--all] [--flavor NAME] [--no-gui]
                                                    boot a host's VM from a fresh overlay
imgman machine ssh  [HOST] [COMMAND ...]            run a command as root in the VM, or open a shell
imgman machine gui  [HOST]                          open the VM's display in remote-viewer
imgman machine rm   [HOST] [--all]                  stop the VM and remove its overlay
imgman test image   [HOST] [--all] [--flavor NAME] [--rm] [--no-gui]
                                                    install if needed, boot fresh, and check the VM
imgman test playbook [HOST] [--all] [--flavor NAME] [--rm] [--no-gui]
                                                    run the host's playbook from the working tree, twice
```

- `HOST` defaults to this machine's short hostname when `hosts.toml` lists it.
  `--all` targets every host. `FLAVOR` defaults to this host's flavor.
- `--flavor NAME` boots a host on another flavor's image. Each host keeps one
  disk per flavor, so it never replaces the host's normal disk.
- `machine ssh` takes a host only when its first word names one, so
  `imgman machine ssh bootc status` runs on this machine's host.
- VMs keep running after a command ends, so you can inspect them. `machine run`
  and `test image` always boot a fresh overlay, replacing any VM the host is
  running; `--rm` stops the VM when `test image` ends.

`test image` is the check to run before committing a change to an image or a
kickstart. It builds the flavor, reinstalls the host's disk if the image or the
kickstart changed since the install, boots it fresh with Secure Boot enforced,
and prints `PASS` or `FAIL` for each check:

- No unit failed. If one did, imgman prints the failed units and their last
  journal lines.
- `bootc status` reports the image and digest the disk was installed from.
- `/usr` is read-only; `/etc` and `/var` are writable; `/opt`, `/srv`, and
  `/usr/local` link into `/var`.
- Secure Boot is enabled.
- The kickstart's layout: the `home` subvolume at `/var/home`, `sean` with UID
  1000, and a file in `~/.cache` absent from a snapshot of `home`.
- The boot reached `graphical.target` with the display manager active.
- For a kickstart that encrypts, the root file system is on a LUKS2 device.
- `bootc upgrade --check` reaches the test registry.

With a current disk, `test image` takes about 20 seconds per host. A reinstall
adds about 7 minutes.

`test playbook` is the check to run before committing a change to a playbook,
role, or dotfile. It copies the working tree, including uncommitted and
untracked changes but not `.git` or ignored files, into the VM's
`/opt/homelab-automation`, then runs the host's playbook twice as the
`ansible_pull` unit runs it. The first run must succeed, and the second must
change nothing. It reuses the host's running VM, so repeated runs take seconds;
`machine run` gives it a fresh overlay first. `--verbose` prints each run's
output.

## Exit status

| Code | Meaning |
| --- | --- |
| 0 | Success. |
| 1 | Bad input: arguments, `hosts.toml`, or other configuration. |
| 2 | Missing prerequisite: a command, a device, the installer ISO, a VM that is not running, or a host another imgman command holds. |
| 3 | A step or check failed, including a command `machine ssh` ran in the VM. |
| 130 | Interrupted. |

## Prerequisites

Before doing any work, imgman checks what the command needs and lists
everything missing at once.

- Python 3.14 or later and `uv`.
- `podman`, `qemu-system-x86_64`, `qemu-img`, and the OVMF firmware
  (`edk2-ovmf`), including its Secure Boot build.
- `xorriso`, to read the installer ISO.
- `rsync` and `git`, for `test playbook`.
- `remote-viewer` (`virt-viewer`) and QEMU's SPICE support
  (`qemu-ui-spice-core`), for `machine gui`.
- Read and write access to `/dev/kvm` and `/dev/vhost-vsock`.
- An ssh configuration that sends `vsock/` hosts through `systemd-ssh-proxy`.
  Fedora's `systemd` package installs it.
- The Fedora netinst ISO, described below.
- About 7 GB per host's disk, plus the test registry. imgman warns when less
  than 25 GB is free.

### Installer ISO

imgman never downloads the installer. Download the Fedora netinst ISO for the
Fedora version the Containerfiles set in `FEDORA_MAJOR_VERSION`, verify it,
and place it in `~/.cache/homelab-images/iso/`. For Fedora 44:

```sh
mkdir -p ~/.cache/homelab-images/iso && cd ~/.cache/homelab-images/iso
base=https://download.fedoraproject.org/pub/fedora/linux/releases/44/Everything/x86_64/iso
curl -fLO "$base/Fedora-Everything-44-1.7-x86_64-CHECKSUM"
curl -fLO "$base/Fedora-Everything-netinst-x86_64-44-1.7.iso"
gpg --dearmor </etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-44-primary >fedora-44.gpg
gpgv --keyring ./fedora-44.gpg Fedora-Everything-44-1.7-x86_64-CHECKSUM
sha256sum --check --ignore-missing Fedora-Everything-44-1.7-x86_64-CHECKSUM
rm fedora-44.gpg
```

Fedora's release key is already on every Fedora host. `gpgv` needs it
dearmored into a keyring file; it cannot read a key from a pipe. Keep exactly
one ISO for each Fedora version: imgman refuses to choose between two.

## How it works

**Disks.** `machine init` pushes the flavor's image to a local test registry,
then boots the ISO's installer kernel directly with the host's kickstart
appended to its initrd. The kickstart's `%pre` reads `imgman.*` kernel
arguments that point it at the test registry, the VM's disk, and a throwaway
LUKS passphrase; on hardware, without them, it uses the host's published image
and system disk, and Anaconda asks for the passphrase. imgman watches the
installer's console and stops QEMU as soon as Anaconda reports an error. After
a successful install, it checks that the stand-in data disks from `hosts.toml`
are still blank, and records the image ID, the kickstart's SHA-256, and the
pushed digest in a `.inputs` file next to the disk. A disk is stale when either
input differs; file timestamps play no part.

**Test registry.** One registry container, `homelab-image-registry`, listens
only on `127.0.0.1:5000`. QEMU's user networking forwards a VM's connections to
`10.0.2.2` to the host's loopback, so VMs reach the registry without the LAN.
Each host and flavor has its own repository, `<host>/workstation-<flavor>:test`.

**Booting.** Each boot uses a throwaway copy-on-write overlay, so the installed
disk never changes. The VM boots with Secure Boot enforced, from the Secure
Boot firmware with Microsoft's keys enrolled; the installer boots with the
standard firmware, because a kernel passed directly to QEMU skips shim. imgman
passes four systemd credentials: a one-time root SSH key, the hostname, the
throwaway LUKS passphrase, and a drop-in that skips `ansible-pull.service`.
imgman reaches the VM over SSH on a virtual socket (vsock).

**Locks.** Commands that change a host's VM or disks hold a per-host lock. A
second command on a busy host fails at once and names the command holding it.
`machine ssh` and `machine gui` never lock.

**Files.**

```text
~/.cache/homelab-images/
├── iso/                              the installer ISO
├── registry/                         the test registry's storage
└── <host>/
    ├── workstation-<flavor>.qcow2    the installed disk
    ├── workstation-<flavor>.inputs   what it was installed from
    ├── install/console.log           the installer's console
    ├── passed/                       image IDs that passed test image
    ├── lock
    └── run/                          the running VM: overlay, console.log, SSH key, SPICE socket
```

To investigate a failure, keep the VM running and look inside it:

```sh
imgman test image x1carbon23
imgman machine ssh x1carbon23 journalctl -b -p warning --no-pager
imgman machine gui x1carbon23
imgman machine rm x1carbon23
```

## Changing imgman

imgman uses only the Python standard library. The development tools are in the
`dev` dependency group, pinned in `uv.lock`: ruff, pyrefly, pytest, and
pykickstart. After any change, run these from this directory. All four must
pass before committing:

```sh
uv run ruff format
uv run ruff check
uv run pyrefly check
uv run pytest
```

- **Types.** pyrefly runs with its strict preset, which rejects implicit
  `Any`, and ruff's annotation rules reject explicit `Any`. Each kind of
  identifier has its own `NewType`, such as `HostName` and `Flavor`; data
  types are frozen dataclasses; commands are a union matched exhaustively
  with `assert_never`. Untyped input, such as `hosts.toml`, command-line
  arguments, and `bootc status` JSON, is parsed into typed values where it
  enters. Fix type errors rather than suppressing them.
- **External commands.** Every command goes through `process.run()`, or
  `process.spawn()` for one imgman watches while it runs. Functions take the
  runner, the clock, and similar dependencies as parameters, so tests replace
  them.
- **Tests.** pytest, with `tests/fakes.py` standing in for commands, background
  processes, and the clock. No test starts a VM, needs the network, or touches
  `~/.cache/homelab-images`; the suite runs in under a second. A test also
  validates every kickstart with pykickstart for both its hardware and VM
  targets. Give new behavior a test.
- **Real VMs.** After a change to how imgman installs or boots, run
  `imgman test image --all` too.
