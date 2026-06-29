#!/bin/bash
IP=$(hostname -I | awk '{print $1}')
PID=$(pgrep -f 'java.*BrokerStartup' | head -1)
ACT=$(systemctl is-active rocketmq-broker.service 2>/dev/null)
NREST=$(systemctl show rocketmq-broker.service -p NRestarts --value 2>/dev/null)
# detect store load failure signature in recent log
FAIL=$(tail -120 /datadisk/rocketmq/logs/broker.log 2>/dev/null | grep -c "load.*false\|Failed to.*store\|shutdown service thread:AllocateMappedFileService")
SIZE=$(du -sh /datadisk/rocketmq/store/dledger-* 2>/dev/null | awk '{print $1}' | tr '\n' ' ')
echo "ip=$IP jvmPid=${PID:-NONE} active=$ACT restarts=$NREST storeSize=$SIZE recentFailSig=$FAIL"
