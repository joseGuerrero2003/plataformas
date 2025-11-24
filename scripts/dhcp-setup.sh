#!/bin/bash
set -euo pipefail
echo "[dhcp-setup] invoking provision_dhcp.sh"
exec /vagrant/scripts/provision_dhcp.sh
