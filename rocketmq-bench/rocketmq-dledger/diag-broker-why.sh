#!/bin/bash
echo "=== HOST: $(hostname) ==="
echo "--- systemctl status (broker unit) ---"
UNIT=$(systemctl list-units --type=service --all 2>/dev/null | grep -iE 'rocketmq|broker' | awk '{print $1}' | head -1)
echo "UNIT=$UNIT"
systemctl status "$UNIT" --no-pager -l 2>/dev/null | head -25
echo "--- journalctl last 30 ---"
journalctl -u "$UNIT" --no-pager -n 30 2>/dev/null
echo "--- disk space ---"
df -h /datadisk 2>/dev/null || df -h /
echo "--- store dir ---"
ls -ld /datadisk/rocketmq/store 2>/dev/null || echo "no store dir"
echo "--- broker config ---"
ls -la /opt/rocketmq-4.9.7/conf/broker-dledger.conf 2>/dev/null
echo "--- find broker logs ---"
find / -name 'broker.log' 2>/dev/null | head -5
