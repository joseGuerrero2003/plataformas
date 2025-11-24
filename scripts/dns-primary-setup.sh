#!/bin/bash
set -euo pipefail
echo "[dns-primary-setup] invoking provision_dns_primary.sh"
exec /vagrant/scripts/provision_dns_primary.sh
