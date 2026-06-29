#!/bin/bash
NS="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"
MQ=/opt/rocketmq-4.9.7/bin/mqadmin
export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
for T in ft_kill ft_stop ft_base; do
  $MQ updateTopic -n "$NS" -c RocketMQCluster -t "$T" -r 8 -w 8 2>&1 | tail -2
  echo "created topic=$T"
done
echo "=== route ft_kill ==="
$MQ topicRoute -n "$NS" -t ft_kill 2>/dev/null | grep -E 'brokerName|brokerAddrs|10.170' | head -20
