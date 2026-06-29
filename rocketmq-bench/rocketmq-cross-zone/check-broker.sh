#!/bin/bash
# Observe broker recovery after power-cut (do NOT kill - let it recover naturally).
for i in $(seq 1 30); do
  A=$(systemctl is-active rocketmq-broker 2>/dev/null)
  ss -lnt 2>/dev/null | grep -q ':10911 ' && L=listening || L=no
  N=$(systemctl show rocketmq-broker -p NRestarts --value 2>/dev/null)
  UP=$(uptime -p 2>/dev/null)
  echo "t=$((i*5))s active=$A port=$L restarts=$N uptime=$UP"
  [ "$L" = listening ] && break
  sleep 5
done
echo "---- last broker.log ----"
tail -8 /datadisk/rocketmq/logs/rocketmqlogs/broker.log 2>/dev/null
echo "---- journal ----"
journalctl -u rocketmq-broker -n 6 --no-pager 2>/dev/null | tail -6
