#!/bin/bash
RUNID=rpo6; DUR=180; TH=8; RATE=80; RET=0
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
ROCKETMQ_HOME=/opt/rocketmq-4.9.7
NS="10.163.0.4:9876;10.163.0.5:9876;10.163.0.6:9876"
mkdir -p /opt/probe
java -cp "$ROCKETMQ_HOME/lib/*:/opt/probe" Probe produce "$NS" ft_topic "$TH" "$DUR" "$RATE" "/opt/probe/ft_${RUNID}.csv" "$RUNID" "$RET" > "/opt/probe/produce_${RUNID}.log" 2>&1
echo "PRODUCE_FG_DONE $RUNID"
tail -3 "/opt/probe/produce_${RUNID}.log"
