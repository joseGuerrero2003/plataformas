#!/bin/bash
set -euo pipefail

mkdir -p /var/lib/chrony /var/log/chrony || true
chown -R chrony:chrony /var/lib/chrony /var/log/chrony 2>/dev/null || true

echo "Starting chronyd in foreground for debugging"
chronyd -d &>/var/log/chrony/chronyd-debug.log &

tail -f /var/log/chrony/chronyd-debug.log
