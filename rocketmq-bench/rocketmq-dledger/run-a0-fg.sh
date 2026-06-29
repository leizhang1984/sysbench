#!/bin/bash
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
echo "=== run mqbroker foreground, capture exit ==="
timeout 25 "$ROCKETMQ_HOME/bin/mqbroker" -c "$ROCKETMQ_HOME/conf/broker-dledger.conf" > /tmp/bk.out 2>&1
echo "exit=$?"
echo "=== last 40 lines (non subscription-group) ==="
grep -vE 'load exist subscription|load /datadisk.*OK|consumeEnable' /tmp/bk.out | tail -n 40
