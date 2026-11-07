# Immutable migration plan

Move every host from traditional Fedora to bootc images built from this
repository, keeping ansible-pull for everything outside the image.

**Current phase:** 3, x1carbon23 install.

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

| Order | Host         | Purpose       | GPU             | Target image             | Disk         |
|       |              |               |                 |                          | encryption   |
|-------|--------------|---------------|-----------------|--------------------------|--------------|
| 1     | x1carbon23   | Laptop, the   | Intel Iris Xe   | `workstation-kde`        | LUKS2, TPM2  |
|       |              | first bootc   |                 |                          | + PIN        |
|       |              | host          |                 |                          | ([D8][d8])   |
| 2     | desktop22    | Workstation   | NVIDIA RTX 4070 | `workstation-kde-nvidia` | Q18          |
|       |              |               | SUPER           |                          |              |
| 3     | desktop25    | Workstation   | NVIDIA RTX      | `workstation-kde-nvidia` | Q18          |
|       |              |               | 2070, installed |                          |              |
|       |              |               | before cutover  |                          |              |
| 4     | odroidh3plus | Server,       | Intel           | `server`                 | Q18          |
|       |              | NFS/SMB,      |                 |                          |              |
|       |              | retro-gaming  |                 |                          |              |
|       |              | kiosk         |                 |                          |              |

[d8]: ../docs/architecture.md#d8-full-disk-encryption

x1carbon23 goes first. It is new hardware with no data to restore, it needs no
NVIDIA modules, and x1carbon2018 stays in service while it settles in. It runs
Secure Boot with Fedora's signed boot chain, so it needs no signing keys of
this repository's own. x1carbon2018, which it replaces, is out of scope (Q16).

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

A phase that adds a significant capability adds
[capability tests](../docs/architecture.md#capability-tests).

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
- [x] VM harness: build a disk from the image, boot it with a
  copy-on-write overlay, run the checks over SSH, exit nonzero when a check
  fails.
- [x] Upgrade and rollback rehearsal in the VM.
- [x] Agent skill that wraps the harness.

### Phase 2: imgman and the x1carbon23 kickstart

**Depends on:** Phase 1, Q4.

**Done when:** `imgman test image x1carbon23` passes on a VM disk that Anaconda
installed with x1carbon23's kickstart, encrypted with LUKS2, unlocked
unattended, and booted with Secure Boot enforced; `imgman test image` also
passes for desktop22 and desktop25; `vm_test.py`, `vm_test_tests.py`, and
`vm-test.sh` are deleted; and `immutable/imgman/README.md`,
`immutable/images/README.md`, `immutable/AGENTS.md`, and the
`test-bootc-image` skill describe `imgman`.

- [x] Finish the design in [imgman-plan.md](imgman-plan.md), working through
  a review of it, deleted once every item was resolved.
- [x] Prototype the install by hand on desktop22, with
  `localhost/workstation-kde` and a throwaway kickstart, before writing
  `imgman`. Confirm each assumption the design depends on, and revisit the
  design for any that fails. Its scripts were removed once `imgman` replaced
  them.
  - [x] Fedora 44's Anaconda (44.30) resolves `%include` of a file written in
    `%pre`, and installs with the `ostreecontainer` and `ignoredisk` commands
    it contains. The data disk stayed blank.
  - [x] The netinst ISO's kernel and initrd boot under QEMU with `-kernel` and
    `-initrd` and read a kickstart appended to the initrd as a cpio archive.
    Stage 2 is `inst.stage2=hd:LABEL=Fedora-E-dvd-x86_64-44`, the ISO's
    volume ID.
  - [x] Anaconda pulls from the test registry at `10.0.2.2:5000` after `%pre`
    marks it insecure. `bootc status` reports the pushed digest, and
    `bootc upgrade --check` reaches the tag once the installed VM marks the
    registry insecure too.
  - [x] With `ostreecontainer`, Anaconda's `user --uid=1000` creates `sean`
    with its home directory before `%post` runs, and a `%post` creates the nested `~/.cache`
    subvolume inside `home`. After `restorecon`, it is labeled
    `cache_home_t`, and a file in it is absent from a snapshot of `home`.
  - [x] A fresh install reaches `running` with no failed units, but only
    after three `%post` fixes, now in "Kickstart Targets" in
    [imgman-plan.md](imgman-plan.md): Anaconda's `/` line in `/etc/fstab`
    fails `systemd-remount-fs`, its `default.target` override selects
    `multi-user.target`, and without `/etc/plasma-setup-done` KDE's
    first-boot wizard takes the seat.
  - [x] With `-display none` and no SPICE server, the VM reaches
    `graphical.target` with the display manager active. Kinoite 44 ships
    Plasma Login Manager, not SDDM, so checks use `display-manager.service`.
  - [x] `-no-reboot` makes QEMU exit 0 when the kickstart's `reboot` runs,
    and the disk then boots without `-kernel`, from a fresh copy of
    `OVMF_VARS.fd`, in about 18 seconds.
  - [x] Fedora 44's systemd (259) applies a
    `systemd.unit-dropin.ansible-pull.service` credential passed through
    SMBIOS: the service is condition-skipped with `Result=success`, and the
    system stays `running`.
  - [x] Kinoite ships `rsync` and `spice-vdagent`, and `remote-viewer`
    connects over `spice+unix://` and shows the login screen. In the KDE
    Wayland session, pasting host text into the guest works, but copying out
    of the guest does not: `spice-vdagent` sees the clipboard only through
    XWayland. Resizing the viewer window resizes the guest display.
  - [x] The install takes about 6.5 minutes (377 and 389 seconds), compared
    with about 5 minutes for `bcvk to-disk`.
- [x] A kickstart per workstation host, `immutable/images/kickstart/<host>.ks`,
  for desktop22, desktop25, and x1carbon2018. x1carbon2018's was removed with
  the host from the scope (Q16):
  - `ignoredisk --only-use` limits the installer to the system disk, so
    desktop22's games SSD survives. In the VM, a blank disk from the host's
    `data_disks` in `hosts.toml` stands in for it.
  - A btrfs `home` subvolume at `/var/home`, with nested subvolumes for
    directories that home snapshots exclude: `~/.cache`,
    `~/.local/share/containers`, and `~/Downloads`.
  - Fixed UIDs, so restored files keep their owners.
  - `en_US.UTF-8`, a `us` keyboard, and `America/Chicago` on every host.
  - `sean` gets a bootstrap password: a yescrypt hash published in the
    kickstart, changed at first login. A locked account has no way in on the
    first boot, because workstations run no SSH server (Q15).
  - btrfs compression actually applies. btrfs takes `compress` from the
    filesystem's first mount, which on a bootc host is the initramfs
    mounting root from `rootflags=subvol=root`, so Anaconda's
    `compress=zstd:1` in fstab never took effect. The prototype confirmed it
    with `filefrag`: no compressed extents until a second
    `rootflags=subvol=root,compress=zstd:1` was on the kernel command line.
    The initramfs combines both `rootflags=`: compression applied with the
    appended one after Anaconda's (added with `rpm-ostree kargs`) and before
    it (written by each kickstart's `bootloader --append`).
  - The same file installs the hardware and the VM. Only the image URL, the
    system disk, and the plain-HTTP registry differ: `%pre` reads the
    `imgman.url`, `imgman.disk`, and `imgman.insecure-registry` kernel
    arguments, each falling back on its own to the hardware value, checks
    that the system disk exists, and writes the image and disk to a file the
    kickstart includes.
- [x] `immutable/images/hosts.toml`, with `flavor` and, for desktop22,
  `data_disks`. Every workstation maps to `kde` until Phase 6 adds
  `kde-nvidia`.
- [x] Prototype encryption and Secure Boot by hand, extending the prototype's
  scripts, before `imgman` relies on them.
  Every assumption held, with `x1carbon23.ks` itself:
  - [x] With `ostreecontainer`, Anaconda creates a LUKS2 container (aes-xts,
    argon2id) holding the btrfs volume from a `part btrfs.01 --fstype=btrfs
    --grow --encrypted --luks-version=luks2 --passphrase=...` line that
    `%pre` writes to `/tmp/target.ks`. The EFI partition and `/boot` stay
    unencrypted, and the install takes 407 seconds, against 392 without
    encryption.
  - [x] Without `--passphrase`, Anaconda stops before touching any disk and
    asks: "Please provide a default LUKS passphrase for all devices you want
    to encrypt."
  - [x] The installed VM unlocks unattended from a `cryptsetup.passphrase`
    systemd credential passed through SMBIOS: the initramfs receives it, and
    `systemd-cryptsetup` unlocks the volume without a prompt. No `swtpm` is
    needed. The initramfs finds the volume from the `rd.luks.uuid` kernel
    argument Anaconda adds, not from the `/etc/crypttab` it also writes,
    which the image's initramfs never sees.
  - [x] The installed VM boots with Secure Boot enforced, from
    `OVMF_CODE.secboot.fd` and a fresh copy of `OVMF_VARS.secboot.fd`, with
    `-machine q35,smm=on` and `-global driver=cfi.pflash01,property=secure,value=on`,
    and `mokutil --sb-state` reports `SecureBoot enabled`. The installer boots
    with the standard firmware: firmware verifying a kernel passed with
    `-kernel` accepts only Microsoft's keys, and Fedora's kernel is signed by
    Fedora, which only shim trusts.
  - [x] `rd.luks.options=discard` on the kernel command line, set with
    `bootloader --append`, lets TRIM reach the disk: `dmsetup table` shows
    `allow_discards`.
- [x] `immutable/images/kickstart/x1carbon23.ks`, from desktop25's, with the
  `part` line `%pre` writes: the VM gets the throwaway passphrase `imgman`
  passes as `imgman.luks-passphrase`, and the hardware gets no `--passphrase`,
  so Anaconda asks for one. x1carbon23 replaces x1carbon2018 in `hosts.toml`.
- [x] `imgman` as a standard-library-only uv project in `immutable/imgman/`,
  installed with `uv tool install --editable` (see "Project Layout" in
  [imgman-plan.md](imgman-plan.md)) and following its "Non-Functional
  Requirements & Code Style": ruff, pyrefly's strict preset, and pytest in a
  pinned `dev` group. Phase 2 needs `image build`, `machine init`, `run`,
  `gui`, `ssh`, and `rm`, and `test image`; `system prune` follows in
  Phase 5, and `test playbook` in Phase 3. `machine init` installs with
  Anaconda from a Fedora netinst ISO that you download, verify, and place in
  `imgman`'s cache; a missing ISO fails the prerequisite check with download
  and placement instructions. `machine init` boots the ISO's kernel and initrd
  directly with the kickstart injected into the initrd, as
  `virt-install --initrd-inject` does. Build it in steps, each passing the
  four checks in `immutable/imgman/README.md`:
  - [x] Skeleton: `pyproject.toml` and `uv.lock`, the argument parser with
    usage errors exiting 1, `hosts.toml` parsing, exit codes, prerequisite
    checks, the per-host lock, and their tests. Every command parses and
    exits 3 with "not implemented yet".
  - [x] `image build`.
  - [x] `machine init`, porting the prototype's `install.sh`.
    `imgman machine init x1carbon23` installs an encrypted disk in 7 minutes,
    and the disk boots with Secure Boot enforced, unlocks from the credential,
    and runs the digest its `.inputs` file records. Also done:
    - It waits until the registry answers on `/v2/` before pushing.
    - It creates `~/.cache/homelab-images` with `chattr +C`, but only when the
      directory does not exist yet; an existing cache keeps copy-on-write
      until `system prune --all --disks` empties it.
    - It finds the installer ISO from the Containerfile's
      `FEDORA_MAJOR_VERSION` before running anything, and explains how to get
      a missing one.
    - It passes `imgman.luks-passphrase` with the other `imgman.*` arguments.
    - It writes the kickstart into the initrd itself, as a cpio archive, so
      `cpio` is not a prerequisite.
    - `%pre` echoes its errors to `/dev/console`, so they reach `console.log`.
    - It detects a failed install by watching `console.log` for Anaconda's
      error output (`ScriptError`, "An error occurred", a Python traceback)
      and stops QEMU at once, with a 30-minute timeout as the backstop.
      Anaconda's `%onerror` did not run after a `%pre` failure, so the
      kickstarts have none.
    - It takes the host's lock, and refuses while the host's VM is running.
  - [x] `machine run`, `ssh`, `gui`, and `rm`, porting the prototype's
    `boot.sh` and `vm.sh`, with the Secure Boot firmware and the
    `cryptsetup.passphrase` credential. `machine run x1carbon23` boots and
    answers over SSH in 13 seconds; `machine ssh` reports a failed command
    with exit 3; `machine gui` refuses a VM started with `--no-gui`.
    `machine run` installs a missing disk while holding the host's lock,
    because a second `flock` on the same file from the same process would
    find the host busy.
  - [x] `test image`, which also checks that Secure Boot is enabled and, for a
    kickstart that encrypts, that the root filesystem is on a LUKS2 device.
    `imgman test image x1carbon23` passes all 15 checks in 20 seconds when
    the disk is current. The data-disk check moved into `machine init`: by
    the time `test image` boots, the VM's data disks are new blank overlays,
    so the installer checks the disks the install itself saw with
    `qemu-img map`. `imgman test image --all` passes for desktop22,
    desktop25, and x1carbon23, installing the two missing disks, in 14 minutes.
- [x] Port `vm_test.py`'s layout checks to `imgman`, then delete
  `vm_test.py`, `vm_test_tests.py`, `vm-test.sh`, and `immutable/images/`'s
  `ruff.toml` and `ty.toml`, whose settings moved to
  `immutable/imgman/pyproject.toml`. `test image` runs the layout checks;
  `imgman`'s own tests replace `vm_test_tests.py`. Its synthetic upgrade and
  rollback are not ported; `test upgrade` replaces them in Phase 7. Its
  `ansible-pull --version` and collection checks are not ported either: they
  restate the image's package install, and converging the playbook in the VM
  exercises both.
- [x] Capability test: a file that `sean` writes under `~/.cache` is absent
  from a snapshot of the `home` subvolume. It is one of `test image`'s checks.
- [x] Durable docs for `imgman`, with the existing docs pointing at them:
  - `immutable/imgman/README.md`: installing and using `imgman`, its
    commands and checks, exit codes, prerequisites, the installer ISO, how it
    works, and "Changing imgman", replacing the "Testing in a VM" and
    "Changing the test harness" sections of `immutable/images/README.md`.
  - `immutable/images/README.md`: the file table lists `hosts.toml` and
    `kickstart/`; "Changing an image" uses `imgman image build` and
    `imgman test image`; a "Hosts and kickstarts" section covers the
    kickstarts; the `COLLECTIONS` step is gone.
  - `immutable/AGENTS.md`: after changing anything under `immutable/imgman/`,
    follow "Changing imgman", replacing the `vm_test.py` rule.
  - `test-bootc-image` skill: its commands and description use `imgman`.
    Phase 7 adds `imgman test upgrade` to it.
  - [imgman-plan.md](imgman-plan.md) moved here from `immutable/images/`
    instead of being deleted: it still holds the design for the commands
    later phases add (`test playbook`, `test upgrade`, `image promote`,
    `system prune`) and the code style. Delete it once they exist and
    `immutable/imgman/README.md` covers them.

### Phase 3: x1carbon23 install

**Depends on:** Phase 2.

**Done when:** x1carbon23 boots its image from GHCR with Secure Boot on and its
disk unlocked by TPM2 + PIN, `immutable/x1carbon23.yml` converges through the
ansible-pull timer, a `bootc upgrade` to a newer build and a `bootc rollback`
keep `/var/home`, and the install runbook in `migration/` matches what was done.

- [ ] Within the 30-day return window, run the "Verify on arrival" checks in
  `docs/devices/x1carbon23/x1carbon23.md` from a Fedora live USB, and record
  the system disk's `/dev/disk/by-id/` path and the firmware's Secure Boot
  settings.
- [x] Publish by hand: push `localhost/workstation-kde` to the public GHCR
  package `ghcr.io/seantwie03/workstation-kde`, tagged with its date and git
  commit (D5), and move `:stable`, the tag x1carbon23 tracks, to it only after
  `imgman test image x1carbon23` passes. CI publishing and signing follow in
  Phase 7 (Q17); until then the laptop tracks unsigned builds pushed by hand.
  Podman logs in with the `gh` CLI's token, after
  `gh auth refresh --scopes write:packages`, with
  `gh auth token | podman login ghcr.io --username seantwie03 --password-stdin`.
  The first push was `:20261106-7ad2330` and `:stable`, both
  `sha256:3d9059c1…`, the digest the x1carbon23 VM had passed `test image`
  with. The package was made public on github.com, and anonymous pulls work.
  To publish a build: check that its image ID is in
  `~/.cache/homelab-images/x1carbon23/passed/`, then push it under its
  date-and-commit tag and under `:stable`.
- [x] Capability test: a VM installed from the test registry
  `bootc switch`es to `ghcr.io/seantwie03/workstation-kde:stable`, boots it,
  and `bootc upgrade --check` reaches GHCR without credentials.
- [x] OS updates (Q6): updates download and stage in the background, and apply
  only at the next reboot you do. Nothing reboots the laptop on its own.
  `images/scripts/updates.sh` enables `bootc-fetch-apply-updates.timer`,
  which every image ships disabled, with a drop-in that runs
  `bootc upgrade` without `--apply`. Tested in the x1carbon23 VM: after a
  newer build was pushed, the service staged it without rebooting, and the
  next reboot booted it, with the previous build kept for rollback.
- [x] `ansible_pull`: the unit runs `immutable/x1carbon23.yml` with the
  overlay config, and `h` is baked into the image as `immutable/images/bin/h`,
  so role changes never rebuild the image (D5). The overlay role writes
  `/etc/ansible-pull.conf`, which the unit loads with `EnvironmentFile=` and
  `h` reads, so the image holds no host-specific paths. It drops the pip
  installs, the Snapper hooks, and its `dnf`, `nextdns`, and `podman`
  dependencies; `nextdns` and `podman` return as Phase 4 ports them. The
  overlay `core` keeps only the `is_graphical_system` fact; its packages
  come from the image, with `images/scripts/base.sh` adding the three
  Kinoite lacks. In Fedora 44, `dnf install wget p7zip` installs
  `wget2-wget` and `7zip`; name those in `base.sh` with the next image change.
- [x] `immutable/x1carbon23.yml`, starting with `ansible_pull`; it gains the
  roles Phase 4 ports.
- [x] `imgman test playbook`: copy the working tree into the VM, then run the
  host's playbook twice, as the `ansible_pull` unit runs it, expecting no
  changes on the second run. `imgman test playbook x1carbon23` converges in
  6 seconds (9 changes) and reruns with no changes; the whole command takes
  12 seconds on a running VM.
- [ ] Add the Fedora package of each collection a ported role needs to
  `immutable/images/scripts/ansible.sh`, which starts with only
  `ansible.posix`.
- [x] Set the image URL in x1carbon23's `%pre` to
  `ghcr.io/seantwie03/workstation-kde:stable`. VM installs override it with
  `imgman.url`.
- [ ] On the day of the install, replace the placeholder system disk in
  x1carbon23's `%pre` with the disk's `/dev/disk/by-id/` path, read from the
  live USB with `ls -l /dev/disk/by-id/`. This is the only step that needs the
  laptop before the install itself; until then, the placeholder fails `%pre`'s
  disk check, so a hardware install cannot start by accident.
- [x] Bootstrap rehearsal: in a fresh x1carbon23 VM with no checkout, the
  `ansible_pull` README's first-run command cloned the repository from
  GitHub and ran `immutable/x1carbon23.yml` with the overlay configuration,
  and `h test` then reran it with no changes.
- [ ] An install runbook, [x1carbon23-install.md](x1carbon23-install.md),
  drafted from the VM rehearsals; its hardware steps are still unverified:
  - BIOS supervisor password, and Secure Boot on. If the install USB does not
    boot, enable "Allow Microsoft 3rd Party UEFI CA" in the BIOS.
  - Boot the install USB with the kickstart, wired through the docking
    station's Ethernet port, and enter the LUKS passphrase when Anaconda asks.
  - Log in with the bootstrap password and change it.
  - Enroll the TPM: `systemd-cryptenroll --tpm2-device=auto
    --tpm2-with-pin=yes --tpm2-pcrs=7`, then add a recovery key with
    `systemd-cryptenroll --recovery-key` and store it in 1Password.
  - Re-enroll after anything that changes PCR 7, such as a Secure Boot
    database update or toggling Secure Boot, unlocking once with the recovery
    key.
- [ ] Confirm on the hardware that the image's initramfs finds the TPM2 token
  in the LUKS2 header without `/etc/crypttab`. The initramfs is built into the
  image, so nothing in the host's `/etc` reaches it; if it does not, add
  `rd.luks.options=tpm2-device=auto` with `bootc`'s kernel arguments.
- [ ] Capability test on the hardware: `mokutil --sb-state` reports Secure Boot
  enabled, and boot asks for the PIN, not the passphrase.

### Phase 4: Runtime roles for x1carbon23

**Depends on:** Phase 3, Q7.

**Done when:** `immutable/x1carbon23.yml` has x1carbon2018's roles, converges in
a VM installed with x1carbon23's kickstart, a second run reports no changes,
every role under [x1carbon23](#x1carbon23) is checked off with its README and
MONITORING current, the checks below pass on the hardware, and x1carbon23 has
been the daily driver for a soak period (length to be decided) without
falling back.

- [ ] Refactor x1carbon23's roles (see the [role checklist](#role-checklist)),
  one at a time, testing each with `imgman test playbook` before it reaches
  the laptop through ansible-pull.
- [ ] Capability tests, run as `sean` in the VM after the playbook converges.
  For example: opening a TypeScript file in Neovim attaches `ts_ls`, a login
  shell starts without errors, rootless Podman runs a container, and names
  resolve through NextDNS. The `cli` role installs Neovim's language servers
  during convergence, so the test does not race Mason's background install.

Recurring checks move into the MONITORING file of the role or image that owns
them, where `check-homelab-host` uses them after every upgrade:

- [ ] CLI (`cli`): opening a file in a TypeScript project in Neovim attaches
  `ts_ls`, and a login shell starts without errors.
- [ ] DNS (`nextdns`): resolver active, NextDNS DNS-over-TLS works, short names
  resolve through the search domain.
- [ ] NFS (`network_storage`): at home, `/srv/source`, `/srv/tier1`, and
  `/srv/tier2` automount with the intended permissions.
- [ ] VPN (`tailscale`): authenticates and routes.
- [ ] Audio (image): PipeWire and WirePlumber run on Sound Open Firmware;
  output switching and media keys work.
- [ ] Zoom (`gui`): launches; audio, microphone, webcam, and screen sharing
  work.
- [ ] Laptop (image): Wi-Fi connects; suspend and resume work; the
  fingerprint reader enrolls and unlocks; power profiles switch with
  `Fn+L`, `Fn+M`, and `Fn+H`; external displays work over Thunderbolt and
  HDMI; `vainfo` lists hardware video decoding; `fwupdmgr get-updates` runs.

### Phase 5: Runtime roles for desktop22

**Depends on:** Phase 4.

**Done when:** `immutable/desktop22.yml` converges in a VM installed with
desktop22's kickstart, a second run reports no changes, and every role under
[desktop22](#desktop22) is checked off with its README and MONITORING current.

- [ ] Refactor the roles desktop22 adds to x1carbon23's.
- [ ] `immutable/desktop22.yml`.
- [ ] Add `imgman`'s host requirements (see "Prerequisites" in
  `immutable/imgman/README.md`) to the workstation image, so `imgman`
  runs on desktop22 after its cutover.
- [ ] `imgman system prune`.

### Phase 6: NVIDIA

**Depends on:** Phase 2, Q3.

**Done when:** the NVIDIA variant builds, desktop22 has the module-signing
certificate enrolled, and `immutable/images/README.md` covers NVIDIA builds,
enrollment, and certificate rotation. Module loading under Secure Boot can only
be confirmed on hardware, in Phase 12.

- [ ] Before building the NVIDIA option, study how Bazzite builds its NVIDIA
  images since Fedora 45: everything in one build stage, with the NVIDIA
  additions behind a build argument. See the
  [Bazzite 45 announcement](https://universal-blue.discourse.group/t/bazzite-45-is-here/12702)
  and `build_files/` in [ublue-os/bazzite](https://github.com/ublue-os/bazzite).
  `imgman` maps each flavor to its own `Containerfile.<flavor>`, so adopting a
  build argument also means deciding how a flavor selects it.
- [ ] NVIDIA build option using Universal Blue's prebuilt modules.
- [ ] desktop22 and desktop25 map to `kde-nvidia` in `hosts.toml`.
- [ ] Certificate fingerprint checked against a source independent of the
  download.
- [ ] Certificate enrolled on desktop22. Enrollment is stored in firmware, so it
  can happen long before cutover.
- [ ] Capability test: the image's NVIDIA kernel modules are signed by the
  certificate desktop22 enrolled. Loading them is confirmed on hardware in
  Phase 12.

### Phase 7: Image publishing and promotion

**Depends on:** Phase 3, Q5, Q17.

**Done when:** CI builds every image and pushes it to GHCR on change and
weekly, CI tests playbook changes without building an image, published images
are promoted only after `imgman test upgrade` passes, and
`immutable/images/README.md` documents the tag, digest, and retention scheme.

- [ ] `.github/workflows/build-images.yml` at the root, triggered by changes
  under `immutable/images/`, weekly, and manually.
- [ ] Run `imgman` in CI inside a privileged `fedora:44` container on
  GitHub's Ubuntu runners, with `/dev/kvm` and `/dev/vhost-vsock` passed
  through. The container installs the same Fedora packages as desktop22, so
  `imgman`'s Fedora paths and tools hold. Prove it with a throwaway workflow
  first: KVM access, free disk space, QEMU and Podman inside the container,
  caching the installer ISO, and run time.
- [ ] A playbook workflow for changes outside `immutable/images/`: run
  `imgman test playbook` on `:stable`, run the capability tests, and publish
  nothing.
- [ ] Tag, digest, and retention scheme.
- [ ] The GHCR packages are public, so installers pull them without
  credentials.
- [ ] Signing (Q17): CI signs each published image without a long-lived key,
  and hosts enforce a signature policy for `ghcr.io/seantwie03`.
- [ ] `imgman test upgrade`, run before promotion and in CI (see the
  [testing strategy](../docs/architecture.md#testing-strategy)):
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
  `test upgrade`. The current image is the oldest published image a host
  runs. Builds carry their git commit in the
  `org.opencontainers.image.revision` label.
- [ ] Capability test: a VM installed from a published image upgrades from
  GHCR to a newer published build and rolls back.

### Phase 8: Runtime roles for desktop25

**Depends on:** Phase 5.

**Done when:** `immutable/desktop25.yml` converges in a VM installed with its
kickstart, a second run reports no changes, and every role under
[desktop25](#desktop25) is checked off with its README and MONITORING current.

- [ ] `immutable/desktop25.yml`.
- [ ] Capability tests in the VM for anything desktop25 adds.
- [ ] Optional: a Niri variant to exercise desktop switching (Q13), with a
  capability test that switching desktops gives a working session.

### Phase 9: Server image and roles for odroidh3plus

**Depends on:** Phase 2, Q12.

**Done when:** the `server` image builds, `immutable/odroidh3plus.yml`
converges in a VM installed with odroidh3plus's kickstart, a second run reports
no changes, and every role under [odroidh3plus](#odroidh3plus) is checked off
with its README and MONITORING current.

- [ ] `server` image: fedora-bootc, no desktop, `cage` for the kiosk.
- [ ] `/usr/local` is the same on both images: a shared script links it to
  `/var/usrlocal` where the base image ships a directory, as fedora-bootc does,
  and adds a tmpfiles rule for `/var/usrlocal/bin`. Neither base image's
  tmpfiles rules create it, although the x1carbon23 VM has it. `bootc
  container lint --fatal-warnings` accepts a fedora-bootc image with the link
  (checked 2026-11-07); booting one waits for odroidh3plus's kickstart.
- [ ] `immutable/images/kickstart/odroidh3plus.ks`, with `ignoredisk
  --only-use` keeping the `/srv` volume, and odroidh3plus in `hosts.toml`.
- [ ] Refactor the server roles.
- [ ] `immutable/odroidh3plus.yml`.
- [ ] Capability tests in the VM: an NFS client mounts each export and reads
  and writes with the intended permissions, an SMB client reads and writes the
  share, karakeep answers over HTTPS, and the kiosk session starts.

### Phase 10: Install rehearsals

**Depends on:** Phases 7, 8, and 9, Q18.

**Done when:** each remaining host's kickstart installs its published image in a
VM with the intended disk layout, a `/var/home` restored from a backup is
readable with correct ownership and SELinux labels, the playbook converges, and
the host's capability tests pass. `immutable/README.md` has the install steps
in "Getting Started".

- [ ] Each kickstart's hardware target installs the host's published image.
  Replace the placeholder image URL and system disk in each kickstart's
  `%pre` with the published image and the disk's `/dev/disk/by-id/` path,
  read on the host with `ls -l /dev/disk/by-id/`.
- [ ] Rehearse each install in a VM, including a restore of `/var/home` from a
  backup. An extra disk stands in for each data disk the install must leave
  alone.
- [ ] A cutover runbook per host in `migration/`, written from its rehearsal.
  Identify disks on the day; device names in the original plan are
  historical.
- [ ] "Getting Started" install steps in `immutable/README.md`, from the
  runbooks, including x1carbon23's.

### Phase 11: desktop22 cutover

**Depends on:** Phase 10, a verified backup.

**Done when:** desktop22 boots its published NVIDIA image, runtime Ansible has
converged, restored data is readable, and the games SSD is intact.

- [ ] Back up, install with the kickstart, restore, and run ansible-pull,
  following the runbook.

### Phase 12: desktop22 acceptance

**Depends on:** Phase 11.

**Done when:** the checks below pass, an upgrade and a rollback on the hardware
keep user and games data, and desktop22 has been the daily driver for a soak
period (length to be decided) without falling back. Checks x1carbon23 already
passed in Phase 4 run again here only through `check-homelab-host`.

- [ ] Gaming (`gaming`): Steam sees the `/srv/games` library; Proton games and
  controllers work.
- [ ] GPU (image): modules load under Secure Boot; `nvidia-smi` reports the
  GPU; CUDA and multi-monitor Wayland work.

One-time checks:

- [ ] `/var/home/sean` restored with correct ownership and SELinux labels.
- [ ] Games SSD mounted at `/srv/games` with its contents intact, and Steam's
  library folder re-added at the new path.

### Phase 13: OS updates

**Depends on:** Phase 12, Q6.

**Done when:** every bootc host tracks `:stable` and receives OS updates as Q6
decides.

- [ ] Automatic OS updates on each host.
- [ ] Capability test: a VM tracking `:stable` installs a newly published
  build on its next update.

### Phase 14: desktop25 cutover

**Depends on:** Phase 13, a verified backup.

**Done when:** desktop25 runs a promoted image and passes the recurring checks
that apply to it.

- [ ] Install the RTX 2070 in desktop25 and enroll Universal Blue's certificate
  there before its cutover.
- [ ] Back up, install with the kickstart, restore, and run ansible-pull,
  following the runbook.

### Phase 15: odroidh3plus cutover

**Depends on:** Phase 13, Q12, a verified backup.

**Done when:** odroidh3plus runs the `server` image; NFS, SMB, karakeep,
orbit, the retro-gaming kiosk, the Tailscale exit node, and `/srv` snapshots
work; and clients' NFS automounts recover.

- [ ] Move `/source` to `/srv/source` on odroidh3plus and point every client's
  mount at the new export.
- [ ] Install with the kickstart, keeping the `/srv` volume, and run
  ansible-pull, following the runbook, including downtime for NFS clients.
- [ ] Capability tests on the hardware for what the VM could not cover, such
  as the kiosk on the real display and the Tailscale exit node.

### Phase 16: Move to the root

**Depends on:** Phases 14 and 15.

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

### Phase 17: Single `site.yml` (optional)

**Depends on:** Phase 16.

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

### Phase 18: YOLO Agent Setup

- [ ] Move section 7 of the original plan to
  `docs/projects/agent-workspaces.md`.
- [ ] Capability test: as `agent`, editing a source checkout works, and reading
  `/home/sean` or `/srv/tier1` fails.

## Role checklist

Each entry records what moves to the image and what stays in the runtime role.
The entries come from the original plan's audit; confirm each one while
refactoring the role.

### x1carbon23

x1carbon2018's roles, including roles pulled in as dependencies. desktop22
and desktop25 run all of them too.

- [ ] `core`: base packages to the image; limits, sysctl, and group membership
  stay.
- [ ] `ansible_pull`: `ansible-core`, `git`, and collections to the image; units, logrotate, and `h` stay; drop pip upgrades, `dnf-makecache` ordering, and Snapper hooks. Move `h` from `immutable/images/bin/` back into the role, installed as `/usr/local/bin/h` with its completion in `/etc/bash_completion.d/`, then remove `bin/` and its `COPY` lines from the image. `/usr/local/bin` comes before `/usr/bin` on `PATH`, so the role's `h` takes over before the image change lands. Template `h`, its completion, and `ansible-pull.service` from the role's variables, as the root role does, and drop `/etc/ansible-pull.conf`; the unit sets `ANSIBLE_CONFIG` itself until the move to the root. Update the role's README and MONITORING, and the `h` entry under "Contents" in `immutable/images/README.md`, which describe the file.
- [ ] `dnf`: drop; OS updates come from images (Q6).
- [ ] `rpm_fusion`: drop. Images use no RPM Fusion (Q14): Flatpak apps bring
  their own codecs, and Steam comes from Flathub.
- [ ] `btrfs`: `btrbk` to the image; configuration and timers stay. `/` is
  read-only, so snapshots move under a mount of the btrfs top level in
  `/var/mnt`. Snapshot the `home` subvolume; nested subvolumes for `~/.cache`
  and `~/.local/share/containers` keep those directories out of snapshots
  (the kickstart creates them at install). desktop22 already has both.
- [ ] `nextdns`: packages to the image; resolver configuration stays.
- [x] `tailscale`: package to the image; enablement, sysctl, and routes stay.
  Fedora packages it, so the image installs it with `scripts/base.sh`. Its
  state and cache directories under `/var` move to `tmpfiles.d`, which
  `bootc container lint` requires.
- [ ] `network_storage`: `nfs-utils` to the image; automounts and groups stay.
  Mount `/source` at `/srv/source`. The role needs separate remote and local
  paths, because odroidh3plus keeps exporting `/source` until its cutover in
  Phase 15. `/srv` links to `/var/srv`, so fstab entries name the real mount
  point, such as `/var/srv/tier1`: on Fedora Atomic, an fstab mount point
  under the `/mnt` link failed where its `/var/mnt` path worked
  ([Team Silverblue issue 46](https://pagure.io/teamsilverblue/issue/46)).
  Everything else, people and scripts included, uses `/srv`. Confirm the
  mounts in the VM.
- [ ] `docker`, `podman`: packages to the image; enablement and groups stay.
- [ ] `libvirt`: packages to the image, including QEMU, OVMF, the SPICE
  support that `imgman` needs, and `python3-libvirt` for
  `start-latest-snapshot`; enablement, groups, and `/var/lib/libvirt`
  stay. Optionally, set `chattr +C` on `/var/lib/libvirt/images` while it is
  still empty, so VM disks skip copy-on-write and compression. desktop22
  keeps `/var/lib/libvirt` in its own subvolume only to exclude it from root
  rollbacks, which bootc hosts no longer do, so the kickstarts add no
  subvolume for it.
- [ ] `flatpak`: remotes and apps stay; they live in `/var`.
- [ ] `nodejs`, `python`, `dotnet`, `rust`: user space, through each
  language's own version manager (Q8). The image keeps only `python3`, which
  Ansible needs.
- [ ] `cli`: rewrite for user-space installs into `~/bin`; drop package tasks.
- [ ] `ai`: user-space installs stay; drop global `npm` installs.
- [ ] `fonts`: system fonts to the image; user fonts stay.
- [x] `onepassword`: RPMs and signing key to the image
  (`scripts/onepassword.sh`); the runtime role keeps only the app's autostart.
  The script moves `/opt/1Password` to `/usr/lib/1Password` with a `tmpfiles`
  link back, creates the three groups with fixed system IDs and declares them
  in `sysusers.d`, and fills the polkit policy's owners with UID 1000; see
  "1Password" in `images/README.md`. Checked in the VM: the setgid helpers
  resolve to their groups, `op` runs, and the installed polkit policy names
  UID 1000 as its owner. No 1Password account signs in to a VM, so the
  signed-in checks run on the hardware, in the runbook's "Check": unlock with
  the system password, `op` app integration, and fill in Firefox, which as a
  Flatpak may need its own browser-integration setup.
- [ ] `devops`: Vagrant packages to the image; Terraform and the AWS CLI move to
  user space.
- [ ] `gui`: graphical packages to the image; Flatpak apps stay.
- [ ] `emacs`: to be audited.

### desktop22

The roles desktop22 adds to x1carbon23's.

- [ ] `wifi`: NetworkManager and firmware to the image. The role only installs
  packages, so it goes away; Kinoite already ships them, which is why
  x1carbon23 needs no `wifi` role.
- [ ] `ai_health_monitor`: system user to the image; sudoers, logrotate,
  scripts, and units stay.
- [ ] `gaming`: Steam from Flathub (Q14); Wine and udev rules to the image;
  user configuration stays. Mount the games SSD at `/srv/games`, with
  `/var/srv/games` in fstab, as `network_storage` does; no role manages that
  mount today.

### desktop25

No roles beyond desktop22's.

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

| #   | Question                                                                     | Blocks      |
|-----|------------------------------------------------------------------------------|-------------|
| Q3  | Universal Blue modules (D3): certificate provenance, how quickly matching    | Phase 6     |
|     | modules follow Fedora kernel updates, and what builds do in between.         |             |
| Q5  | Publishing (D5): retention. The tags are decided: `:stable`, which every     | Phase 7     |
|     | host tracks and CI moves to a build once it passes its VM tests, plus a      |             |
|     | date-and-commit tag per build.                                               |             |
| Q7  | The `cli` role installs your everyday tools with `dnf`, which runtime roles  | Phase 4     |
|     | cannot do. Which go into the image, and which become pinned user-space       |             |
|     | downloads (D4)? The recommendation: stable distro tools (`git`, `tree`,      |             |
|     | `bind-utils`, `fzf`, `bat`, `abduco`) into the image; fast-moving tools with |             |
|     | release builds (Neovim, `gh`, `yazi`, `asciinema`) into user space. The      |             |
|     | login shell is bash, which the image already ships.                          |             |
| Q12 | odroidh3plus cutover: downtime for NFS clients, keeping `/srv` on its own    | Phases 9    |
|     | volume, and moving its services. fedora-bootc ships `/opt` read-only (Q1):   | and 15      |
|     | where do the checkout and karakeep's compose project live? When does the     |             |
|     | server apply staged OS updates, given that workstations apply them only at a |             |
|     | reboot you do (Q6)?                                                          |             |
| Q13 | Switching desktops replaces `/usr` but not configuration in home             | Phase 8     |
|     | directories. What does a clean switch require?                               |             |
| Q16 | x1carbon2018, which x1carbon23 replaces: a backup for odroidh3plus on the    | Phase 9, if |
|     | `server` image, or retired? Its workstation kickstart and `hosts.toml` entry | it becomes  |
|     | were removed.                                                                | a server    |
| Q17 | Image signing: CI signs published images without a long-lived key (cosign    | Phase 7     |
|     | keyless signing with GitHub Actions' identity), and hosts enforce a          |             |
|     | signature policy for `ghcr.io/seantwie03`, switching to it with              |             |
|     | `bootc switch --enforce-container-sigpolicy` after an install that used      |             |
|     | `--no-signature-verification`. Until then, hosts track unsigned images,      |             |
|     | protected by the GHCR account's two-factor login.                            |             |
| Q18 | Disk encryption for desktop22, desktop25, and odroidh3plus, decided per host | Phase 10    |
|     | ([D8](../docs/architecture.md#d8-full-disk-encryption)). An encrypted        |             |
|     | desktop or server unlocks with TPM2 automatic unlock. The games SSD and the  |             |
|     | `/srv` volume survive installs unencrypted unless reformatted and restored,  |             |
|     | and a headless server whose automatic unlock breaks after a firmware update  |             |
|     | waits at a passphrase prompt.                                                |             |

## Answered questions

| #   | Answer                                                                                     |
|-----|--------------------------------------------------------------------------------------------|
| Q1  | Kinoite links `/opt`, `/srv`, `/usr/local`, `/home`, `/mnt`, and `/root` into `/var`.      |
|     | Workstations keep the checkout at `/opt/homelab-automation`, the image adds no top-level   |
|     | directories, and runtime roles create the directories under `/srv`. fedora-bootc links     |
|     | `/srv` but ships `/opt` and `/usr/local` as read-only directories, which moves the         |
|     | server's checkout question to Q12. Recorded in the                                         |
|     | [filesystem table](../docs/architecture.md#filesystem).                                    |
| Q2  | KDE builds on `quay.io/fedora/fedora-kinoite`, published by Fedora release engineering.    |
|     | `quay.io/fedora-ostree-desktops/kinoite` is the Atomic Desktops SIG's CI channel for the   |
|     | same composes, with dated tags and sigstore signatures. The official repository has only   |
|     | the major-version tag and no signatures, so builds pin by digest when publishing starts    |
|     | (Q5). Recorded in [D2](../docs/architecture.md#d2-one-base-image-per-desktop).             |
| Q4  | Each host is installed by a kickstart file whose `ostreecontainer` directive installs the  |
|     | host's image directly, with the disk layout declared in the file. VM test disks are        |
|     | installed with the same kickstarts, from images built locally and served by the test       |
|     | registry, so kickstart development starts in Phase 2. A host's hardware install waits      |
|     | until its kickstart and image pass in a VM. Recorded in Phases 2, 3, and 10.               |
| Q6  | Workstations download and stage OS updates in the background and apply them only at the    |
|     | next reboot you do; nothing reboots them on their own. bootc's stock update timer, which   |
|     | reboots to apply, is not used as shipped. The server's policy is part of Q12. Recorded in  |
|     | Phase 3.                                                                                   |
| Q8  | Language runtimes (`nodejs`, `python`, `dotnet`, `rust`) live in user space, each through  |
|     | its own version manager, so per-project versions and updates need no image build. The      |
|     | image keeps only `python3`, which Ansible needs.                                           |
| Q10 | Images: the VM harness runs a registry container on `127.0.0.1:5000`, which the VM reaches |
|     | at `10.0.2.2:5000`, and the test disk tracks a tag there. Checkout: `imgman test playbook` |
|     | copies the working tree into the VM over SSH. Recorded in `immutable/images/README.md`.    |
| Q11 | Claude Code finds skills under `immutable/` only after a session touches a file there.     |
|     | Codex finds them only when started inside `immutable/`. Skills go in the root              |
|     | `.agents/skills/`; see the exceptions under                                                |
|     | [how the overlay works](#how-the-overlay-works).                                           |
| Q14 | Images use no RPM Fusion. Flatpak apps, including Firefox, bring their own codecs, Steam   |
|     | comes from Flathub, and hardware video decoding uses what Fedora ships. Recorded in the    |
|     | role checklist.                                                                            |
| Q15 | Workstations run no SSH server: images leave `sshd.service` disabled, as Kinoite ships it, |
|     | and no role enables it. desktop22 runs one today, so it loses it at its cutover.           |
