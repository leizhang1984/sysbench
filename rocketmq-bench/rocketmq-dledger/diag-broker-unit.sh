#!/bin/bash
echo "=== HOST: $(hostname) ==="
echo "--- rocketmq unit files ---"
systemctl list-unit-files 2>/dev/null | grep -iE 'rocketmq|mqbroker' 
echo "--- all units containing rocketmq/mq ---"
systemctl list-units --all 2>/dev/null | grep -iE 'rocketmq|mqbroker'
echo "--- broker.log tail 40 ---"
tail -n 40 /datadisk/rocketmq/logs/broker.log 2>/dev/null
echo "--- broker config content ---"
cat /opt/rocketmq-4.9.7/conf/broker-dledger.conf 2>/dev/null
