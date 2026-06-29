#!/bin/bash
systemctl stop rmq-broker 2>/dev/null || true
sleep 2
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
timeout 20 /opt/rocketmq-4.9.7/bin/mqbroker -c /opt/rocketmq-4.9.7/conf/broker.conf 2>&1 | head -40
