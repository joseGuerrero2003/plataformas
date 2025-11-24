#!/bin/bash
set -euo pipefail

# Ensure directories and permissions
mkdir -p /var/log/kea /var/run/kea /var/lib/kea || true
chown -R _kea:_kea /var/log/kea /var/run/kea /var/lib/kea 2>/dev/null || true

echo "Arrancando Kea DHCP (4 y opcionalmente 6)"
exec /opt/plataformas/scripts/start_kea.sh
