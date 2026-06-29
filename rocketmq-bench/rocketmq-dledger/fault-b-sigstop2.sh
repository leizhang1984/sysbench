#!/bin/bash
# Fault B (robust): SIGSTOP freeze broker-a Leader, VERIFY freeze took effect, then SIGCONT.
# Run ON the Leader VM. Arg1 = freeze seconds (default 50).
MQ=/opt/rocketmq-4.9.7
NS=10.170.0.6:9876
LOG=/datadisk/rocketmq/logs/broker.log
HOLD=${1:-50}
mapfile -t PIDS < <(pgrep -f 'org.apache.rocketmq.broker.BrokerStartup')
echo "host=$(hostname) BrokerStartup PIDs: ${PIDS[*]}"
if [ ${#PIDS[@]} -eq 0 ]; then echo "NO BROKER PID"; exit 1; fi
echo "ledger tail BEFORE freeze:"; grep -E 'LEADER\] term' $LOG 2>/dev/null | tail -1
echo "T0_STOP=$(date -u +%H:%M:%S.%3N)"
for p in "${PIDS[@]}"; do kill -STOP "$p"; done
sleep 1
echo "states right after STOP: $(for p in "${PIDS[@]}"; do echo -n "$p=$(ps -o stat= -p $p 2>/dev/null) "; done)"
sleep 12
echo "T+13s state: $(for p in "${PIDS[@]}"; do echo -n "$p=$(ps -o stat= -p $p 2>/dev/null) "; done)"
echo "ledger tail at T+13s (should be SAME as before if frozen):"; grep -E 'LEADER\] term' $LOG 2>/dev/null | tail -1
echo "NS view of broker-a at T+13s:"; $MQ/bin/mqadmin clusterList -n $NS 2>/dev/null | awk '$2=="broker-a"'
sleep $((HOLD-13))
for p in "${PIDS[@]}"; do kill -CONT "$p"; done
echo "T1_CONT=$(date -u +%H:%M:%S.%3N)"
echo "states after CONT: $(for p in "${PIDS[@]}"; do echo -n "$p=$(ps -o stat= -p $p 2>/dev/null) "; done)"
echo "ledger tail AFTER cont:"; grep -E 'LEADER\] term' $LOG 2>/dev/null | tail -1
