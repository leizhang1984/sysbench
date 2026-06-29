#!/bin/bash
set -e
export HOME=/root
tar czf /tmp/tiup.tgz -C /root .tiup
ls -lh /tmp/tiup.tgz
scp -o StrictHostKeyChecking=no -o BatchMode=yes -i /root/.ssh/id_rsa /tmp/tiup.tgz azureadmin@10.142.0.52:/tmp/tiup.tgz
echo OK_XFER