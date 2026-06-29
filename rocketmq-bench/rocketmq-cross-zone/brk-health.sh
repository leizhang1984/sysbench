#!/bin/bash
# Check broker recovery state on the host it runs on.
echo "is-active=$(systemctl is-active rocketmq-broker)"
echo "sub-state=$(systemctl show rocketmq-broker -p SubState --value)"
echo "NRestarts=$(systemctl show rocketmq-broker -p NRestarts --value)"
echo "ExecMainStatus=$(systemctl show rocketmq-broker -p ExecMainStatus --value)"
ss -lnt | grep -q ':10911' && echo '10911 listening' || echo '10911 NOT listening'
echo "--- broker.log tail ---"
tail -12 /datadisk/rocketmq/logs/rocketmqlogs/broker.log 2>/dev/null
echo "--- journal tail ---"
journalctl -u rocketmq-broker -n 8 --no-pager 2>/dev/null
