#!/bin/bash
echo "=== find broker.log ==="
find / -name 'broker.log' 2>/dev/null
echo "=== find rocketmqlogs dirs ==="
find / -type d -name 'rocketmqlogs' 2>/dev/null
echo "=== logback config logdir ==="
grep -rE 'user.home|logback|logRoot|file.*\.log' /opt/rocketmq-4.9.7/conf/*.xml 2>/dev/null | grep -iE 'home|logRoot|\.log' | head
echo "=== home of azureadmin/root ==="
ls -la /root/logs/rocketmqlogs 2>&1 | head
ls -la /home/azureadmin/logs/rocketmqlogs 2>&1 | head
