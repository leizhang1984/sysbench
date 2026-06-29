#!/bin/bash
CFG=$(ls /opt/rocketmq-4.9.7/conf/broker-dledger.conf 2>/dev/null \
   || ls /opt/rocketmq-4.9.7/conf/*.conf 2>/dev/null | head -1)
echo "=== config file: $CFG ==="
cat "$CFG"
echo "=== systemd unit ==="
cat /etc/systemd/system/rocketmq-broker.service 2>/dev/null
echo "=== runtime.conf (JVM) ==="
grep -E '^\s*(-Xms|-Xmx|-Xmn|-XX:)' /opt/rocketmq-4.9.7/bin/runbroker.sh | head -20
