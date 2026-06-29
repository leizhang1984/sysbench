#!/bin/bash
echo "=== HOST: $(hostname) IP: $(hostname -I| awk '{print $1}') ==="
echo "--- broker service unit ---"
systemctl is-active rocketmq-broker 2>/dev/null || systemctl is-active broker 2>/dev/null || echo "no broker unit/active"
echo "--- BrokerStartup process ---"
if ps -ef | grep BrokerStartup | grep -v grep >/dev/null; then
  echo "PROC:RUNNING"
else
  echo "PROC:NOT-RUNNING"
fi
echo "--- listen ports (10911/40911/10909) ---"
ss -ltn | grep -E '10911|40911|10909' || echo "NO-BROKER-PORTS"
echo "--- last broker.log errors ---"
LOG=$(ls -1t /datadisk/rocketmq/logs/rocketmqlogs/broker.log /root/logs/rocketmqlogs/broker.log /opt/rocketmq-4.9.7/logs/rocketmqlogs/broker.log 2>/dev/null | head -1)
echo "LOGFILE=$LOG"
if [ -n "$LOG" ]; then
  tail -n 8 "$LOG"
fi
