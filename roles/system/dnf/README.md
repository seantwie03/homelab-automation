# DNF

Configures package metadata refresh and unattended DNF updates.

This role manages:

- `dnf5-automatic.timer` for weekly automatic updates.
- `/etc/dnf/automatic.conf`, rendered from role defaults.
- A notification helper at `/usr/local/bin/dnf-automatic-notify.sh`.
- System `dnf-makecache.timer` overrides that force all enabled repositories to
  be checked every four hours.
- A user `dnf-makecache.timer` that performs the same forced refresh for the
  separate unprivileged DNF cache.

The automatic update service is ordered after DNS readiness, Ansible Pull, and
the system metadata refresh. Its service override also wraps update runs with
Snapper pre/post snapshots.

Both metadata services use `dnf5 makecache --refresh`. Without `--refresh`,
DNF5 skips repositories whose metadata has not expired yet. A repository can
then expire between timer runs and make the next interactive DNF command wait
for a refresh.

## Variables

`dnf_automatic_reboot` controls whether automatic updates reboot the system.
Valid values are `never`, `when-needed`, and `always`; the default is `never`.

See `MONITORING.md` for package health checks, timer schedules, update logs,
and snapshot verification.
