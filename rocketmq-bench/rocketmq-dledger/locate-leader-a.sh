#!/bin/bash
# Locate broker-a current Leader (BID=0) and print its IP + VM name mapping.
MQ=/opt/rocketmq-4.9.7
NS=10.170.0.6:9876
LINE=$($MQ/bin/mqadmin clusterList -n $NS 2>/dev/null | awk '$2=="broker-a" && $3=="0"{print $4}')
IP=${LINE%%:*}
echo "broker-a LEADER (BID=0) addr = $LINE"
echo "LEADER_IP=$IP"
case "$IP" in
  10.170.0.10) echo "LEADER_VM=v6rocketmqbroker-a-0" ;;
  10.170.0.11) echo "LEADER_VM=v6rocketmqbroker-a-1" ;;
  10.170.0.12) echo "LEADER_VM=v6rocketmqbroker-a-2" ;;
  *) echo "LEADER_VM=UNKNOWN_IP" ;;
esac
echo "--- full broker-a rows ---"
$MQ/bin/mqadmin clusterList -n $NS 2>/dev/null | awk 'NR==1 || $2=="broker-a"'
