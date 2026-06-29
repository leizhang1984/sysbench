#!/bin/bash
echo "=== HOST: $(hostname) ==="
echo "--- rocketmq-broker.service status ---"
systemctl status rocketmq-broker.service --no-pager -l 2>/dev/null | head -20
echo "=== journalctl rocketmq-broker last 25 ==="
journalctl -u rocketmq-broker.service --no-pager -n 25 2>/dev/null
echo "=== broker.log ERROR/Exception/Caused (last 30 matches) ==="
grep -nE 'ERROR|Exception|Caused by|DLedger|No enough|election|not ready|disk' /datadisk/rocketmq/logs/broker.log 2>/dev/null | tail -30
echo "=== disk usage ==="
df -h /datadisk
