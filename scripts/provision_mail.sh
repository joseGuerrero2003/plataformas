#!/bin/bash
set -euo pipefail

echo "[mail] Installing Postfix and Dovecot"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends postfix dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd mailutils

echo "[mail] Deploying configuration"
install -m 644 /vagrant/mail/postfix-main.cf /etc/postfix/main.cf
install -m 644 /vagrant/mail/dovecot.conf /etc/dovecot/dovecot.conf

echo "[mail] Creating system users for mail: alice, bob"
/vagrant/mail/create_mail_users.sh || true

echo "[mail] Enabling and restarting services"
systemctl enable --now postfix || service postfix restart || true
systemctl enable --now dovecot || service dovecot restart || true

# Ensure mail directories exist and ownerships
mkdir -p /var/mail /var/spool/postfix /var/log/mail || true
chown -R postfix:postfix /var/spool/postfix 2>/dev/null || true
chown -R dovecot:dovecot /var/mail 2>/dev/null || true

# Start services manually if systemd is not present
if ! pidof systemd >/dev/null 2>&1; then
	echo "[mail] systemd not detected; starting postfix and dovecot manually (foreground for debug)"
	# start postfix in background
	/usr/sbin/postfix start-fg &>/var/log/postfix-foreground.log &
	# start dovecot in background
	dovecot -F &>/var/log/dovecot-foreground.log &
fi

# Ensure start wrapper is executable
chmod +x /vagrant/scripts/start_mail_services.sh || true

echo "[mail] Done"

exit 0
