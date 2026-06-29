#!/bin/bash
export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
MQ=/opt/rocketmq-4.9.7
echo "===== clusterList via ns02 (10.170.0.6:9876) ====="
$MQ/bin/mqadmin clusterList -n 10.170.0.6:9876 2>/dev/null
