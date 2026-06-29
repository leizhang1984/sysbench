#!/bin/bash
set -e
ssh -o StrictHostKeyChecking=no -o BatchMode=yes -i /root/.ssh/id_rsa azureadmin@10.142.0.52 'sudo bash -lc "export HOME=/root; export TIUP_HOME=/root/.tiup; /root/.tiup/bin/tiup mirror --help"'
