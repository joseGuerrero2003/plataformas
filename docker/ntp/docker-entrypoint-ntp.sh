#!/bin/bash
set -euo pipefail

echo "Iniciando Chrony"
mkdir -p /var/log/chrony || true
touch /var/log/chrony/chronyd-debug.log || true
chown -R chrony:chrony /var/log/chrony 2>/dev/null || true

exec /opt/plataformas/scripts/start_chrony.sh
