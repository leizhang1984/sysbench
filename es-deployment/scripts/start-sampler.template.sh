#!/bin/bash
# Installs the sampler script to the node and starts it in background via nohup.
mkdir -p /opt/bench
cat > /opt/bench/hostmetrics-sampler.sh <<'SAMPLER_EOF'
__SAMPLER_BODY__
SAMPLER_EOF
chmod +x /opt/bench/hostmetrics-sampler.sh
# stop any previous sampler
touch /tmp/hostmetrics.stop 2>/dev/null
pkill -f hostmetrics-sampler.sh 2>/dev/null
sleep 6
rm -f /tmp/hostmetrics.stop /tmp/hostmetrics.csv
nohup /opt/bench/hostmetrics-sampler.sh >/tmp/sampler.log 2>&1 &
sleep 7
echo "=== $(hostname) sampler started, pid=$(pgrep -f hostmetrics-sampler.sh) ==="
echo "--- first lines ---"
head -n 3 /tmp/hostmetrics.csv 2>/dev/null
