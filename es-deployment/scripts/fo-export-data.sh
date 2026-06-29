#!/usr/bin/env bash
# Emit the 4 scenario CSVs as a single gzip+base64 blob for retrieval.
cd /tmp
tar -czf /tmp/fo_data.tgz \
  fo_requests_scenarioA.csv fo_state_scenarioA.csv \
  fo_requests_scenarioB.csv fo_state_scenarioB.csv \
  fo_requests_baseline.csv fo_state_baseline.csv 2>/dev/null
echo "TGZ_BYTES=$(wc -c < /tmp/fo_data.tgz)"
echo "B64_START"
base64 -w0 /tmp/fo_data.tgz
echo
echo "B64_END"
