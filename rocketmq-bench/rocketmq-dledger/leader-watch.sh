#!/bin/bash
# Watch broker-a leader transition. Polls clusterList every 2s for up to N polls.
# Prints timestamped BID=0 addr each time it changes. Arg1 = total seconds (default 60).
MQ=/opt/rocketmq-4.9.7
NS=10.170.0.6:9876
TOTAL=${1:-60}
prev=""
end=$((SECONDS+TOTAL))
while [ $SECONDS -lt $end ]; do
  cur=$($MQ/bin/mqadmin clusterList -n $NS 2>/dev/null | awk '$2=="broker-a" && $3=="0"{print $4}')
  ts=$(date -u +%H:%M:%S)
  if [ "$cur" != "$prev" ]; then
    echo "$ts  broker-a BID0 -> ${cur:-<none/unavailable>}"
    prev="$cur"
  fi
  sleep 2
done
echo "FINAL $(date -u +%H:%M:%S): $($MQ/bin/mqadmin clusterList -n $NS 2>/dev/null | awk 'NR==1||$2=="broker-a"')"
