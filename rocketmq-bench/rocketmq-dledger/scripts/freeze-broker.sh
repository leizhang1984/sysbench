#!/bin/bash
# Freeze the broker JVM with SIGSTOP (simulates whole-machine silence / no RST).
PID=$(pgrep -f BrokerStartup | head -1)
if [ -z "$PID" ]; then echo "NO_BROKER_PID host=$(hostname -I | awk '{print $1}')"; exit 1; fi
kill -STOP "$PID"
echo "FROZEN host=$(hostname -I | awk '{print $1}') pid=$PID at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
cat /proc/$PID/stat | awk '{print "procstate="$3}'
