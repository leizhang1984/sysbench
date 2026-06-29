#!/bin/bash
# Stop crash-loop, run broker in foreground long enough, capture REAL error.
systemctl stop rmq-broker 2>/dev/null
pkill -9 -f 'java.*BrokerStartup' 2>/dev/null
sleep 3
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
# mark log position
LINES_BEFORE=$(wc -l < /datadisk/rocketmq/logs/broker.log 2>/dev/null || echo 0)
echo "broker.log lines before=$LINES_BEFORE"
# run foreground up to 90s, capture stdout+stderr
timeout 90 "$ROCKETMQ_HOME/bin/mqbroker" -c "$ROCKETMQ_HOME/conf/broker.conf" > /opt/ft/fg-out.log 2>&1
echo "foreground rc=$?"
echo "=== stdout/stderr (non-warning) ==="
grep -vE 'WARNING|illegal reflective|consider reporting|--illegal-access|All illegal' /opt/ft/fg-out.log | tail -n 30
echo "=== new broker.log lines ==="
tail -n +$((LINES_BEFORE+1)) /datadisk/rocketmq/logs/broker.log 2>/dev/null | grep -iE 'error|exception|exit|fail|load|recover' | tail -n 25
echo "=== dmesg OOM ==="
dmesg 2>/dev/null | grep -iE 'oom|killed process|out of memory' | tail -n 8
