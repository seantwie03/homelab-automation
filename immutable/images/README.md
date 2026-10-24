# Images

Bootable container images for bootc hosts. A host boots one of these images,
then configures everything outside it with ansible-pull. See the
[architecture](../docs/architecture.md) for what belongs in an image.

| File                  | Purpose                                                                                        |
|-----------------------|------------------------------------------------------------------------------------------------|
| `Containerfile.kde`   | `workstation-kde`: KDE Plasma on Kinoite.                                                      |
| `scripts/ansible.sh`  | Installs `git`, `python3`, `ansible-core`, and the Ansible collections that runtime roles use. |
| `hosts.toml`          | The hosts a VM can stand in for, and each host's flavor and VM resources.                      |
| `kickstart/<host>.ks` | Installs a host, on its hardware or as a VM.                                                   |
| `vm_test.py`          | Builds an image and tests it in a VM.                                                          |
| `vm_test_tests.py`    | Unit tests for `vm_test.py`.                                                                   |
| `ruff.toml`           | Lint and format settings for the Python files.                                                 |
| `ty.toml`             | Type checker settings for the Python files.                                                    |

## Contents

Each image starts from a Fedora base pinned to a major version by the
`FEDORA_MAJOR_VERSION` build argument, then adds:

- The Ansible bootstrap. `ansible-core` and the collections come from Fedora
  packages, which install collections to `/usr/share/ansible/collections`.
  ansible-pull runs on first boot with no network installs, and both update
  with the base image.

## Changing an image

- Put build logic in `scripts/*.sh`. Containerfiles stay thin: each step
  copies one script and runs it.
- Start scripts with `set -euo pipefail`, indent them with 4 spaces, and keep
  them ShellCheck clean:

  ```sh
  shellcheck images/scripts/*.sh
  ```

- Pin base images to a Fedora major version through `FEDORA_MAJOR_VERSION`.
  Never build from `:latest`.
- Leave `/var` and `/run` empty. bootc copies the image's `/var` only at
  install, so anything left there never reaches upgraded hosts. Every
  Containerfile ends with `RUN bootc container lint --fatal-warnings`, which
  fails the build on leftovers and on any other lint warning. If a base image
  update introduces a warning you can't fix, skip that lint with
  `--skip NAME` and a comment explaining why. `bootc container lint --list`
  lists the lints.
- To add a package repository with a signing key, check the key into
  `images/`, install it under `/etc/pki/rpm-gpg/`, import it from that file,
  verify its full fingerprint, and keep `gpgcheck` enabled. Document how to
  rotate the key in this README.
- To add an Ansible collection a role needs, add its `ansible-collection-*`
  package to `scripts/ansible.sh` and its name to `COLLECTIONS` in
  `vm_test.py`.
- After every change, build the image with `images/vm_test.py build`, which
  also runs the lint. Before committing, test the image in a VM with
  `images/vm_test.py all`, described below. The VM test takes about 5
  minutes, most of it installing the image to a disk.

## Building

Run from the repository root. The build context is this directory:

```sh
podman build \
    -f images/Containerfile.kde \
    -t localhost/workstation-kde \
    images
```

`images/vm_test.py build` runs the same command.

## Testing in a VM

`vm_test.py` installs an image to a VM disk and checks it in a booted VM. It
runs without root.

```sh
images/vm_test.py all     # build, install to a disk, and check
images/vm_test.py build   # build localhost/workstation-kde
images/vm_test.py disk    # install the image to a disk
images/vm_test.py check   # boot the disk and run the checks
images/vm_test.py clean   # remove the registry, disks, and test images
```

`--flavor NAME` selects `Containerfile.NAME`. `check` prints a `PASS` or
`FAIL` line per check and exits nonzero if any fails. It checks that:

- `bootc status` reports the image the disk was installed from.
- `/usr` is read-only, and `/etc` and `/var` are writable.
- `/opt`, `/srv`, and `/usr/local` link into `/var`.
- `ansible-pull` runs, and the collections from `scripts/ansible.sh` are
  installed.
- After `bootc upgrade` and a reboot, the VM runs the new image, and changes
  in `/etc` and `/var` survive.
- After `bootc rollback` and a reboot, the VM runs the original image, and
  changes in `/etc` and `/var` survive.

### Requirements

- Python 3.12 or later and `uv`. The `python` role installs `uv` and `ruff`.
- Podman, `bcvk`, QEMU, and the OVMF firmware. The `devops` role installs
  ShellCheck and `bcvk`, and the `libvirt` role installs QEMU and OVMF.
- Read and write access to `/dev/kvm` and `/dev/vhost-vsock`.
- An ssh configuration that sends `vsock/` hosts through `systemd-ssh-proxy`.
  Fedora's `systemd` package installs it.
- About 30 GB free for the image, the disk, and the test registry.

Before doing any work, `vm_test.py` checks what its command needs and lists
everything missing. It also warns when less than 15 GB is free. It exits 2 on
a usage error and 1 when a step or check fails.

### How it works

`bcvk to-disk` installs a test image to a qcow2 disk under
`~/.cache/homelab-images`. The test image is the image plus one change:
`sshd.service` is enabled. bcvk runs the installer in a VM booted from the
image it installs and reaches that VM over SSH on TCP, while workstation
images leave sshd disabled. Each `check` boots the disk through a throwaway
copy-on-write overlay, so the installed disk never changes.

The harness itself reaches the VM over SSH on a virtual socket (vsock), which
systemd's SSH generator opens in any VM whether or not `sshd.service` is
enabled. A one-time root key arrives in a `tmpfiles.extra` systemd credential,
which systemd-tmpfiles writes to `/var/roothome/.ssh` at boot. The host's
`systemd-ssh-proxy` configuration handles `ssh vsock/CID`.

The upgrade check needs a registry the VM can pull from. The harness runs a
`docker.io/library/registry` container, `homelab-image-registry`, listening
only on `127.0.0.1:5000`. QEMU user networking forwards the VM's connections
to `10.0.2.2` to the host's loopback interface, so the VM reaches the registry
at `10.0.2.2:5000` without exposing it to the network. The test image is
tagged `10.0.2.2:5000/workstation-kde:test` before it is installed, so the VM
tracks that tag. The check pushes the test image plus one marker file in
`/usr` to the tag, then runs `bootc upgrade` in the VM, which fetches only the
new layer.

The upgrade image depends only on the test image, so the harness builds and
pushes it in a background thread: during `check`, while the VM boots and the
layout checks run; during `all`, while bcvk installs the disk. Each step logs
its duration.

To investigate a failure, keep the VM running and run commands in it as root:

```sh
images/vm_test.py check --keep
images/vm_test.py ssh bootc status
images/vm_test.py stop
```

While the VM runs, its serial console is logged to
`~/.cache/homelab-images/run/console.log`.

## Changing the test harness

`vm_test.py` uses only the Python standard library. Its first lines are an
inline metadata block ([PEP 723](https://peps.python.org/pep-0723/)), and its
`#!` line runs it with `uv run --script`. If it ever needs a third-party
package, declare it in that block's `dependencies` list, and `uv` installs it
into a cached environment. Do not add packages any other way.

Every function has type annotations. After changing either Python file, run
these from this directory:

```sh
ruff format vm_test.py vm_test_tests.py
ruff check vm_test.py vm_test_tests.py
ty check
./vm_test_tests.py
```

- `ruff.toml` sets a 100-column limit and adds import sorting, modern syntax,
  likely-bug, simplification, and required-annotation rules to ruff's
  defaults.
- `ty`, Astral's type checker, checks the annotations. It is in beta, so a new
  version can report new problems. `ty.toml` puts this directory on its import
  path, which is why `vm_test_tests.py` has no inline metadata block: `ty`
  checks a file that has one in isolation, where it cannot import `vm_test`.
- `vm_test_tests.py` mocks every external command, so the unit tests run in
  under a second and never start a VM. Give new behavior a test there.

Before committing, also run `vm_test.py all`.
