#!/bin/bash
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
MQ=$ROCKETMQ_HOME/bin/mqadmin
for NS in 10.170.0.4:9876 10.170.0.6:9876 10.170.0.5:9876; do
  echo "########## clusterList via NameServer ${NS} ##########"
  sh "$MQ" clusterList -n "${NS}" 2>/dev/null
  echo
done
echo "########## brokerStatus broker-c master (self) ##########"
sh "$MQ" brokerStatus -n 10.170.0.4:9876 -b 10.170.0.16:10911 2>/dev/null | grep -iE 'brokerName|brokerId|role|msgPutTotal|getMessage' | head
