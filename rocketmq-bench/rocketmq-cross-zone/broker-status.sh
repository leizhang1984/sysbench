#!/bin/bash
echo "host=$(hostname)"
echo -n "java="; (java -version 2>&1 | head -1) || echo none
echo -n "svc="; systemctl is-active rocketmq-broker 2>&1
echo -n "datadisk="; df -h /datadisk 2>/dev/null | tail -1 || echo "NOT-MOUNTED"
echo -n "ports="; ss -lnt 2>/dev/null | awk '{print $4}' | grep -Eo ':(10911|10909|10912)$' | tr '\n' ' '; echo
echo "--- broker.conf (key lines) ---"
grep -E '^(brokerClusterName|brokerName|brokerId|brokerRole|namesrvAddr)=' /opt/rocketmq-4.9.7/conf/broker.conf 2>/dev/null || echo "no broker.conf"
echo "--- setup log tail ---"
tail -n 6 /var/log/rocketmq-setup.log 2>/dev/null || echo "no log"
