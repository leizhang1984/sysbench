#!/bin/bash
echo "--- dledger jar ---"
ls /opt/rocketmq-4.9.7/lib/ | grep -i dledger
echo "--- search preferredLeaderIds across all jars ---"
for j in /opt/rocketmq-4.9.7/lib/*.jar; do
  if unzip -p "$j" 2>/dev/null | strings | grep -aqi 'preferredLeaderId'; then
    echo "FOUND preferredLeaderId in $(basename $j)"
  fi
done
echo "--- search leadership transfer support ---"
for j in /opt/rocketmq-4.9.7/lib/*dledger*.jar; do
  echo "== $(basename $j) =="
  unzip -l "$j" 2>/dev/null | grep -iE 'LeadershipTransfer|LeaderElect' | head
done
echo "--- broker recognized dledger keys (MessageStoreConfig) ---"
for j in /opt/rocketmq-4.9.7/lib/rocketmq-store*.jar; do
  unzip -p "$j" org/apache/rocketmq/store/config/MessageStoreConfig.class 2>/dev/null | strings | grep -iE 'dLeger|preferredLeader' | head -20
done
