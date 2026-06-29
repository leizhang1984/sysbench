#!/usr/bin/env bash
# Cleanup failover-test index and verify cluster state.
ES=http://10.122.0.8:9200

echo "=== before delete ==="
curl -s "$ES/_cat/indices/failover-test?v&h=health,index,pri,rep,docs.count"

echo "=== delete failover-test ==="
curl -s -XDELETE "$ES/failover-test"
echo

echo "=== after delete check ==="
curl -s "$ES/_cat/indices/failover-test?v&h=health,index,pri,rep,docs.count"
echo

echo "=== cluster health ==="
curl -s "$ES/_cluster/health?pretty" | tr -d '\n'
echo

echo "=== nodes ==="
curl -s "$ES/_cat/nodes?v&h=name,ip,master,heap.percent"
