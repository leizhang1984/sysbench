#!/bin/bash
LOGDIR=/opt/rocketmq-4.9.7/logs/rocketmqlogs
echo "=== logs present ==="
ls -la $LOGDIR 2>&1 | head -30
echo "=== broker.log FULL tail 60 ==="
tail -n 60 $LOGDIR/broker.log 2>&1
echo "=== broker_default.log tail 40 ==="
tail -n 40 $LOGDIR/broker_default.log 2>&1
echo "=== any *.log with Exception (last 30) ==="
grep -rnE 'Exception|Caused by|System.exit|initialize.*fail|load.*fail|Lock failed|ERROR' $LOGDIR 2>/dev/null | tail -n 30
