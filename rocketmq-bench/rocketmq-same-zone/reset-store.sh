#!/bin/bash
systemctl stop rmq-broker 2>/dev/null || true
pkill -9 -f BrokerStartup 2>/dev/null || true
sleep 3
# fresh slave with no real data: clear store to remove inconsistent pre-allocated commitlog from live migration
rm -rf /datadisk/rocketmq/store
mkdir -p /datadisk/rocketmq/store/commitlog /datadisk/rocketmq/store/consumequeue
systemctl reset-failed rmq-broker
systemctl start rmq-broker
sleep 15
systemctl is-active rmq-broker
ss -lnt | grep -q 10911 && echo "10911 listening" || echo "NOT listening"
journalctl -u rmq-broker --no-pager -n 5 | tail -5
