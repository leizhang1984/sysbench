#!/bin/bash
# Add dsv6 node_exporter targets to dsv5 Prometheus and reload via SIGHUP.
set -e
PYML=/tidb/deploy/prometheus-9090/conf/prometheus.yml

if grep -q 'dsv6-node' "$PYML"; then
  echo "dsv6-node job already present, skip append"
else
  cp -a "$PYML" "${PYML}.bak.$(date +%s)"
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
  echo "appended dsv6-node job"
fi

PID=$(pgrep -f 'bin/prometheus/prometheus' | head -1)
echo "prometheus pid=$PID"
kill -HUP "$PID"
sleep 5
echo "===== targets up for dsv6 ====="
curl -s 'http://localhost:9090/api/v1/targets?state=active' \
  | grep -oE '"instance":"10\.142\.0\.(31|32|33|41|42|43):9100","[^}]*"health":"[a-z]+"' \
  | sed -E 's/.*instance":"([^"]+)".*health":"([a-z]+)"/\1 \2/' || echo "parse-failed"
echo "===== raw count ====="
curl -s 'http://localhost:9090/api/v1/query?query=up{job="dsv6-node"}' | grep -o '"value"' | wc -l
echo "===== DONE ====="
