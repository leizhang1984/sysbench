#!/bin/bash
# Show the node scrape job block and prometheus run args (for reload method).
PYML=/tidb/deploy/prometheus-9090/conf/prometheus.yml
echo "===== node job block (lines 25-36) ====="
sed -n '25,36p' "$PYML"
echo "===== labels/relabel sample ====="
sed -n '36,48p' "$PYML"
echo "===== prometheus process args ====="
ps -ef | grep -E 'prometheus( |$)' | grep -v grep | head -2
echo "===== lifecycle reload ====="
grep -o 'web.enable-lifecycle' /tidb/deploy/prometheus-9090/scripts/run_prometheus.sh 2>/dev/null && echo "lifecycle=YES" || echo "lifecycle=UNKNOWN"
echo "===== DONE ====="
