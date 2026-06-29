#!/bin/bash
set +e
echo "=== HOST: $(hostname) ==="
echo "--- namesrvAddr in service env / config ---"
grep -rE 'namesrvAddr|NAMESRV' /opt/rocketmq-4.9.7/conf/broker-dledger.conf /etc/systemd/system/rocketmq-broker.service 2>/dev/null
echo "--- broker.log register lines (last 15) ---"
grep -nE 'register|Register|namesrv|NameServer|name server' /root/logs/rocketmqlogs/broker.log 2>/dev/null | tail -15
echo "--- TCP to each nameserver 9876 ---"
for ip in 10.170.0.4 10.170.0.6 10.170.0.5; do timeout 3 bash -c "echo > /dev/tcp/$ip/9876" 2>/dev/null && echo "$ip:9876 OK" || echo "$ip:9876 FAIL"; done
echo "--- current listen ports ---"
ss -ltn | grep -E ':10911|:40911|:10909'
