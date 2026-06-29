#!/bin/bash
set +e
echo "=== find broker logs ==="
find / -name 'broker*.log' 2>/dev/null | head -20
echo "=== rocketmqlogs dir (root home) ==="
ls -la /root/logs/rocketmqlogs/ 2>/dev/null | head
echo "=== tail broker.log @ root home ==="
tail -n 40 /root/logs/rocketmqlogs/broker.log 2>/dev/null
echo "=== grep load/recover/exit in root broker.log ==="
grep -nE 'load|recover|exit|Error|Exception|Caused|DLedger|abnormal|crc|corrupt' /root/logs/rocketmqlogs/broker.log 2>/dev/null | tail -n 40
echo "=== store dir sizes ==="
du -sh /datadisk/rocketmq/store/* 2>/dev/null
