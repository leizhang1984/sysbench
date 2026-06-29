#!/bin/bash
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
sh /opt/rocketmq-4.9.7/bin/mqadmin clusterList -n 10.161.0.4:9876 2>/dev/null
