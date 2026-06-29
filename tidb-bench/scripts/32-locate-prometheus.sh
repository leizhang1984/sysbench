#!/bin/bash
# Locate prometheus config on clientvm01 and test dsv6 node_exporter reachability.
echo "===== prometheus.yml path ====="
find /tidb /home /data -maxdepth 4 -name 'prometheus.yml' 2>/dev/null
echo "===== existing scrape jobs ====="
PYML=$(find /tidb -maxdepth 4 -name 'prometheus.yml' 2>/dev/null | head -1)
echo "PYML=$PYML"
grep -nE "job_name|targets" "$PYML" 2>/dev/null | head -40
echo "===== dsv6 node_exporter :9100 ====="
for ip in 10.142.0.31 10.142.0.32 10.142.0.33 10.142.0.41 10.142.0.42 10.142.0.43; do
  if timeout 3 bash -lc "</dev/tcp/${ip}/9100" 2>/dev/null; then echo "${ip}:9100 OK"; else echo "${ip}:9100 FAIL"; fi
done
echo "===== prometheus reload api ====="
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:9090/-/ready 2>/dev/null || echo "no-curl"
echo "===== DONE ====="
