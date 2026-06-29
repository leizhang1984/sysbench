#!/bin/bash
RMQ=/opt/rocketmq-4.9.7
NS="10.161.0.4:9876;10.161.0.5:9876;10.161.0.6:9876"
export NAMESRV_ADDR="$NS"
cd "$RMQ" || exit 1
# Recreate ft_topic across whole cluster (a group lost it after store wipe)
sh bin/mqadmin updateTopic -n "$NS" -c RocketMQCluster -t ft_topic -w 8 -r 8 2>&1 | tail -5
echo "---- route ----"
sh bin/mqadmin topicRoute -n "$NS" -t ft_topic 2>&1 | grep -E 'brokerName|writeQueueNums|readQueueNums' | head -40
echo "DONE"
