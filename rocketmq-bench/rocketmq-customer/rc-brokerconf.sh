#!/bin/bash
echo "host=$(hostname)"
cat /opt/rocketmq-4.9.7/conf/broker.conf 2>/dev/null || echo "no broker.conf"
