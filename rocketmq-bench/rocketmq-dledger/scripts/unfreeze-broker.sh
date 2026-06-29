#!/bin/bash
# Resume any frozen broker processes (both wrapper shell and JVM) with SIGCONT.
IP=$(hostname -I | awk '{print $1}')
PIDS=$(pgrep -f BrokerStartup)
if [ -z "$PIDS" ]; then echo "NO_BROKER_PID host=$IP"; exit 1; fi
for p in $PIDS; do kill -CONT "$p" 2>/dev/null; done
echo "RESUMED host=$IP pids=$PIDS at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
sleep 1
for p in $PIDS; do echo "pid=$p stat=$(ps -o stat= -p $p 2>/dev/null)"; done
