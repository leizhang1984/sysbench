#!/bin/bash
set -e
export HOME=/root
rm -rf /root/.tiup
tar xzf /tmp/tiup.tgz -C /root
chown -R root:root /root/.tiup
/root/.tiup/bin/tiup --version 2>&1 | head -1
/root/.tiup/bin/tiup cluster list 2>&1 | head -3 || true
echo OK_EXTRACT