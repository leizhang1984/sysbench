#!/bin/bash
# P1 health: clusterList overview + per-node service/port checks.
set -euo pipefail
cd "$(dirname "$0")"
source ./00-vars.sh
az account set --subscription "$SUBSCRIPTION"
sed -i 's/\r$//' rc-health.sh rc-clusterlist.sh 2>/dev/null || true

echo "########## clusterList (via NS01) ##########"
az vm run-command create -g "$RG" --vm-name v6rocketmqnamesvr01 --run-command-name hc-cl \
  --async-execution false --timeout-in-seconds 120 --script "@rc-clusterlist.sh" -o none
az vm run-command show -g "$RG" --vm-name v6rocketmqnamesvr01 --run-command-name hc-cl \
  --instance-view --query instanceView.output -o tsv

ALL=(v6rocketmqnamesvr01 v6rocketmqnamesvr02 v6rocketmqnamesvr03 broker-a-0 broker-a-1 broker-b-0 broker-b-1 broker-c-0 broker-c-1)
echo "########## per-node ##########"
for vm in "${ALL[@]}"; do
  az vm run-command create -g "$RG" --vm-name "$vm" --run-command-name hc-node \
    --async-execution false --timeout-in-seconds 90 --script "@rc-health.sh" -o none
  echo "=== $vm ==="
  az vm run-command show -g "$RG" --vm-name "$vm" --run-command-name hc-node \
    --instance-view --query instanceView.output -o tsv
done
