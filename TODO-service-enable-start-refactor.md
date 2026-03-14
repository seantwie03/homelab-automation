# Service Enable/Start Refactor

## Goal

Ensure all roles that install a package with a systemd unit correctly handle enable/start
in an idempotent way that recovers from accidental disable or stop, and does not fail on
first install.

## Benefits

- Consistent pattern across all roles
- Recovers from accidental disable or stop
- **Fixes a first-run failure mode for timers:** when a package that ships a systemd timer
  is installed for the first time, systemd is not yet aware of the new unit file. Any task
  that tries to enable or start that timer will fail with "Could not find the requested
  service". A `daemon_reload` task before the enable/start task ensures systemd discovers
  the new unit first.

---

## Recommended Pattern: Timers

Timers need a `daemon_reload` before enable/start on first install. The simplest idempotent
approach is an unconditional `daemon_reload` task with `changed_when: false`, followed by a
regular enable/start task.

```yaml
# tasks/main.yml
- name: foo is installed
  ansible.builtin.package:
    name: foo
    state: present

- name: systemd daemon is reloaded
  ansible.builtin.systemd:
    daemon_reload: true
  changed_when: false

- name: foo.timer is enabled and started
  ansible.builtin.systemd:
    name: foo.timer
    enabled: true
    state: started
```

- `daemon_reload` runs every play but is invisible (`changed_when: false`) and fast.
- The enable/start task is idempotent and recovers from accidental disable or stop.
- No handler, no `register`, no `flush_handlers`.

## Recommended Pattern: Services

Services do not need `daemon_reload` — package scriptlets typically register the unit with
systemd during install. A regular enable/start task is sufficient.

```yaml
- name: foo is installed
  ansible.builtin.package:
    name: foo
    state: present

- name: foo.service is enabled and started
  ansible.builtin.systemd:
    name: foo.service
    enabled: true
    state: started
```

---

## Roles to Refactor

### Timers

#### `roles/runtimes/podman`
- Install task: `podman` package
- Timer: `podman-auto-update.timer`

#### `roles/apps/cli` (locate.yml)
- Install task: `plocate` package
- Timer: `plocate-updatedb.timer`

#### `roles/system/btrfs` (btrbk.yml)
- Install task: `btrbk` package
- Timer: `btrbk.timer`
- Note: btrbk.timer also has a systemd override — verify task ordering is correct

### Services

#### `roles/system/tailscale`
- Install task: `tailscale` package
- Service: `tailscaled.service`

#### `roles/runtimes/docker`
- Install task: docker packages
- Service: `docker.service`

#### `roles/apps/gui` (printer.yml)
- Two separate refactors in the same file:
  1. `cups` package → `cups.service`
  2. `avahi` package → `avahi-daemon.service`

#### `roles/services/nfs`
- Install task: `nfs-utils` package
- Services: `rpcbind` + `nfs-server`

#### `roles/services/smb`
- Install task: samba packages
- Services: `smb` + `nmb`

### Marginal (Evaluate During Refactor)

#### `roles/wm/waybar` and `roles/wm/dunst`
- User-scoped services (`scope: user`), no `state: started`
- Evaluate whether this pattern applies or current approach is fine

---

## Action Required

Before performing the role refactors listed above, first update
`roles/system/ansible_pull/tasks/dnf_automatic.yml` to use the timer pattern as the new
reference implementation. Then apply that pattern consistently across all timer roles, and
the service pattern across all service roles.

---

## Documentation Updates

After completing the refactor, update `CLAUDE.md` under the YAML and Task Conventions
section:

**For timers:**
> When a role installs a package that ships a systemd timer, add an unconditional
> `daemon_reload` task (`changed_when: false`) between the package install and the
> enable/start task. This ensures systemd discovers the new unit file on first install
> without failing with "Could not find the requested service". Example:
> `roles/system/ansible_pull/tasks/dnf_automatic.yml`.

**For services:**
> When a role installs a package that ships a systemd service, add a regular enable/start
> task after the package install. No `daemon_reload` is needed — package scriptlets handle
> unit registration. Example: `roles/system/tailscale`.
