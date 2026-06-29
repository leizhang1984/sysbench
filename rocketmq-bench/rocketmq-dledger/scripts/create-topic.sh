#!/bin/bash
# create-topic.sh <topic>
T="$1"
export NAMESRV_ADDR="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"
cd /opt/rocketmq-4.9.7 || exit 1
sh bin/mqadmin updateTopic -n "$NAMESRV_ADDR" -c RocketMQCluster -t "$T" -r 8 -w 8 2>&1 | tail -5
echo "--- route ---"
sh bin/mqadmin topicRoute -n "$NAMESRV_ADDR" -t "$T" 2>&1 | grep -E "brokerName|10.170" | head -20
