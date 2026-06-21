---
name: check-homelab-host
description: Audit the health of a host managed by this homelab Ansible repository. Use when asked to check, monitor, diagnose, or verify a desktop, laptop, server, or other host after an upgrade, configuration change, reboot, or suspected failure. Derive checks from the current hostname playbook and repository MONITORING.md files instead of assuming one host's services apply everywhere.
---

# Check Homelab Host

Perform a read-only health audit by default. Investigate unhealthy results to
their likely root cause. Do not restart services, clear failed state, delete
snapshots, or otherwise alter the host unless the user asks for remediation.

## Discover The Host

1. Run `hostname --short`.
2. From the repository root, run
   `.agents/skills/check-homelab-host/scripts/list-roles.sh <hostname>.yml`.
   Treat its output as the complete role inventory, including dependencies from
   `meta/main.yml`.
3. Open `<hostname>.yml` and read its variables to resolve host-specific
   behavior.
4. List all monitoring files with `find roles -name MONITORING.md -print`.
   Use this only as a path index for locating documentation for roles that
   apply to the current host. Do not treat every returned file as applicable.
   Do not use a fixed `-maxdepth`; roles live under category directories such
   as `roles/system`, `roles/apps`, `roles/runtimes`, and `roles/wm`.
5. For each role in the script output, locate that role's directory under
   `roles/` and fully read its `README.md` and `MONITORING.md` when those files
   exist.
6. Apply only the monitoring instructions for roles in the current host's role
   inventory. Note checks that are documented but not applicable to this host.
7. Read role tasks and defaults when needed to resolve expected
   service names, schedules, paths, thresholds, or host-specific variables.

If role discovery fails, report that failure and derive a conservative role
list from the host playbook and role dependencies. Do not fall back to applying
every `MONITORING.md` file in the repository.

Do not treat monitoring documentation as infallible. Compare it with the
deployed units, current package behavior, and role implementation. Report stale
documentation separately from host failures.

Prioritize problems that are easy to miss during normal interactive use, such
as failed jobs, missed timers, stale automation, skipped maintenance, storage
pressure, recurring background warnings, and disabled or degraded services.
Still record hardware or desktop-session problems when evidence is clear, but
de-emphasize issues that the user would likely notice directly through normal
computer use, such as obviously malfunctioning input devices, displays, audio,
or peripherals.

## Run The Common Baseline

Check:

- release, kernel, uptime, load, memory, swap, and mounted filesystem usage
- `systemctl is-system-running` and failed system/user units
- all timers, emphasizing missed cadence and failed activations
- persistent services implied by the host's roles
- socket-activated services and sockets, not only daemon process state
- graphical user services only when the host has a graphical role and session
- DNS, networking, and Tailscale when their roles are present
- RPM database and dependency health
- current-boot kernel warnings, errors, and hardware initialization failures
- `/sys` health and security status interfaces for degraded or vulnerable states
- storage errors and OOM events

Use read-only system commands and request scoped elevated access when the
sandbox blocks the system bus, journal, or device metadata. Commands requiring
an interactive sudo password may not work through Codex; report the exact
remaining commands rather than weakening authentication.

## Apply Role Monitoring

Execute the commands and evaluate the thresholds in each applicable
`MONITORING.md`.

For storage checks:

- distinguish filesystem free space from Btrfs allocated-chunk utilization
- compare Btrfs data, metadata, and unallocated space with documented thresholds
- inspect scrub, balance, trim, btrbk, and Snapper service journals when direct
  privileged CLI output is unavailable
- treat persistent Btrfs device error counters as follow-up items even when the
  latest scrub succeeded

For Ansible and DNF:

- extract the latest complete Ansible recap
- require `failed=0` and `unreachable=0`
- distinguish expected configuration changes from recurring non-idempotence
- confirm DNF metadata refresh and automatic-update transactions completed
- inspect the effective timer/service units, including drop-ins

## Interpret Service State

Do not flag `inactive` alone as failure.

- Check sockets for socket-activated Docker and libvirt services.
- Account for Fedora modular libvirt daemons such as `virtqemud`.
- Account for generated UWSM and XDG autostart unit names.
- Confirm whether NetworkManager replaces a standalone Wi-Fi supplicant unit.
- For oneshot services, use the last result and journal rather than expecting
  them to remain active.

When a documented service name is absent, identify its replacement before
calling it a regression.

## Investigate Anomalies

For every failed or suspicious result:

1. Inspect `systemctl status`, relevant journal entries, and the effective unit.
2. Determine whether the failing configuration is managed by this repository.
3. Identify whether the issue is active, historical, expected, or documentation
   drift.
4. State the technical cause and the narrowest repository fix.
5. If the user requests remediation, edit the owning role, review its README or
   `MONITORING.md`, run `ansible-lint`, apply the playbook when authorized, and
   verify the affected service plus overall system state.

Do not add handlers merely to clear a prior failed state. Add a handler only
when the service must reload, restart, or run to consume changed configuration
or when immediate validation is an explicit desired behavior.

## Report

Lead with actionable findings ordered by severity. Then summarize:

- healthy core system state
- service and user-session health
- timer and automation health
- package and network health
- storage, snapshot, and maintenance health
- checks blocked by interactive sudo
- stale monitoring documentation

Include exact dates for timer cadence and recent runs. Keep expected historical
warnings separate from new post-change regressions.
