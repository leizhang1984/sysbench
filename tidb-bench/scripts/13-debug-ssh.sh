#!/bin/bash
echo "=== home perms ==="
ls -ld /home/azureadmin /home/azureadmin/.ssh
echo "=== authorized_keys ==="
ls -lZ /home/azureadmin/.ssh/authorized_keys
echo "--- content (first 60 chars/line) ---"
awk '{print substr($0,1,60)"... ["NF" fields]"}' /home/azureadmin/.ssh/authorized_keys
echo "=== sshd PubkeyAuthentication ==="
grep -Ei '^\s*(PubkeyAuthentication|AuthorizedKeysFile|PasswordAuthentication)' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/* 2>/dev/null
echo "=== SELinux mode ==="
getenforce 2>/dev/null
echo "=== recent ssh denials (audit) ==="
ausearch -m avc -ts recent 2>/dev/null | grep -i ssh | tail -5
tail -20 /var/log/secure 2>/dev/null | grep -i ssh | tail -10
