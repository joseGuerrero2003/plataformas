#!/bin/bash
set -euo pipefail

echo "[check] Listing DHCP leases from Kea (if available) and client IPs"
echo "-- Kea leases (if /var/lib/kea exists) --"
if [ -f /var/lib/kea/dhcp4.leases ]; then
  tail -n 50 /var/lib/kea/dhcp4.leases || true
else
  echo "No Kea lease file found on this host. Run this on the DHCP VM or inspect /var/lib/kea there."
fi

echo "-- Client IPs (from this host) --"
vagrant ssh client1 -c "ip -4 -o addr show; ip -6 -o addr show" || true
vagrant ssh client2 -c "ip -4 -o addr show; ip -6 -o addr show" || true

echo "[check] Done"
