# ansible_pull Role — Monitoring

## Timer

`ansible-pull.timer` runs daily at 03:00 with up to 10 minutes of random delay (`RandomizedDelaySec=600`). `Persistent=true` means it catches up on the next boot if the machine was off at 03:00.

Check when it last ran and when it will run next:

```
systemctl status ansible-pull.timer
```

## Last Run Result

```
journalctl -u ansible-pull.service --since "24 hours ago" | grep "PLAY RECAP"
```

Expected output:

```
localhost : ok=NNN  changed=0  unreachable=0  failed=0  skipped=NN
```

- `failed=0` and `unreachable=0` are required — anything else is an error.
- `changed=0` means the system was already in the desired state.
- `changed>0` means the run applied updates — normal after a repo push.

## Snapper Pre/Post Snapshots

ansible-pull creates a snapper pre/post snapshot pair around each run. Verify the cleanup type is consistent:

```
snapper -c root list | grep ansible-pull
```

All ansible-pull pre/post rows should show the same value in the `Cleanup` column. A mix of `number` and `timeline` values indicates the snapper integration changed at some point. See the snapper section of the host runbook for how to handle stale `number`-type snapshots.
