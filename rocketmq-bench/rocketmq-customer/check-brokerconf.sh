#!/bin/bash
set -e
cd "$(dirname "$0")"
source ./00-vars.sh
az account set --subscription "$SUBSCRIPTION" >/dev/null
sed -i 's/\r$//' rc-brokerconf.sh 2>/dev/null || true
for vm in broker-a-0 broker-a-1 broker-b-0 broker-b-1 broker-c-0 broker-c-1; do
  az vm run-command create -g "$RG" --vm-name "$vm" --run-command-name bconf \
    --async-execution false --timeout-in-seconds 90 --script "@rc-brokerconf.sh" -o none
  echo "=== $vm ==="
  az vm run-command show -g "$RG" --vm-name "$vm" --run-command-name bconf \
    --instance-view --query instanceView.output -o tsv
done
