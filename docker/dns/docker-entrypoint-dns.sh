#!/bin/bash
set -euo pipefail

KEYDIR=/etc/bind/keys
mkdir -p "$KEYDIR"
chown -R bind:bind /etc/bind 2>/dev/null || true

# If /etc/bind is not writable, prefer the shared Docker volume at /var/lib/bind/keys
if [ ! -w "$KEYDIR" ]; then
  echo "/etc/bind not writable; using fallback/shared key dir at /var/lib/bind/keys"
  mkdir -p /var/lib/bind/keys || true
  KEYDIR=/var/lib/bind/keys
  chmod 700 "$KEYDIR" || true
fi
chown -R bind:bind "$KEYDIR" 2>/dev/null || true

# Some legacy configs in the repo reference /vagrant; create a symlink
# so those includes still work inside the container.
mkdir -p /vagrant
rm -f /vagrant/dns-primary || true
ln -s /etc/bind /vagrant/dns-primary

# Ensure keys directory is writable (if mount was read-only earlier this will fail)
if [ ! -w "$KEYDIR" ]; then
  echo "/etc/bind not writable; creating writable fallback at /var/lib/bind/keys"
  mkdir -p /var/lib/bind/keys || true
  KEYDIR=/var/lib/bind/keys
  chmod 700 "$KEYDIR" || true
fi
chown -R bind:bind "$KEYDIR" 2>/dev/null || true

## Use existing tsig.key from repo if present, otherwise generate a small secret
KEYFILE="$KEYDIR/tsig.key"
# If there's a tsig.key provided in /etc/bind (repo mount), copy it into the
# active keydir so both primary and secondary see the same key. This works
# even when /etc/bind is mounted read-only (we only read from it).
if [ -f /etc/bind/tsig.key ]; then
  echo "Found /etc/bind/tsig.key in repo; copying into $KEYDIR"
  mkdir -p "$KEYDIR" || true
  cp -f /etc/bind/tsig.key "$KEYFILE" 2>/dev/null || true
else
  if [ -f "$KEYFILE" ]; then
    echo "Usando tsig.key presente en $KEYFILE"
  else
    echo "Generando tsig.key en $KEYFILE"
    SECRET=$(openssl rand -base64 32)
    mkdir -p "$KEYDIR" || true
    cat > "$KEYFILE" <<EOF
key "transfer-key" {
  algorithm hmac-sha256;
  secret "$SECRET";
};
EOF
  fi
fi
# Ensure ownership/permissions on the key in the shared volume (may fail if volume driver enforces permissions)
chown bind:bind "$KEYFILE" 2>/dev/null || true
chmod 640 "$KEYFILE" 2>/dev/null || true

# For compatibility with configs that include /etc/bind/tsig.key, copy the key there if writable
if [ -w /etc/bind ] || [ ! -e /etc/bind ]; then
  cp -f "$KEYFILE" /etc/bind/tsig.key 2>/dev/null || true
  chown bind:bind /etc/bind/tsig.key 2>/dev/null || true
  chmod 640 /etc/bind/tsig.key 2>/dev/null || true
fi

# Try to generate DNSSEC keys and sign zone files if dnssec tools available
for zf in /etc/bind/*.db /etc/bind/zones/*.db; do
  [ -f "$zf" ] || continue
  zone=$(basename "$zf" .db)
  KZ=$(ls /etc/bind/${zone}.*.key 2>/dev/null || true)
  if [ -z "$KZ" ]; then
    if command -v dnssec-keygen >/dev/null 2>&1; then
      echo "Creando claves DNSSEC para zona $zone"
      cd /etc/bind || true
      dnssec-keygen -a RSASHA256 -b 2048 -n ZONE "$zone" || true
      for k in K${zone}*.key; do
        [ -f "$k" ] || continue
        cat "$k" >> ${zone}.db
      done
      if command -v dnssec-signzone >/dev/null 2>&1; then
        dnssec-signzone -A -N INCREMENT -o "$zone" -t ${zone}.db || true
      fi
      cd - >/dev/null || true
    fi
  fi
done

echo "Iniciando named..."
## Ensure zones directory exists and zone files are in the expected path
ZONES_DIR=/etc/bind/zones
mkdir -p "$ZONES_DIR" || true
mkdir -p "$ZONES_DIR/slaves" || true
chown -R bind:bind "$ZONES_DIR" 2>/dev/null || true
chown -R bind:bind "$ZONES_DIR/slaves" 2>/dev/null || true

# If a zone file exists at /etc/bind/db.lab.local (repo layout), copy it
# into the zones directory where named.conf.local expects it.
if [ -f /etc/bind/db.lab.local ] && [ ! -f "$ZONES_DIR/db.lab.local" ]; then
  echo "Detected /etc/bind/db.lab.local, copying to $ZONES_DIR/db.lab.local"
  cp /etc/bind/db.lab.local "$ZONES_DIR/db.lab.local" || true
  chown bind:bind "$ZONES_DIR/db.lab.local" || true
fi

# Ensure runtime directories named needs are present
mkdir -p /run/named || true
chown -R bind:bind /run/named 2>/dev/null || true

exec /opt/plataformas/scripts/start_named.sh
