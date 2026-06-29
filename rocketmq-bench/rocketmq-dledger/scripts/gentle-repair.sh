#!/bin/bash
# gentle-repair.sh : try to recover a crash-looping DLedger node WITHOUT losing
# the commitlog. Keeps dledger-n* (raft commitlog) + config/; removes only the
# derived/runtime artifacts (consumequeue, index, checkpoint, abort) so the
# broker rebuilds them from the commitlog on restart.
SELF=$(grep -E '^dLegerSelfId' /opt/rocketmq-4.9.7/conf/broker-dledger.conf | cut -d= -f2 | tr -d ' \r')
STORE=/datadisk/rocketmq/store
IP=$(hostname -I | awk '{print $1}')
echo "host=$IP self=$SELF"
systemctl stop rocketmq-broker.service 2>/dev/null
pkill -9 -f 'java.*BrokerStartup' 2>/dev/null
sleep 2
echo "before: $(du -sh $STORE/dledger-$SELF 2>/dev/null)"
rm -rf "$STORE/consumequeue" "$STORE/index" "$STORE/abort" "$STORE/checkpoint"
systemctl reset-failed rocketmq-broker.service 2>/dev/null
systemctl start rocketmq-broker.service
sleep 30
echo "active=$(systemctl is-active rocketmq-broker.service) restarts=$(systemctl show rocketmq-broker.service -p NRestarts --value)"
echo "jvmPid=$(pgrep -f 'java.*BrokerStartup' | head -1)"
echo "--- broker.log tail ---"
tail -6 /datadisk/rocketmq/logs/broker.log 2>/dev/null
