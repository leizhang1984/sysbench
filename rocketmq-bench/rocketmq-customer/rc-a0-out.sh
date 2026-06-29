#!/bin/bash
echo "=== broker .out ==="; tail -40 /datadisk/rocketmq/logs/*.out 2>/dev/null; tail -40 ~/logs/rocketmqlogs/broker.out 2>/dev/null
echo "=== anywhere ==="; find / -name 'broker.out' 2>/dev/null
echo "=== ERROR lines ==="; grep -rn 'ERROR\|Exception\|Caused' /datadisk/rocketmq/logs/broker.log | tail -20
echo "=== run-command unit ==="; systemctl cat rmq-broker | tail -20
