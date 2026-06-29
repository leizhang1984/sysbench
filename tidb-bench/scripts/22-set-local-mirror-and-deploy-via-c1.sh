#!/bin/bash
set -e
ssh -o StrictHostKeyChecking=no -o BatchMode=yes -i /root/.ssh/id_rsa azureadmin@10.142.0.52 'sudo bash -lc "
set -e
export HOME=/root
export TIUP_HOME=/root/.tiup
TIUP=/root/.tiup/bin/tiup

# Try local mirror first
$TIUP mirror set /root/.tiup/bin || true
echo MIRROR_NOW:
$TIUP mirror show || true

# quick sanity
$TIUP cluster list || true

# deploy if not exists
if $TIUP cluster list 2>/dev/null | grep -q tidb-dsv6; then
  echo EXIST
else
  $TIUP cluster deploy tidb-dsv6 v8.5.6 /root/topology-dv6.yaml -u azureadmin -i /root/.ssh/id_rsa -y
fi
$TIUP cluster start tidb-dsv6
$TIUP cluster display tidb-dsv6 | head -40
"'
