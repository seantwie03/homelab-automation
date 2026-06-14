# dnf Role - Monitoring

## Package Health

```sh
sudo rpm --verifydb
sudo rpm -qa >/dev/null
sudo dnf check
```

All three commands should complete without output. Signature errors, unreadable
RPM headers, or dependency problems require investigation before unattended
updates can be trusted.

## Timers

```sh
systemctl list-timers \
    dnf-makecache.timer \
    dnf5-automatic.timer \
    --all
systemctl --user list-timers dnf-makecache.timer --all
```

| Timer | Expected schedule |
|---|---|
| System `dnf-makecache.timer` | Every 4 hours, persistent, up to 5 minutes random delay |
| User `dnf-makecache.timer` | Every 4 hours, persistent, up to 5 minutes random delay |
| `dnf5-automatic.timer` | Tuesday at 23:00, no random delay |

The user timer exists so package metadata remains available to unprivileged DNF
commands.

## Metadata Refresh

```sh
systemctl show dnf-makecache.service -p Result -p ExecMainStatus
journalctl -u dnf-makecache.service --since '12 hours ago' --no-pager

systemctl --user show dnf-makecache.service -p Result -p ExecMainStatus
journalctl --user -u dnf-makecache.service \
    --since '12 hours ago' --no-pager
```

Expected:

- The last result is successful.
- The system service reports `Metadata cache created.`
- The user service completes its DNS pre-check and metadata refresh.

Oneshot services are normally inactive between runs.

## Automatic Updates

```sh
systemctl status dnf5-automatic.timer --no-pager
systemctl show dnf5-automatic.service -p Result -p ExecMainStatus
journalctl -u dnf5-automatic.service --since '8 days ago' --no-pager
systemctl cat dnf5-automatic.timer dnf5-automatic.service
```

Expected:

- The timer is enabled and active.
- A continuously running host has a successful transaction on its weekly
  schedule.
- The journal reports `Transaction finished.` when updates were available.
- The effective service orders itself after DNS, Ansible Pull, and the system
  metadata refresh.

The timer is not persistent. A host that was off Tuesday at 23:00 can
legitimately have no run for that week.

## Snapper Pre/Post Snapshots

```sh
snapper -c root list | grep dnf5-automatic
```

Recent completed runs should have matching `Before dnf5-automatic` and `After
dnf5-automatic` snapshots using the `number` cleanup algorithm. The snapshots
wrap the service, so a run with no package changes may still create a pair.

