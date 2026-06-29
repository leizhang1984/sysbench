#!/bin/bash
set +e
H=$(hostname)
ACT=$(systemctl is-active rocketmq-broker.service)
PROC=$(pgrep -f BrokerStartup >/dev/null && echo UP || echo DOWN)
P10911=$(ss -ltn 2>/dev/null | grep -q ':10911' && echo Y || echo N)
P40911=$(ss -ltn 2>/dev/null | grep -q ':40911' && echo Y || echo N)
DISK=$(df -h /datadisk | tail -1 | awk '{print $2" "$5}')
echo "$H svc=$ACT proc=$PROC port10911=$P10911 port40911=$P40911 disk=$DISK"
