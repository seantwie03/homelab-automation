#!/usr/bin/env bash
# Stages OS updates in the background without rebooting. bootc's update timer
# downloads a newer image and stages it, and the host boots into it at the
# next reboot someone does. The stock service applies the update and reboots
# at once, so a drop-in replaces its command.
set -euo pipefail

dropin=/usr/lib/systemd/system/bootc-fetch-apply-updates.service.d
mkdir -p "$dropin"
cat >"$dropin/50-stage-only.conf" <<'CONF'
[Unit]
Description=Stage bootc updates

[Service]
ExecStart=
ExecStart=/usr/bin/bootc upgrade --quiet
CONF
systemctl enable bootc-fetch-apply-updates.timer
