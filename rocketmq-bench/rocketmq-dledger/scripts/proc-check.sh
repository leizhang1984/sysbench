#!/bin/bash
H=$(hostname)
PID=$(ps -ef | grep -i 'BrokerStartup' | grep -v grep | awk '{print $2}')
UP=$(systemctl is-active rocketmq-broker 2>/dev/null)
SELF=$(grep dLegerSelfId /opt/rocketmq-4.9.7/conf/broker-dledger.conf | cut -d= -f2)
GRP=$(grep dLegerGroup /opt/rocketmq-4.9.7/conf/broker-dledger.conf | cut -d= -f2)
echo "host=$H group=$GRP self=$SELF brokerPid=${PID:-NONE} systemd=$UP"
