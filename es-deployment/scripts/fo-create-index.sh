#!/usr/bin/env bash
# Create replicated failover-test index on dsv6 cluster
ES=http://10.122.0.7:9200

curl -s -XDELETE "$ES/failover-test" >/dev/null 2>&1
sleep 1
curl -s -XPUT "$ES/failover-test" -H 'Content-Type: application/json' -d '{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "index.unassigned.node_left.delayed_timeout": "12s"
  }
}'
echo
echo "--- health ---"
curl -s "$ES/_cluster/health/failover-test?wait_for_status=green&timeout=30s&pretty" | tr -d '\n'
echo
echo "--- shard placement ---"
curl -s "$ES/_cat/shards/failover-test?v&h=index,shard,prirep,state,node"
