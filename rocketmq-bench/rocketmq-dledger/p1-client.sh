#!/bin/bash
# P1 client readiness on v6rocketmqclient
MQ=/opt/rocketmq-4.9.7
echo "=== client host: $(hostname) ==="
echo "--- java ---"
java -version 2>&1 | head -1
echo "--- benchmark tools ---"
ls -1 $MQ/benchmark/ 2>/dev/null | head
echo "--- probe dir ---"
ls -l /opt/probe/ 2>/dev/null || echo "PROBE DIR MISSING"
echo "--- rocketmq-client jar on classpath ---"
ls -1 $MQ/lib/rocketmq-client*.jar 2>/dev/null
echo "--- namesrv reachability ---"
for ip in 10.170.0.4 10.170.0.6 10.170.0.5; do
  timeout 3 bash -c "echo > /dev/tcp/$ip/9876" 2>/dev/null && echo "$ip:9876 OK" || echo "$ip:9876 FAIL"
done
echo "--- clusterList (via reachable ns) ---"
for ip in 10.170.0.6 10.170.0.4 10.170.0.5; do
  if timeout 3 bash -c "echo > /dev/tcp/$ip/9876" 2>/dev/null; then
    $MQ/bin/mqadmin clusterList -n $ip:9876 2>/dev/null | head -15
    break
  fi
done
