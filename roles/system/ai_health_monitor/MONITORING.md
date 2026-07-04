# ai-health-monitor Role - Monitoring

## Timer

```sh
systemctl status ai-health-monitor.timer --no-pager
systemctl list-timers ai-health-monitor.timer --all
systemctl cat ai-health-monitor.timer ai-health-monitor.service
```

Expected:

- `ai-health-monitor.timer` is enabled and active.
- The next run matches `health_monitor_schedule` plus the randomized delay.
- The service orders after network, DNS, Ansible Pull, DNF automatic updates,
  Btrfs maintenance, and locate database updates.

## Last Run

```sh
systemctl show ai-health-monitor.service -p Result -p ExecMainStatus
journalctl -u ai-health-monitor.service --since '8 days ago' --no-pager
ls -lt /var/log/ai-health-monitor
```

Open the newest report in `/var/log/ai-health-monitor/`. The last line should
be one of:

```text
VERDICT: Healthy
VERDICT: Attention Required
```

Investigate missing reports, unknown verdict notifications, or repeated Codex
failures. If the report says a check was blocked, compare the command with
`/etc/sudoers.d/ai-health-monitor` before broadening permissions.

Expected report structure:

- Action required
- Ongoing follow-up
- Informational observations
- Healthy areas
- Checks skipped or blocked

`VERDICT: Attention Required` should appear only when the report contains at
least one action required finding or unresolved ongoing follow-up item. Healthy
systems with only informational observations or non-critical skipped checks
should use `VERDICT: Healthy`.

## Credentials And Hardening

```sh
namei -l /home/ai-health-monitor/.config/openrouter/openrouter-api-key
systemctl cat ai-health-monitor.service
```

Expected:

- The OpenRouter key is owned by `root:ai-health-monitor` with mode `0440`.
- The service uses `ProtectSystem=strict`, `InaccessiblePaths=/home/sean`,
  `ReadOnlyPaths=/home/ai-health-monitor/.config/openrouter`, and writable
  paths only for reports and Codex state.
