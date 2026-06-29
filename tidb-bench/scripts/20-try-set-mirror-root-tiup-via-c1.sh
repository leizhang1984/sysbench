#!/bin/bash
set -e
ssh -o StrictHostKeyChecking=no -o BatchMode=yes -i /root/.ssh/id_rsa azureadmin@10.142.0.52 'sudo bash -lc "export HOME=/root; export TIUP_HOME=/root/.tiup; ls -l /root/.tiup | head -20; /root/.tiup/bin/tiup mirror set /root/.tiup || true; /root/.tiup/bin/tiup mirror show"'
