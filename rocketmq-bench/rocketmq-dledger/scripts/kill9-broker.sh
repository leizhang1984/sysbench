#!/bin/bash
# Hard-kill the broker JVM with SIGKILL (kill -9). systemd will try to restart it.
PID=$(pgrep -f BrokerStartup | head -1)
if [ -z "$PID" ]; then echo "NO_BROKER_PID host=$(hostname -I | awk '{print $1}')"; exit 1; fi
kill -9 "$PID"
echo "KILLED host=$(hostname -I | awk '{print $1}') pid=$PID at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
