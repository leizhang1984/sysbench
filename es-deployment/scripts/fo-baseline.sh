#!/usr/bin/env bash
# Run a short baseline to verify the probe collects data correctly.
cd /tmp
nohup /opt/rally-venv/bin/python /tmp/fo-probe.py 12 baseline > /tmp/fo_baseline.log 2>&1
echo "=== baseline.log ==="
cat /tmp/fo_baseline.log
echo "=== request summary ==="
awk -F, 'NR>1{tot++; if($4==1)ok++; else fail++} END{printf "total=%d ok=%d fail=%d\n", tot, ok, fail}' /tmp/fo_requests_baseline.csv
echo "=== latency (ok only) p50/avg/max ms ==="
awk -F, 'NR>1 && $4==1{print $5}' /tmp/fo_requests_baseline.csv | sort -n | awk '{a[NR]=$1; s+=$1} END{printf "p50=%.1f avg=%.1f max=%.1f n=%d\n", a[int(NR*0.5)], s/NR, a[NR], NR}'
echo "=== state samples ==="
cat /tmp/fo_state_baseline.csv
