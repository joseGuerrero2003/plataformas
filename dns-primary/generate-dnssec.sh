#!/bin/bash
set -euo pipefail

ZONE=db.lab.local
ZONEFILE=/etc/bind/zones/db.lab.local
SIGNED=${ZONEFILE}.signed

echo "[dnssec] Creating zones directory"
mkdir -p /etc/bind/zones
cp /vagrant/dns-primary/db.lab.local ${ZONEFILE}

echo "[dnssec] Generating ZSK and KSK"
cd /etc/bind/zones
KSK=$(dnssec-keygen -a RSASHA256 -b 2048 -n ZONE ${ZONE} | sed 's/\.key$//')
ZSK=$(dnssec-keygen -a RSASHA256 -b 1024 -n ZONE ${ZONE} | sed 's/\.key$//')

echo "[dnssec] Keys: $KSK (KSK), $ZSK (ZSK)"

cat ${ZONEFILE} > ${ZONEFILE}.unsigned

echo "[dnssec] Signing zone"
dnssec-signzone -o ${ZONE} -k ${KSK} -m ${ZSK} ${ZONEFILE}

echo "[dnssec] Signed zone created: ${SIGNED}"

systemctl reload bind9 || service bind9 reload || true

echo "[dnssec] Done"
