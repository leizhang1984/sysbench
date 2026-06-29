#!/usr/bin/env bash
# Scenario B: freeze ES with SIGSTOP (simulates a silent VM hang - no RST).
PID=$(pgrep -f 'org.elasticsearch.bootstrap.Elasticsearch')
echo "STOP_AT=$(date +%H:%M:%S.%N) PID=$PID"
kill -STOP "$PID"
sleep 1
echo "proc_state=$(ps -o stat= -p $PID)"
echo "(T = stopped/frozen)"
