#!/bin/bash
# Fix broken append: restore from backup, re-append dsv6-node job with leading newline.
set -e
PYML=/tidb/deploy/prometheus-9090/conf/prometheus.yml
BAK=$(ls -t ${PYML}.bak.* 2>/dev/null | head -1)
echo "restoring from: $BAK"
cp -a "$BAK" "$PYML"

# Ensure file ends with newline, then append job block.
printf '\n' >> "$PYML"
cat >> "$PYML" <<'EOF'
  - job_name: "dsv6-node"
    honor_labels: true
    static_configs:
    - targets:
      - '10.142.0.31:9100'
      - '10.142.0.32:9100'
      - '10.142.0.33:9100'
      - '10.142.0.41:9100'
      - '10.142.0.42:9100'
      - '10.142.0.43:9100'
EOF

echo "===== promtool check ====="
/tidb/deploy/prometheus-9090/bin/prometheus/promtool check config "$PYML" 2>&1 | tail -5
PID=$(pgrep -f 'bin/prometheus/prometheus' | head -1)
echo "prometheus pid=$PID -> SIGHUP"
kill -HUP "$PID"
sleep 20
echo "===== up dsv6-node ====="
curl -s 'http://localhost:9090/api/v1/query?query=up%7Bjob%3D%22dsv6-node%22%7D' | grep -oE '"10\.142\.0\.[0-9]+:9100"|"value":\[[0-9.]+,"[01]"\]'
echo "===== DONE ====="
