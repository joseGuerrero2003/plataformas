#!/bin/bash
set -euo pipefail

mkdir -p /var/log

echo "Starting Postfix (foreground) and Dovecot (foreground)"
/usr/sbin/postfix start-fg &>/var/log/postfix-foreground.log &
dovecot -F &>/var/log/dovecot-foreground.log &

tail -f /var/log/postfix-foreground.log /var/log/dovecot-foreground.log
