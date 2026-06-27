# DNF

Configures package metadata refresh and unattended DNF updates.

This role manages:

- `dnf5-automatic.timer` for weekly automatic updates.
- `/etc/dnf/automatic.conf`, rendered from role defaults.
- A notification helper at `/usr/local/bin/dnf-automatic-notify.sh`.
- System `dnf-makecache.timer` overrides for predictable metadata refresh.
- A user `dnf-makecache.timer` so unprivileged DNF commands have fresh metadata.

The automatic update service is ordered after DNS readiness, Ansible Pull, and
the system metadata refresh. Its service override also wraps update runs with
Snapper pre/post snapshots.

## Variables

`dnf_automatic_reboot` controls whether automatic updates reboot the system.
Valid values are `never`, `when-needed`, and `always`; the default is `never`.

See `MONITORING.md` for package health checks, timer schedules, update logs,
and snapshot verification.

