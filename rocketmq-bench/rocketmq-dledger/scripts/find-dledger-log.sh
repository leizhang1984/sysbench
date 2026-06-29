#!/bin/bash
IP=$(hostname -I | awk '{print $1}')
echo "host=$IP"
echo "=== log files ==="
ls -la /datadisk/rocketmq/logs/ 2>/dev/null | head -40
echo "=== grep election-ish terms across logs (last 12) ==="
grep -aihE 'become|leader|vote|term=|candidate|electi' /datadisk/rocketmq/logs/*.log 2>/dev/null | tail -12
