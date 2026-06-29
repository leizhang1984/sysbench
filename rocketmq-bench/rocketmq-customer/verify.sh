#!/bin/bash
# Phase 3 - Verify cluster registration: clusterList should show 6 brokers
# (broker-a/b/c with brokerId 0 and 1) registered on the NameServers.
set -euo pipefail
cd "$(dirname "$0")"
source ./00-vars.sh
[ -f "$NS_FILE" ] && source "$NS_FILE"

az account set --subscription "$SUBSCRIPTION"

NS1="${NS_NODES[0]%%|*}"
echo "=== clusterList via $NS1 (NAMESRV_ADDR=${NAMESRV_ADDR:-?}) ==="
cat > /tmp/clusterlist.sh <<EOF
export ROCKETMQ_HOME=/opt/rocketmq-${RMQ_VERSION}
export JAVA_HOME=\$(dirname \$(dirname \$(readlink -f \$(command -v java))))
\$ROCKETMQ_HOME/bin/mqadmin clusterList -n 127.0.0.1:9876
EOF
az vm run-command create -g "$RG" --vm-name "$NS1" --run-command-name clusterlist \
  --async-execution false --timeout-in-seconds 300 \
  --script "@/tmp/clusterlist.sh" -o none
az vm run-command show -g "$RG" --vm-name "$NS1" --run-command-name clusterlist \
  --instance-view --query "instanceView.output" -o tsv
