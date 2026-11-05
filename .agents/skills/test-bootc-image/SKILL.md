---
name: test-bootc-image
description: Build this repository's bootc images and test them in VMs installed with each host's kickstart, using imgman. Checks Secure Boot, LUKS2 on hosts whose kickstart encrypts, read-only /usr, writable /etc and /var, the kickstart's btrfs layout, a clean boot, and that the VM can reach its update source. Use before committing a change to a Containerfile, build script, kickstart, or hosts.toml under immutable/images, or when checking how a bootc host behaves.
---

# Test Bootc Image

Use `imgman`, in `immutable/imgman/`, to build bootc images and test them. It
runs without root: rootless Podman builds the image, Anaconda installs it to a
VM disk with the host's kickstart, and QEMU boots the disk with KVM. Do not use
`sudo`, `bootc-image-builder`, or `bootc switch` on this machine.

Run imgman from the repository root through uv, which works whether or not it
is installed:

```sh
uv run --project immutable/imgman imgman image build
```

While iterating on an image change, rebuild it, which also runs the lint:

```sh
uv run --project immutable/imgman imgman image build --all
```

Before committing the change, test every host:

```sh
uv run --project immutable/imgman imgman test image --all --rm --no-gui
```

`test image` builds each host's flavor, reinstalls the host's VM disk if the
image or the host's kickstart changed, boots it, and prints a `PASS` or `FAIL`
line per check. It exits 3 if any check fails. With current disks it takes
about 20 seconds per host; each reinstall adds about 7 minutes, so run it in
the background and wait for it to finish. Each host's disk needs about 7 GB.

Test one host by naming it, such as `imgman test image x1carbon23`.
`imgman/README.md` describes every command, the checks, and the exit codes.

## Investigating failures

`test image` without `--rm` leaves the VM running. Run commands in it as root,
then stop it:

```sh
uv run --project immutable/imgman imgman machine ssh x1carbon23 bootc status
uv run --project immutable/imgman imgman machine ssh x1carbon23 journalctl -b -p warning --no-pager
uv run --project immutable/imgman imgman machine rm x1carbon23
```

The VM's serial console is logged to
`~/.cache/homelab-images/<host>/run/console.log`, and the installer's to
`~/.cache/homelab-images/<host>/install/console.log`. A failed install shows
Anaconda's error at the end of the installer's console log. Changes inside a
running VM are discarded when it stops.
