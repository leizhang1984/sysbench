#!/bin/bash
systemctl stop rocketmq-broker 2>/dev/null
sleep 2
echo "=== ports 40911/10911 ==="
ss -ltnp 2>/dev/null | grep -E '40911|10911' || echo "none listening"
echo "=== leftover java procs ==="
ps -ef | grep -i 'java\|Broker' | grep -v grep
echo "=== dledger.log tail ==="
tail -n 30 /datadisk/rocketmq/logs/dledger.log 2>/dev/null || echo "no dledger.log"
echo "=== run foreground 30s, capture to /tmp/fg.out ==="
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
cd /opt/rocketmq-4.9.7
timeout 30 sh bin/mqbroker -c conf/broker-dledger.conf > /tmp/fg.out 2>&1
echo "exitcode=$?"
echo "=== /tmp/fg.out tail 40 ==="
tail -n 40 /tmp/fg.out
