#!/bin/bash
mkdir -p /opt/bench
cat > /opt/bench/diskmetrics-sampler.sh <<'SAMPLER_EOF'
__SAMPLER_BODY__
SAMPLER_EOF
chmod +x /opt/bench/diskmetrics-sampler.sh
touch /tmp/diskmetrics.stop 2>/dev/null
pkill -f diskmetrics-sampler.sh 2>/dev/null
sleep 2
rm -f /tmp/diskmetrics.stop /tmp/diskmetrics.csv
nohup /opt/bench/diskmetrics-sampler.sh >/tmp/disksampler.log 2>&1 &
sleep 3
echo "=== $(hostname) disk sampler pid=$(pgrep -f diskmetrics-sampler.sh) ==="
head -n 3 /tmp/diskmetrics.csv 2>/dev/null
