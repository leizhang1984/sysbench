#!/bin/bash
# DLedger / cluster verification, run from a broker node (has mqadmin + RocketMQ installed)
export NAMESRV_ADDR="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"
RH=$(ls -d /opt/rocketmq-4.9.7 2>/dev/null || ls -d /opt/rocketmq* 2>/dev/null | head -1)
echo "ROCKETMQ_HOME=$RH"
echo "===== clusterList ====="
JAVA_HOME=${JAVA_HOME:-$(dirname $(dirname $(readlink -f $(which java))))} \
  "$RH/bin/mqadmin" clusterList -n "$NAMESRV_ADDR" 2>/dev/null
echo "===== DLedger role on this node ====="
grep -aoE 'become (Leader|Follower|Candidate)|BECOME_LEADER|BECOME_FOLLOWER|MemberState.*(LEADER|FOLLOWER)' \
  /datadisk/rocketmq/store/dledger* 2>/dev/null | tail -5
tail -n 15 "$RH"/logs/dledger* 2>/dev/null | grep -aiE 'leader|follower|term' | tail -10
