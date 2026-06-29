#!/bin/bash
echo "=== hostname / ip ==="
hostname
hostname -I
echo "=== namesrv proc ==="
ps -ef | grep -E 'NamesrvStartup|mqnamesrv' | grep -v grep | head
echo "=== listen 9876 ==="
ss -lntp 2>/dev/null | grep 9876 || echo "(9876 not listening)"
echo "=== service ==="
systemctl --no-pager -l status rocketmq-namesrv.service 2>/dev/null | head -n 8
systemctl list-units --type=service --no-pager 2>/dev/null | grep -iE 'name|mq' | head
