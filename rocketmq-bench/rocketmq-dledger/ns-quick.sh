#!/bin/bash
echo "HOST=$(hostname)"
echo "active=$(systemctl is-active rocketmq-namesrv 2>/dev/null)"
pgrep -f NamesrvStartup >/dev/null && echo "proc=UP" || echo "proc=DOWN"
ss -ltn 2>/dev/null | grep -q ':9876' && echo "port9876=Y" || echo "port9876=N"
echo "--- last 8 namesrv journal ---"
journalctl -u rocketmq-namesrv --no-pager -n 8 2>/dev/null | tail -8
