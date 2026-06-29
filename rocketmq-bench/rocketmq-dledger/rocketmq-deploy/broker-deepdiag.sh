#!/bin/bash
echo "=== log dir listing (recent) ==="
ls -lat /opt/rocketmq-4.9.7/logs/rocketmqlogs/ 2>/dev/null | head -n 20
echo "=== grep ERROR/Exception across logs (last 30) ==="
grep -rEh 'ERROR|Exception|Caused by|Error|cannot|Cannot|failed|Failed' /opt/rocketmq-4.9.7/logs/rocketmqlogs/ 2>/dev/null | tail -n 30
echo "=== broker-dledger.conf storePath + dledger ==="
grep -E 'storePathRootDir|storePathCommitLog|dLeger|dLedger|preferredLeaderId|listenPort' /opt/rocketmq-4.9.7/conf/broker-dledger.conf
echo "=== store dir ==="
DLDIR=$(grep -E 'storePathRootDir' /opt/rocketmq-4.9.7/conf/broker-dledger.conf | head -n1 | cut -d= -f2)
echo "storeRoot=$DLDIR"
ls -la "$DLDIR" 2>/dev/null
echo "=== runbroker JVM opts ==="
grep -E 'Xms|Xmx|Xmn|MaxDirectMemory' /opt/rocketmq-4.9.7/bin/runbroker.sh
