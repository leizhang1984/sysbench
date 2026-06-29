#!/bin/bash
MQ=/opt/rocketmq-4.9.7
echo "=== client host: $(hostname) ==="
echo "--- namesrv reachability ---"
for ip in 10.170.0.4 10.170.0.6 10.170.0.5; do
  timeout 3 bash -c "echo > /dev/tcp/$ip/9876" 2>/dev/null && echo "$ip:9876 OK" || echo "$ip:9876 FAIL"
done
echo "--- benchmark tools present? ---"
ls -1 $MQ/benchmark/ 2>/dev/null | head
echo "--- java ---"
java -version 2>&1 | head -1
echo "--- clusterList (any reachable ns) ---"
for ip in 10.170.0.6 10.170.0.4 10.170.0.5; do
  if timeout 3 bash -c "echo > /dev/tcp/$ip/9876" 2>/dev/null; then
    $MQ/bin/mqadmin clusterList -n $ip:9876 2>/dev/null
    break
  fi
done
