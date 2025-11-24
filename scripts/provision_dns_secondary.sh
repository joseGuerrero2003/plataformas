#!/bin/bash
set -euo pipefail

echo "[dns-secondary] Installing BIND9"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends bind9 bind9utils dnsutils

echo "[dns-secondary] Deploying configuration files"
mkdir -p /etc/bind/zones/slaves
install -m 644 /vagrant/dns-secondary/named.conf.options /etc/bind/named.conf.options
install -m 644 /vagrant/dns-secondary/named.conf.local /etc/bind/named.conf.local
install -m 644 /vagrant/dns-primary/tsig.key /etc/bind/tsig.key
chown -R bind:bind /etc/bind/zones

# Ensure bind writable dirs exist and correct ownership
mkdir -p /var/cache/bind /var/lib/bind /var/run/named || true
chown -R bind:bind /var/cache/bind /var/lib/bind /var/run/named || true
chown -R bind:bind /etc/bind || true

echo "[dns-secondary] Starting BIND"
systemctl enable --now bind9 || service bind9 restart || true

# If systemd is not available (containers), start named in background for debugging
if ! pidof systemd >/dev/null 2>&1; then
	echo "[dns-secondary] systemd not detected; starting named manually in background"
	cd /var/cache/bind || true
	sudo -u bind named -c /etc/bind/named.conf.local &>/var/log/named-manual-secondary.log &
fi

# Ensure wrapper is executable
chmod +x /vagrant/scripts/start_named.sh || true

echo "[dns-secondary] Triggering initial zone transfer"
sleep 2
rndc reload || true

echo "[dns-secondary] Done"

exit 0
