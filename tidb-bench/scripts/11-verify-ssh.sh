#!/bin/bash
# Run on a control machine. Verifies passwordless SSH (as azureadmin) to all its cluster nodes.
set +e
export PATH=/root/.tiup/bin:$PATH
NODES="$@"
for ip in $NODES; do
  out=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=8 \
        -i /root/.ssh/id_rsa azureadmin@$ip 'echo OK:$(hostname) /tidb=$(mountpoint -q /tidb && echo yes || echo no)' 2>&1)
  echo "[$ip] $out"
done
