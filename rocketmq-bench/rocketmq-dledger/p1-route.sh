#!/bin/bash
MQ=/opt/rocketmq-4.9.7
NS=10.170.0.6:9876
for T in BenchTopic_1K ft_topic; do
  echo "===== topicRoute $T ====="
  $MQ/bin/mqadmin topicRoute -n $NS -t $T 2>&1 | tail -60
done
echo "===== confirm leftover producers gone ====="
ps -ef | grep -E 'benchmark|Probe' | grep -v grep || echo "none-clean"
