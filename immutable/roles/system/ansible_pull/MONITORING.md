# ansible_pull Role - Monitoring

## Settings

```sh
cat /etc/ansible-pull.conf
```

Expected: `ANSIBLE_PULL_PLAYBOOK` names this host's playbook, and
`ANSIBLE_CONFIG` names an existing file in the checkout.

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

Open the newest log summary:

```sh
h logs
```

The first `less` buffer shows the final play recap and changed tasks.
Press `:n` in `less` to move to the full log. The play recap should look like:

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

## Logs

```sh
ls -lh /var/log/ansible-pull
cat /etc/logrotate.d/ansible-pull
```

Expected:

- `/var/log/ansible-pull` is owned by `root:wheel` with mode `0775` so
  unprivileged health checks can list available logs.
- The role retains up to 30 rotations or 30 days of logs.

Missing logs after a successful timer activation are unexpected.
