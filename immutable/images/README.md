# Images

Bootable container images for bootc hosts. A host boots one of these images,
then configures everything outside it with ansible-pull. See the
[architecture](../docs/architecture.md) for what belongs in an image.

| File                  | Purpose                                                                                        |
|-----------------------|------------------------------------------------------------------------------------------------|
| `Containerfile.kde`   | `workstation-kde`: KDE Plasma on Kinoite.                                                      |
| `scripts/ansible.sh`  | Installs `git`, `python3`, `ansible-core`, and the Ansible collections that runtime roles use. |
| `scripts/base.sh`     | Installs the command-line tools every host uses that the base image lacks.                     |
| `scripts/updates.sh`  | Stages OS updates in the background without rebooting.                                         |
| `scripts/onepassword.sh` | Installs the 1Password app and CLI.                                                         |
| `keys/`               | Signing keys of the package repositories the scripts use.                                      |
| `bin/h`               | `h`, the homelab management script, installed as `/usr/bin/h`, with its bash completion.       |
| `hosts.toml`          | The hosts a VM can stand in for, and each host's flavor and VM resources.                      |
| `kickstart/<host>.ks` | Installs a host, on its hardware or as a VM.                                                   |

## Contents

Each image starts from a Fedora base pinned to a major version by the
`FEDORA_MAJOR_VERSION` build argument, then adds:

- The Ansible bootstrap. `ansible-core` and the collections come from Fedora
  packages, which install collections to `/usr/share/ansible/collections`.
- `h`, which manages the host's `ansible-pull` runs. It reads the host's
  settings from `/etc/ansible-pull.conf`, which the `ansible_pull` role writes,
  so the image holds no host-specific paths.
- Command-line tools every host uses, such as `wget` and `7z`.
- Staged OS updates. `bootc-fetch-apply-updates.timer` is enabled, with a
  drop-in that runs `bootc upgrade` without `--apply`: it downloads a newer
  image and stages it an hour after boot and every 8 hours, and the host
  boots into it at the next reboot you do. Nothing reboots the host on its
  own.
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
  package to `scripts/ansible.sh`.
- After every change, build the image with `imgman image build`, which also
  runs the lint. Before committing, test it in VMs with
  `imgman test image --all`, which installs a host's disk again only if the
  image or the host's kickstart changed. See [imgman](../imgman/README.md).

## 1Password

`scripts/onepassword.sh` installs the 1Password app and CLI from 1Password's
repository, then adapts what their install scripts assume about a writable
system:

- They install to `/opt/1Password`. The script moves the files to
  `/usr/lib/1Password`, and `systemd-tmpfiles` links `/opt/1Password` to them
  at boot.
- They create the `onepassword`, `onepassword-cli`, and `onepassword-mcp`
  groups for their setgid helpers. The script creates them first with fixed
  system IDs 450 to 452, below Fedora's dynamically allocated system groups and
  below regular users, and declares the same IDs in `sysusers.d`.
- Their polkit policy names the users allowed to authorize the CLI and SSH
  agent. The script names UID 1000, every host's user.

The repository's signing key is `keys/1password.asc`. The script verifies its
fingerprint before importing it. If 1Password rotates the key, the build fails
until it is updated:

```sh
curl -fsSL https://downloads.1password.com/linux/keys/1password.asc \
    -o images/keys/1password.asc
gpg --show-keys --with-fingerprint images/keys/1password.asc
```

Check the new fingerprint against 1Password's published one, then set
`fingerprint` in `scripts/onepassword.sh` to it, with no spaces.

## Building

Run from the repository root. The build context is this directory:

```sh
podman build \
    -f images/Containerfile.kde \
    -t localhost/workstation-kde \
    images
```

`imgman image build` runs the same command.

## Hosts and kickstarts

`hosts.toml` lists the hosts imgman can run as VMs: each host's flavor, any
data disks its kickstart must leave alone, and the VM's memory and vCPUs.
Each host has one kickstart, `kickstart/<host>.ks`, which installs both its
hardware and its VM. The kickstart's `%pre` reads `imgman.*` kernel arguments
that point the install at the test registry, the VM's disk, and a throwaway
LUKS passphrase; without them, as on hardware, it uses the host's published
image and system disk, and Anaconda asks for the passphrase. Every kickstart's
`%post` undoes what Anaconda does that does not suit a bootc host:

- It removes the `/` line from `/etc/fstab`. bootc mounts the composefs root
  from the kernel command line, and the line makes `systemd-remount-fs` fail.
- It removes Anaconda's `default.target` link to `multi-user.target`, so the
  image's `graphical.target` applies.
- It creates `/etc/plasma-setup-done`, so KDE's first-boot wizard does not run
  for the user the kickstart already created.

btrfs takes `compress` from the file system's first mount, the initramfs
mounting root, so each kickstart puts `compress=zstd:1` in `rootflags` on the
kernel command line, not in fstab.

## Testing in a VM

See [imgman](../imgman/README.md).
