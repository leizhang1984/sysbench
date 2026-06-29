#!/bin/bash
IP=$(hostname -I | awk '{print $1}')
PID=$(pgrep -f BrokerStartup | head -1)
echo "host=$IP pid=$PID stat=$(ps -o stat= -p $PID 2>/dev/null)"
echo "now=$(date -u +%H:%M:%S)Z"
echo "--- broker.log last mtime + tail ts (logback tz=UTC+8) ---"
ls -la --time-style=+%H:%M:%S /datadisk/rocketmq/logs/broker.log
tail -2 /datadisk/rocketmq/logs/broker.log
echo "--- freeze event ---"
cat /tmp/freeze-event.log 2>/dev/null || echo none
