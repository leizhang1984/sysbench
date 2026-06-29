#!/bin/bash
echo "=== HOST: $(hostname) IP: $(hostname -I) ==="
echo "--- namesrv service ---"
systemctl is-active rocketmq-namesrv 2>/dev/null || systemctl is-active namesrv 2>/dev/null || echo "no namesrv unit"
echo "--- java processes ---"
ps -ef | grep -E 'NamesrvStartup|BrokerStartup' | grep -v grep
echo "--- listen ports ---"
ss -ltn | grep -E '9876|10911|40911|10909' || echo "no rmq ports"
