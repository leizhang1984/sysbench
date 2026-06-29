#!/bin/bash
echo "=== start-broker.sh ==="; cat /opt/rocketmq-4.9.7/bin/start-broker.sh
echo "=== last 12 broker.log ts ==="; tail -3 /datadisk/rocketmq/logs/broker.log
echo "=== count crash ==="; systemctl show rmq-broker -p NRestarts
