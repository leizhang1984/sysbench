#!/bin/bash
# P1 finalize: clean leftover producers + create topics across all 3 groups
MQ=/opt/rocketmq-4.9.7
NS=10.170.0.6:9876
echo "=== leftover java procs on client (before) ==="
ps -ef | grep -E 'benchmark|Probe|producer' | grep -v grep || echo "none"
echo "=== killing any leftover benchmark/Probe producers ==="
pkill -f 'org.apache.rocketmq.example.benchmark' 2>/dev/null && echo "killed benchmark" || echo "no benchmark proc"
pkill -f 'Probe produce' 2>/dev/null && echo "killed Probe" || echo "no Probe proc"
sleep 2
echo "=== procs after ==="
ps -ef | grep -E 'benchmark|Probe|producer' | grep -v grep || echo "none"

for T in BenchTopic_1K ft_topic; do
  echo "=== create topic $T on all 3 groups (8r8w) ==="
  for b in broker-a broker-b broker-c; do
    $MQ/bin/mqadmin updateTopic -n $NS -b $b -t $T -r 8 -w 8 2>&1 | tail -1
  done
done
sleep 3
echo "=== topicRoute BenchTopic_1K ==="
$MQ/bin/mqadmin topicRoute -n $NS -t BenchTopic_1K 2>&1 | grep -E 'brokerName|writeQueueNums' | head -12
echo "=== topicRoute ft_topic ==="
$MQ/bin/mqadmin topicRoute -n $NS -t ft_topic 2>&1 | grep -E 'brokerName|writeQueueNums' | head -12
