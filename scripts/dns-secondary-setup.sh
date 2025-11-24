#!/bin/bash
set -euo pipefail
echo "[dns-secondary-setup] invoking provision_dns_secondary.sh"
exec /vagrant/scripts/provision_dns_secondary.sh
