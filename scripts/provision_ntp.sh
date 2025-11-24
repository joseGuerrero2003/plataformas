#!/bin/bash
set -euo pipefail

echo "[ntp] Installing chrony"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends chrony

echo "[ntp] Deploying chrony configuration"
install -m 644 /vagrant/ntp/chrony.conf /etc/chrony/chrony.conf

systemctl enable --now chrony || service chrony restart || true

# Ensure chrony runtime dirs and fallback start for containers without systemd
mkdir -p /var/lib/chrony /var/log/chrony || true
chown -R chrony:chrony /var/lib/chrony /var/log/chrony 2>/dev/null || true
if ! pidof systemd >/dev/null 2>&1; then
	echo "[ntp] systemd not detected; starting chronyd in background"
	chronyd -d &>/var/log/chrony/chronyd-debug.log &
fi

# Ensure start wrapper is executable
chmod +x /vagrant/scripts/start_chrony.sh || true

echo "[ntp] Done"

exit 0
