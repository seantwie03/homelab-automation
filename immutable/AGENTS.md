# AGENTS.md: bootc overlay

These rules apply to files under `immutable/`. They add to the root `AGENTS.md`
and override it where the two conflict. At the end of the migration they are
merged into the root `AGENTS.md`.

## The overlay

`immutable/` mirrors the future repository root for bootc hosts. Read the plan
in `immutable/migration/README.md` before starting migration work.

- Add a file here only when it is new or replaces a root file. Unchanged files
  stay at the root; overlay playbooks resolve root roles through
  `immutable/ansible.cfg`.
- To change a root role for bootc hosts, copy the whole role here first. Do not
  edit root roles to suit bootc hosts, because traditional hosts still run them.
- Root files must not depend on anything under `immutable/`.
- Material that only matters during the migration goes in
  `immutable/migration/`. Nothing outside of this file and `immutable/migration`
  should mention the migration. Instead, documents, comments, etc. should be
  written as if it were developed for immutable from the beginning.

## Image or runtime

The image owns everything that installs software or writes under `/usr`:
packages, repositories and their signing keys, kernel modules, compositors and
display managers, units enabled on every host that uses the image, and the
Ansible bootstrap.

Runtime roles own `/etc`, `/var`, and home directories: host configuration,
per-host service enablement, mounts, users and groups, Flatpaks, user-space
tools, and dotfiles.

Runtime roles must not:

- Install or remove packages (`ansible.builtin.package`, `dnf`, `rpm_key`,
  `yum_repository`).
- Write under `/usr`.
- Run `pip` or `npm -g` installs outside a user's home directory.
- Create directories directly under `/`. Mount points and shared data go under
  `/srv`.

When a runtime role needs a package, add the package to the image build and
list it in the role's README as an image requirement.

## Image builds

- Build logic lives in `images/scripts/*.sh`. Containerfiles stay thin: copy a
  script, run it.
- Scripts start with `set -euo pipefail`, use 4-space indentation, and pass
  ShellCheck.
- The root repository-signing-key rules still apply, but they run in a build
  script instead of a role: check the key into `images/`, install it under
  `/etc/pki/rpm-gpg/`, import it from that file, verify the full fingerprint,
  and keep `gpgcheck` enabled. Document key rotation in `images/README.md`.
- Pin base images to a Fedora major version. Never build from `:latest`.

## Paths

- Refer to the repository checkout through `playbook_path` and
  `dotfiles_path`, never a literal path. The bootc checkout location is still
  open.

## Validation

- `ansible-lint`
- `shellcheck immutable/images/scripts/*.sh`

## Documentation

- Durable docs for bootc hosts go under `immutable/` at their final path, such
  as `immutable/README.md`, `immutable/images/README.md`, and role README and
  MONITORING files.
- Write a durable doc in the present tense once the thing it describes exists.
  Until then, the design lives in `immutable/migration/README.md` and
  `immutable/docs/architecture.md`.
- Recurring health checks go in the owning role's MONITORING file, not in the
  migration plan.
