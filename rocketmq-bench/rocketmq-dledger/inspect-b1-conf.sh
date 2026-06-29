#!/bin/bash
echo "===== start-broker.sh (which conf is used) ====="
cat /opt/rocketmq-4.9.7/bin/start-broker.sh 2>/dev/null
echo ""
echo "===== dledger broker-n2.conf (the 3rd replica = b-2 identity) ====="
cat /opt/rocketmq-4.9.7/conf/dledger/broker-n2.conf 2>/dev/null
echo ""
echo "===== broker-dledger.conf ====="
cat /opt/rocketmq-4.9.7/conf/broker-dledger.conf 2>/dev/null
echo ""
echo "===== store dir actual location ====="
grep -rE "storePathRootDir|storePathCommitLog" /opt/rocketmq-4.9.7/conf/dledger/ 2>/dev/null
ls -ld /datadisk/* 2>/dev/null | head
