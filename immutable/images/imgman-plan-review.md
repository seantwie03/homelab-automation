# imgman plan review

Review of `imgman-plan.md`. Verdict: not ready to implement. The CLI design
(the command tree, overlays, a VM directory per host) holds up, but the plan
depends on files and decisions that don't exist yet, and has design bugs that
would show up as soon as code is written.

## Blockers: dependencies that don't exist yet

### 1. `site.yml` conflicts with the migration plan

- [x] Resolved: keep a playbook per host. `site.yml` with `desktop.fact` is
  optional Phase 15 in `migration/README.md`.

The plan has every host converge on one `site.yml` that picks desktop roles
from `ansible_local.desktop.flavor`. `migration/README.md` plans one playbook
per host (`immutable/desktop22.yml`), and Phase 13 keeps that layout with
`<host>.yml` shims. Neither the fact nor `host_vars/` exists.

**Fix:** decide, and record the decision in `docs/architecture.md` before any
code depends on it.

### 2. Inputs come from later phases

- [x] Resolved: `migration/README.md` now has Phase 2, "imgman and kickstart
  installs", before the runtime roles. It adds the workstation kickstarts,
  `hosts.toml` (every workstation on `kde` until Phase 4), and `imgman`, and
  deletes `vm_test.py`. `test playbook` follows in Phase 3, and the server
  kickstart in Phase 7.

- Host kickstarts: Phase 7, which depends on Phases 4–6.
- `Containerfile.kde-nvidia`: Phase 3.
- A bootc `ansible_pull` unit and host playbooks: Phase 2, still open.
- `hosts.toml`: doesn't exist.

As written, only the `kde` flavor could run, and only with `bcvk`.
`machine init` and `test playbook` can't be built yet.

**Fix:** split the plan into what can be built now and what waits.

### 3. One kickstart can't serve both the VM and the real host

- [x] Resolved: `%pre` reads `imgman.url` and `imgman.disk` from the kernel
  command line, falls back to the hardware values, and writes the two
  directives to a file the kickstart includes. QEMU's `-no-reboot` turns
  `reboot` into an exit. See "Kickstart Targets" in `imgman-plan.md`.

A production kickstart will:

- install the published GHCR image, not `10.0.2.2:5000/...:test`;
- limit the installer with `ignoredisk --only-use` to real disk IDs, not the
  VM's `vda`;
- probably end with `reboot` rather than `poweroff`.

**Fix:** specify a mechanism, such as a shared `%include` with a small file
per target, or substitution at init time. Otherwise the parity claim in §1.3
is false.

### 4. Swapping `bcvk to-disk` for Anaconda is unstated

- [x] Resolved, except install time, which Phase 2's prototype measures. The
  docs, skill, and tests that replacing `vm_test.py` touches are Phase 2
  tasks.

Missing pieces:

- ~~how the ISO is downloaded, pinned, and checksummed~~: you download and
  verify it; `imgman` checks for it in the prerequisite check and prints
  download and placement instructions when it's missing (see "Installer ISO"
  in `imgman-plan.md`);
- ~~how the kickstart reaches Anaconda~~: injected into the initrd extracted
  from the ISO, booted with `-kernel`/`-initrd` and `inst.ks=file:/ks.cfg`,
  as `virt-install --initrd-inject` does;
- ~~how Anaconda pulls over plain HTTP from the registry~~: the kickstart's
  `%pre` writes the insecure-registry config in the VM branch;
- expected install time compared with today's ~5 minutes.

~~The plan also never says whether `imgman` replaces `vm_test.py`.~~ It does
(Phase 2 deletes `vm_test.py`). `imgman-plan.md` should still cover the
README, the `test-bootc-image` skill, the unit tests, `COLLECTIONS`, the
`ruff`/`ty` rules, and the exit codes.

## Design bugs

### 5. Hosts sharing a flavor corrupt each other's tests

- [x] Resolved: the test registry has a repository per host and flavor,
  `<host>/workstation-<flavor>:test`.

desktop22 and desktop25 are both `kde-nvidia`, so they share
`workstation-kde-nvidia:test`. `test image` pushes the synthetic upgrade layer
to that tag. A `machine init` or upgrade test for the other host running at
the same time picks up the marker image. §1.7 invites running hosts in
parallel.

**Fix:** a tag per host, such as `:test-<host>`.

### 6. `test all` runs the playbook on a VM that `test image` left dirty

- [x] Resolved: no change. After item 13, the leftovers are minor; revisit
  only if they cause a real failure.

After `test image`, the VM has been through upgrade and rollback, carries
`/etc/homelab-vm-test` and the insecure registry config, and has a rollback
deployment.

Update after item 13: `test image` no longer upgrades or rolls back, so the
only leftovers are the insecure registry config, the `~/.cache` snapshot
check's files, and the state of a booted system.

**Fix:** `test playbook` within `test all` boots a fresh overlay first.

### 7. Staleness rules contradict each other

- [x] Resolved: a `.inputs` file next to each disk records the image ID and
  kickstart SHA-256. `test image` and `test upgrade` build and reinstall stale
  disks; `test playbook` and `machine run` only warn. Includes and flavor
  changes needed nothing extra. See "Dependency Detection Logic" in
  `imgman-plan.md`.

§1.2 and the `test` intro say every `test` command rebuilds stale
dependencies, but `test playbook` only boots whatever disk exists.
Separately, comparing mtimes misses:

- files the kickstart `%include`s;
- flavor changes in `hosts.toml`;
- `git checkout` resetting mtimes, which causes spurious reinstalls.

**Fix:** store a hash of the inputs next to the disk, and state which
commands check it.

### 8. Relying on `ansible-pull.timer` failing

- [x] Resolved: a `systemd.unit-dropin.ansible-pull.service` credential adds
  `ConditionVirtualization=!vm`, so the service is skipped, not failed. Phase
  2's prototype confirms the credential works.

Without `.git`, a timer run inside the VM is expected to fail, and that is the
safeguard. The failed unit will then trip any `systemctl --failed` capability
check.

**Fix:** mask the timer in the VM, for example with a credential or drop-in.

### 9. `test image` and `--rm` stop a VM you may be using

- [x] Resolved: documented under principle 6, and imgman prints a line
  whenever it replaces a running VM. No refusals or locks.

The plan doesn't say so.

**Fix:** document it, or have those commands refuse to touch a VM that
`machine run` started.

### 10. VNC port and vsock CID allocation are undecided

- [x] Resolved: the display is SPICE on a Unix socket in each host's `run/`
  directory, so there are no ports to allocate. CIDs stay random, and a CID
  in use is retried up to 5 times.

The plan says "`5900 + host_index` or dynamic free port". `host_index` shifts
whenever `hosts.toml` changes, and `-vnc :N` takes a display number, not a
port. Random vsock CIDs can also collide, so the "no collisions" claim needs a
retry or deterministic CIDs.

**Fix:** pick one allocation scheme for each.

## Smaller gaps

### 11. Unstated requirements

- [x] Resolved: "Requirements" in `imgman-plan.md`, checked per command. The
  host packages go in the workstation image (Phase 2).

`remote-viewer` (the `virt-viewer` package), `qemu-ui-spice-core`, and
`xorriso` on the host, and `rsync` and `spice-vdagent` inside the image
(check that Kinoite ships them).

### 12. Syncing the working tree

- [x] Resolved: no change. The repository has one `.gitignore`, at the root,
  which `rsync --filter=':- .gitignore'` reads correctly. `--files-from`
  would break `--delete`. Revisit only if a stray file causes trouble.

rsync's `.gitignore` filter is per-directory.
`git ls-files -co --exclude-standard | rsync --files-from=-` matches git
exactly.

### 13. Upgrade test ignores the open D7 proposal

- [x] Resolved: `test image` drops the synthetic upgrade and rollback, and
  adds kickstart layout, boot, and `bootc upgrade --check` checks. A new
  `test upgrade` runs the D7 test from cached current and converged disks,
  and `image promote` requires it. Both are in `imgman-plan.md` and Phase 3.

Phase 3 has an open proposal to replace the synthetic upgrade with a
current-to-new image upgrade (D7). This plan keeps the synthetic one without
mentioning it.

### 14. Where the plan lives

- [x] Resolved: no move. Both `imgman-plan*.md` files are deleted once
  `imgman` works, after durable docs and skills are written (Phase 2).

Per `immutable/AGENTS.md`, designs for things that don't exist yet belong in
`immutable/migration/`, not `immutable/images/`.
