#!/bin/bash
for ip in 10.170.0.4 10.170.0.6 10.170.0.5; do
  timeout 3 bash -c "echo > /dev/tcp/$ip/9876" 2>/dev/null && echo "$ip:9876 OK" || echo "$ip:9876 FAIL"
done
