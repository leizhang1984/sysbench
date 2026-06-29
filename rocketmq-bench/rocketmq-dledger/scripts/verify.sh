#!/bin/bash
# verify.sh <topic> <runId> <idleSec>
TOPIC="$1"; RUNID="$2"; IDLE="${3:-20}"
NS="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"
export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
cd /opt/probe || exit 1
java -cp "/opt/probe:/opt/rocketmq-4.9.7/lib/*" Probe verify "$NS" "$TOPIC" "$RUNID" "$IDLE" 2>&1 | grep -E "VERIFY_DONE|Exception|ERROR" | tail -20
