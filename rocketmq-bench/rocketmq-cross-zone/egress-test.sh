#!/bin/bash
# egress-test.sh  —  Diagnose outbound internet connectivity.
set -uo pipefail
echo "host: $(hostname)"
echo "=== default route ==="; ip route | grep default || echo "no default route"
echo "=== DNS resolve ==="
for h in mirrors.rockylinux.org archive.apache.org dl.rockylinux.org; do
  ip=$(getent hosts "$h" | awk '{print $1}' | head -1)
  echo "  $h -> ${ip:-FAILED}"
done
echo "=== TCP 443 reachability (5s timeout) ==="
for hp in mirrors.rockylinux.org:443 archive.apache.org:443 dl.rockylinux.org:443 8.8.8.8:443; do
  h=${hp%:*}; p=${hp#*:}
  if timeout 5 bash -c "echo > /dev/tcp/$h/$p" 2>/dev/null; then echo "  $hp OK"; else echo "  $hp FAIL"; fi
done
echo "=== curl HEAD apache archive ==="
curl -sS -m 10 -I https://archive.apache.org/dist/rocketmq/4.9.7/ 2>&1 | head -3 || echo "curl failed"
