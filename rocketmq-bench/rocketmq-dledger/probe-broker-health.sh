#!/bin/bash
echo "=== HOST $(hostname) ==="
systemctl is-active rocketmq-broker.service 2>/dev/null || true
systemctl is-active rmq-broker.service 2>/dev/null || true
ps -ef | grep -E 'mqbroker|BrokerStartup' | grep -v grep || true
ss -lntp 2>/dev/null | grep -E ':10911|:10909|:10912|:40911' || true
grep -E 'brokerName=|brokerId=|dLegerGroup=|dLegerSelfId=|dLegerPeers=|namesrvAddr=' /opt/rocketmq-4.9.7/conf/broker*.conf 2>/dev/null || true
grep -E 'brokerName=|brokerId=|dLegerGroup=|dLegerSelfId=|dLegerPeers=|namesrvAddr=' /opt/rocketmq-4.9.7/conf/broker-dledger.conf 2>/dev/null || true
