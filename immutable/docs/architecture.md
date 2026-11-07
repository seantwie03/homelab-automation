# Architecture

Each host boots a bootc image built from this repository, then configures
itself with ansible-pull. The image owns the operating system. Ansible owns
everything a running host is allowed to change.

## Two layers

```text
Image: built from images/, deployed to /usr
  Kernel and modules, desktop or kiosk compositor, system packages,
  repositories and signing keys, Ansible bootstrap
                         │ boots into
                         ▼
Runtime: ansible-pull on each host, writing /etc, /var, and home directories
  Host configuration, per-host service enablement, mounts, users and groups,
  Flatpaks, scripts in /usr/local, user-space CLI tools, dotfiles
```

A change belongs in the image if it installs software or writes under `/usr`,
apart from `/usr/local`.
Everything else belongs in a runtime role.

## Images

**Status:** proposed.

| Image                    | Base                                           | Hosts                |
|--------------------------|------------------------------------------------|----------------------|
| `workstation-kde-nvidia` | Kinoite, plus ublue's prebuilt NVIDIA packages | desktop22, desktop25 |
| `workstation-kde`        | Kinoite                                        | x1carbon23           |
| `server`                 | fedora-bootc                                   | odroidh3plus         |

Niri and GNOME variants are possible additions (D2). `images/README.md` covers
building, switching, upgrades, and rollback.

### Tags

Each build is pushed to GHCR under a tag of its build date and git commit,
such as `:20261106-7ad2330`, and is identified by its digest. `:stable` is the
only tag that moves. CI moves it to a build once the build passes its VM tests,
and every host tracks it: a host stages each new `:stable` build in the
background and boots it at its next reboot, with the previous deployment one
GRUB entry away. How long old builds are kept is open.

## Filesystem

**Status:** decided for workstation images, where every VM test checks the
read-only, writable, and linked paths. Proposed for the server image.

| Path         | Owned by     | Behavior                                                           |
|--------------|--------------|--------------------------------------------------------------------|
| `/usr`       | Image        | Read-only on a running host.                                       |
| `/etc`       | Runtime      | Writable. Local changes carry across image updates through a       |
|              |              | three-way merge.                                                   |
| `/var`       | Runtime      | Persistent and writable. Holds `/var/home`, Flatpaks, and          |
|              |              | container storage. bootc copies the image's `/var` only at         |
|              |              | install, so image builds leave it empty.                           |
| `/`          | Image        | Read-only. The image adds no top-level directories.                |
| `/srv`       | Runtime      | Links to `/var/srv` in every base image. Holds mounted and shared  |
|              |              | storage: `/srv/source`, `/srv/tier1`, and `/srv/tier2` (NFS mounts |
|              |              | on clients, local data on odroidh3plus) and `/srv/games` (a local  |
|              |              | games disk). Runtime roles create these directories.               |
| `/opt`       | Runtime on   | Kinoite links it to `/var/opt`. fedora-bootc ships it as a         |
|              | workstations | read-only directory.                                               |
| Repository   | Runtime      | `/opt/homelab-automation` on workstations. The server's location   |
| checkout     |              | is open.                                                           |
| `/usr/local` | Runtime      | Links to `/var/usrlocal` in every image. Kinoite ships the link,   |
|              |              | and the server image adds it in place of fedora-bootc's read-only  |
|              |              | directory. Holds the scripts runtime roles install for systemd,    |
|              |              | root, and `sudo`, in `/usr/local/bin`.                             |
| System disk  | Kickstart    | The EFI partition and `/boot` are unencrypted. On an encrypted     |
|              |              | host, a LUKS2 container holds the btrfs volume with `root`, `var`, |
|              |              | and `home` (D8).                                                   |

## Testing Strategy

**Status:** proposed.

Every change is tested in a VM booted from an image before it reaches a host.
What a VM cannot show is checked on the host itself.

### Tested in a VM

VMs are created using the host's kickstart. Playbooks targeting specific hosts
see the disk layout and users they expect. With this setup VMs can test:

- Secure Boot
- File system layout: read-only `/usr`, writable `/etc` and `/var`
- A clean boot, with no failed units
- Upgrades
- Rollbacks
- Ansible roles and idempotency

Every host tracks `:stable` ([Tags](#tags)), so each change is tested on the
image it will meet:

- A playbook change converges on `:stable`.
- A new build converges with the playbook on `main` before `:stable` moves to
  it.

Hosts run `:stable` nearly all the time: most new builds are the weekly rebuild
with Fedora's updates, and image changes made here are rare, because most
configuration lives in runtime roles. A host that has not rebooted for a while
runs an older build, but older builds differ from `:stable` mostly in Fedora's
package updates. Two consequences follow:

- A role change that needs new image content waits until that image is
  `:stable`: the image change first, the role change later.
- A host that rolls back from `:stable` runs an image the playbook was not
  tested on, and its ansible-pull runs may fail. Disable the timer with
  `h job disable` until the host is upgraded again.

Changes are tested in a VM before they are committed. CI also runs each
playbook change on `:stable`, but the change reaches hosts through ansible-pull
as soon as it is on `main`, so CI can only report a failing playbook after the
fact. Testing before committing is the gate.

Container tests were rejected. A container shares the host's kernel and is not
a bootc deployment, so it shows less than a VM without a faster loop, and
playbooks written for `hosts: localhost` would need changes to target one.

#### Capability Tests

One thing we don't want is tests becoming a copy of the Ansible tasks in
reverse by ensuring that a package is installed when a task clearly says to
install it. Instead, we will test capabilities. Example: when I open this
TypeScript file with Neovim the `ts_ls` language server attaches. That one
check covers Neovim, Node.js, the language server install, the dotfiles, and
`PATH` together. A VM runs the capability tests after its playbook converges. A
capability test that should keep passing on a running host is also the check in
the owning role's MONITORING file.

### Not Testable in a VM

A VM is not good at testing specific hardware. Testing that an NVIDIA module
loads under Secure Boot or that a TPM2 unlock works is not easily done in a VM.

## Decisions

Each decision records why it was made and what it rules out. **Decided** means
settled. **Proposed** means the direction is chosen but still needs validation.

### D1. Bootable container images with runtime Ansible

**Status:** decided.

Every host, including the server, runs a bootc image. ansible-pull manages
everything outside the image.

**Why:** Updates and rollbacks apply to the whole OS as one known build.
Changing desktops replaces `/usr` without leftover packages. The workflow
matches RHEL 10 image mode. ansible-pull keeps host configuration in this
repository, and each host applies its own without a central control node.

**Alternatives rejected:**

- Traditional Fedora with Btrfs/Snapper rollback: snapshots
  restore a filesystem state rather than a known OS build, and package drift
  accumulates.
- Stock Fedora Atomic with rpm-ostree package layering: layered packages are
  per-host state outside the repository.
- Universal Blue images such as Aurora or Bazzite, used directly: less control
  over contents, and no practice building images.

**Consequences:** A package change means an image build and a reboot. Runtime
roles never install packages. Images need a build and publishing pipeline
(D5).

### D2. One base image per desktop

**Status:** decided for KDE; proposed for the others.

KDE builds on Kinoite (`quay.io/fedora/fedora-kinoite`) and GNOME on
Silverblue. Niri and the server build on fedora-bootc
(`quay.io/fedora/fedora-bootc`). All of these come from Fedora release
engineering.

**Why:** The Fedora desktop images already include the display manager,
portals, and session services for their desktop. Adding a full desktop to a
minimal base means maintaining all of that here.

**Alternatives rejected:**

- One fedora-bootc base with every desktop added by scripts. It shares one
  layer cache, but this repository would own each desktop's composition.
- `quay.io/fedora-ostree-desktops/kinoite`, the Atomic Desktops SIG's CI
  channel. It publishes the same composes with dated tags and sigstore
  signatures, but it is a testing channel rather than a release.

**Consequences:** Flavors share no layer cache. Shared build scripts keep
common steps in one place. Each base is pinned to a Fedora major version, so
major upgrades are deliberate changes. The release repositories publish only
the major-version tag and no signatures, so a build is reproducible only
through the base image digest it records.

### D3. NVIDIA modules from Universal Blue

**Status:** proposed.

NVIDIA images install Universal Blue's prebuilt, signed open kernel modules
and the matching NVIDIA driver packages. Both come from
`ghcr.io/ublue-os/akmods-nvidia-open`, which is mounted only for the build step
that runs its installer.

**Why:** Compiling `akmod-nvidia` during the build takes 10–15 minutes, needs
`kernel-devel` to match the image kernel exactly, and needs a private signing
key in CI.

**Alternative rejected:** Building and signing the modules here with a locally
generated Machine Owner Key.

**Consequences:** Each NVIDIA host enrolls Universal Blue's public certificate
once. Kernel updates wait for matching modules. The open modules support Turing
and newer GPUs, which covers the RTX 4070 SUPER and the RTX 2070.

### D4. Everyday CLI tools in user space

**Status:** proposed.

Runtime Ansible downloads pinned release builds, verifies their checksums,
installs each version into its own directory under `~/.local/share`, and links
the active version into `~/bin`. The image carries only what Ansible needs to
run.

**Why:** Updating a tool needs no image build or reboot. The same versions run
on every host, and switching back to an installed version needs no download.

**Alternatives rejected:**

- RPMs in the image: every tool update is an image build and a reboot.
- Toolbx or Distrobox: tools run inside a container, adding a step to everyday
  use.
- Homebrew: a second package manager with its own update sprawl.

**Consequences:** This repository maintains versions and checksums by hand.

### D5. Images published to GHCR and promoted by tag

**Status:** proposed.

CI builds every image when its sources change and weekly. An image's sources
are the `images/` directory, which is its only build context. Playbooks, roles,
and dotfiles reach hosts through ansible-pull, never through the image, so
changing them never builds or publishes an image. CI tests a playbook change
without a build, as the [testing strategy](#testing-strategy) describes.

CI moves `:stable`, the tag every host tracks, to a build once the build
passes its VM tests. [Tags](#tags) describes the scheme.

**Why:** Weekly builds pick up Fedora updates, and no host receives a build
that failed its VM tests. Workstations boot a new image only at a reboot you
do, so a bad build shows at once, and the previous deployment is one GRUB
entry away. Playbooks change more often than images, and a playbook change
reaches hosts on their next ansible-pull run without a new image.

**Alternatives rejected:**

- Each host building its own image, which needs build tooling and build time
  on every host.
- A canary host that runs each build before `:stable` moves to it. It adds a
  tag and a manual promotion step, and the workstations already reboot into
  new images only while someone watches. Revisit it if hosts start rebooting
  into updates on their own, as the server may.

**Consequences:**

- A build that passes its VM tests reaches every host at its next update, with
  no manual step. Rolling back a bad build is choosing the previous deployment
  in GRUB, or `bootc rollback`.
- Anything baked into an image lives under `images/`, such as repository
  signing keys. Copying a file in from a role would make role changes rebuild
  the image.

### D8. Full-disk encryption

**Status:** decided for laptops. Open for each desktop and the server.

Laptops encrypt the system disk with LUKS2. The EFI partition and `/boot` stay
unencrypted, and the btrfs volume with `root`, `var`, and `home` sits inside
the LUKS2 container. A laptop unlocks with TPM2 + PIN, sealed to PCR 7, the
Secure Boot state, with a recovery key stored in 1Password. A desktop or server
that is encrypted unlocks with TPM2 automatic unlock.

**Why:** A laptop travels, so the main threat is the whole machine being stolen
while powered off. With TPM2 + PIN, the key never leaves the TPM, which limits
PIN guesses, so a short PIN protects the disk and a copied disk is useless
elsewhere. TPM2 automatic unlock releases the key to anyone who boots the
machine: PCR 7 does not cover the kernel command line, so adding
`systemd.debug-shell` at the GRUB menu gives a root shell on the unlocked disk.
That is acceptable only for machines that stay at home, where the threat is a
disk leaving the house for warranty replacement or disposal and unattended
reboots matter.

**Alternatives rejected:**

- A passphrase at every boot, with no TPM: a long passphrase each boot, and
  anyone with a copy of the disk can guess it offline.
- The SSD's OPAL self-encryption: drive firmware implementations have had
  serious flaws, and Anaconda does not set it up.
- Encrypting every host for uniformity: each host has its own kickstart, so
  encryption is one host's `part` line either way, and uniformity saves no
  work.

**Consequences:**

- The passphrase never enters the repository. The hardware install's
  kickstart has no `--passphrase`, so Anaconda asks for one. VM installs use a
  throwaway passphrase passed on the kernel command line, and the VM unlocks
  from a systemd credential. VMs have no TPM.
- TPM enrollment is a one-time step on the hardware, after the install. It
  needs the real TPM, and PCR 7 differs between the installer's boot and the
  installed system's.
- The initramfs is built into the image, so nothing in the host's
  `/etc/crypttab` reaches it. Unlock settings come from the LUKS2 header's
  token or from kernel arguments.
- Anything that changes PCR 7, such as a Secure Boot database update or
  toggling Secure Boot, needs a re-enrollment, unlocking once with the
  recovery key.
- Neither unlock method stops an attacker who tampers with the boot and waits
  for the owner to type the PIN: Fedora's image-based systems do not sign the
  initramfs.
