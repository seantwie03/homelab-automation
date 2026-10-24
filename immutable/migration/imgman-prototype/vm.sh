#!/usr/bin/env bash
# Runs a command as root in the prototype VM over vsock SSH.
R=~/.cache/homelab-images/prototype/run
exec ssh -i "$R/id_ed25519" -o BatchMode=yes -o ConnectTimeout=5 -o LogLevel=ERROR \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "vsock/$(cat "$R/cid")" "$@"
