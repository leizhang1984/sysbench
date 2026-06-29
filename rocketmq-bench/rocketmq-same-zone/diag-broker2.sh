#!/bin/bash
systemctl stop rmq-broker 2>/dev/null || true
sleep 3
echo "=== latest broker.log exceptions ==="
grep -iE 'exception|error|lock|caused by|register' /datadisk/rocketmq/logs/broker.log 2>/dev/null | tail -20
echo "=== broker_default.log ==="
ls -la /datadisk/rocketmq/logs/ 2>/dev/null
tail -30 /datadisk/rocketmq/logs/broker_default.log 2>/dev/null
