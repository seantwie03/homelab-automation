# Architecture

Each host boots a bootc image built from this repository, then configures
itself with ansible-pull. The image owns the operating system. Ansible owns
everything a running host is allowed to change.

## Two layers

```text
Image: built from images/, deployed to /usr
  Kernel and modules, desktop or kiosk compositor, system packages,
  repositories and signing keys, Ansible bootstrap, h
                         │ boots into
                         ▼
Runtime: ansible-pull on each host, writing /etc, /var, and home directories
  Host configuration, per-host service enablement, mounts, users and groups,
  Flatpaks, user-space CLI tools, dotfiles
```

A change belongs in the image if it installs software or writes under `/usr`.
Everything else belongs in a runtime role.

## Images

**Status:** proposed.

| Image                    | Base                                           | Hosts                |
|--------------------------|------------------------------------------------|----------------------|
| `workstation-kde-nvidia` | Kinoite, plus ublue's prebuilt NVIDIA packages | desktop22, desktop25 |
| `workstation-kde`        | Kinoite                                        | x1carbon2018         |
| `server`                 | fedora-bootc                                   | odroidh3plus         |

Niri and GNOME variants are possible additions (D2). `images/README.md` covers
building, switching, upgrades, and rollback.

## Filesystem

**Status:** proposed. Each row is verified in a VM before roles depend on it.

| Path | Owned by | Behavior |
| --- | --- | --- |
| `/usr` | Image | Read-only on a running host. |
| `/etc` | Runtime | Writable. Local changes carry across image updates through a three-way merge. |
| `/var` | Runtime | Persistent and writable. Holds `/var/home`, Flatpaks, and container storage. |
| `/` | Image | Read-only. The only top-level directory the image adds is `/srv`. |
| `/srv` | Image | Holds mounted and shared storage: `/srv/source`, `/srv/tier1`, and `/srv/tier2` (NFS mounts on clients, local data on odroidh3plus) and `/srv/games` (a local games disk). |
| Repository checkout | Runtime | Location to be decided. |
| `/usr/local` | Runtime | Expected to link to `/var/usrlocal`; to be confirmed. |

## Decisions

Each decision records why it was made and what it rules out. **Decided** means
settled. **Proposed** means the direction is chosen but still needs validation.

### D1. Bootable container images with runtime Ansible

**Status:** decided.

Every host, including the server, runs a bootc image. ansible-pull stays and
manages everything outside the image.

**Why:** Updates and rollbacks apply to the whole OS as one known build.
Changing desktops replaces `/usr` without leftover packages. The workflow
matches RHEL 10 image mode. The existing ansible-pull model carries over for
host configuration.

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

**Status:** proposed.

KDE builds on Kinoite and GNOME on Silverblue. Niri and the server build on
fedora-bootc.

**Why:** The Fedora desktop images already include the display manager,
portals, and session services for their desktop. Adding a full desktop to a
minimal base means maintaining all of that here.

**Alternative rejected:** One fedora-bootc base with every desktop added by
scripts. It shares one layer cache, but this repository would own each
desktop's composition.

**Consequences:** Flavors share no layer cache. Shared build scripts keep
common steps in one place. Each base is pinned to a Fedora major version, so
major upgrades are deliberate changes.

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

CI builds every image when its sources change and weekly. Each build gets a
date-and-commit tag and is identified by digest. desktop22 follows the newest
build. Other hosts move to a tag after desktop22 has run it.

**Why:** Weekly builds pick up Fedora updates. Hosts other than the canary
never receive an untested build.

**Alternative rejected:** Each host building its own image, which needs build
tooling and build time on every host.

**Consequences:** Promoting a release is a manual step.

### D6. Three test tiers

**Status:** proposed.

| Tier | Environment | Shows | Cannot show |
| --- | --- | --- | --- |
| 1 | Container | Runtime roles converge and are idempotent; tools and dotfiles install. | bootc behavior, read-only `/usr`, upgrades. |
| 2 | VM booted from the image | Filesystem layout, `/etc` merge, persistence, upgrade and rollback. | GPU, Secure Boot, peripherals. |
| 3 | desktop22 hardware | NVIDIA under Secure Boot, desktop session, audio, peripherals, daily use. | — |

**Why:** Each tier covers what the cheaper tier cannot.

**Consequences:** A VM harness exists before the first host changes, and no
hardware change happens before tier 2 passes.
