#!/bin/bash
# Phase 2 - Provision via managed run-command create (invoke only runs a sample here).
# NS -> masters -> slaves. Reads NAMESRV_ADDR from inventory.env.
set -euo pipefail
cd "$(dirname "$0")"
source ./00-vars.sh
[ -f "$NS_FILE" ] || { echo "ERROR: run inventory.sh first"; exit 1; }
source "$NS_FILE"
[ -n "${NAMESRV_ADDR:-}" ] || { echo "ERROR: NAMESRV_ADDR empty"; exit 1; }
echo "NAMESRV_ADDR=$NAMESRV_ADDR"
az account set --subscription "$SUBSCRIPTION"

run_ns () {  # <vm>
  az vm run-command create -g "$RG" --vm-name "$1" --run-command-name ns-setup \
    --async-execution false --timeout-in-seconds 1800 \
    --script "@namesrv-setup.sh" --query 'instanceView.executionState' -o tsv
}
run_broker () {  # <vm> <bname> <bid> <role>
  printf 'set -- %s %s %s "%s"\n' "$2" "$3" "$4" "$NAMESRV_ADDR" > /tmp/bs-$1.sh
  cat broker-setup.sh >> /tmp/bs-$1.sh
  az vm run-command create -g "$RG" --vm-name "$1" --run-command-name broker-setup \
    --async-execution false --timeout-in-seconds 1800 \
    --script "@/tmp/bs-$1.sh" --query 'instanceView.executionState' -o tsv
}

echo "########## Phase A: NameServers ##########"
for e in "${NS_NODES[@]}"; do IFS='|' read -r NAME ZONE <<< "$e"; echo "=== $NAME ==="; run_ns "$NAME"; done
sleep 60
echo "########## Phase B: masters ##########"
for e in "${BROKER_NODES[@]}"; do IFS='|' read -r NAME ZONE BNAME BID ROLE <<< "$e"; [ "$BID" = 0 ] || continue; echo "=== $NAME ==="; run_broker "$NAME" "$BNAME" "$BID" "$ROLE"; done
sleep 60
echo "########## Phase C: slaves ##########"
for e in "${BROKER_NODES[@]}"; do IFS='|' read -r NAME ZONE BNAME BID ROLE <<< "$e"; [ "$BID" = 1 ] || continue; echo "=== $NAME ==="; run_broker "$NAME" "$BNAME" "$BID" "$ROLE"; done
echo "=== done; allow ~3-5 min ==="
