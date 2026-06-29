#!/bin/bash
MQ=/opt/rocketmq-4.9.7
NS=10.170.0.6:9876
TOPIC=BenchTopic01
echo "=== updateTopic on broker-a (full output) ==="
$MQ/bin/mqadmin updateTopic -n $NS -b broker-a -t $TOPIC -r 8 -w 8 2>&1 | grep -iE "Caused by|CODE:|DESC:|success|create topic to" | head -10
echo "=== try clusterName mode instead of -b ==="
$MQ/bin/mqadmin updateTopic -n $NS -c RocketMQCluster -t $TOPIC -r 8 -w 8 2>&1 | grep -iE "Caused by|CODE:|DESC:|success|create topic to" | head -20
