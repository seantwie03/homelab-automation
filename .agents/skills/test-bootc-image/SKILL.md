---
name: test-bootc-image
description: Build this repository's bootc workstation image and test it in a VM installed from it, checking read-only /usr, writable /etc and /var, the Ansible bootstrap, and an upgrade followed by a rollback. Use before committing a change to a Containerfile or build script under immutable/images, or when checking how a bootc host behaves.
---

# Test Bootc Image

Use `immutable/images/vm_test.py` to build and test bootc images. It runs
without root: rootless Podman builds the image, `bcvk` installs it to a VM
disk, and QEMU boots the disk with KVM. Do not use `sudo`,
`bootc-image-builder`, or `bootc switch` on the host.

While iterating on an image change, rebuild it, which also runs the lint:

```sh
immutable/images/vm_test.py build
```

Before committing the change, run the whole cycle:

```sh
immutable/images/vm_test.py all
```

`all` builds `localhost/workstation-kde`, installs it to a disk under
`~/.cache/homelab-images`, boots the disk through a throwaway overlay, and
prints a `PASS` or `FAIL` line per check. It exits nonzero if any check
fails. A first run takes several minutes and needs about 30 GB free, so run it
in the background and wait for it to finish.

Run the steps separately to avoid repeating work:

```sh
immutable/images/vm_test.py build   # rebuild the image
immutable/images/vm_test.py disk    # reinstall the disk from the image
immutable/images/vm_test.py check   # boot the disk and run the checks
```

`check` uses the existing disk, so run `disk` after `build` to test a new
image. Select another Containerfile with `--flavor NAME`, which builds
`Containerfile.NAME`.

## Investigating failures

Keep the VM running after the checks, then run commands in it as root:

```sh
immutable/images/vm_test.py check --keep
immutable/images/vm_test.py ssh bootc status
immutable/images/vm_test.py ssh journalctl -b -p warning --no-pager
immutable/images/vm_test.py stop
```

The VM's console log is `~/.cache/homelab-images/run/console.log` while it
runs. Changes inside the VM are discarded when it stops.

## Upgrade test

The upgrade check starts a registry container, `homelab-image-registry`, on
`127.0.0.1:5000`. The VM reaches it at `10.0.2.2:5000` through QEMU user
networking. The check pushes the image plus one marker file in `/usr` to the
tag the VM tracks, then runs `bootc upgrade` and `bootc rollback` in the VM,
rebooting after each.

## Cleanup

Remove the registry, disks, and test images:

```sh
immutable/images/vm_test.py clean
```
