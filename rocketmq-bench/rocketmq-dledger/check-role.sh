#!/bin/bash
MQ=/opt/rocketmq-4.9.7
NS=10.170.0.6:9876
echo "=== brokerStatus per master (check role/master) ==="
for ip in 10.170.0.14 10.170.0.11 10.170.0.18; do
  echo "--- $ip ---"
  $MQ/bin/mqadmin brokerStatus -n $NS -b $ip:10911 2>&1 | grep -iE "brokerRole|msgPutTotal|getMessage|brokerId|putMessageDistributeTime" | head -6
done
echo ""
echo "=== full topicRoute for BenchTopic01 (perm/brokerData) ==="
$MQ/bin/mqadmin topicRoute -n $NS -t BenchTopic01 2>&1 | head -60
