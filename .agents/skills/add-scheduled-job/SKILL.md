---
name: add-scheduled-job
description: Use when adding, changing, or reviewing a scheduled job in this homelab Ansible repository, including systemd timers, timer overrides, persistent timer behavior on laptops/desktops, service ordering, network readiness, daemon reloads, handlers, monitoring docs, and avoiding cron.
---

# Add Scheduled Job

Use systemd timers for scheduled work in this repository. Do not add crontabs,
`cron`, `anacron`, user shell startup loops, or ad hoc background scripts.

## Before Editing

Inspect existing timer patterns before choosing a schedule or ordering, examples:

- `roles/system/ansible_pull/templates/ansible-pull.timer.j2`
- `roles/system/ansible_pull/templates/ansible-pull.service.j2`
- `roles/system/dnf/tasks/dnf_automatic.yml`
- `roles/system/dnf/files/dnf5-automatic-service-override.conf`
- `roles/system/dnf/files/dnf-makecache-timer-override.conf`
- related role `MONITORING.md` files when the change affects expected cadence

For role changes, check whether that role has `README.md` or `MONITORING.md` and
update stale schedules, expected services, timer names, or known issues.

## Timer Design

Prefer a `.timer` plus a `.service` unit, or a timer override for a package-owned
unit. Keep the service as a oneshot unless the job is genuinely long-running.

These hosts are often workstations and laptops that sleep or power off. For jobs
that must not be skipped, set `Persistent=true`. Assume multiple persistent
timers may catch up immediately after wake or boot.

Use `RandomizedDelaySec=` to reduce timer herding, but keep delays short. Prefer
less than 10 minutes unless the role has a specific reason to tolerate a longer
delay.

If the job needs the network or DNS, order the service after DNS readiness:

```ini
[Unit]
After=dns-online.service
Wants=dns-online.service
```

Use `network-online.target` only when link availability matters separately from
DNS. For package mirrors, repositories, HTTP APIs, Git remotes, or domain names,
prefer `dns-online.service`.

## Ordering Persistent Timers

Order catch-up work on the service unit with `After=`, not by adding broad
dependencies to the timer. This keeps timers independent while preventing many
jobs from running at the same instant after wake.

Use `After=` for jobs that should complete first. Do not add `Wants=` or
`Requires=` unless this job should actively start the other unit. A health check
may order after update or maintenance services without forcing them to run.
If the new timer or service has an `After=` or `Wants=` dependency on a unit
created by another role, add a `meta/main.yml` dependency on that role so the
dependent unit is guaranteed to exist on hosts using the new timer.

Prefer top-level units that already encode their own prerequisites. For example,
if `dnf5-automatic.service` already has `After=dnf-makecache.service`, a later
job can usually order after `dnf5-automatic.service` instead of repeating
`dnf-makecache.service`.

When adding a new persistent timer, consider whether later monitoring, update,
backup, indexing, or maintenance jobs should add `After=<new-service>.service`.
Update those units or their planned design when necessary.

## Ansible Conventions

After package installation, place all timer unit files, service unit files,
drop-ins, and configuration before enabling the timer. Add an unconditional
daemon reload immediately before enable/start:

```yaml
- name: systemd daemon is reloaded
  ansible.builtin.systemd:
    daemon_reload: true
  changed_when: false

- name: foo.timer is enabled and started
  ansible.builtin.service:
    name: foo.timer
    enabled: true
    state: started
```

Override tasks must notify a handler that restarts the timer. Use the repo's
lowercase state-description task names, generic `package`/`service` modules when
practical, unquoted octal modes, and normal YAML quoting rules from `AGENTS.md`.

For package-owned services with no custom timer or drop-in, package scriptlets
usually register the unit. Enable/start the service normally; do not add a
daemon reload just because a service exists.

## Validation

At minimum, verify:

- `ansible-lint`
- the rendered timer and service names
- `systemctl daemon-reload` is represented idempotently in the role
- `systemctl list-timers <name>.timer --all`
- `systemctl cat <name>.timer <name>.service`
- ordering with `systemctl show <name>.service -p After -p Wants -p Requires`
- relevant `MONITORING.md` instructions include cadence, expected state, and
  journal commands
