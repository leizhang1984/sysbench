#!/bin/bash
# Add a public IP to every VM in the cluster (NIC ipconfig1).
set -uo pipefail
source ./00-vars.sh
az account set --subscription "$SUBSCRIPTION"
ALL=()
for e in "${NS_NODES[@]}" "${BROKER_NODES[@]}" "${CLIENT_NODES[@]}"; do ALL+=("${e%%|*}"); done
for NAME in "${ALL[@]}"; do
  NIC="${NAME}-nic"; PIP="${NAME}-pip"
  echo "=== $NAME ==="
  az network public-ip create -g "$RG" -n "$PIP" -l "$LOCATION" --sku Standard --zone 1 2 3 -o none 2>/dev/null || \
    az network public-ip create -g "$RG" -n "$PIP" -l "$LOCATION" --sku Standard -o none 2>&1 || true
  IPCFG=$(az network nic show -g "$RG" -n "$NIC" --query "ipConfigurations[0].name" -o tsv)
  az network nic ip-config update -g "$RG" --nic-name "$NIC" -n "$IPCFG" --public-ip-address "$PIP" -o none 2>&1 || true
done
echo "--- public IPs ---"
az network public-ip list -g "$RG" --query "[].{n:name,ip:ipAddress}" -o table
