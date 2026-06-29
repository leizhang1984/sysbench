#!/usr/bin/env bash
# Poll until node01 rejoins; confirm 3-node green.
for i in $(seq 1 12); do
  n=$(curl -s 'http://10.122.0.8:9200/_cat/nodes?h=name' | grep -c .)
  if [ "$n" -ge 3 ]; then break; fi
  sleep 5
done
echo "nodes_now=$n"
curl -s 'http://10.122.0.8:9200/_cat/nodes?v&h=name,ip,master,heap.percent'
echo "--- health ---"
curl -s 'http://10.122.0.8:9200/_cluster/health/failover-test?pretty' | tr -d '\n'
echo
echo "--- shards ---"
curl -s 'http://10.122.0.8:9200/_cat/shards/failover-test?v&h=index,shard,prirep,state,node'
