#!/bin/bash
MQ=/opt/rocketmq-4.9.7
NS=10.170.0.6:9876
TOPIC=BenchTopic01
echo "=== create topic $TOPIC on all 3 groups ==="
for b in broker-a broker-b broker-c; do
  echo "--- $b ---"
  $MQ/bin/mqadmin updateTopic -n $NS -b $b -t $TOPIC -r 8 -w 8 2>&1 | tail -3
done
sleep 3
echo "=== topicRoute ==="
$MQ/bin/mqadmin topicRoute -n $NS -t $TOPIC 2>&1 | tail -40
