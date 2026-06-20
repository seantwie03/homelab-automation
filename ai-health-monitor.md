# Automated Weekly Health Monitoring

## Summary

A new Ansible role `roles/system/ai-health-monitor` creates the `ai-health-monitor` user, configures its agent environment, sets up a tightly scoped sudoers whitelist, deploys the monitoring wrapper, configures systemd timer + service, sets up log rotation, and sends desktop notifications to `sean`.

The only manual setup step is placing the OpenRouter API key.

## Role Structure

```text
roles/system/ai-health-monitor/
├── defaults/
│   └── main.yml
├── files/
│   └── sudoers.ai-health-monitor
├── handlers/
│   └── main.yml
├── meta/
│   └── main.yml
├── tasks/
│   └── main.yml
├── templates/
│   ├── agent-config.toml.j2
│   ├── ai-health-monitor-notify.sh.j2
│   ├── ai-health-monitor.service.j2
│   ├── ai-health-monitor.timer.j2
│   ├── ai-health-monitor-run.sh.j2
│   └── logrotate.ai-health-monitor.j2
├── MONITORING.md
└── README.md
```

## Defaults

`roles/system/ai-health-monitor/defaults/main.yml`:

```yaml
---
health_monitor_user: ai-health-monitor
health_monitor_group: ai-health-monitor
health_monitor_home: /home/ai-health-monitor

health_monitor_repo_path: /opt/homelab-automation
health_monitor_report_dir: /var/log/{{ health_monitor_user }}
health_monitor_openrouter_dir: "{{ health_monitor_home }}/.config/openrouter"
health_monitor_openrouter_key_file: "{{ health_monitor_openrouter_dir }}/openrouter-api-key"

health_monitor_schedule: "Fri 12:00:00"
health_monitor_delay_sec: 10min
health_monitor_log_retention: 12

health_monitor_notify_user: sean
health_monitor_notify_uid: 1000

health_monitor_prompt: |
  You are a senior Linux systems engineer performing a scheduled health audit
  for this ansible-managed host: {{ ansible_facts['hostname'] }}. Use the
  $check-homelab-host skill to accomplish this task. Your goal during this task
  is to report on any indicators that may signal degrading health of this
  system, including active failures, recurring warnings, missed maintenance,
  storage pressure, dependency problems, network degradation, stale automation,
  or documentation drift that could hide a real operational issue.

  Work in read-only mode. Do not modify files, restart services, clear failed
  units, prune containers, change snapshots, update packages, apply Ansible, or
  otherwise remediate anything. If a check requires elevated access, use only
  the sudo commands explicitly allowed in the
  /etc/sudoers.d/{{ health_monitor_user }} file. If a useful check is blocked,
  record exactly what was blocked and why rather than trying to broaden access 
  or work around the restriction.

  Pay particular attention to systemd health, failed units, missed timers,
  Ansible pull results, DNF automatic updates, kernel and hardware warnings,
  Btrfs allocation and device error counters, scrub/balance/trim status,
  btrbk and Snapper health, network and DNS behavior, Tailscale state when
  applicable, container health when container roles are present, and user
  graphical services when graphical roles are present.

  Write a concise but complete report to the path in the REPORT_FILE
  environment variable. Lead with actionable findings ordered by severity, then
  summarize healthy areas and checks that were skipped or blocked. Include 
  exact unit names, command evidence, relevant timestamps, and the likely owning
  role for each issue when you can determine it. Do not overstate uncertainty;
  if the evidence is incomplete, say what remains unknown.

  The very last line in the report should be either:
  VERDICT: Healthy
  or
  VERDICT: Attention Required

  Choose 'VERDICT: Attention Required' when the user needs to read the report and take action.
```

`health_monitor_repo_path` is the single source of truth for the repository path. It is used by the wrapper script and the agent project trust config.

## Tasks

`roles/system/ai-health-monitor/meta/main.yml` should declare:

```yaml
---
dependencies:
  - role: ai
```

The `ai-health-monitor` role must not install Codex, Node.js, npm packages, or other AI tools directly. The existing `ai` role owns global AI tool installation.

`roles/system/ai-health-monitor/tasks/main.yml` should:

1. Rely on the `ai` role dependency for globally installed AI tools and on the `ansible_pull` role for logrotate.
2. Create the `ai-health-monitor` group.
3. Create the `ai-health-monitor` user with home `/home/ai-health-monitor` and shell `/bin/bash`.
4. Add `ai-health-monitor` to the `systemd-journal` supplementary group.
5. Create `{{ health_monitor_home }}/.codex/` with mode `0700`.
6. Create `{{ health_monitor_home }}/.config/` with owner `root`, group `{{ health_monitor_group }}`, and mode `0750`.
7. Deploy `templates/agent-config.toml.j2` to `{{ health_monitor_home }}/.codex/config.toml` with mode `0600`.
8. Create `{{ health_monitor_openrouter_dir }}` with owner `root`, group `{{ health_monitor_group }}`, and mode `0750`.
9. Enforce owner `root`, group `{{ health_monitor_group }}`, and mode `0440` on `{{ health_monitor_openrouter_key_file }}` when the manually managed key exists; do not create or overwrite secret contents.
10. Deploy `files/sudoers.ai-health-monitor` to `/etc/sudoers.d/ai-health-monitor` with mode `0440` and `validate: /usr/sbin/visudo -cf %s`.
11. Create `{{ health_monitor_report_dir }}` with owner `{{ health_monitor_user }}` and mode `0755`.
12. Deploy `templates/logrotate.ai-health-monitor.j2` to `/etc/logrotate.d/ai-health-monitor`.
13. Deploy `templates/ai-health-monitor-notify.sh.j2` to `/usr/local/bin/ai-health-monitor-notify` with owner `root`, group `root`, and mode `0555`.
14. Deploy `templates/ai-health-monitor-run.sh.j2` to `/usr/local/bin/ai-health-monitor-run` with mode `0755`.
15. Deploy `templates/ai-health-monitor.service.j2` to `/etc/systemd/system/ai-health-monitor.service` and notify `restart ai-health-monitor timer`.
16. Deploy `templates/ai-health-monitor.timer.j2` to `/etc/systemd/system/ai-health-monitor.timer` and notify `restart ai-health-monitor timer`.
17. Reload systemd daemon with `changed_when: false`.
18. Enable and start `ai-health-monitor.timer`.

## Handlers

`roles/system/ai-health-monitor/handlers/main.yml`:

```yaml
---
- name: restart ai-health-monitor timer
  ansible.builtin.systemd:
    name: ai-health-monitor.timer
    state: restarted
    daemon_reload: true
```

## Agent Config

`roles/system/ai-health-monitor/templates/agent-config.toml.j2`:

```toml
[projects."{{ health_monitor_repo_path }}"]
trust_level = "trusted"

model_provider = "openrouter"
model = "deepseek/deepseek-v4-flash"
model_reasoning_effort = "high"

[model_providers.openrouter]
name = "openrouter"
base_url = "https://openrouter.ai/api/v1"

[model_providers.openrouter.auth]
command = "/usr/bin/cat"
args = ["{{ health_monitor_openrouter_key_file }}"]
```

## Prompt Variable

The prompt lives in `health_monitor_prompt` in `defaults/main.yml`. The wrapper script is templated by Ansible, so any prompt change updates `/usr/local/bin/ai-health-monitor-run` on the next Ansible run and triggers the normal service deployment path.

The wrapper exports `REPORT_FILE` before invoking Codex. Keep the prompt static in Ansible defaults and render it with Jinja's `quote` filter so shell variables such as `$check-homelab-host` are not expanded by the wrapper.

## Sudoers

`roles/system/ai-health-monitor/files/sudoers.ai-health-monitor`:

```sudoers
ai-health-monitor ALL=(root) NOPASSWD: \
    SYSTEMD_PAGER= /usr/bin/systemctl is-system-running, \
    SYSTEMD_PAGER= /usr/bin/systemctl status * --no-pager, \
    SYSTEMD_PAGER= /usr/bin/systemctl show *, \
    SYSTEMD_PAGER= /usr/bin/systemctl list-timers * --all, \
    SYSTEMD_PAGER= /usr/bin/systemctl list-units *, \
    SYSTEMD_PAGER= /usr/bin/systemctl is-enabled *, \
    SYSTEMD_PAGER= /usr/bin/systemctl cat *, \
    /usr/bin/btrfs filesystem usage *, \
    /usr/bin/btrfs device stats *, \
    /usr/bin/btrfs scrub status *, \
    /usr/bin/snapper -c root list, \
    /usr/bin/btrbk -c /etc/btrbk/btrbk.conf list *, \
    /usr/bin/btrbk -c /etc/btrbk/btrbk.conf stats, \
    /usr/bin/btrbk -c /etc/btrbk/btrbk.conf dryrun

ai-health-monitor ALL=(root) NOPASSWD: \
    /usr/local/bin/ai-health-monitor-notify requires-attention *, \
    /usr/local/bin/ai-health-monitor-notify all-good *, \
    /usr/local/bin/ai-health-monitor-notify monitor-failed
```

Notes:

- `SYSTEMD_PAGER=` prevents pager-based root shell escape during interactive debugging.
- `systemctl` is restricted to read-only subcommands. Wildcards remain only where the monitoring workflow needs arbitrary unit names, timer names, or unit-file inspection.
- Commands that do not require sudo should not be added to this sudoers file.
- `btrfs` is restricted to read-only inspection subcommands. Wildcards are used only for mount points or device paths discovered from the host.
- `snapper` is restricted to `-c root list`.
- `btrbk` is restricted to `list`, `stats`, and `dryrun` with the pinned config path. The `list` wildcard is for read-only btrbk list selectors such as `snapshots`.
- Notification delivery is delegated to a root-owned helper with explicit allowed modes, so sudoers does not grant arbitrary command execution as `sean`.
- `visudo -cf` must validate the file before installation.

## Notification Helper

`roles/system/ai-health-monitor/templates/ai-health-monitor-notify.sh.j2`:

```bash
#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "this script must be run as root" >&2
    exit 1
fi

mode=${1:-}
report_file=${2:-}
dbus_socket=/run/user/{{ health_monitor_notify_uid }}/bus

if [ ! -S "$dbus_socket" ]; then
    exit 0
fi

case "$mode" in
    requires-attention)
        urgency=critical
        title="Host Health: Requires Your Attention"
        body="Review the report at $report_file"
        ;;
    all-good)
        urgency=normal
        title="Host Health: All Good"
        body="Full report at $report_file"
        ;;
    monitor-failed)
        urgency=critical
        title="Host Health: Monitoring System Failure"
        body="The health check script failed or returned an unknown verdict. Check systemd logs."
        ;;
    *)
        echo "usage: ai-health-monitor-notify {requires-attention|all-good|monitor-failed} [report-file]" >&2
        exit 2
        ;;
esac

if [ "$mode" != "monitor-failed" ]; then
    case "$report_file" in
        {{ health_monitor_report_dir }}/*.md) ;;
        *)
            echo "invalid report path: $report_file" >&2
            exit 2
            ;;
    esac
fi

export DBUS_SESSION_BUS_ADDRESS="unix:path=${dbus_socket}"

runuser -u {{ health_monitor_notify_user }} -- \
    notify-send \
        --urgency="$urgency" \
        --app-name="ai-health-monitor" \
        "$title" \
        "$body"
```

Helper behavior:

- Accepts only `requires-attention`, `all-good`, or `monitor-failed`.
- Validates report paths for report-based notifications.
- Sends no notification if `{{ health_monitor_notify_user }}` has no active D-Bus session.
- Uses `runuser` internally as root so the main wrapper never gets arbitrary command execution as `{{ health_monitor_notify_user }}`.

## Wrapper Script

`roles/system/ai-health-monitor/templates/ai-health-monitor-run.sh.j2`:

```bash
#!/bin/bash
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE={{ health_monitor_report_dir }}/health-report-$TIMESTAMP.md
export REPORT_FILE

cd {{ health_monitor_repo_path }}

AGENT_STATUS=0
HOME={{ health_monitor_home }} \
codex exec \
    --dangerously-bypass-approvals-and-sandbox \
    -C {{ health_monitor_repo_path }} \
    {{ health_monitor_prompt | quote }} \
    -o "$REPORT_FILE" || AGENT_STATUS=$?

if [ "$AGENT_STATUS" -ne 0 ]; then
    VERDICT=unknown
else
    VERDICT=$(grep -Ei '^VERDICT: (Healthy|Attention Required)$' "$REPORT_FILE" | tail -1 | sed -E 's/^VERDICT: //I' | tr '[:upper:]' '[:lower:]' || echo "unknown")
fi

if [ "$VERDICT" = "attention required" ]; then
    sudo /usr/local/bin/ai-health-monitor-notify requires-attention "$REPORT_FILE"
elif [ "$VERDICT" = "healthy" ]; then
    sudo /usr/local/bin/ai-health-monitor-notify all-good "$REPORT_FILE"
else
    sudo /usr/local/bin/ai-health-monitor-notify monitor-failed
fi
```

Script behavior:

- Does not create `/var/log/ai-health-monitor`; the role creates it.
- Embeds the Ansible-managed `health_monitor_prompt` default into the wrapper script.
- Exports `REPORT_FILE` so the prompt can refer to the runtime report path without shell prompt manipulation.
- Writes Codex's final response directly to `REPORT_FILE` with `codex exec -o`.
- Parses the final verdict from `REPORT_FILE`; no separate summary file is created.
- Uses `--dangerously-bypass-approvals-and-sandbox` so Codex can inspect the real host without its internal sandbox blocking health checks.
- Treats agent failure or unknown verdict as critical.
- Delegates notification delivery to `/usr/local/bin/ai-health-monitor-notify`.

## Systemd Service

`roles/system/ai-health-monitor/templates/ai-health-monitor.service.j2`:

```ini
[Unit]
Description=Weekly automated ai host health check
Documentation={{ homelab_ansible_repo_url }}
After=network-online.target
After=dns-online.service
After=ansible-pull.service
After=dnf5-automatic.service
After=btrbk.service
After=btrfs-scrub.service
After=btrfs-balance.service
After=btrfs-trim.service
After=plocate-updatedb.service
Wants=network-online.target
Wants=dns-online.service

[Service]
Type=oneshot
User={{ health_monitor_user }}
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ProtectSystem=strict
InaccessiblePaths=/home/sean
ReadOnlyPaths={{ health_monitor_openrouter_dir }}
ReadWritePaths={{ health_monitor_report_dir }} {{ health_monitor_home }}/.codex
ExecStart=/usr/local/bin/ai-health-monitor-run
```

Notes:

- No `NoNewPrivileges=true`; it breaks `sudo`.
- Explicit `PATH` avoids systemd environment differences.
- The `After=` entries order the health check behind top-level repo-managed maintenance services when persistent timers catch up after sleep or boot. `dnf-makecache.service` is intentionally not listed because `ansible-pull.service` and `dnf5-automatic.service` already order themselves after it.
- Do not add `Wants=` for maintenance services; the health monitor should not force-run updates, snapshots, scrubs, balances, trims, or locate indexing.
- Security boundary is the `ai-health-monitor` user, the sudoers whitelist, and systemd filesystem restrictions.
- `ProtectSystem=strict` makes the host filesystem read-only to the service except for explicit `ReadWritePaths`.
- `InaccessiblePaths=/home/sean` prevents the service from reading `sean`'s home directory, including SSH keys and user secrets.
- `ReadOnlyPaths={{ health_monitor_openrouter_dir }}` keeps the OpenRouter API key directory read-only inside the service mount namespace.
- `ReadWritePaths={{ health_monitor_report_dir }} {{ health_monitor_home }}/.codex` allows report output and Codex service-user state without making the whole service home writable.
- The role makes `{{ health_monitor_home }}/.config` and `{{ health_monitor_openrouter_dir }}` root-owned so `ai-health-monitor` can read the API key but cannot replace the containing directory.

## Systemd Timer

`roles/system/ai-health-monitor/templates/ai-health-monitor.timer.j2`:

```ini
[Unit]
Description=Weekly host health check schedule
Documentation={{ homelab_ansible_repo_url }}

[Timer]
OnCalendar={{ health_monitor_schedule }}
Persistent=true
RandomizedDelaySec={{ health_monitor_delay_sec }}

[Install]
WantedBy=timers.target
```

## Logrotate

`roles/system/ai-health-monitor/templates/logrotate.ai-health-monitor.j2`:

```text
{{ health_monitor_report_dir }}/*.md {
    su {{ health_monitor_user }} {{ health_monitor_group }}
    rotate {{ health_monitor_log_retention }}
    maxage 90
    missingok
    notifempty
    nocompress
    nocreate
}
```

## Playbook Integration

Add the role only to `desktop25.yml` at first, immediately after the existing `ai` role:

```yaml
    - role: ai-health-monitor
```

## Manual Setup

After the first role run, place the OpenRouter API key at:

```text
/home/ai-health-monitor/.config/openrouter/openrouter-api-key
```

Required ownership and mode:

```text
owner: root
group: ai-health-monitor
mode: 0440
```

No other manual setup is required.

## Test Plan

1. Verify `ai-health-monitor` exists, has `/home/ai-health-monitor`, uses `/bin/bash`, and belongs to `systemd-journal`.
2. Verify `/etc/sudoers.d/ai-health-monitor` passes `visudo -cf`.
3. Verify allowed sudo commands work without a password: `systemctl is-system-running`, `btrfs device stats /`, `snapper -c root list`.
4. Verify denied sudo commands fail: `systemctl start sshd.service`, `btrfs filesystem balance /`, `btrbk run`.
5. Verify sudo wildcard coverage is read-only and scoped: documented `systemctl status <unit> --no-pager`, `systemctl list-timers <timer> --all`, Btrfs mount checks, and btrbk list selectors work, while mutating systemctl, btrfs, and btrbk commands fail.
6. Verify `/usr/local/bin/ai-health-monitor-run` includes the current `health_monitor_prompt` content, exports `REPORT_FILE`, writes Codex output to `REPORT_FILE`, and parses only case-insensitive `VERDICT: Healthy` or `VERDICT: Attention Required` from the report.
7. Verify `ai-health-monitor` can read `/home/ai-health-monitor/.config/openrouter/openrouter-api-key` but cannot write it, and verify the service sees `{{ health_monitor_openrouter_dir }}` as read-only.
8. Verify the service cannot access `/home/sean`.
9. Verify the service can write reports under `{{ health_monitor_report_dir }}`.
10. Run `/usr/local/bin/ai-health-monitor-run` as `ai-health-monitor` and confirm a report appears in `/var/log/ai-health-monitor/`.
11. Verify `/usr/local/bin/ai-health-monitor-notify` accepts only supported modes and rejects report paths outside `{{ health_monitor_report_dir }}`.
12. Confirm unknown verdict or agent failure sends a critical notification when `sean` has an active D-Bus session.
13. Enable and start `ai-health-monitor.timer`, then confirm it appears in `systemctl list-timers`.

## Issues to Resolve

 ### High Severity

- [x] ai-health-monitor.md:181: The wrapper runs codex exec --dangerously-bypass-approvals-and-sandbox. That makes “read-only” purely prompt-based, not enforced. The agent would have unsandboxed shell access as ai-health-monitor plus whitelisted sudo. A safer design should keep Codex sandboxed/read-only and have the wrapper write the final report itself via -o, instead of asking the model to write files.
- [x] ai-health-monitor.md:110: The new ai-health-monitor user is not guaranteed to have the $check-homelab-host skill installed or visible. The skill exists in this session, but the service user’s Codex environment will be separate. The role needs to install/copy/register that skill for the service user, or avoid relying on skill discovery and embed explicit instructions.
- [x] ai-health-monitor/ai-health-monitor.md:151: Notification sudo is likely wrong. The wrapper runs sudo -u sean DBUS_SESSION_BUS_ADDRESS=... /usr/bin/dunstify, but sudoers only allows /usr/bin/dunstify *; it does not allow setting DBUS_SESSION_BUS_ADDRESS. Existing repo scripts use runuser -u {{ user }} -- notify-send after exporting the D-Bus address. The plan should reuse that pattern and probably use notify-send, not dunstify.
- [x] ai-health-monitor.md:287: “Add to each managed host playbook after core and ansible_pull” conflicts with desktop22.yml, where docker is currently before ansible_pull. Also, placing this before ai/nodejs means the role must be fully self-contained. If it depends on the existing ai role, the ordering must say so.
- [x] Address TODO in timer about dependency. See how this is addressed in other roles and copy the pattern here.

### Medium Severity

- [x] ai-health-monitor.md:84: agent-config.toml is static while defaults claim health_monitor_repo_path is the source of truth. This should be a template, otherwise changing health_monitor_repo_path or health_monitor_home silently breaks Codex trust and API-key lookup.
- [x] ai-health-monitor.md:64: “Install the agent CLI globally via npm” is underspecified. Existing role uses community.general.npm with @openai/codex; the plan should name that package/module explicitly.
- [x] ai-health-monitor.md:192: Verdict parsing only matches **verdict:** .... If Codex emits plain verdict: as the prompt says “exactly one line” but includes Markdown formatting in examples, this is brittle. Pick one exact format and parse only that.
- [x] ai-health-monitor.md:173: The report file is created by the agent, not the wrapper. If Codex fails before writing it, the notification points at a missing report. Prefer codex exec -o "$REPORT_FILE" or write a failure report in the wrapper.
- [x] ai-health-monitor.md:135: The sudo allowlist may not match likely commands from the monitoring skill. The skill emphasizes journals, timers, failed units, RPM health, /sys, storage, etc. Some are unprivileged, but privileged journalctl access may still be needed beyond systemd- journal group. The test plan should include real skill-run command coverage, not just three sample sudo commands.

### Low Severity / Cleanup

- [x] ai-health-monitor.md:20: handlers/main.yml is listed but no handlers are specified. Either define restart/reload handlers for timer changes or remove it.
- [x] ai-health-monitor.md:49: Project convention says avoid quotes unless required. health_monitor_schedule: "Fri 12:00:00" does need quotes because of the colon, so this one is fine, but the plan should preserve that reasoning during implementation.
- [x] ai-health-monitor.md:320: The file ends with an unmatched closing code fence. Remove the trailing ```.
