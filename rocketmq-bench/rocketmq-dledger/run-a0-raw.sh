#!/bin/bash
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
timeout 25 "$ROCKETMQ_HOME/bin/mqbroker" -c "$ROCKETMQ_HOME/conf/broker-dledger.conf" > /tmp/bk.out 2>&1
echo "exit=$?"
echo "=== RAW last 50 lines ==="
tail -n 50 /tmp/bk.out
echo "=== any error/exception in whole out ==="
grep -nE 'Error|Exception|Caused|fail|Fail|exit|Lock|recover|DLedger|raft' /tmp/bk.out | tail -n 30
