#!/bin/bash
set +e
echo "=== HOST: $(hostname) ==="
echo "--- systemctl status (tail) ---"
systemctl status rocketmq-broker.service --no-pager -l 2>&1 | tail -n 20
echo "--- journal (last 25) ---"
journalctl -u rocketmq-broker.service --no-pager -n 25 2>&1
echo "--- df /datadisk ---"
df -h /datadisk | tail -1
echo "--- broker.log tail ---"
tail -n 15 /datadisk/rocketmq/logs/broker.log 2>/dev/null
echo "--- broker_default.log tail ---"
tail -n 15 /datadisk/rocketmq/logs/broker_default.log 2>/dev/null
