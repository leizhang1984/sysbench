#!/bin/bash
echo "=== host/ip ==="
hostname; hostname -I
echo "=== java ==="
java -version 2>&1 | head -1 || echo "no java"
echo "=== rocketmq home ==="
ls -d /opt/rocketmq* 2>/dev/null
RMQ=$(ls -d /opt/rocketmq-* 2>/dev/null | head -1)
echo "RMQ=$RMQ"
echo "=== tools present ==="
ls "$RMQ/bin/mqadmin" "$RMQ/bin/tools.sh" 2>/dev/null
echo "=== nameserver TCP reachability ==="
for NS in 10.170.0.4 10.170.0.6 10.170.0.5; do
  if timeout 5 bash -c "cat < /dev/null > /dev/tcp/${NS}/9876" 2>/dev/null; then
    echo "${NS}:9876 OPEN"
  else
    echo "${NS}:9876 CLOSED"
  fi
done
