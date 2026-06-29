#!/bin/bash
# Create topics across whole cluster via -c clusterName (DLedger-safe)
MQ=/opt/rocketmq-4.9.7
NS=10.170.0.6:9876
for T in BenchTopic_1K ft_topic; do
  echo "===== updateTopic $T -c RocketMQCluster (8r8w) ====="
  $MQ/bin/mqadmin updateTopic -n $NS -c RocketMQCluster -t $T -r 8 -w 8 2>&1 | tail -6
done
sleep 4
for T in BenchTopic_1K ft_topic; do
  echo "===== topicRoute $T (brokerName lines) ====="
  $MQ/bin/mqadmin topicRoute -n $NS -t $T 2>&1 | grep -E '"brokerName"|writeQueueNums' | sort | uniq -c
done
