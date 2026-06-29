#!/bin/bash
# Verify dsv6-node targets in Prometheus after reload.
echo "===== config reload success metric ====="
curl -s 'http://localhost:9090/api/v1/query?query=prometheus_config_last_reload_successful' | head -c 300; echo
echo "===== up dsv6-node ====="
curl -s 'http://localhost:9090/api/v1/query?query=up%7Bjob%3D%22dsv6-node%22%7D' | head -c 800; echo
echo "===== active targets dsv6 ====="
curl -s 'http://localhost:9090/api/v1/targets?state=active' | tr ',' '\n' | grep -A1 -E '10\.142\.0\.(31|41)' | head -20
echo "===== DONE ====="
