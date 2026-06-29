#!/bin/bash
RMQ=$(ls -d /opt/rocketmq-* 2>/dev/null | head -1)
[ -z "$RMQ" ] && RMQ=/opt/rocketmq-4.9.7
export ROCKETMQ_HOME="$RMQ"
export JAVA_HOME=${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}
NS="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"
export NAMESRV_ADDR="$NS"
TOPIC=TopicTest
echo "=== create $TOPIC on whole cluster (spreads to broker-a/b/c) ==="
sh "$RMQ/bin/mqadmin" updateTopic -n "$NS" -c RocketMQCluster -t "$TOPIC" -w 8 -r 8 2>&1 | tail -5
echo "=== send 1000 messages via quickstart Producer ==="
sh "$RMQ/bin/tools.sh" org.apache.rocketmq.example.quickstart.Producer 2>/dev/null | grep -oE 'broker-[abc]' | sort | uniq -c
echo "=== topicStatus: per-broker queue offsets (max>0 means traffic landed) ==="
sh "$RMQ/bin/mqadmin" topicStatus -n "$NS" -t "$TOPIC" 2>/dev/null
