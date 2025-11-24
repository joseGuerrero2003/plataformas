#!/bin/bash
set -euo pipefail

echo "[client] Provisioning client for DHCP (IPv4 + IPv6)"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends systemd-networkd ifupdown isc-dhcp-client net-tools iproute2 mailutils mutt

echo "[client] Writing systemd-networkd .network files to enable DHCP for typical interface names"
mkdir -p /etc/systemd/network

cat > /etc/systemd/network/10-dhcp-en.network <<'EOF'
[Match]
Name=en*

[Network]
DHCP=both
IPv6AcceptRA=yes
EOF

cat > /etc/systemd/network/10-dhcp-eth.network <<'EOF'
[Match]
Name=eth*

[Network]
DHCP=both
IPv6AcceptRA=yes
EOF

cat > /etc/systemd/network/10-dhcp-ens.network <<'EOF'
[Match]
Name=ens*

[Network]
DHCP=both
IPv6AcceptRA=yes
EOF

echo "[client] Enable and restart systemd-networkd"
systemctl enable systemd-networkd --now || true

echo "[client] Restarting network interfaces to pick up DHCP"
sleep 2
for iface in $(ls /sys/class/net | grep -E '^(en|eth|ens)'); do
  ip link set dev "$iface" down || true
  ip link set dev "$iface" up || true
done

echo "[client] Waiting for DHCP leases"
sleep 5
ip -4 addr show || true
ip -6 addr show || true

echo "[client] Done"

exit 0
