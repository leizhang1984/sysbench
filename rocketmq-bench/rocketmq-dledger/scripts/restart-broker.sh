#!/bin/bash
echo "=== restarting rocketmq-broker on $(hostname -I | awk '{print $1}') ==="
systemctl restart rocketmq-broker
sleep 18
echo "--- systemd state ---"
systemctl is-active rocketmq-broker
echo "--- broker pid ---"
pgrep -f 'BrokerStartup|mqbroker' | head -5
echo "done"
