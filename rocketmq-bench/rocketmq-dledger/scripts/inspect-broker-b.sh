#!/bin/bash
echo "==== broker-b-0 dledger conf ===="
grep -E 'brokerName|dLegerGroup|dLegerPeers|dLegerSelfId|preferredLeaderId|namesrvAddr' /opt/rocketmq-4.9.7/conf/broker-dledger.conf
echo "==== start-broker.sh (which conf) ===="
cat /opt/rocketmq-4.9.7/bin/start-broker.sh 2>/dev/null | grep -E 'conf|namesrv|dledger' -i
