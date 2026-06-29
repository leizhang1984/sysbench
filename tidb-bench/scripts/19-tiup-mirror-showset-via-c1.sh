#!/bin/bash
set -e
ssh -o StrictHostKeyChecking=no -o BatchMode=yes -i /root/.ssh/id_rsa azureadmin@10.142.0.52 'sudo bash -lc "export HOME=/root; export TIUP_HOME=/root/.tiup; echo BEFORE:; /root/.tiup/bin/tiup mirror show; echo TRY_SET_LOCAL:; /root/.tiup/bin/tiup mirror set file:///root/.tiup/mirror || true; echo AFTER:; /root/.tiup/bin/tiup mirror show"'
