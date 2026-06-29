#!/bin/bash
# Phase 2-5 - Provision all nodes via az vm run-command.
# Order: NameServers -> Broker masters (id=0) -> Broker slaves (id=1).
set -euo pipefail
cd "$(dirname "$0")"
source ./00-vars.sh
az account set --subscription "$SUBSCRIPTION"

run_on () {  # <vmName> <localScript> [args...]
  local VM="$1"; shift
  local SCRIPT="$1"; shift
  echo "=== run-command -> $VM ($SCRIPT $*) ==="
  if [ "$#" -gt 0 ]; then
    az vm run-command invoke -g "$RG" -n "$VM" --command-id RunShellScript \
      --scripts "@${SCRIPT}" --parameters "$@" -o json \
      --query "value[0].message" -o tsv || echo "WARN: run-command on $VM returned error"
  else
    az vm run-command invoke -g "$RG" -n "$VM" --command-id RunShellScript \
      --scripts "@${SCRIPT}" -o json \
      --query "value[0].message" -o tsv || echo "WARN: run-command on $VM returned error"
  fi
}

echo "########## Phase 4: NameServers ##########"
for entry in "${NS_NODES[@]}"; do
  IFS='|' read -r NAME IP ZONE <<< "$entry"
  run_on "$NAME" "namesrv-setup.sh"
done

echo "Waiting 60s for NameServers to come up..."
sleep 60

echo "########## Phase 5a: Broker masters (brokerId=0) ##########"
for entry in "${BROKER_NODES[@]}"; do
  IFS='|' read -r NAME IP ZONE BNAME BID ROLE <<< "$entry"
  [ "$BID" = "0" ] || continue
  run_on "$NAME" "broker-setup.sh" "$BNAME" "$BID" "$ROLE"
done

echo "Waiting 60s for masters to register..."
sleep 60

echo "########## Phase 5b: Broker slaves (brokerId=1) ##########"
for entry in "${BROKER_NODES[@]}"; do
  IFS='|' read -r NAME IP ZONE BNAME BID ROLE <<< "$entry"
  [ "$BID" = "1" ] || continue
  run_on "$NAME" "broker-setup.sh" "$BNAME" "$BID" "$ROLE"
done

echo "=== Provisioning dispatched. Allow a few minutes, then run ./verify.sh ==="
