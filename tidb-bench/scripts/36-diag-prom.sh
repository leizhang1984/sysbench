#!/bin/bash
# Diagnose prometheus reload: tail config, check log, validate, list all jobs via API.
PYML=/tidb/deploy/prometheus-9090/conf/prometheus.yml
echo "===== tail prometheus.yml ====="
tail -15 "$PYML"
echo "===== all job_names via API ====="
curl -s 'http://localhost:9090/api/v1/targets?state=active' | tr ',' '\n' | grep -oE '"scrapePool":"[^"]+"' | sort -u
echo "===== prometheus log tail ====="
LOG=$(find /tidb/deploy/prometheus-9090 -name '*.log' 2>/dev/null | head -1)
echo "LOG=$LOG"
tail -15 "$LOG" 2>/dev/null
echo "===== promtool check ====="
/tidb/deploy/prometheus-9090/bin/prometheus/promtool check config "$PYML" 2>&1 | tail -8 || echo "no-promtool"
echo "===== DONE ====="
