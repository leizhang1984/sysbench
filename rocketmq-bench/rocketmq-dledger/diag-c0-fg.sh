#!/bin/bash
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
echo "=== stop systemd loop ==="
systemctl stop rocketmq-broker.service 2>/dev/null
sleep 2
echo "=== foreground run, capture full output ==="
timeout 25 "$ROCKETMQ_HOME/bin/mqbroker" -c "$ROCKETMQ_HOME/conf/broker-dledger.conf" > /tmp/bk.out 2>&1
echo "exit=$?"
echo "=== RAW last 60 lines ==="
tail -n 60 /tmp/bk.out
echo "=== errors/exceptions ==="
grep -nE 'Error|Exception|Caused|fail|Fail|exit|Lock|recover|DLedger|raft|disk|Disk|space' /tmp/bk.out | tail -n 40
