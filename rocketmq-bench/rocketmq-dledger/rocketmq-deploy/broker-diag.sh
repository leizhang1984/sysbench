#!/bin/bash
echo "=== systemd status ==="
systemctl status rocketmq-broker --no-pager -l 2>/dev/null | head -n 15
echo "=== java proc ==="
pgrep -af 'org.apache.rocketmq.broker.BrokerStartup' || echo NO_JAVA
echo "=== last broker.log ==="
tail -n 25 /opt/rocketmq-4.9.7/logs/rocketmqlogs/broker.log 2>/dev/null
echo "=== broker_default / dledger appender errors ==="
tail -n 15 /opt/rocketmq-4.9.7/logs/rocketmqlogs/broker_default.log 2>/dev/null
