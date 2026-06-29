#!/bin/bash
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
MQ=$ROCKETMQ_HOME/bin/mqadmin
echo "=== TCP reachability to ns03 9876 ==="
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/10.170.0.5/9876' && echo "ns03:9876 OPEN" || echo "ns03:9876 CLOSED/UNREACHABLE"
echo "=== clusterList via ns03 (retry) ==="
for i in 1 2 3; do
  echo "--- attempt $i ---"
  sh "$MQ" clusterList -n 10.170.0.5:9876 2>&1 | sed -n '1,8p'
  sleep 2
done
