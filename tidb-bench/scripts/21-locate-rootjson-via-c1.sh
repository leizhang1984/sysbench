#!/bin/bash
set -e
ssh -o StrictHostKeyChecking=no -o BatchMode=yes -i /root/.ssh/id_rsa azureadmin@10.142.0.52 'sudo bash -lc "export HOME=/root; find /root/.tiup -maxdepth 3 -name root.json -o -name manifest.json | sed -n 1,40p"'
