#!/bin/bash
set -euo pipefail

echo "[dns-primary] Installing BIND9 and tools"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends bind9 bind9utils bind9-doc dnsutils

echo "[dns-primary] Deploying configuration files"
mkdir -p /etc/bind/zones
install -m 644 /vagrant/dns-primary/named.conf.options /etc/bind/named.conf.options
install -m 644 /vagrant/dns-primary/named.conf.local /etc/bind/named.conf.local
install -m 644 /vagrant/dns-primary/db.lab.local /etc/bind/zones/db.lab.local
install -m 644 /vagrant/dns-primary/tsig.key /etc/bind/tsig.key
chown -R bind:bind /etc/bind/zones

echo "[dns-primary] Ensure include of tsig key is readable"
chmod 640 /etc/bind/tsig.key || true

# Ensure bind-owned writable directories exist (used for caches, journals, runtime files)
mkdir -p /var/cache/bind /var/lib/bind /var/run/named || true
chown -R bind:bind /var/cache/bind /var/lib/bind /var/run/named || true
chown -R bind:bind /etc/bind || true

echo "[dns-primary] Creating forwarders and enabling service"
systemctl enable --now bind9 || service bind9 restart || true

echo "[dns-primary] Generating DNSSEC signed zone (this may take a moment)"
/vagrant/dns-primary/generate-dnssec.sh || true

# Ensure start wrapper is executable (for container fallback)
chmod +x /vagrant/scripts/start_named.sh || true

echo "[dns-primary] Done"

exit 0
