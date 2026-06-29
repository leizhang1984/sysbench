#!/bin/bash
set -e
cat >/tmp/remote-localmirror-deploy.sh <<'EOF_REMOTE'
#!/bin/bash
set -e
export HOME=/root
export TIUP_HOME=/root/.tiup
TIUP=/root/.tiup/bin/tiup

$TIUP mirror set /root/.tiup/bin || true
echo MIRROR_NOW
$TIUP mirror show || true
$TIUP cluster list || true

if $TIUP cluster list 2>/dev/null | grep -q tidb-dsv6; then
  echo EXIST
else
  $TIUP cluster deploy tidb-dsv6 v8.5.6 /root/topology-dv6.yaml -u azureadmin -i /root/.ssh/id_rsa -y
fi
$TIUP cluster start tidb-dsv6
$TIUP cluster display tidb-dsv6 | head -40
EOF_REMOTE

chmod +x /tmp/remote-localmirror-deploy.sh
scp -o StrictHostKeyChecking=no -o BatchMode=yes -i /root/.ssh/id_rsa /tmp/remote-localmirror-deploy.sh azureadmin@10.142.0.52:/tmp/remote-localmirror-deploy.sh
ssh -o StrictHostKeyChecking=no -o BatchMode=yes -i /root/.ssh/id_rsa azureadmin@10.142.0.52 'sudo bash /tmp/remote-localmirror-deploy.sh'
