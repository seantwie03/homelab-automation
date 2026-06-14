#!/bin/bash
# This script lists all roles that will be executed when a playbook is ran, including dependent roles.

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "usage: $0 PLAYBOOK.yml" >&2
    exit 2
fi

ansible-playbook -i localhost, "$1" --list-tasks |
    sed -nE 's/^[[:space:]]+([[:alnum:]_.-]+)[[:space:]]+:[[:space:]].*/\1/p' |
    sort -u
