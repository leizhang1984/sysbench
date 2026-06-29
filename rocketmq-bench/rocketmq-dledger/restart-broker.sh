#!/bin/bash
# Reset failed restart counter and (re)start broker so all 3 nodes come up together
systemctl reset-failed rocketmq-broker.service 2>/dev/null
systemctl restart rocketmq-broker.service 2>/dev/null &
echo "restart issued on $(hostname) selfId=$(grep dLegerSelfId /opt/rocketmq-4.9.7/conf/broker-dledger.conf)"
