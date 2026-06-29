#!/bin/bash
# Start a detached Probe producer on the client. Args: runId threads durSec ratePerThread retries
# Writes CSV to /opt/probe/<runId>.csv and console to /opt/probe/<runId>.console.log
RUNID=$1; TH=${2:-10}; DUR=${3:-260}; RATE=${4:-100}; RETRIES=${5:-0}
MQ=/opt/rocketmq-4.9.7
NS="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"
cd /opt/probe
JAVA_BIN=$(readlink -f "$(which java)")
export JAVA_HOME=$(dirname "$(dirname "$JAVA_BIN")")
CP=".:$MQ/lib/*"
setsid "$JAVA_HOME/bin/java" -cp "$CP" Probe produce "$NS" ft_topic $TH $DUR $RATE /opt/probe/$RUNID.csv $RUNID $RETRIES \
  > /opt/probe/$RUNID.console.log 2>&1 < /dev/null &
sleep 6
echo "=== producer $RUNID started (threads=$TH dur=$DUR rate=$RATE retries=$RETRIES, ~$((TH*RATE))/s) ==="
head -5 /opt/probe/$RUNID.console.log
echo "--- proc ---"
ps -ef | grep "Probe produce" | grep -v grep | head -1 || echo "none"
