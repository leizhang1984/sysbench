#!/bin/bash
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export PATH=$JAVA_HOME/bin:$PATH
ROCKETMQ_HOME=/opt/rocketmq-4.9.7
NS="10.163.0.4:9876;10.163.0.5:9876;10.163.0.6:9876"
cd /opt/probe
timeout 15 java -cp "$ROCKETMQ_HOME/lib/*:/opt/probe" Probe produce "$NS" ft_topic 4 12 50 /opt/probe/ft_test.csv test 0 2>&1 | tail -8
echo "--- csv ---"; tail -3 /opt/probe/ft_test.csv 2>/dev/null || echo NOCSV
