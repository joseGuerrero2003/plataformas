#!/bin/bash
set -euo pipefail

echo "Preparando servicios de mail (Postfix + Dovecot)"
# Ejecutar script de creación de usuarios si existe
if [ -x /opt/plataformas/scripts/create_mail_users.sh ]; then
  /opt/plataformas/scripts/create_mail_users.sh || true
fi

# If a custom Postfix main.cf is provided in the repo under /opt/mail, copy it
# to /etc/postfix so Postfix runs with the lab configuration (mydestination, etc).
if [ -f /opt/mail/postfix-main.cf ]; then
  echo "Found repo Postfix config; installing /etc/postfix/main.cf"
  cp -f /opt/mail/postfix-main.cf /etc/postfix/main.cf || true
fi

# Ensure /etc/mailname exists for Postfix (used by myorigin)
if [ ! -f /etc/mailname ]; then
  echo "lab.local" > /etc/mailname || true
fi

# Run create_mail_users.sh from the repo if present (creates test users)
if [ -f /opt/mail/create_mail_users.sh ]; then
  if [ -x /opt/mail/create_mail_users.sh ]; then
    /opt/mail/create_mail_users.sh || true
  else
    bash /opt/mail/create_mail_users.sh || true
  fi
fi

# Asegurar directorios y ficheros de log para evitar "no such file"
mkdir -p /var/log
touch /var/log/postfix-foreground.log /var/log/dovecot-foreground.log || true
chmod 644 /var/log/postfix-foreground.log /var/log/dovecot-foreground.log || true

exec /opt/plataformas/scripts/start_mail_services.sh
