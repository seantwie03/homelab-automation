# cli Role - Monitoring

## Locate Database Timer

```sh
systemctl status plocate-updatedb.timer --no-pager
systemctl list-timers plocate-updatedb.timer --all
systemctl show plocate-updatedb.service -p Result -p ExecMainStatus
journalctl -u plocate-updatedb.service --since '8 days ago' --no-pager
```

The timer should be enabled and active, and its latest service result should be
successful. The oneshot service is normally inactive between runs.

## Database And Exclusions

```sh
ls -lh /var/lib/plocate/plocate.db
grep -E '^(PRUNENAMES|PRUNE_BIND_MOUNTS)' /etc/updatedb.conf
```

The database should exist. Snapshot directories and bind mounts should be
excluded as configured by the role, preventing duplicate indexing and
unnecessary traversal of Btrfs snapshots.

