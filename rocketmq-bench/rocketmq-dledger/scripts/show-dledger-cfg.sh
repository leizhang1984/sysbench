#!/bin/bash
CONF=/opt/rocketmq-4.9.7/conf/broker-dledger.conf
echo "=== broker-dledger.conf (relevant) ==="
grep -iE "heartBeat|election|Timeout|Interval|preferred|dLeger|sendMessageThread|brokerRole|flushDisk" "$CONF" 2>/dev/null
echo "=== nameserver heartbeat-related (broker -> ns) ==="
grep -iE "registerNameServerPeriod|heartbeatTimeoutMillis|registerBrokerTimeoutMills" "$CONF" 2>/dev/null
echo "(空 = 用默认值)"
