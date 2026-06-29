#!/bin/bash
# clusterlist.sh  —  Show RocketMQ cluster status from a name server node.
set -uo pipefail
RMQ_HOME=/opt/rocketmq-4.9.7
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export ROCKETMQ_HOME=$RMQ_HOME
NS=$(grep -hoP 'namesrvAddr=\K.*' ${RMQ_HOME}/conf/broker.conf 2>/dev/null | head -1)
[ -n "${NS:-}" ] || NS="127.0.0.1:9876"
echo "=== clusterList (ns=$NS) ==="
sh ${RMQ_HOME}/bin/mqadmin clusterList -n "$NS" 2>/dev/null
