#!/bin/bash
set -e
ssh -o StrictHostKeyChecking=no -o BatchMode=yes -i /root/.ssh/id_rsa azureadmin@10.142.0.52 '
  sudo bash -lc "export HOME=/root; export TIUP_HOME=/root/.tiup; \
  if [ -x /root/.tiup/bin/tiup ]; then /root/.tiup/bin/tiup cluster list || true; /root/.tiup/bin/tiup cluster display tidb-dsv6 || true; else echo NO_TIUP; fi"'
