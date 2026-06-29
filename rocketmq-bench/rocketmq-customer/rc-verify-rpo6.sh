#!/bin/bash
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export PATH=$JAVA_HOME/bin:$PATH
ROCKETMQ_HOME=/opt/rocketmq-4.9.7
NS="10.163.0.4:9876;10.163.0.5:9876;10.163.0.6:9876"
java -cp "$ROCKETMQ_HOME/lib/*:/opt/probe" Probe verify "$NS" ft_topic rpo6 45 2>&1 | tail -n 20
