# AI Health Monitor

Runs a weekly Codex-based host health audit as the dedicated
`ai-health-monitor` user. The role deploys a systemd timer, a restricted
sudoers allowlist, report log rotation, and a notification helper.

The role depends on the existing `ai` role for globally installed AI tooling and
does not install Codex or Node.js itself.

## Manual Setup

After the first role run, create the OpenRouter API key file manually:

```sh
sudo install -o root -g ai-health-monitor -m 0440 \
    /dev/null \
    /home/ai-health-monitor/.config/openrouter/openrouter-api-key
sudoedit /home/ai-health-monitor/.config/openrouter/openrouter-api-key
```

The key file is root-owned and group-readable by `ai-health-monitor`. The
systemd service marks the OpenRouter directory read-only in its mount namespace.

The run script sets `CODEX_HOME=/home/ai-health-monitor/.codex` before calling
Codex. If a manual run prints `provider: openai`, Codex is not using the
role-managed OpenRouter config and the run should be treated as failed.

## Schedule

`ai-health-monitor.timer` runs weekly using `health_monitor_schedule`, defaults
to Friday at 12:00, is persistent, and has a short randomized delay. The service
orders itself after existing repo maintenance services so missed persistent
timers do not all run at once after a workstation wakes.

Reports are written to `/var/log/ai-health-monitor/` and rotated by logrotate.
