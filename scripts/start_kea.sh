#!/bin/bash
set -euo pipefail

mkdir -p /var/log/kea /var/run/kea /var/lib/kea
chown -R _kea:_kea /var/log/kea /var/run/kea /var/lib/kea 2>/dev/null || true

echo "Starting kea-dhcp4 and kea-dhcp6 in foreground for debugging"
if command -v kea-dhcp4 >/dev/null 2>&1; then
    kea-dhcp4 -c /etc/kea/kea-dhcp4.conf &>/var/log/kea/kea-dhcp4.log &
fi
if command -v kea-dhcp6 >/dev/null 2>&1; then
    kea-dhcp6 -c /etc/kea/kea-dhcp6.conf &>/var/log/kea/kea-dhcp6.log &
fi

tail -f /var/log/kea/*.log
