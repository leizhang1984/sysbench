#!/bin/bash
echo "=== HOST: $(hostname) ==="
echo "--- namesrv service ---"
systemctl reset-failed rocketmq-namesrv.service 2>/dev/null
systemctl start rocketmq-namesrv.service 2>/dev/null
sleep 5
systemctl is-active rocketmq-namesrv.service
pgrep -f NamesrvStartup >/dev/null && echo "proc=UP" || echo "proc=DOWN"
ss -ltn 2>/dev/null | grep ':9876' && echo "9876 LISTEN" || echo "9876 NOT-LISTEN"
