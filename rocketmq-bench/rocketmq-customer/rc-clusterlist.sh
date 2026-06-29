#!/bin/bash
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
"$ROCKETMQ_HOME/bin/mqadmin" clusterList -n 10.163.0.4:9876
