#!/bin/bash
RMQ=/opt/rocketmq-4.9.7
NS="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"
echo "==== clusterList (BID 0 = leader) ===="
sh "$RMQ/bin/mqadmin" clusterList -n "$NS" 2>/dev/null
echo "==== brokerProcess on this host ===="
ps -ef | grep BrokerStartup | grep -v grep | awk '{print $2}'
