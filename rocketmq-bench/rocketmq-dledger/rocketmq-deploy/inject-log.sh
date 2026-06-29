#!/bin/bash
echo "now_epoch=$(date +%s)"
echo "broker_active=$(systemctl is-active rocketmq-broker)"
echo "inject_unit=$(systemctl is-active inject-scenario.service)"
echo "--- inject log ---"
cat /var/log/inject-scenario.log 2>/dev/null
echo "--- port 40911 ---"
ss -ltn 2>/dev/null | grep ':40911' || echo "PORT_DOWN"
