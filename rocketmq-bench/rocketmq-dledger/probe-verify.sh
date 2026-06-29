#!/bin/bash
# Verify consumed unique count for RPO. Args: runId idleSec(default 25)
RUNID=$1; IDLE=${2:-25}
MQ=/opt/rocketmq-4.9.7
NS="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"
cd /opt/probe
JAVA_BIN=$(readlink -f "$(which java)")
export JAVA_HOME=$(dirname "$(dirname "$JAVA_BIN")")
CP=".:$MQ/lib/*"
"$JAVA_HOME/bin/java" -cp "$CP" Probe verify "$NS" ft_topic $RUNID $IDLE 2>&1 | grep -E 'VERIFY_DONE|VERIFY consuming'
echo "--- producer side okTotal for $RUNID ---"
awk -F',' 'END{print "okTotal="$6" failTotal="$7}' /opt/probe/$RUNID.csv 2>/dev/null
