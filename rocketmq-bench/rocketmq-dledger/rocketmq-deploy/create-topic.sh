#!/bin/bash
# Create the failover test topic on BOTH DLedger broker groups so producer
# traffic spans both groups. In DLedger you create the topic against the
# broker cluster; specify each broker (group) leader addr via -b is per-broker,
# but simplest is cluster-wide with -c, which lands queues on all brokers.
. /etc/profile.d/rocketmq.sh
TOPIC="${1:-FailoverTopic}"
QUEUES="${2:-8}"
echo "Creating topic=$TOPIC queues=$QUEUES on cluster RocketMQCluster"
mqadmin updateTopic -n "$NAMESRV_ADDR" -c RocketMQCluster -t "$TOPIC" \
  -r "$QUEUES" -w "$QUEUES" 2>&1 | tail -n 20
echo "--- topicRoute ---"
mqadmin topicRoute -n "$NAMESRV_ADDR" -t "$TOPIC" 2>&1 | tail -n 40
