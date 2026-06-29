#!/bin/bash
LOG=/datadisk/rocketmq/logs/broker.log
echo "=== a-1 recent DLedger role lines ==="
grep -iE 'become|leader|follower|candidate|roleChange|MASTER|SLAVE' "$LOG" 2>/dev/null | tail -15
echo "=== a-1 self check ==="
ps -ef | grep BrokerStartup | grep -v grep | awk '{print "pid="$2}'
systemctl is-active rocketmq-broker
