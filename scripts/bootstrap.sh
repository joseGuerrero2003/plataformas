#!/bin/bash
set -euo pipefail
# bootstrap.sh <ipv6_address> <hostname>
ADDR="${1:-}"   # e.g. fd00:100:100::a
HOSTNAME="${2:-$(hostname -f)}"

echo "[bootstrap] Setting hostname to $HOSTNAME and adding IPv6 address $ADDR"

if [ -n "$HOSTNAME" ]; then
  hostnamectl set-hostname "$HOSTNAME" || true
fi

# Add host entry for local name
if ! grep -q "$HOSTNAME" /etc/hosts 2>/dev/null; then
  echo "127.0.0.1 $HOSTNAME" >> /etc/hosts || true
fi

# Try to find primary interface (non-loopback)
IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(en|eth|ens|enp)' | head -n1 || true)
if [ -z "$IFACE" ]; then
  IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n1 || true)
fi

if [ -n "$ADDR" ] && [ -n "$IFACE" ]; then
  echo "[bootstrap] Adding IPv6 address $ADDR/64 to $IFACE"
  ip -6 addr add "$ADDR/64" dev "$IFACE" || true
else
  echo "[bootstrap] Could not determine interface or address; skipping IPv6 addition"
fi

exit 0
