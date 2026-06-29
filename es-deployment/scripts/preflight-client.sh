#!/bin/bash
echo "=== $(hostname) connectivity check ==="
echo "[esrally] $(esrally --version 2>&1 | head -n1)"
echo "[java] $(java -version 2>&1 | head -n1)"
for ip in "$@"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://$ip:9200/_cluster/health" --max-time 5)
  name=$(curl -s "http://$ip:9200/_cluster/health" --max-time 5 | grep -o '"cluster_name"[^,]*')
  echo "[reach] $ip:9200 -> HTTP $code $name"
done
echo "=== done ==="
