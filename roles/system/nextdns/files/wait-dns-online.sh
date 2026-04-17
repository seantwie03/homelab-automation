#!/bin/bash
# Waits for systemd-resolved DoT to be ready after wake/boot.
# Run as a systemd oneshot before services that require DNS.

HOST="dns.nextdns.io"
MAX_ATTEMPTS=30
SLEEP_INTERVAL=2

echo "Testing DNS resolution of ${HOST}..."

for i in $(seq 1 ${MAX_ATTEMPTS}); do
    if systemd-resolve "${HOST}" >/dev/null 2>&1; then
        echo "DNS is online (attempt ${i}/${MAX_ATTEMPTS})"
        exit 0
    fi
    echo "Attempt ${i}/${MAX_ATTEMPTS}: DNS not ready, retrying in ${SLEEP_INTERVAL}s..."
    sleep "${SLEEP_INTERVAL}"
done

echo "DNS did not come online after ${MAX_ATTEMPTS} attempts ($(( MAX_ATTEMPTS * SLEEP_INTERVAL ))s)" >&2
exit 1
