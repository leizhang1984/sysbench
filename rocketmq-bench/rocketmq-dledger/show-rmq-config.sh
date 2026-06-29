#!/bin/bash
set -e
if [ -f /opt/rocketmq-4.9.7/conf/namesrv.properties ]; then
  echo "=== /opt/rocketmq-4.9.7/conf/namesrv.properties ==="
  cat /opt/rocketmq-4.9.7/conf/namesrv.properties
fi
if [ -f /opt/rocketmq-4.9.7/conf/broker-dledger.conf ]; then
  echo "=== /opt/rocketmq-4.9.7/conf/broker-dledger.conf ==="
  cat /opt/rocketmq-4.9.7/conf/broker-dledger.conf
fi
