#!/bin/bash
cat /opt/broker.conf 2>/dev/null
java -version 2>&1 | head -1
systemctl is-active rmq-namesrv 2>/dev/null
systemctl is-active rmq-broker 2>/dev/null
ss -lnt | grep -E '9876|10911' || echo no-ports
tail -5 /var/log/rocketmq-setup.log 2>/dev/null
