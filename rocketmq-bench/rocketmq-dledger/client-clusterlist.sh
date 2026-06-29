#!/bin/bash
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
MQ=$ROCKETMQ_HOME/bin/mqadmin
NS="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"
echo "=== clusterList (full topology via all 3 nameservers) ==="
sh "$MQ" clusterList -n "$NS" 2>/dev/null
