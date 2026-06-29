#!/bin/bash
IP=$(hostname -I | awk '{print $1}')
echo "host=$IP"
echo "--- systemctl status (short) ---"
systemctl status rocketmq-broker.service --no-pager -n 0 2>/dev/null | head -8
echo "--- broker.log tail ---"
tail -15 /datadisk/rocketmq/logs/broker.log 2>/dev/null
echo "--- journalctl last 15 ---"
journalctl -u rocketmq-broker.service --no-pager -n 15 2>/dev/null | tail -15
