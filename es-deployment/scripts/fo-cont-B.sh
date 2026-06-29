#!/usr/bin/env bash
# Scenario B: after ~45s frozen, resume ES with SIGCONT.
sleep 45
PID=$(pgrep -f 'org.elasticsearch.bootstrap.Elasticsearch')
echo "CONT_AT=$(date +%H:%M:%S.%N) PID=$PID"
kill -CONT "$PID"
sleep 2
echo "proc_state=$(ps -o stat= -p $PID)"
echo "(S/R = running again)"
