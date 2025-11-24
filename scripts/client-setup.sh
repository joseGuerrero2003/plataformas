#!/bin/bash
set -euo pipefail
echo "[client-setup] invoking provision_client.sh"
exec /vagrant/scripts/provision_client.sh
