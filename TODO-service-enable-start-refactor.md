# Service Enable/Start Handler Refactor

## Goal

Move `enabled: true` / `state: started` service tasks out of `tasks/main.yml` and into
handlers triggered by the package install task. This follows the pattern established in
`roles/system/dnf_automatic`.

## Benefits

- Service enable/start only runs when the package actually changes (first install)
- Avoids no-op service tasks on every ansible-pull run
- Consistent pattern across all roles
- **Fixes a first-run failure mode:** when a package that ships a systemd timer is installed
  for the first time, systemd is not yet aware of the new unit file. Any task that tries to
  enable or start that timer will fail with "Could not find the requested service". Including
  `daemon_reload: true` in the handler ensures systemd discovers the new unit before
  attempting to enable/start it. This pattern applies cleanly to all services and timers, so
  `daemon_reload: true` should be used in all handlers regardless of unit type.

## Reference Implementation

`roles/system/ansible_pull/tasks/dnf_automatic.yml` — install task notifies handler, handler does
`daemon_reload: true` + `enabled: true` + `state: started` in a single
`ansible.builtin.systemd` task.

```yaml
# tasks/main.yml
- name: dnf-automatic is installed
  ansible.builtin.package:
    name: dnf-automatic
    state: present
  notify: dnf-automatic timer is started and enabled

# handlers/main.yml
- name: dnf-automatic timer is started and enabled
  ansible.builtin.systemd:
    name: dnf-automatic-install.timer
    enabled: true
    state: started
    daemon_reload: true
  changed_when: true
```

---

## Roles to Refactor

### Strong 1:1 Candidates

#### `roles/system/tailscale`
- Install task: `tailscale` package
- Move to handler: `tailscaled.service` enable/start
- Handler name: `tailscaled service is started and enabled`

#### `roles/runtimes/podman`
- Install task: `podman` package
- Move to handler: `podman-auto-update.timer` enable/start
- Handler name: `podman-auto-update timer is started and enabled`

#### `roles/runtimes/docker`
- Install task: docker packages
- Move to handler: `docker.service` enable/start
- Handler name: `docker service is started and enabled`

#### `roles/apps/gui` (printer.yml)
- Two separate refactors in the same file:
  1. `cups` package → `cups.service` handler: `cups service is started and enabled`
  2. `avahi` package → `avahi-daemon.service` handler: `avahi-daemon service is started and enabled`

#### `roles/apps/cli` (locate.yml)
- Install task: `plocate` package
- Move to handler: `plocate-updatedb.timer` enable/start
- Handler name: `plocate-updatedb timer is started and enabled`

#### `roles/system/btrfs` (btrbk.yml)
- Install task: `btrbk` package
- Move to handler: `btrbk.timer` enable/start
- Handler name: `btrbk timer is started and enabled`
- Note: btrbk.timer also has a systemd override — verify handler ordering is correct

### Multi-Service Candidates

#### `roles/services/nfs`
- Install task: `nfs-utils` package
- Move to handler: `rpcbind` + `nfs-server` enable/start
- Use `listen` so both fire from one notification:
  - `rpcbind service is started and enabled` (listen: nfs-utils installed)
  - `nfs-server service is started and enabled` (listen: nfs-utils installed)

#### `roles/services/smb`
- Install task: samba packages
- Move to handler: `smb` + `nmb` enable/start
- Use `listen` so both fire from one notification:
  - `smb service is started and enabled` (listen: samba installed)
  - `nmb service is started and enabled` (listen: samba installed)

### Marginal (Evaluate During Refactor)

#### `roles/wm/waybar` and `roles/wm/dunst`
- User-scoped services (`scope: user`), no `state: started`
- Evaluate whether the handler pattern makes sense here or if current approach is fine

---

## Flaw: Accidental Disable Not Recovered

### Problem

The handler-only pattern has a blind spot. Because handlers only fire when the package task
reports a change, if a service or timer is accidentally disabled (manually, by a system
update side-effect, or anything else), the playbook will never re-enable it. The package is
already installed so the task reports `ok`, the handler never fires, and the service stays
disabled indefinitely.

### Options Considered

**Option A — Keep handler-only (current)**
- Pro: clean, no-op on every run
- Con: does not recover from accidental disable

**Option B — Regular enable/start task + handler for daemon_reload only**
- Use `register` on the install task, then a conditional `daemon_reload` task (`when:
  result.changed`, `changed_when: false`), then a regular enable/start task
- Pro: recovers from accidental disable; daemon_reload only runs on fresh install
- Con: adds a task that runs every play (though it's fast and idempotent)

**Option C — Regular enable/start task with `daemon_reload: true` always**
- Always include `daemon_reload: true` on the regular task
- Pro: simplest — one task handles everything
- Con: systemd daemon reload runs on every play even when nothing changed (minor overhead)

### Recommended Solution: Option B

```yaml
# tasks/main.yml
- name: dnf-automatic is installed
  ansible.builtin.package:
    name: dnf-automatic
    state: present
  register: dnf_automatic_package

- name: systemd daemon is reloaded after dnf-automatic install
  ansible.builtin.systemd:
    daemon_reload: true
  when: dnf_automatic_package.changed
  changed_when: false

- name: dnf-automatic-install.timer is enabled and started
  ansible.builtin.systemd:
    name: dnf-automatic-install.timer
    enabled: true
    state: started
```

This removes the need for the "timer is started and enabled" handler entirely. The
`restart dnf-automatic timer` handler (triggered by config changes) remains.

### Action Required

Before performing the role refactors listed above, first update `roles/system/ansible_pull/tasks/dnf_automatic.yml`
to use Option B as the new reference implementation. Then apply that pattern consistently
across all refactored roles.

---

## Documentation Updates

After completing the refactor, update the following files:

### `CLAUDE.md`

Add a new convention under the YAML and Task Conventions section describing this pattern:

> **Service enable/start belongs in handlers, not tasks.** When a role installs a package
> that ships a systemd service or timer, the enable/start task must go in a handler notified
> by the package install task — not as a standalone task. Always include `daemon_reload: true`
> in the handler. This ensures systemd discovers newly installed unit files before attempting
> to enable them (without this, first-run playbooks fail with "Could not find the requested
> service"). Example: `roles/system/ansible_pull/tasks/dnf_automatic.yml`.

### `README.md`

Add a section describing this as an established pattern in the codebase, with a short
explanation of why it exists and a pointer to `roles/system/dnf_automatic` as the reference.
