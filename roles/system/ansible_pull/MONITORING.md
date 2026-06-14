# ansible_pull Role - Monitoring

## Timer

`ansible-pull.timer` runs daily at 03:00 with up to 10 minutes of random delay.
It is persistent, so a missed run starts after the next boot.

```sh
systemctl status ansible-pull.timer --no-pager
systemctl list-timers ansible-pull.timer --all
```

Expected:

- The timer is enabled and active.
- The last and next trigger are consistent with the configured daily schedule.

## Last Run

Find the newest Ansible Pull log:

```sh
ls -t /var/log/ansible-pull | head -1
```

Read that file from `/var/log/ansible-pull/` and find its final play recap:

```text
localhost : ok=NNN changed=N unreachable=0 failed=0 skipped=NN ...
```

Expected:

- `failed=0` and `unreachable=0`.
- A nonzero `changed` count is normal after configuration changes.
- A second run with no intervening changes should normally report `changed=0`.
- A missing recap means the run ended before Ansible completed. Read the entire
  log and inspect the service journal.

```sh
systemctl show ansible-pull.service \
    -p Result -p ExecMainCode -p ExecMainStatus
journalctl -u ansible-pull.service --since '2 days ago' --no-pager
```

## Snapper Pre/Post Snapshots

```sh
snapper -c root list | grep ansible-pull
```

Recent completed runs should have a `Before ansible-pull` pre snapshot and a
matching `After ansible-pull` post snapshot. Both should use the `number`
cleanup algorithm.

Older unmatched snapshots or rows using `timeline` may reflect historical
configuration bugs. Report them as historical unless the problem recurs on
recent runs. A new unmatched pre snapshot can indicate an interrupted run or a
failed post-snapshot command.

## Logs

```sh
ls -lh /var/log/ansible-pull
cat /etc/logrotate.d/ansible-pull
```

The role retains up to 30 rotations or 30 days of logs. Missing logs after a
successful timer activation are unexpected.

