#!/bin/bash
echo '=== start-broker.sh ==='
cat /opt/rocketmq-4.9.7/bin/start-broker.sh 2>/dev/null
echo '=== JAVA_HOME resolve ==='
ls -la /usr/lib/jvm 2>/dev/null
readlink -f $(which java)
echo '=== os-release ==='
cat /etc/os-release | head -3
