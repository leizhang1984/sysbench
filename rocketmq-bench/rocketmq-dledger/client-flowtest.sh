#!/bin/bash
export JAVA_HOME=${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}
RMQ=$(ls -d /opt/rocketmq-* 2>/dev/null | head -1)
[ -z "$RMQ" ] && RMQ=/opt/rocketmq-4.9.7
NS="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"
export NAMESRV_ADDR="$NS"
TOPIC=flowtest_$(date +%H%M%S)
echo "=== create topic $TOPIC across all 3 broker clusters ==="
for B in broker-a broker-b broker-c; do
  sh "$RMQ/bin/mqadmin" updateTopic -n "$NS" -c RocketMQCluster -b "" -t "$TOPIC" -w 8 -r 8 2>/dev/null | tail -1
done
sh "$RMQ/bin/mqadmin" updateTopic -n "$NS" -c RocketMQCluster -t "$TOPIC" -w 8 -r 8 2>&1 | tail -3
echo "=== send 60 messages via Producer ==="
export ROCKETMQ_HOME="$RMQ"
sh "$RMQ/bin/tools.sh" org.apache.rocketmq.example.quickstart.Producer 2>/dev/null | grep -E 'SendResult|brokerName|sendStatus' | head -80 > /tmp/send.out
echo "sent lines: $(wc -l < /tmp/send.out)"
echo "=== distinct broker targets that received traffic ==="
grep -oE 'broker-[abc]' /tmp/send.out | sort | uniq -c
echo "=== topicRoute for $TOPIC (which brokers serve it) ==="
sh "$RMQ/bin/mqadmin" topicRoute -n "$NS" -t "$TOPIC" 2>/dev/null | grep -E 'brokerName|Topic[A-Za-z]*Queue' | head -40
echo "=== topicStats: per-queue offsets prove messages landed on each broker ==="
sh "$RMQ/bin/mqadmin" topicStatus -n "$NS" -t "$TOPIC" 2>/dev/null | head -60
