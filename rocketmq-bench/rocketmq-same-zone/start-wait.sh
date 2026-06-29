#!/bin/bash
systemctl reset-failed rmq-broker 2>/dev/null
pkill -9 -f 'java.*BrokerStartup' 2>/dev/null
sleep 2
systemctl start rmq-broker
for i in $(seq 1 18); do
  sleep 5
  A=$(systemctl is-active rmq-broker)
  ss -lnt | grep -q ':10911 ' && L=listening || L=no
  echo "t=$((i*5))s active=$A port=$L"
  [ "$L" = listening ] && break
done
