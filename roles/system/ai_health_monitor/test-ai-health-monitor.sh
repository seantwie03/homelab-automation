#!/bin/bash
set -u

expected_user=ai-health-monitor
expected_home=/home/ai-health-monitor
report_dir=/var/log/ai-health-monitor
openrouter_dir=$expected_home/.config/openrouter
openrouter_key=$openrouter_dir/openrouter-api-key
codex_config=$expected_home/.codex/config.toml
run_script=/usr/local/bin/ai-health-monitor-run
notify_script=/usr/local/bin/ai-health-monitor-notify
service_name=ai-health-monitor.service
timer_name=ai-health-monitor.timer

pass_count=0
fail_count=0

pass() {
    pass_count=$((pass_count + 1))
    printf 'PASS: %s\n' "$1"
}

fail() {
    fail_count=$((fail_count + 1))
    printf 'FAIL: %s\n' "$1"
}

check() {
    description=$1
    shift

    if "$@" >/dev/null 2>&1; then
        pass "$description"
    else
        fail "$description"
    fi
}

contains() {
    value=$1
    expected=$2

    case "$value" in
        *"$expected"*) return 0 ;;
        *) return 1 ;;
    esac
}

systemd_value() {
    unit=$1
    property=$2

    systemctl show "$unit" --property="$property" --value 2>/dev/null
}

check_path_contains() {
    description=$1
    unit=$2
    property=$3
    expected=$4

    value=$(systemd_value "$unit" "$property")
    if contains "$value" "$expected"; then
        pass "$description"
    else
        fail "$description (got: ${value:-<empty>})"
    fi
}

check_equals() {
    description=$1
    actual=$2
    expected=$3

    if [ "$actual" = "$expected" ]; then
        pass "$description"
    else
        fail "$description (got: ${actual:-<empty>}, expected: $expected)"
    fi
}

check_not_writable() {
    description=$1
    path=$2

    if [ -e "$path" ] && [ ! -w "$path" ]; then
        pass "$description"
    else
        fail "$description"
    fi
}

check_readable_not_writable() {
    description=$1
    path=$2

    if [ -e "$path" ] && [ -r "$path" ] && [ ! -w "$path" ]; then
        pass "$description"
    else
        fail "$description"
    fi
}

check_report_output() {
    latest_before=$1
    latest_after=
    codex_log=

    latest_after=$(ls -t "$report_dir"/health-report-*.md 2>/dev/null | head -1 || true)

    if [ -n "$latest_after" ] && [ "$latest_after" != "$latest_before" ]; then
        pass "$2 creates a new report"
    else
        fail "$2 creates a new report"
        return
    fi

    if grep -Eiq '^VERDICT: (Healthy|Attention Required)$' "$latest_after"; then
        pass "new report contains a valid verdict"
    else
        fail "new report contains a valid verdict"
    fi

    if [ "$(wc -l < "$latest_after")" -gt 20 ]; then
        pass "new report contains full markdown content"
    else
        fail "new report contains full markdown content"
    fi

    codex_log=${latest_after%.md}.codex.log
    if [ -s "$codex_log" ]; then
        pass "codex execution transcript is written separately"
    else
        fail "codex execution transcript is written separately"
    fi
}

check_direct_run() {
    latest_before=

    latest_before=$(ls -t "$report_dir"/health-report-*.md 2>/dev/null | head -1 || true)

    if "$run_script"; then
        pass "direct health monitor run exits successfully"
    else
        fail "direct health monitor run exits successfully"
        return
    fi

    check_report_output "$latest_before" "direct health monitor run"
}

check_service_run() {
    latest_before=

    if [ "$(id -u)" -ne 0 ]; then
        fail "service run test is running as root"
        return
    else
        pass "service run test is running as root"
    fi

    latest_before=$(ls -t "$report_dir"/health-report-*.md 2>/dev/null | head -1 || true)

    if systemctl start "$service_name" >/dev/null 2>&1; then
        pass "systemd service run exits successfully"
    else
        fail "systemd service run exits successfully"
        return
    fi

    check_equals "service result is success" "$(systemd_value "$service_name" Result)" success
    check_equals "service main exit status is 0" "$(systemd_value "$service_name" ExecMainStatus)" 0

    check_report_output "$latest_before" "systemd service run"
}

case "${1:-}" in
    "")
        run_mode=check
        ;;
    --full-run)
        run_mode=direct
        ;;
    --service-run)
        run_mode=service
        ;;
    -h|--help)
        cat <<EOF
usage: $0 [--full-run|--service-run]

Run default mode and --full-run as the ai-health-monitor user after applying the
role. Run --service-run as root.

Default mode validates installed files, permissions, sudo access, and systemd
configuration without calling the model.

--full-run executes /usr/local/bin/ai-health-monitor-run directly. This calls
Codex and validates report creation, but it does not exercise the systemd
service sandbox.

--service-run starts ai-health-monitor.service with systemd. This calls Codex
through the deployed service and exercises ProtectSystem, InaccessiblePaths,
ReadOnlyPaths, ReadWritePaths, User, and the service environment.
EOF
        exit 0
        ;;
    *)
        printf 'usage: %s [--full-run|--service-run]\n' "$0" >&2
        exit 2
        ;;
esac

printf 'ai-health-monitor validation\n'
printf '============================\n'

if [ "$run_mode" = service ]; then
    check_equals "script is running as root for service execution" "$(id -u)" 0
else
    check_equals "script is running as $expected_user" "$(id -un)" "$expected_user"
fi
check_equals "passwd home is $expected_home" "$(getent passwd "$expected_user" | cut -d: -f6)" "$expected_home"

check "run script exists and is executable" test -x "$run_script"
check "notify script exists and is executable" test -x "$notify_script"
check "codex executable is available" command -v codex
check "run script sets CODEX_HOME to the service user's Codex config" \
    grep -Fq "CODEX_HOME=$expected_home/.codex" "$run_script"
check "run script prompt tells Codex to use non-interactive sudo only" \
    grep -Fq "Never run interactive sudo" "$run_script"
check "run script prompt tells Codex to review sudoers before sudo" \
    grep -Fq "Before running any sudo command" "$run_script"
check "run script prompt includes allowed sudo commands" \
    grep -Fq "Allowed sudo commands" "$run_script"

check "report directory exists" test -d "$report_dir"
check "report directory is writable by $expected_user" test -w "$report_dir"
check "codex config exists and is readable" test -r "$codex_config"
check "codex config references openrouter key file" grep -Fq "$openrouter_key" "$codex_config"
check "codex config declares openrouter before project tables" \
    awk '
        /^\[projects\./ { seen_project = 1 }
        /^model_provider = "openrouter"$/ && !seen_project { found = 1 }
        END { exit found ? 0 : 1 }
    ' "$codex_config"

check "openrouter directory exists" test -d "$openrouter_dir"
check "openrouter directory is searchable" test -x "$openrouter_dir"
check_readable_not_writable "openrouter key exists, is readable, and is not writable" "$openrouter_key"
check "openrouter key is not empty" test -s "$openrouter_key"
check_not_writable "openrouter directory is not writable by $expected_user" "$openrouter_dir"
check_not_writable "/home/sean is not writable by $expected_user" /home/sean

check "timer is enabled" systemctl is-enabled --quiet "$timer_name"
check "timer is active" systemctl is-active --quiet "$timer_name"
check "service unit is visible to systemd" systemctl cat "$service_name"
check "timer unit is visible to systemd" systemctl cat "$timer_name"

check_equals "service runs as $expected_user" "$(systemd_value "$service_name" User)" "$expected_user"
check_equals "service has ProtectSystem=strict" "$(systemd_value "$service_name" ProtectSystem)" strict
check_path_contains "service makes /home/sean inaccessible" "$service_name" InaccessiblePaths /home/sean
check_path_contains "service makes openrouter config read-only" "$service_name" ReadOnlyPaths "$openrouter_dir"
check_path_contains "service can write reports" "$service_name" ReadWritePaths "$report_dir"
check_path_contains "service can write Codex state" "$service_name" ReadWritePaths "$expected_home/.codex"
check_path_contains "service orders after dns-online.service" "$service_name" After dns-online.service
check_path_contains "service wants dns-online.service" "$service_name" Wants dns-online.service

check "sudo allows systemctl health inspection without a password" \
    sudo -n /usr/bin/systemctl --no-pager cat "$service_name"

if sudo -n /usr/bin/id >/dev/null 2>&1; then
    fail "sudo does not allow arbitrary /usr/bin/id"
else
    pass "sudo does not allow arbitrary /usr/bin/id"
fi

if [ "$run_mode" = direct ]; then
    printf '\nRunning direct wrapper test. This does not exercise the systemd sandbox.\n'
    check_direct_run
elif [ "$run_mode" = service ]; then
    printf '\nRunning systemd service test. This exercises the deployed service hardening.\n'
    check_service_run
else
    printf '\nSkipping monitor execution. Re-run with --full-run for a direct wrapper test or --service-run as root for the hardened systemd service test.\n'
fi

printf '\nSummary: %s passed, %s failed\n' "$pass_count" "$fail_count"

if [ "$fail_count" -eq 0 ]; then
    printf 'RESULT: PASS\n'
    exit 0
else
    printf 'RESULT: FAIL\n'
    exit 1
fi
