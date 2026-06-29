#!/bin/bash
RMQ=/opt/rocketmq-4.9.7
NS="10.162.0.4:9876;10.162.0.5:9876;10.162.0.6:9876"
export NAMESRV_ADDR="$NS"
cd "$RMQ" || exit 1
# Create/ensure ft_topic across whole cluster (spans a/b/c)
sh bin/mqadmin updateTopic -n "$NS" -c RocketMQCluster -t ft_topic -w 8 -r 8 2>&1 | tail -5
echo "---- route ----"
sh bin/mqadmin topicRoute -n "$NS" -t ft_topic 2>&1 | grep -E 'brokerName|writeQueueNums|readQueueNums' | head -40
echo "DONE"
