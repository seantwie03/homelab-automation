#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "this script must be run as root" >&2
    exit 1
fi

CONF=/etc/systemd/resolved.conf.d/nextdns.conf
BACKUP=/tmp/nextdns.conf.bak

if [ -f "${CONF}" ]; then
    mv "${CONF}" "${BACKUP}"
    systemctl restart systemd-resolved
    echo "DNS-over-TLS disabled. Run again to restore."
elif [ -f "${BACKUP}" ]; then
    mv "${BACKUP}" "${CONF}"
    systemctl restart systemd-resolved
    echo "DNS-over-TLS restored."
else
    echo "neither ${CONF} nor ${BACKUP} found — nothing to do" >&2
    exit 1
fi
