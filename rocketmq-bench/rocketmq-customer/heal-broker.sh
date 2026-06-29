#!/bin/bash
A=$(systemctl is-active rmq-broker 2>/dev/null)
ss -lnt | grep -q 10911 && L=listening || L="NOT-listening"
echo "active=$A port=$L"
if [ "$A" != "active" ] || [ "$L" != "listening" ]; then
  echo "RECOVERING (clearing store - fresh node, no data)"
  systemctl stop rmq-broker 2>/dev/null || true
  pkill -9 -f BrokerStartup 2>/dev/null || true
  sleep 3
  rm -rf /datadisk/rocketmq/store
  mkdir -p /datadisk/rocketmq/store/commitlog /datadisk/rocketmq/store/consumequeue
  systemctl reset-failed rmq-broker
  systemctl start rmq-broker
  sleep 15
  echo "after: $(systemctl is-active rmq-broker)"
  ss -lnt | grep -q 10911 && echo "10911 listening" || echo "still NOT listening"
fi
