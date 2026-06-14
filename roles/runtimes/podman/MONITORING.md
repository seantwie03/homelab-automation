# podman Role - Monitoring

## Auto-Update Timer

```sh
systemctl status podman-auto-update.timer --no-pager
systemctl list-timers podman-auto-update.timer --all
systemctl show podman-auto-update.service -p Result -p ExecMainStatus
journalctl -u podman-auto-update.service --since '8 days ago' --no-pager
```

The timer should be enabled and active. The oneshot service is normally
inactive between runs; evaluate its last result and journal.

## Containers

```sh
podman ps --all
podman auto-update --dry-run
```

Investigate unexpected exited or unhealthy containers and failed image-policy
checks. A container must have the appropriate auto-update label and systemd
management for the timer to update it.

If rootless containers are used, repeat the checks with the owning user and
inspect that user's systemd units rather than assuming system-wide ownership.

