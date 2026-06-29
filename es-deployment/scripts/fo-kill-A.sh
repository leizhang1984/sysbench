#!/usr/bin/env bash
# Scenario A: kill -9 the ES process on this node and record the exact time.
PID=$(pgrep -f 'org.elasticsearch.bootstrap.Elasticsearch')
echo "KILL_AT=$(date +%H:%M:%S.%N) PID=$PID"
kill -9 "$PID"
sleep 1
echo "AFTER_KILL pid_check=$(pgrep -f 'org.elasticsearch.bootstrap.Elasticsearch' || echo GONE)"
echo "service_status=$(systemctl is-active elasticsearch)"
