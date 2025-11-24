#!/bin/bash
set -euo pipefail
set -x

echo "[dhcp] Installing Kea DHCP (dhcp4 + dhcp6)"
export DEBIAN_FRONTEND=noninteractive

# Actualizar repositorios
apt-get update

# Instalar dependencias básicas
apt-get install -y --no-install-recommends isc-dhcp-client curl

# Instalar Kea DHCP si no está presente
if ! dpkg -l | grep -q kea-dhcp4-server; then
    apt-get install -y --no-install-recommends kea-dhcp4-server kea-dhcp6-server
fi

echo "[dhcp] Configuring DHCP Server (Kea)"

# Directorio de configuración de Kea
KEA_CONF_DIR="/etc/kea"

# Servidores DNS
PRIMARY_DNS_IPV4="192.168.100.10"
PRIMARY_DNS_IPV6="fd00:100:100::a"
SECONDARY_DNS_IPV4="192.168.100.11"
SECONDARY_DNS_IPV6="fd00:100:100::b"

echo "Primary DNS IPv4: $PRIMARY_DNS_IPV4"
echo "Primary DNS IPv6: $PRIMARY_DNS_IPV6"
echo "Secondary DNS IPv4: $SECONDARY_DNS_IPV4"
echo "Secondary DNS IPv6: $SECONDARY_DNS_IPV6"

# Copiar archivos de configuración de Kea
echo "[dhcp] Deploying configuration files"
install -m 644 /vagrant/dhcp/kea-dhcp4.conf $KEA_CONF_DIR/kea-dhcp4.conf || cp /vagrant/dhcp/kea-dhcp4.conf $KEA_CONF_DIR/kea-dhcp4.conf
install -m 644 /vagrant/dhcp/kea-dhcp6.conf $KEA_CONF_DIR/kea-dhcp6.conf || cp /vagrant/dhcp/kea-dhcp6.conf $KEA_CONF_DIR/kea-dhcp6.conf

# Ensure Kea config files are owned by the Kea runtime user
if id -u _kea >/dev/null 2>&1; then
    chown -R _kea:_kea $KEA_CONF_DIR || true
else
    # Older/newer packages might use user 'kea' instead of '_kea'
    chown -R kea:kea $KEA_CONF_DIR 2>/dev/null || true
fi

# Crear directorio de leases y permisos
mkdir -p /var/lib/kea
chown -R _kea:_kea /var/lib/kea 2>/dev/null || true

# Asegurar directorios de runtime y logs para Kea
mkdir -p /var/log/kea /var/run/kea || true
chown -R _kea:_kea /var/log/kea /var/run/kea 2>/dev/null || true

# Reiniciar y habilitar servicios Kea
echo "[dhcp] Starting Kea services"
systemctl enable --now kea-dhcp4-server || service kea-dhcp4-server restart || true
systemctl enable --now kea-dhcp6-server || service kea-dhcp6-server restart || true

# If systemd is not available, start Kea daemons manually for debugging
if ! pidof systemd >/dev/null 2>&1; then
    echo "[dhcp] systemd not detected; starting kea daemons manually"
    # start kea-dhcp4
    if command -v kea-dhcp4 >/dev/null 2>&1; then
        kea-dhcp4 -c /etc/kea/kea-dhcp4.conf &>/var/log/kea/kea-dhcp4.log &
    fi
    # start kea-dhcp6
    if command -v kea-dhcp6 >/dev/null 2>&1; then
        kea-dhcp6 -c /etc/kea/kea-dhcp6.conf &>/var/log/kea/kea-dhcp6.log &
    fi
fi

# Ensure container has an IPv6 address on the primary interface (so Kea can bind)
IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(en|eth|ens|enp)' | head -n1 || true)
if [ -z "$IFACE" ]; then
    IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n1 || true)
fi
if [ -n "$IFACE" ]; then
    echo "[dhcp] Detected interface: $IFACE"
    IPV6_ADDR="fd00:100:100::c"
    # Add IPv6 address if not already present
    if ! ip -6 addr show dev "$IFACE" | grep -q "${IPV6_ADDR}"; then
        echo "[dhcp] Adding IPv6 address $IPV6_ADDR/64 to $IFACE"
        ip -6 addr add "${IPV6_ADDR}/64" dev "$IFACE" || true
    else
        echo "[dhcp] IPv6 address $IPV6_ADDR already present on $IFACE"
    fi
fi

# Ensure the Kea config files are owned by the kea runtime user
if id -u _kea >/dev/null 2>&1; then
    chown -R _kea:_kea $KEA_CONF_DIR || true
else
    chown -R kea:kea $KEA_CONF_DIR 2>/dev/null || true
fi

# Ensure start wrapper is executable
chmod +x /vagrant/scripts/start_kea.sh || true

echo "[dhcp] Done"

exit 0
