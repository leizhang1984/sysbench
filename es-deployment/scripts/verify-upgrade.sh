#!/bin/bash
echo "=== $(hostname) ==="
cat /etc/rocky-release 2>/dev/null
echo "kernel: $(uname -r)"
echo "uptime: $(uptime -p)"
echo "pending security/updates:"
dnf -q check-update >/dev/null 2>&1; rc=$?
if [ $rc -eq 100 ]; then echo "  updates STILL available"; elif [ $rc -eq 0 ]; then echo "  fully up to date"; else echo "  (check-update rc=$rc)"; fi
# service checks where relevant
if systemctl list-unit-files | grep -q '^elasticsearch'; then
  echo "elasticsearch: $(systemctl is-active elasticsearch)"
fi
if [ -x /usr/local/bin/esrally ]; then
  echo "esrally: $(/usr/local/bin/esrally --version 2>&1 | head -n1)"
fi
echo "=== done ==="
