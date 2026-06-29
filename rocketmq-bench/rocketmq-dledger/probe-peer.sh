#!/bin/bash
echo "=== HOST $(hostname) IP $(hostname -I) ==="
echo "=== service ==="
systemctl is-enabled rocketmq-broker.service 2>&1
systemctl is-active rocketmq-broker.service 2>&1
echo "=== broker procs ==="
pgrep -af 'BrokerStartup' | head
echo "=== conf key ==="
grep -E 'dLegerSelfId|dLegerPeers|dLegerGroup|namesrvAddr|brokerName' /opt/rocketmq-4.9.7/conf/broker-dledger.conf 2>&1
echo "=== peer 40911 reachability (a-0=.10 a-1=.11 a-2=.12) ==="
for ip in 10.170.0.10 10.170.0.11 10.170.0.12; do
  timeout 3 bash -c "echo > /dev/tcp/$ip/40911" 2>/dev/null && echo "$ip:40911 OPEN" || echo "$ip:40911 CLOSED"
done
echo "=== listen ports ==="
ss -lntp 2>/dev/null | grep -E '40911|10911|10909|10912' || echo "(none listening)"
