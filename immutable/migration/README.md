# Immutable migration plan

Move every host from traditional Fedora to bootc images built from this
repository, keeping ansible-pull for everything outside the image.

**Current phase:** 1, first image and VM test loop.

This directory holds material that only matters during the migration and is
deleted when it ends. Everything else under `immutable/` is the future
repository root. See [how the overlay works](#how-the-overlay-works).

The original single-document plan is kept as
[original-plan.md](original-plan.md) for its code sketches. The sketches are
unvalidated starting points for the real files. Delete it once nothing in it is
needed.

## Goal

- Transactional OS updates and rollback, replacing Btrfs/Snapper root rollback.
- Desktop changes by switching images, without leftover packages.
- Hands-on practice with the image-mode workflow used by RHEL 10.
- Everyday CLI tools available directly, without Toolbx, Distrobox, or
  Homebrew.

The reasons and rejected alternatives are in the
[architecture decisions](../docs/architecture.md#decisions).

## Scope

| Order | Host | Purpose | GPU | Target image |
| --- | --- | --- | --- | --- |
| 1 | desktop22 | Workstation, canary | NVIDIA RTX 4070 SUPER | `workstation-kde-nvidia` |
| 2 | desktop25 | Workstation | NVIDIA RTX 2070, installed before cutover | `workstation-kde-nvidia` |
| 3 | x1carbon2018 | Laptop | Intel | `workstation-kde` |
| 4 | odroidh3plus | Server, NFS/SMB, retro-gaming kiosk | Intel | `server` |

Agent workspaces (section 7 of the original plan) are a separate project.

## How the overlay works

`immutable/` is laid out like the future repository root. It lives on `main`
next to the current tree, and traditional hosts never read it.

1. Add a file under `immutable/` only when it is new or replaces a root file.
   Unchanged files stay at the root.
2. Copy a root file in only when you start changing it. A copy stops receiving
   changes made to the root version.
3. Bootc hosts run `immutable/<host>.yml` with
   `ANSIBLE_CONFIG=immutable/ansible.cfg`. Its `roles_path` lists the overlay
   roles first and the root roles second, so a copied role replaces the root
   one only for bootc hosts. Relative paths in that file resolve from
   `immutable/`.
4. `migration/` never moves to the root.

Exceptions to the mirror rule:

- `immutable/AGENTS.md` holds only the rules that differ from the root
  `AGENTS.md`. Agents load it in addition to the root file. It is merged into
  the root file at the end.
- CI workflows live in the root `.github/workflows/`, because GitHub reads
  workflows only from there.

## Phases

A phase is done when its "done when" holds and the durable docs for what it
delivered exist under `immutable/`.

### Phase 0: Overlay setup

**Depends on:** nothing.

**Done when:** `immutable/` is on `main`, `ansible-lint` passes, and ansible-pull
runs on the current hosts are unaffected.

- [x] Copy `immutable/` to `main`.
- [x] Add to the root `AGENTS.md`: "Files under `immutable/` also follow
  `immutable/AGENTS.md`."
- [x] Create `immutable/ansible.cfg`: overlay role directories first, then the
  same directories under `../roles/`.

### Phase 1: First image and VM test loop

**Depends on:** Phase 0, Q1, Q2, Q10, Q11.

**Done when:** a KDE image without NVIDIA builds from `immutable/images/`, its
scripts pass ShellCheck, and it boots in a VM where these checks pass: `/usr` is
read-only, `/etc` is writable, data in `/var` survives an upgrade and a
rollback, and `bootc status` reports the expected image.
`immutable/images/README.md` explains how to build and boot it, and
`immutable/AGENTS.md` lists the build and test commands.

- [ ] `immutable/images/Containerfile.kde` and shared scripts: repositories,
  Ansible bootstrap (`git`, `python3`, `ansible-core`, pinned collections),
  and `/srv`.
- [ ] VM harness (tier 2): build a disk from the image, boot it with a
  copy-on-write overlay, run the checks over SSH, exit nonzero when a check
  fails.
- [ ] Upgrade and rollback rehearsal in the VM.
- [ ] Agent skill that wraps the harness.

### Phase 2: Runtime roles for desktop22

**Depends on:** Phase 1, Q7, Q8, Q9.

**Done when:** `immutable/desktop22.yml` converges in the VM from a fresh image,
a second run reports no changes, and every role under [desktop22](#desktop22)
is checked off with its README and MONITORING current.

- [ ] Container tests (tier 1) for fast role iteration.
- [ ] Refactor desktop22's roles (see the [role checklist](#role-checklist)).
- [ ] `immutable/desktop22.yml`.
- [ ] `ansible_pull`: the unit runs `immutable/desktop22.yml` with the overlay
  config, and `h` is baked into the image.

### Phase 3: NVIDIA and Secure Boot

**Depends on:** Phase 1, Q3.

**Done when:** the NVIDIA variant builds, desktop22 has the module-signing
certificate enrolled, and `immutable/images/README.md` covers NVIDIA builds,
enrollment, and certificate rotation. Module loading under Secure Boot can only
be confirmed on hardware, in Phase 5.

- [ ] NVIDIA build option using Universal Blue's prebuilt modules.
- [ ] Certificate fingerprint checked against a source independent of the
  download.
- [ ] Certificate enrolled on desktop22. Enrollment is stored in firmware, so it
  can happen before cutover.

### Phase 4: desktop22 cutover

**Depends on:** Phases 2 and 3, Q4, a verified backup.

**Done when:** desktop22 boots the custom NVIDIA image, runtime Ansible has
converged, restored data is readable, and the games SSD is intact.

- [ ] Rehearse the whole install in a VM: installer, disk layout, restore,
  switch to the custom image.
- [ ] Write `desktop22-cutover.md` from the rehearsal. Identify disks on the
  day; device names in the original plan are historical.
- [ ] Write the generic install steps into "Getting Started" in
  `immutable/README.md`.
- [ ] Back up, install, restore, switch, run ansible-pull.

### Phase 5: desktop22 acceptance

**Depends on:** Phase 4.

**Done when:** the checks below pass, an upgrade and a rollback on the hardware
keep user and games data, and desktop22 has been the daily driver for a soak
period (length to be decided) without falling back.

Recurring checks move into the MONITORING file of the role or image that owns
them, where `check-homelab-host` uses them after every upgrade:

- [ ] CLI (`cli`): `nvim`, `rg`, `fd`, `bat`, `yazi`, `zsh`, and `tmux` run;
  Neovim finds its runtime files.
- [ ] DNS (`nextdns`): resolver active, NextDNS DNS-over-TLS works, short names
  resolve through the search domain.
- [ ] NFS (`network_storage`): `/srv/source`, `/srv/tier1`, and `/srv/tier2`
  automount with the intended permissions.
- [ ] VPN (`tailscale`): authenticates and routes.
- [ ] Audio (image): PipeWire and WirePlumber run; output switching and media
  keys work.
- [ ] Gaming (`gaming`): Steam sees the `/srv/games` library; Proton games and
  controllers work.
- [ ] Zoom (`gui`): launches; audio, microphone, and screen sharing work.
- [ ] GPU (image): modules load under Secure Boot; `nvidia-smi` reports the
  GPU; CUDA and multi-monitor Wayland work.

One-time checks:

- [ ] `/var/home/sean` restored with correct ownership and SELinux labels.
- [ ] Games SSD mounted at `/srv/games` with its contents intact, and Steam's
  library folder re-added at the new path.

### Phase 6: Image publishing

**Depends on:** Phase 5, Q5, Q6.

**Done when:** CI builds and pushes every image to GHCR on change and weekly,
promotion works as documented in `immutable/images/README.md`, and desktop22
updates from the registry instead of local builds.

- [ ] `.github/workflows/build-images.yml` at the root.
- [ ] Tag, digest, and retention scheme.
- [ ] Promotion from the canary to other hosts.
- [ ] Automatic OS updates on each host.

### Phase 7: desktop25 and x1carbon2018

**Depends on:** Phase 6.

**Done when:** both hosts run a promoted image and pass the recurring checks
that apply to them.

- [ ] Refactor the remaining roles they use (see
  [desktop25 and x1carbon2018](#desktop25-and-x1carbon2018)).
- [ ] `immutable/desktop25.yml` and `immutable/x1carbon2018.yml`.
- [ ] Install the RTX 2070 in desktop25 and enroll Universal Blue's certificate
  there before its cutover.
- [ ] A cutover runbook per host, adapted from desktop22's.
- [ ] Optional: a Niri variant to exercise desktop switching (Q13).

### Phase 8: odroidh3plus

**Depends on:** Phase 6, Q12.

**Done when:** odroidh3plus runs the `server` image; NFS, SMB, karakeep,
orbit, the retro-gaming kiosk, the Tailscale exit node, and `/srv` snapshots
work; and clients' NFS automounts recover.

- [ ] `server` image: fedora-bootc, no desktop, `cage` for the kiosk.
- [ ] Refactor the server roles (see [odroidh3plus](#odroidh3plus)).
- [ ] `immutable/odroidh3plus.yml`.
- [ ] Move `/source` to `/srv/source` on odroidh3plus and point every client's
  mount at the new export.
- [ ] A cutover runbook, including downtime for NFS clients.

### Phase 9: Move to the root

**Depends on:** Phases 7 and 8.

**Done when:** the repository root is the new tree, `immutable/` is gone, and
every host's ansible-pull run is green.

- [ ] For each copied file, port root changes made since the copy.
- [ ] Delete root files that were replaced or are obsolete, including the `dnf`
  and `rpm_fusion` roles. Decide whether to keep roles no host uses (`niri`,
  `hyprland`, `waybar`, `virtualbox`, and others).
- [ ] Merge `immutable/AGENTS.md` and `immutable/ansible.cfg` into their root
  versions, and remove the pointer line from the root `AGENTS.md`.
- [ ] Move the rest of `immutable/`, except `migration/`, to the root. Update
  CI paths and the ansible-pull unit template.
- [ ] Leave `immutable/<host>.yml` shims that import the root playbooks, and
  `immutable/ansible.cfg`, until every host has run once from the root. Each
  host's unit points into `immutable/` until its next run re-templates it.
- [ ] Delete `immutable/`. Optionally keep a short retrospective in
  `docs/projects/`.

### Phase 10: YOLO Agent Setup

- [ ] Move section 7 of the original plan to
  `docs/projects/agent-workspaces.md`.

## Role checklist

Each entry records what moves to the image and what stays in the runtime role.
The entries come from the original plan's audit; confirm each one while
refactoring the role.

### desktop22

Includes roles pulled in as dependencies.

- [ ] `core`: base packages to the image; limits, sysctl, and group membership
  stay.
- [ ] `ansible_pull`: `ansible-core`, `git`, collections, and `h` to the image;
  units and logrotate stay; drop pip upgrades, `dnf-makecache` ordering, and
  Snapper hooks.
- [ ] `dnf`: drop; OS updates come from images (Q6).
- [ ] `rpm_fusion`: drop; repositories are configured in the image build.
- [ ] `btrfs`: `btrbk` to the image; configuration and timers stay. Check
  which snapshots still make sense with bootc.
- [ ] `wifi`: NetworkManager and firmware to the image; connection profiles
  stay.
- [ ] `nextdns`: packages to the image; resolver configuration stays.
- [ ] `tailscale`: package to the image; enablement, sysctl, and routes stay.
- [ ] `network_storage`: `nfs-utils` to the image; automounts and groups stay.
  Mount `/source` at `/srv/source`. The role needs separate remote and local
  paths, because odroidh3plus keeps exporting `/source` until Phase 8.
- [ ] `ai_health_monitor`: system user to the image; sudoers, logrotate,
  scripts, and units stay.
- [ ] `docker`, `podman`: packages to the image; enablement and groups stay.
- [ ] `libvirt`: packages to the image; enablement, groups, and
  `/var/lib/libvirt` stay.
- [ ] `flatpak`: remotes and apps stay; they live in `/var`.
- [ ] `nodejs`, `dotnet`, `rust`: image or user space (Q8).
- [ ] `cli`: rewrite for user-space installs into `~/bin`; drop package tasks.
- [ ] `ai`: user-space installs stay; drop global `npm` installs.
- [ ] `fonts`: system fonts to the image; user fonts stay.
- [ ] `onepassword`: RPMs and signing key to the image; polkit rules and
  browser integration stay.
- [ ] `devops`: Vagrant packages to the image; Terraform and the AWS CLI move to
  user space.
- [ ] `gui`: graphical packages to the image; Flatpak apps stay.
- [ ] `emacs`: to be audited.
- [ ] `gaming`: Steam, Wine, and udev rules to the image; user configuration
  stays. Mount the games SSD at `/srv/games`; no role manages that mount
  today.

### desktop25 and x1carbon2018

- [ ] `python`: image or user space (Q8).

### odroidh3plus

- [ ] `nfs`, `smb`: server packages to the image; exports, shares, and services
  stay. The `/source` export moves to `/srv/source`, onto the `/srv` volume.
- [ ] `karakeep`: the compose project stays; it lives under `/opt/karakeep`
  today (Q1).
- [ ] `orbit`: to be audited.
- [ ] `retrogaming`, `autologin`: `cage` and the frontend go to the image or
  user space, to be audited; the getty drop-in stays.

## Docs to replace

Each of these describes the traditional setup. Write its replacement under
`immutable/` at the same path.

- [ ] `README.md`: Getting Started, Automation Workflow, the `dnf-automatic`
  paragraph, the `h` table, and `/opt` paths.
- [ ] `AGENTS.md`: commands using `/opt`; the signing-key and service
  conventions assume runtime package installs.
- [ ] `.agents/skills/add-scheduled-job/SKILL.md`: examples point at the `dnf`
  role.
- [ ] `.agents/skills/check-homelab-host/SKILL.md`: DNF update checks.
- [ ] README and MONITORING files of every refactored role.
- [ ] `docs/devices/<host>/<host>.md` for each migrated host.
- [ ] `dotfiles/bash/.bash_functions`: the `rmt` comment mentions `/source`.

## Open questions

| # | Question | Blocks |
| --- | --- | --- |
| Q1 | Do the chosen base images already link `/opt` and `/srv` into `/var`? If `/opt` is linked, keep `/opt/homelab-automation` and skip the path change; this also decides where karakeep's compose project lives. If `/srv` is linked, the image adds nothing at the top level, and runtime roles create the directories under `/srv`. | Phase 1 |
| Q2 | Base images (D2): what is the publishing status and provenance of `quay.io/fedora-ostree-desktops/kinoite`? Or should KDE build on `fedora-bootc`? | Phase 1 |
| Q3 | Universal Blue modules (D3): certificate provenance, how quickly matching modules follow Fedora kernel updates, and what builds do in between. | Phase 3 |
| Q4 | Cutover install method: stock Kinoite followed by `bootc switch`, or installing the custom image directly? | Phase 4 |
| Q5 | Publishing (D5): tag format, retention, and how a host is promoted to a release. | Phase 6 |
| Q6 | How do hosts receive OS updates? bootc's stock update timer reboots to apply them, and the goals rule out forced reboots. Does the server differ? | Phase 6 |
| Q7 | User-space tools (D4): tools without standalone release builds (`zsh`, `tmux`) and the login shell: image or user space? | Phase 2 |
| Q8 | Language runtimes (`nodejs`, `python`, `dotnet`, `rust`): image or user space? | Phase 2 |
| Q9 | Container tests: which roles can converge in a container, and how do playbooks written for `hosts: localhost` with a local connection target the container instead of the machine running the tests? | Phase 2 |
| Q10 | VM tests: how do the checkout and newer images reach the guest so it can run ansible-pull and an upgrade? | Phase 1 |
| Q11 | Do Claude Code and Codex discover skills under `immutable/.agents/skills/`? If not, new skills go straight to the root. | Phase 1 |
| Q12 | odroidh3plus cutover: downtime for NFS clients, keeping `/srv` on its own volume, and moving its services. | Phase 8 |
| Q13 | Switching desktops replaces `/usr` but not configuration in home directories. What does a clean switch require? | Phase 7 |
