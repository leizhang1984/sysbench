#!/bin/bash
# Phase 6 - Verify the cluster from a NameServer node using mqadmin clusterList.
set -euo pipefail
cd "$(dirname "$0")"
source ./00-vars.sh
az account set --subscription "$SUBSCRIPTION"

VM="v6rocketmqnamesvr01"
echo "=== clusterList (from $VM) ==="
az vm run-command invoke -g "$RG" -n "$VM" --command-id RunShellScript --scripts \
  'export ROCKETMQ_HOME=/opt/rocketmq-4.9.7; export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")"); sh $ROCKETMQ_HOME/bin/mqadmin clusterList -n 127.0.0.1:9876' \
  --query "value[0].message" -o tsv

echo
echo "Expected: 6 brokers (broker-a/b/c, each BID 0 master + BID 1 slave) all online."
