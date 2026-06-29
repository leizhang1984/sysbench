#!/bin/bash
IP=$(hostname -I | awk '{print $1}')
PID=$(pgrep -f BrokerStartup | head -1)
echo "host=$IP pid=$PID"
if [ -n "$PID" ]; then
  echo "stat=$(ps -o stat= -p $PID) state=$(awk '{print $3}' /proc/$PID/stat 2>/dev/null)"
fi
echo "--- freeze-event ---"
cat /tmp/freeze-event.log 2>/dev/null || echo "(none)"
