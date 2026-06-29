#!/bin/bash
# Launch the failover probe in produce mode, fully detached so it survives the
# run-command return. Args: TOPIC THREADS DURATION RATE RUNID [RETRIES]
TOPIC=$1; THREADS=$2; DUR=$3; RATE=$4; RUNID=$5; RETRIES=${6:-0}
NS="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"
export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
cd /opt/probe
CSV=/opt/probe/$RUNID.csv
LOG=/opt/probe/$RUNID.console.log
rm -f "$CSV" "$LOG"
setsid nohup java -cp "/opt/probe:/opt/rocketmq-4.9.7/lib/*" Probe produce "$NS" "$TOPIC" "$THREADS" "$DUR" "$RATE" "$CSV" "$RUNID" "$RETRIES" > "$LOG" 2>&1 < /dev/null &
sleep 3
echo "PROBE launched runId=$RUNID topic=$TOPIC threads=$THREADS dur=$DUR rate=$RATE retries=$RETRIES"
echo "pid=$(pgrep -f "Probe produce.*$RUNID" | head -1)"
echo "--- first console lines ---"
head -6 "$LOG" 2>/dev/null
