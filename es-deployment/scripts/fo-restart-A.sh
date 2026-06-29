#!/usr/bin/env bash
# Check cluster health from a surviving node, then restart ES on node01 and wait for green.
ES2=http://10.122.0.8:9200
echo "=== health BEFORE restart (via node02) ==="
curl -s "$ES2/_cluster/health/failover-test?pretty" | tr -d '\n'; echo
echo "=== shards BEFORE restart ==="
curl -s "$ES2/_cat/shards/failover-test?v&h=index,shard,prirep,state,node"
echo "=== restarting ES on node01 ==="
systemctl start elasticsearch
echo "start_issued=$(date +%H:%M:%S)"
curl -s "$ES2/_cluster/health/failover-test?wait_for_status=green&timeout=60s&pretty" | tr -d '\n'; echo
echo "=== nodes AFTER restart ==="
curl -s "$ES2/_cat/nodes?v&h=name,ip,master"
echo "=== shards AFTER restart ==="
curl -s "$ES2/_cat/shards/failover-test?v&h=index,shard,prirep,state,node"
