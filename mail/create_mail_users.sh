#!/bin/bash
set -euo pipefail

echo "[mail-users] Creating test users"
for u in alice bob usuario; do
  if id -u "$u" >/dev/null 2>&1; then
    echo "[mail-users] User $u already exists"
  else
    useradd -m -s /bin/bash "$u"
    echo "$u:P@ssw0rd" | chpasswd
    mkdir -p /home/$u/Maildir
    chown -R $u:$u /home/$u/Maildir
    echo "[mail-users] Created $u with password P@ssw0rd"
  fi
done

exit 0
