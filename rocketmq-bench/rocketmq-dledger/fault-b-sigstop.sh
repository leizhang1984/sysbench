#!/bin/bash
# Fault B: SIGSTOP freeze broker-a Leader, watch DLedger re-election during freeze, then SIGCONT.
# Run ON the Leader VM. Arg1 = freeze seconds (default 50).
MQ=/opt/rocketmq-4.9.7
NS=10.170.0.6:9876
HOLD=${1:-50}
PID=$(pgrep -f 'org.apache.rocketmq.broker.BrokerStartup' | head -1)
if [ -z "$PID" ]; then echo "NO BROKER PID"; exit 1; fi
echo "broker pid=$PID host=$(hostname)"
echo "T0_STOP=$(date -u +%H:%M:%S.%3N)"
kill -STOP $PID
prev=""
end=$((SECONDS+HOLD))
while [ $SECONDS -lt $end ]; do
  cur=$($MQ/bin/mqadmin clusterList -n $NS 2>/dev/null | awk '$2=="broker-a" && $3=="0"{print $4}')
  if [ "$cur" != "$prev" ]; then
    echo "$(date -u +%H:%M:%S)  broker-a BID0(Leader) -> ${cur:-<none>}"
    prev="$cur"
  fi
  sleep 3
done
kill -CONT $PID
echo "T1_CONT=$(date -u +%H:%M:%S.%3N)"
echo "state after CONT: $(ps -o stat= -p $PID 2>/dev/null)"
echo "FINAL clusterList broker-a:"
$MQ/bin/mqadmin clusterList -n $NS 2>/dev/null | awk 'NR==1||$2=="broker-a"'
