#!/bin/bash
# Phase 1.5 - Resolve dynamic private IPs and emit the NameServer address list.
# Writes ./inventory.env with NAMESRV_ADDR (consumed by broker-setup) and a full
# node->IP table for reference. Run AFTER deploy-infra.sh.
set -euo pipefail
cd "$(dirname "$0")"
source ./00-vars.sh

az account set --subscription "$SUBSCRIPTION"

get_ip () {  # <vmName>
  az vm list-ip-addresses -g "$RG" -n "$1" \
    --query "[0].virtualMachine.network.privateIpAddresses[0]" -o tsv
}

echo "=== Resolving NameServer private IPs ==="
NS_ADDR=""
for entry in "${NS_NODES[@]}"; do
  IFS='|' read -r NAME ZONE <<< "$entry"
  IP=$(get_ip "$NAME")
  [ -n "$IP" ] || { echo "ERROR: no IP for $NAME"; exit 1; }
  echo "  $NAME -> $IP (zone $ZONE)"
  NS_ADDR="${NS_ADDR:+$NS_ADDR;}${IP}:9876"
done

{
  echo "NAMESRV_ADDR=\"$NS_ADDR\""
  echo "# nodes:"
  for entry in "${NS_NODES[@]}" "${BROKER_NODES[@]}" "${CLIENT_NODES[@]}"; do
    NAME="${entry%%|*}"
    echo "#   $NAME=$(get_ip "$NAME")"
  done
} > "$NS_FILE"

echo "=== Wrote $NS_FILE ==="
cat "$NS_FILE"
