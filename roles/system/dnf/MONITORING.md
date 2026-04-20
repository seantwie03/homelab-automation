# dnf Role — Monitoring

## Timers

| Timer | Schedule | What it does |
|-------|----------|-------------|
| `dnf-makecache.timer` | Every 4h | Refreshes package metadata cache |
| `dnf5-automatic.timer` | Weekly (Tue 23:00) | Downloads and installs updates unattended |

## dnf-makecache

Check the last run succeeded:

```
journalctl -u dnf-makecache.service --since "24 hours ago"
```

Expected: `Metadata cache created.` with exit code 0.

## dnf5-automatic (weekly updates)

Check when it last ran:

```
systemctl status dnf5-automatic.timer
journalctl -u dnf5-automatic.service --since "7 days ago" | tail -20
```

Expected: `Transaction finished.` with exit code 0. The run consumes significant memory (~2 GiB peak) and CPU — that is normal.

If no entry appears in the last 7 days, the machine was likely off on Tuesday night. `Persistent=true` is not set on this timer, so missed runs are not caught up automatically.
