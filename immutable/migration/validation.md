# Validation

Checks to run by hand while reviewing the bootc work: a walkthrough of the
established workflow on a machine that has never run it, and prototypes of
changes still to be decided. Run them on desktop25, a traditional Fedora 44
host with every `imgman` prerequisite installed, from the repository root,
`/opt/homelab-automation`, unless a step says otherwise.

desktop25 is in `immutable/images/hosts.toml`, so `imgman` defaults to it, but
it has no playbook. Always name the host, such as `x1carbon23`.

## Read first

1. [The plan](README.md): phases, the role checklist, and open questions.
2. [Architecture](../docs/architecture.md): the decisions and the file system
   layout.
3. [`immutable/AGENTS.md`](../AGENTS.md): what belongs in the image and what
   belongs in a runtime role.
4. [Images](../images/README.md) and [imgman](../imgman/README.md).

[imgman-plan.md](imgman-plan.md) only matters for commands not built yet.
[original-plan.md](original-plan.md) is superseded.

## 1. Set up imgman

Review "Installing", "Prerequisites", and "Installer ISO" in
`immutable/imgman/README.md`.

- [ ] Create the cache directory with `chattr +C` before anything else creates
  it. `imgman` sets the attribute only when `machine init` creates the cache,
  and the README's ISO step creates the directory first:

  ```sh
  mkdir ~/.cache/homelab-images && chattr +C ~/.cache/homelab-images
  lsattr -d ~/.cache/homelab-images
  ```

- [ ] Download and verify the netinst ISO as "Installer ISO" describes.
- [ ] Install `imgman` and check that it runs:

  ```sh
  uv tool install --editable immutable/imgman
  imgman --help
  ```

- [ ] Run imgman's checks from `immutable/imgman/`:

  ```sh
  uv run ruff format --check
  uv run ruff check
  uv run pyrefly check
  uv run pytest
  ```

## 2. Build the image

Review `immutable/images/Containerfile.kde`, `scripts/*.sh`, `keys/`, and
`bin/h`. The first build pulls the Kinoite base image, about 7 GB.

- [ ] Build and lint the image:

  ```sh
  imgman image build kde
  ```

- [ ] Check that the image's initramfs carries the TPM2 support x1carbon23's
  TPM2 + PIN unlock needs. Only the hardware can test the unlock itself:

  ```sh
  podman run --rm localhost/workstation-kde sh -c \
      'lsinitrd /usr/lib/modules/*/initramfs.img 2>/dev/null |
          grep -E "libtss2|systemd-tpm2|libcryptsetup-token"'
  ```

## 3. Install x1carbon23's VM disk

Review `immutable/images/kickstart/x1carbon23.ks` and
`immutable/imgman/src/imgman/installer.py`.

- [ ] Install the disk, which takes about 7 minutes, and watch the installer's
  console from another terminal:

  ```sh
  imgman machine init x1carbon23
  tail -f ~/.cache/homelab-images/x1carbon23/install/console.log
  ```

## 4. Test the image

Review `immutable/imgman/src/imgman/checks.py` and `vm.py`.

- [ ] Run the checks. All 15 should pass in about 20 seconds:

  ```sh
  imgman test image x1carbon23
  ```

- [ ] Look around the VM as root. Without the bootstrap password, set one for
  `sean`; changes last only until the VM stops:

  ```sh
  imgman machine ssh x1carbon23
  passwd sean
  ```

- [ ] Log in to the desktop:

  ```sh
  imgman machine gui x1carbon23
  ```

## 5. Test the playbook

Review `immutable/x1carbon23.yml`, `immutable/ansible.cfg`, the roles under
`immutable/roles/`, and `immutable/imgman/src/imgman/playbook.py`.

- [ ] Converge twice. The second run must change nothing:

  ```sh
  imgman test playbook x1carbon23
  ```

- [ ] Check whether starting `ansible-pull.timer` also starts the service. The
  timer lists `Requires=ansible-pull.service`, which on desktop25 starts a run
  at every boot. The VM skips the service, so read the unit instead:

  ```sh
  imgman machine ssh x1carbon23 systemctl show ansible-pull.timer -p Requires
  ```

## 6. Rehearse the bootstrap

Review the `ansible_pull` role's README and `immutable/images/bin/h`. The
bootstrap clones `main` from GitHub, so it tests what is pushed, not the
working tree.

- [ ] Boot a fresh VM, then, in its root shell, run the first-run command from
  "Bootstrap" in `immutable/roles/system/ansible_pull/README.md`:

  ```sh
  imgman machine run x1carbon23
  imgman machine ssh x1carbon23
  ```

- [ ] In the same shell, `h test` reruns the playbook with no changes, and `h`
  shows `ansible-pull.service`, which the VM skips.

## 7. Updates from GHCR

Review `immutable/images/scripts/updates.sh` and "Publish by hand" in Phase 3
of the plan.

- [ ] Switch a VM to the published image and reboot it. The switch downloads
  the whole image. The reboot closes the SSH connection, so `imgman` reports
  that command as failed; wait about 20 seconds before the next one:

  ```sh
  imgman machine ssh x1carbon23 bootc switch ghcr.io/seantwie03/workstation-kde:stable
  imgman machine ssh x1carbon23 systemctl reboot
  ```

- [ ] Check that the VM booted the published image and reaches GHCR without
  credentials:

  ```sh
  imgman machine ssh x1carbon23 bootc status
  imgman machine ssh x1carbon23 bootc upgrade --check
  ```

- [ ] Check that updates stage without rebooting:

  ```sh
  imgman machine ssh x1carbon23 systemctl cat bootc-fetch-apply-updates.service
  imgman machine ssh x1carbon23 systemctl list-timers bootc-fetch-apply-updates.timer
  ```

## 8. Other hosts and the runbook

- [ ] Test every host. The first run installs desktop22's and desktop25's
  disks, about 15 minutes in all:

  ```sh
  imgman test image --all
  ```

- [ ] Read [x1carbon23-install.md](x1carbon23-install.md) against Phase 3's
  open items.

## Prototype: `/opt` as an image directory

Kinoite links `/opt` to `/var/opt`, the original ostree layout. fedora-bootc
follows bootc's layout instead: `/opt` is a regular directory in the image,
read-only on a running host. `/usr/local` stays a link to `/var/usrlocal` in
every image, so runtime roles can install scripts there. Checked on
2026-11-07:

- Kinoite 44 and 45 link `/opt`; fedora-bootc 44 and 45 ship it as a
  directory.
- No package in any of those images ships files under `/opt`.
- The link is part of the base image. rpm-ostree's tmpfiles file only creates
  the `/var/opt` directory, so nothing recreates the link at boot.

See the [bootc file system docs](https://bootc.dev/bootc/bootc-filesystem.7.html)
and the
[Fedora discussion of the links](https://discussion.fedoraproject.org/t/are-opt-and-usr-local-symlinks-on-silverblue-because-it-is-an-ostree-image-and-not-bootc/199320).

Do this before x1carbon23's install. Once a host keeps data under `/var/opt`,
switching needs a migration.

- [ ] Replace the `/opt` link with a directory in the image.
- [ ] Install 1Password to `/opt/1Password` directly: drop `onepassword.sh`'s
  move to `/usr/lib/1Password` and its tmpfiles link, and update "1Password"
  in `immutable/images/README.md`.
- [ ] Move the checkout to `/var/homelab-automation`: `playbook_path` and
  the bootstrap command in the `ansible_pull` role and its README,
  `GUEST_CHECKOUT` in imgman's `playbook.py` with its tests and README, the
  Filesystem table in `architecture.md`, "Paths" in `immutable/AGENTS.md`, and
  the runbook.
- [ ] Change `test image`'s layout checks: `/opt` is a read-only directory, not
  a link.
- [ ] `imgman test image --all` and `imgman test playbook x1carbon23` pass.
- [ ] Once a role that links dotfiles runs in the VM, check for SELinux
  denials. The checkout's label changes from `usr_t` under `/opt` to `var_t`
  under `/var`, and dotfiles in the home directory link into it. `ausearch`
  prints `<no matches>` and exits 1 when there are none:

  ```sh
  imgman machine ssh x1carbon23 ausearch -m avc -ts boot
  ```

- [ ] Record the outcome. If the layout holds, add a decision to
  `architecture.md`, and update its Filesystem table and the Q1 answer in the
  plan. If it fights the base image, record why and keep the link.

## Proposal: align imgman with the testing strategy

Review these with `imgman`, against "Testing Strategy" in the
[architecture](../docs/architecture.md#testing-strategy). Decide each one on
its own.

- [ ] **Install from `:stable`.** The strategy tests a playbook change on
  `:stable`, but `imgman` installs every disk from the local build. Add an
  option that leaves out `imgman.url`, so the kickstart installs its own
  default, `:stable`. CI needs it to test a playbook change without a build.
  Keep the local build as the default for local runs: with `images/`
  unchanged, it differs from `:stable` mostly in Fedora's package updates.
  desktop22's and desktop25's kickstarts first need `:stable` as their default
  image instead of a placeholder.
- [ ] **`test image` also converges the playbook.** After its checks,
  `test image` runs the host's playbook twice and then the capability tests,
  and skips both for a host with no playbook, as desktop22 and desktop25 have
  today. CI's gate becomes `test image --all`, and `test all` is never built.
  Also make `test playbook` check that the host has a playbook before it boots
  or installs anything.
- [ ] **Drop `test upgrade`, `image promote`, and the local `:current` tag.**
  A fresh install misses what changes when an existing host upgrades: local
  `/etc` edits meeting the image's `/etc` changes, groups the image adds, and
  kernel arguments. But ansible-pull reapplies role-managed `/etc` files after
  every boot, workstations reboot into a new image only while someone watches,
  with the previous deployment one GRUB entry away, and Fedora tests bootc's
  own upgrade path. Revisit this if an upgrade breaks a host, or when
  odroidh3plus, which may reboot into updates on its own, migrates. Without
  `test upgrade`, nothing needs `image promote`, `:current`, or the cached
  current and converged disks: remove them from Phase 7 and `imgman-plan.md`.
  Keep the `passed/` records, which publishing by hand checks until CI
  publishes.
- [ ] **One source for capability tests.** Write each capability test as an
  executable script in the role that owns it. `imgman` runs it in the VM
  after the playbook converges, and the role's MONITORING file has
  `check-homelab-host` run the same script on the host. Settle the file name
  with the first one, in Phase 4.
- [ ] **What CI runs.** For an image build, on a change and weekly:
  `test image --all` for the hosts that use the flavor, which gates
  `:stable`. For a playbook change: `test playbook` on `:stable` for each host
  with a playbook, as a report. Update Phase 7 to match.
