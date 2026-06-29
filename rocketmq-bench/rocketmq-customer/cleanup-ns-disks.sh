#!/bin/bash
# One-off: remove mistakenly-created NameServer data disks (NS needs no data disk).
set -uo pipefail
RG=rocketmq-customer
for ns in v6rocketmqnamesvr01 v6rocketmqnamesvr02 v6rocketmqnamesvr03; do
  echo "detach ${ns}-datadisk"
  az vm disk detach -g "$RG" --vm-name "$ns" --name "${ns}-datadisk" -o none 2>&1 || true
done
for ns in v6rocketmqnamesvr01 v6rocketmqnamesvr02 v6rocketmqnamesvr03; do
  echo "delete ${ns}-datadisk"
  az disk delete -g "$RG" -n "${ns}-datadisk" --yes -o none 2>&1 || true
done
echo "--- disks left ---"
az disk list -g "$RG" --query "[].name" -o tsv
