# Immutable migration plan

Move every host from traditional Fedora to bootc images built from this
repository, keeping ansible-pull for everything outside the image.

**Current phase:** 2, imgman and kickstart installs.

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

Agent workspaces (section 7 of the original plan) are a separate project. So is
a self-hosted forge with CI and a container registry, such as Forgejo or GitLab
on odroidh3plus; nothing in this plan depends on one.

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
- Agent skills live in the root `.agents/skills/`, because Codex discovers
  skills only under the directory it starts in (Q11).

## Phases

A phase is done when its "done when" holds, its capability tests pass, and
the durable docs for what it delivered exist under `immutable/`.

A phase that adds a significant capability adds capability tests: end-to-end
checks that use the capability the way a person would. For example, opening a
file in a TypeScript project in Neovim attaches the `ts_ls` language server.
That one check covers Neovim, Node.js, the language server install, the
dotfiles, and `PATH` together. Do not write tests that restate a task, such as
checking that a package version is installed or that a symlink exists. A
capability test that should keep passing on a running host also becomes the
check in the owning role's MONITORING file.

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

- [x] `immutable/images/Containerfile.kde` and shared scripts: Ansible
  bootstrap (`git`, `python3`, `ansible-core`, collections) and
  `/srv`.
- [x] VM harness (tier 2): build a disk from the image, boot it with a
  copy-on-write overlay, run the checks over SSH, exit nonzero when a check
  fails.
- [x] Upgrade and rollback rehearsal in the VM.
- [x] Agent skill that wraps the harness.

### Phase 2: imgman and kickstart installs

**Depends on:** Phase 1, Q4.

**Done when:** `imgman test image` passes for desktop22, desktop25, and
x1carbon2018, each on a VM disk that Anaconda installed with that host's
kickstart; `vm_test.py`, `vm_test_tests.py`, and `vm-test.sh` are deleted; and
`immutable/imgman/README.md`, `immutable/images/README.md`,
`immutable/AGENTS.md`, and the `test-bootc-image` skill describe `imgman`.

- [x] Finish the design in `immutable/images/imgman-plan.md`, working through
  `immutable/images/imgman-plan-review.md`.
- [ ] Prototype the install by hand on desktop22, with
  `localhost/workstation-kde` and a throwaway kickstart, before writing
  `imgman`. Confirm each assumption
  the design depends on, and revisit the design for any that fails:
  - [ ] Fedora 44's Anaconda resolves `%include` of a file written in `%pre`,
    and installs with the `ostreecontainer` and `ignoredisk` commands it
    contains.
  - [ ] The netinst ISO's kernel and initrd boot under QEMU with `-kernel` and
    `-initrd`, read a kickstart appended to the initrd as a cpio archive, and
    find stage 2 with the `inst.stage2` value found here. Record that value.
  - [ ] Anaconda pulls from the test registry at `10.0.2.2:5000` after `%pre`
    marks it insecure.
  - [ ] With `ostreecontainer`, Anaconda's `user --uid=1000` creates `sean`,
    and a `%post` creates the nested `~/.cache` subvolume inside the `home`
    subvolume.
  - [ ] A fresh install reaches `systemctl is-system-running` = `running`,
    with no failed units, before any playbook runs.
  - [ ] With `-display none` and no SPICE server, the VM still reaches
    `graphical.target` with SDDM active, because `virtio-vga` stays.
  - [ ] `-no-reboot` makes QEMU exit when the kickstart's `reboot` runs, and
    the disk then boots without `-kernel`.
  - [ ] The installed image's systemd applies a
    `systemd.unit-dropin.ansible-pull.service` credential passed through
    SMBIOS: a condition-skipped service is not counted as failed.
  - [ ] Whether Kinoite ships `rsync` and `spice-vdagent`, and whether
    `remote-viewer` connects over `spice+unix://`.
  - [ ] How long the install takes, compared with about 5 minutes for
    `bcvk to-disk`.
- [ ] A kickstart per workstation host, `immutable/images/kickstart/<host>.ks`:
  - `ignoredisk --only-use` limits the installer to the system disk, so
    desktop22's games SSD survives. In the VM, a blank disk from the host's
    `data_disks` in `hosts.toml` stands in for it.
  - A btrfs `home` subvolume at `/var/home`, with nested subvolumes for
    directories that home snapshots exclude: `~/.cache`,
    `~/.local/share/containers`, and possibly `~/Downloads`.
  - Fixed UIDs, so restored files keep their owners.
  - The same file installs the hardware and the VM. Only the image URL and
    the system disk differ: `%pre` takes them from `imgman.url` and
    `imgman.disk` kernel arguments when `imgman` passes them, uses the
    hardware values otherwise, and writes them to a file the kickstart
    includes.
- [ ] `immutable/images/hosts.toml`, with `flavor` and, for desktop22,
  `data_disks`. Every workstation maps to `kde` until Phase 4 adds
  `kde-nvidia`.
- [ ] `imgman` as a standard-library-only uv project in `immutable/imgman/`,
  installed with `uv tool install --editable` (see "Project Layout" in
  `immutable/images/imgman-plan.md`) and following its "Non-Functional
  Requirements & Code Style": ruff, pyrefly's strict preset, and pytest in a
  pinned `dev` group. Its commands are `image build`, `machine init`, `run`,
  `gui`, `ssh`, and `rm`, `test image`, and `system prune`. `machine init`
  installs with Anaconda from a Fedora netinst ISO that you download, verify,
  and place in `imgman`'s cache; a missing ISO fails the prerequisite check
  with download and placement instructions. `machine init` boots the ISO's
  kernel and initrd directly with the kickstart injected into the initrd, as
  `virt-install --initrd-inject` does. `test playbook` follows in Phase 3.
- [ ] Port `vm_test.py`'s layout checks to `imgman` and its unit tests to
  pytest, then delete `vm_test.py`, `vm_test_tests.py`, `vm-test.sh`, and
  `immutable/images/ruff.toml` and `ty.toml`, whose settings move to
  `immutable/imgman/pyproject.toml`. Its synthetic upgrade and rollback are
  not ported; `test upgrade` replaces them in Phase 3. Its
  `ansible-pull --version` and collection checks are not ported either: they
  restate the image's package install, and converging the playbook in the VM
  exercises both.
- [ ] Add `imgman`'s host requirements (see "Requirements" in
  `immutable/images/imgman-plan.md`) to the workstation image, so `imgman`
  runs on desktop22 after its cutover. Add `rsync` to the image if Kinoite
  lacks it, and `spice-vdagent` if wanted.
- [ ] Capability test: a file that `sean` writes under `~/.cache` is absent
  from a snapshot of the `home` subvolume.
- [ ] Once `imgman` works, write its durable docs and point the existing
  ones at it, then delete `immutable/images/imgman-plan.md` and
  `imgman-plan-review.md`:
  - `immutable/imgman/README.md`: installing and using `imgman`, its
    prerequisites, the installer ISO, and "Changing imgman" (formatting,
    linting, type checking, and unit tests), replacing the "Testing in a VM"
    and "Changing the test harness" sections of `immutable/images/README.md`.
  - `immutable/images/README.md`: the file table lists `hosts.toml` and
    `kickstart/` instead of `vm_test.py`, `ruff.toml`, and `ty.toml`;
    "Changing an image" uses `imgman image build` and `imgman test image`;
    the `COLLECTIONS` step goes.
  - `immutable/AGENTS.md`: under Validation, after changing anything under
    `immutable/imgman/`, follow "Changing imgman" in
    `immutable/imgman/README.md`, replacing the `vm_test.py` rule.
  - `test-bootc-image` skill: its commands and description use `imgman`.
    Its description drops the Ansible bootstrap and the upgrade and rollback
    checks, which `imgman test image` no longer runs. Phase 3 adds
    `imgman test upgrade` to the skill.

### Phase 3: Runtime roles for desktop22

**Depends on:** Phase 2, Q7, Q8, Q9, Q14, Q15.

**Done when:** `immutable/desktop22.yml` converges in a VM installed with
desktop22's kickstart, a second run reports no changes, and every role under
[desktop22](#desktop22) is checked off with its README and MONITORING current.

- [ ] Container tests (tier 1) for fast role iteration.
- [ ] Refactor desktop22's roles (see the [role checklist](#role-checklist)).
- [ ] `immutable/desktop22.yml`.
- [ ] `ansible_pull`: the unit runs `immutable/desktop22.yml` with the overlay
  config, and `h` is baked into the image. Move `h`'s source under
  `immutable/images/`, such as `immutable/images/bin/h`, instead of copying it
  from the role, so role changes never rebuild the image (D5).
- [ ] `imgman test playbook`: copy the working tree into the VM, then run the
  host's playbook twice, as the `ansible_pull` unit runs it, expecting no
  changes on the second run.
- [ ] Add the Fedora package of each collection a ported role needs to
  `immutable/images/scripts/ansible.sh`, which starts with only
  `ansible.posix`.
- [ ] RPM Fusion repositories in the image, if Q14 keeps them: a shared script
  that installs the checked-in keys and verifies their fingerprints.
- [ ] `imgman test upgrade`, the upgrade test for
  [D7](../docs/architecture.md#d7-playbooks-support-the-current-and-next-image),
  run before promotion and in CI:
  1. Start from a cached disk installed from the current image and converged
     once. Run the working tree's playbook twice, expecting no changes on the
     second run, and run the capability tests.
  2. Upgrade to the new build and reboot. Run the playbook twice and the
     capability tests.
  3. Roll back, reboot, and run the capability tests.

  The cached disks are rebuilt only when the current image changes, so a run
  costs three boots and incremental playbook runs. `test image` has no
  upgrade test of its own: upgrading a build to itself plus a marker file
  only re-tested bootc.
- [ ] `imgman image promote` marks a build as the current image, refusing
  builds that have not passed `test image` and, once a current image exists,
  `test upgrade`. After Phase 5, the current image is the oldest published
  image a host runs. Builds carry their git commit in the
  `org.opencontainers.image.revision` label.
- [ ] Capability tests, run as `sean` in the VM after the playbook converges.
  For example: opening a TypeScript file in Neovim attaches `ts_ls`, a login
  shell starts without errors, rootless Podman runs a container, and names
  resolve through NextDNS. The `cli` role installs Neovim's language servers
  during convergence, so the test does not race Mason's background install.

### Phase 4: NVIDIA and Secure Boot

**Depends on:** Phase 2, Q3.

**Done when:** the NVIDIA variant builds, desktop22 has the module-signing
certificate enrolled, and `immutable/images/README.md` covers NVIDIA builds,
enrollment, and certificate rotation. Module loading under Secure Boot can only
be confirmed on hardware, in Phase 10.

- [ ] NVIDIA build option using Universal Blue's prebuilt modules.
- [ ] desktop22 and desktop25 map to `kde-nvidia` in `hosts.toml`.
- [ ] Certificate fingerprint checked against a source independent of the
  download.
- [ ] Certificate enrolled on desktop22. Enrollment is stored in firmware, so it
  can happen long before cutover.
- [ ] Capability test: the image's NVIDIA kernel modules are signed by the
  certificate desktop22 enrolled. Loading them is confirmed on hardware in
  Phase 10.

### Phase 5: Image publishing

**Depends on:** Phase 4, Q5.

**Done when:** CI builds every image and pushes it to GHCR on change and
weekly, CI tests playbook changes without building an image, and
`immutable/images/README.md` documents the tag, digest, and retention scheme.
No host runs the published images yet.

- [ ] `.github/workflows/build-images.yml` at the root, triggered by changes
  under `immutable/images/`, weekly, and manually.
- [ ] Run `imgman` in CI inside a privileged `fedora:44` container on
  GitHub's Ubuntu runners, with `/dev/kvm` and `/dev/vhost-vsock` passed
  through. The container installs the same Fedora packages as desktop22, so
  `imgman`'s Fedora paths and tools hold. Prove it with a throwaway workflow
  first: KVM access, free disk space, QEMU and Podman inside the container,
  caching the installer ISO, and run time.
- [ ] A playbook workflow for changes outside `immutable/images/`: run
  `imgman test playbook` on the current published image, run the capability
  tests, and publish nothing.
- [ ] Tag, digest, and retention scheme.
- [ ] The GHCR packages are public, so installers pull them without
  credentials.
- [ ] Capability test: a VM installed from a published image upgrades from
  GHCR to a newer published build and rolls back.

### Phase 6: Runtime roles for desktop25 and x1carbon2018

**Depends on:** Phase 3.

**Done when:** `immutable/desktop25.yml` and `immutable/x1carbon2018.yml`
converge in VMs installed with their kickstarts, a second run reports no
changes, and every role under
[desktop25 and x1carbon2018](#desktop25-and-x1carbon2018) is checked off with
its README and MONITORING current.

- [ ] Refactor the remaining roles they use.
- [ ] `immutable/desktop25.yml` and `immutable/x1carbon2018.yml`.
- [ ] Capability tests in the VM for the roles these hosts add.
- [ ] Optional: a Niri variant to exercise desktop switching (Q13), with a
  capability test that switching desktops gives a working session.

### Phase 7: Server image and roles for odroidh3plus

**Depends on:** Phase 2, Q12.

**Done when:** the `server` image builds, `immutable/odroidh3plus.yml`
converges in a VM installed with odroidh3plus's kickstart, a second run reports
no changes, and every role under [odroidh3plus](#odroidh3plus) is checked off
with its README and MONITORING current.

- [ ] `server` image: fedora-bootc, no desktop, `cage` for the kiosk.
- [ ] `immutable/images/kickstart/odroidh3plus.ks`, with `ignoredisk
  --only-use` keeping the `/srv` volume, and odroidh3plus in `hosts.toml`.
- [ ] Refactor the server roles.
- [ ] `immutable/odroidh3plus.yml`.
- [ ] Capability tests in the VM: an NFS client mounts each export and reads
  and writes with the intended permissions, an SMB client reads and writes the
  share, karakeep answers over HTTPS, and the kiosk session starts.

### Phase 8: Install rehearsals

**Depends on:** Phases 5, 6, and 7.

**Done when:** each host's kickstart installs its published image in a VM with
the intended disk layout, a `/var/home` restored from a backup is readable with
correct ownership and SELinux labels, the playbook converges, and the host's
capability tests pass. `immutable/README.md` has the install steps in "Getting
Started".

- [ ] Each kickstart's hardware target installs the host's published image.
- [ ] Rehearse each install in a VM, including a restore of `/var/home` from a
  backup. An extra disk stands in for each data disk the install must leave
  alone.
- [ ] A cutover runbook per host in `migration/`, written from its rehearsal.
  Identify disks on the day; device names in the original plan are
  historical.
- [ ] "Getting Started" install steps in `immutable/README.md`.

### Phase 9: desktop22 cutover

**Depends on:** Phase 8, a verified backup.

**Done when:** desktop22 boots its published NVIDIA image, runtime Ansible has
converged, restored data is readable, and the games SSD is intact.

- [ ] Back up, install with the kickstart, restore, and run ansible-pull,
  following the runbook.

### Phase 10: desktop22 acceptance

**Depends on:** Phase 9.

**Done when:** the checks below pass, an upgrade and a rollback on the hardware
keep user and games data, and desktop22 has been the daily driver for a soak
period (length to be decided) without falling back.

Recurring checks move into the MONITORING file of the role or image that owns
them, where `check-homelab-host` uses them after every upgrade:

- [ ] CLI (`cli`): opening a file in a TypeScript project in Neovim attaches
  `ts_ls`, and a login shell starts without errors.
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

### Phase 11: Promotion and OS updates

**Depends on:** Phase 10, Q6.

**Done when:** promoting a build from the canary to the other hosts works as
documented in `immutable/images/README.md`, and bootc hosts receive OS updates
as Q6 decides.

- [ ] Promotion from the canary to other hosts.
- [ ] Automatic OS updates on each host.
- [ ] Capability test: a VM tracking the promoted tag installs a newly
  promoted build on its next update.

### Phase 12: desktop25 and x1carbon2018 cutover

**Depends on:** Phase 11, a verified backup of each host.

**Done when:** both hosts run a promoted image and pass the recurring checks
that apply to them.

- [ ] Install the RTX 2070 in desktop25 and enroll Universal Blue's certificate
  there before its cutover.
- [ ] Back up, install with each host's kickstart, restore, and run
  ansible-pull, following the runbooks.
- [ ] Capability tests on the hardware: on x1carbon2018, the managed Wi-Fi
  profile connects, and suspend and resume work.

### Phase 13: odroidh3plus cutover

**Depends on:** Phase 11, Q12, a verified backup.

**Done when:** odroidh3plus runs the `server` image; NFS, SMB, karakeep,
orbit, the retro-gaming kiosk, the Tailscale exit node, and `/srv` snapshots
work; and clients' NFS automounts recover.

- [ ] Move `/source` to `/srv/source` on odroidh3plus and point every client's
  mount at the new export.
- [ ] Install with the kickstart, keeping the `/srv` volume, and run
  ansible-pull, following the runbook, including downtime for NFS clients.
- [ ] Capability tests on the hardware for what the VM could not cover, such
  as the kiosk on the real display and the Tailscale exit node.

### Phase 14: Move to the root

**Depends on:** Phases 12 and 13.

**Done when:** the repository root is the new tree, `immutable/` is gone, and
every host's ansible-pull run is green.

- [ ] For each copied file, port root changes made since the copy.
- [ ] Delete root files that were replaced or are obsolete, including the `dnf`
  and `rpm_fusion` roles. Decide whether to keep roles no host uses (`niri`,
  `hyprland`, `waybar`, `virtualbox`, and others).
- [ ] Merge `immutable/AGENTS.md` and `immutable/ansible.cfg` into their root
  versions, and remove the pointer line from the root `AGENTS.md`.
- [ ] Move the rest of `immutable/`, except `migration/`, to the root. Update
  CI and skill paths and the ansible-pull unit template.
- [ ] Leave `immutable/<host>.yml` shims that import the root playbooks, and
  `immutable/ansible.cfg`, until every host has run once from the root. Each
  host's unit points into `immutable/` until its next run re-templates it.
- [ ] Delete `immutable/`. Optionally keep a short retrospective in
  `docs/projects/`.

### Phase 15: Single `site.yml` (optional)

**Depends on:** Phase 14.

**Done when:** every host runs `site.yml`, the per-host playbooks are gone, and
every host's ansible-pull run is green.

Replaces the near-duplicate per-host playbooks with one playbook. Record the
decision in `docs/architecture.md` first.

- [ ] Each image writes its flavor to `/etc/ansible/facts.d/desktop.fact`, so
  `ansible_local.desktop.flavor` names the booted image.
- [ ] `site.yml` includes the desktop roles (`wm/kde`, `wm/niri`) for that
  flavor, and `host_vars/` holds per-host differences.
- [ ] An inventory that names each host, replacing `--limit localhost`, and an
  ansible-pull unit that runs `site.yml` with it.
- [ ] `imgman test playbook` runs `site.yml` with the same inventory and limit
  as the unit.

### Phase 16: YOLO Agent Setup

- [ ] Move section 7 of the original plan to
  `docs/projects/agent-workspaces.md`.
- [ ] Capability test: as `agent`, editing a source checkout works, and reading
  `/home/sean` or `/srv/tier1` fails.

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
- [ ] `rpm_fusion`: drop. NVIDIA packages come from Universal Blue, whose
  installer disables RPM Fusion. Whether the image needs RPM Fusion at all is
  Q14.
- [ ] `btrfs`: `btrbk` to the image; configuration and timers stay. `/` is
  read-only, so snapshots move under a mount of the btrfs top level in
  `/var/mnt`. Snapshot the `home` subvolume; nested subvolumes for `~/.cache`
  and `~/.local/share/containers` keep those directories out of snapshots
  (the kickstart creates them at install). desktop22 already has both.
- [ ] `wifi`: NetworkManager and firmware to the image; connection profiles
  stay.
- [ ] `nextdns`: packages to the image; resolver configuration stays.
- [ ] `tailscale`: package to the image; enablement, sysctl, and routes stay.
- [ ] `network_storage`: `nfs-utils` to the image; automounts and groups stay.
  Mount `/source` at `/srv/source`. The role needs separate remote and local
  paths, because odroidh3plus keeps exporting `/source` until its cutover in
  Phase 13.
- [ ] `ai_health_monitor`: system user to the image; sudoers, logrotate,
  scripts, and units stay.
- [ ] `docker`, `podman`: packages to the image; enablement and groups stay.
- [ ] `libvirt`: packages to the image, including QEMU, OVMF, and the SPICE
  support that `imgman` needs; enablement, groups, and `/var/lib/libvirt`
  stay.
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
- [ ] `gaming`: Steam, Wine, and udev rules to the image, or Steam from
  Flathub (Q14); user configuration stays. Mount the games SSD at
  `/srv/games`; no role manages that mount today.

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
| Q3 | Universal Blue modules (D3): certificate provenance, how quickly matching modules follow Fedora kernel updates, and what builds do in between. | Phase 4 |
| Q5 | Publishing (D5): tag format, retention, and how a host is promoted to a release. | Phase 5 |
| Q6 | How do hosts receive OS updates? bootc's stock update timer reboots to apply them, and the goals rule out forced reboots. Does the server differ? | Phase 11 |
| Q7 | User-space tools (D4): tools without standalone release builds (`zsh`, `tmux`) and the login shell: image or user space? | Phase 3 |
| Q8 | Language runtimes (`nodejs`, `python`, `dotnet`, `rust`): image or user space? | Phase 3 |
| Q9 | Container tests: which roles can converge in a container, and how do playbooks written for `hosts: localhost` with a local connection target the container instead of the machine running the tests? | Phase 3 |
| Q12 | odroidh3plus cutover: downtime for NFS clients, keeping `/srv` on its own volume, and moving its services. fedora-bootc ships `/opt` read-only (Q1): where do the checkout and karakeep's compose project live? | Phases 7 and 13 |
| Q13 | Switching desktops replaces `/usr` but not configuration in home directories. What does a clean switch require? | Phase 6 |
| Q14 | RPM Fusion: with NVIDIA from Universal Blue, RPM Fusion supplies only Steam (`gaming`), the freeworld multimedia codecs, and `intel-media-driver`. Add RPM Fusion to the image for those, or take Steam from Flathub and rely on Flatpak apps for codecs? | Phase 3 |
| Q15 | sshd: desktop22 runs `sshd.service` today, but no role manages it, and Kinoite ships it disabled. Should workstation images enable it, or should a runtime role enable it per host? | Phase 3 |

## Answered questions

| # | Answer |
| --- | --- |
| Q1 | Kinoite links `/opt`, `/srv`, `/usr/local`, `/home`, `/mnt`, and `/root` into `/var`. Workstations keep the checkout at `/opt/homelab-automation`, the image adds no top-level directories, and runtime roles create the directories under `/srv`. fedora-bootc links `/srv` but ships `/opt` and `/usr/local` as read-only directories, which moves the server's checkout question to Q12. Recorded in the [filesystem table](../docs/architecture.md#filesystem). |
| Q2 | KDE builds on `quay.io/fedora/fedora-kinoite`, published by Fedora release engineering. `quay.io/fedora-ostree-desktops/kinoite` is the Atomic Desktops SIG's CI channel for the same composes, with dated tags and sigstore signatures. The official repository has only the major-version tag and no signatures, so builds pin by digest when publishing starts (Q5). Recorded in [D2](../docs/architecture.md#d2-one-base-image-per-desktop). |
| Q4 | Each host is installed by a kickstart file whose `ostreecontainer` directive installs the host's image directly, with the disk layout declared in the file. VM test disks are installed with the same kickstarts, from images built locally and served by the test registry, so kickstart development starts in Phase 2. Hardware cutovers wait until every host has an equivalent setup in VMs. Recorded in Phases 2 and 8. |
| Q10 | Images: the VM harness runs a registry container on `127.0.0.1:5000`, which the VM reaches at `10.0.2.2:5000`, and the test disk tracks a tag there. Checkout: `imgman test playbook` copies the working tree into the VM over SSH. Recorded in `immutable/images/README.md`. |
| Q11 | Claude Code finds skills under `immutable/` only after a session touches a file there. Codex finds them only when started inside `immutable/`. Skills go in the root `.agents/skills/`; see the exceptions under [how the overlay works](#how-the-overlay-works). |
