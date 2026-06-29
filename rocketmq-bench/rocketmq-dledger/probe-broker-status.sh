#!/bin/bash
echo "=== host ==="; hostname; hostname -I
echo "=== broker proc ==="
ps -ef | grep -E 'BrokerStartup|mqbroker' | grep -v grep | wc -l
echo "=== service ==="
systemctl is-active rocketmq-broker.service 2>/dev/null || echo "no-service"
systemctl --no-pager status rocketmq-broker.service 2>/dev/null | head -n 4
echo "=== listen ports ==="
ss -lntp 2>/dev/null | grep -E '10911|40911' || echo "(no broker ports)"
