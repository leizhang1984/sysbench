#!/bin/bash
# Append a public key (passed as args, rejoined) to azureadmin authorized_keys.
set -e
PUB="$*"
mkdir -p /home/azureadmin/.ssh
chmod 700 /home/azureadmin/.ssh
touch /home/azureadmin/.ssh/authorized_keys
grep -qF "$PUB" /home/azureadmin/.ssh/authorized_keys || echo "$PUB" >> /home/azureadmin/.ssh/authorized_keys
chmod 600 /home/azureadmin/.ssh/authorized_keys
chown -R azureadmin:azureadmin /home/azureadmin/.ssh
# Fix SELinux labels so sshd can read the key (ssh_home_t)
command -v restorecon >/dev/null 2>&1 && restorecon -R /home/azureadmin/.ssh || true
echo "DISTRIBUTED_OK keys=$(wc -l < /home/azureadmin/.ssh/authorized_keys) ctx=$(ls -Z /home/azureadmin/.ssh/authorized_keys 2>/dev/null | awk '{print $1}')"
