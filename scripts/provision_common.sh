#!/bin/bash
set -euo pipefail

# Common provisioning steps used by all VMs
echo "[common] Starting common provisioning"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends curl gnupg lsb-release ca-certificates software-properties-common

# Enable IP forwarding and common kernel tweaks useful for lab
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1
cat > /etc/sysctl.d/99-lab.conf <<'EOF'
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF
sysctl --system

echo "[common] Locale and timezone defaults"
timedatectl set-timezone UTC || true

echo "[common] User and tooling"
apt-get install -y --no-install-recommends vim less jq unzip

echo "[common] Done"

exit 0
