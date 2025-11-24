#!/bin/bash
set -euo pipefail

# Wrapper to start named from a writable working directory as user 'bind'
mkdir -p /var/cache/bind
chown -R bind:bind /var/cache/bind || true
mkdir -p /run/named || true
chown -R bind:bind /run/named || true
cd /var/cache/bind || exit 1

echo "Starting named (foreground, user=bind)"
exec sudo -u bind named -g -c /etc/bind/named.conf.local
