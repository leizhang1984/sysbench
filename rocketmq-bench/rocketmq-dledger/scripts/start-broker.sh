#!/bin/bash
systemctl start rocketmq-broker
sleep 3
systemctl is-active rocketmq-broker
ps -ef | grep -i BrokerStartup | grep -v grep | awk '{print "pid="$2}'
