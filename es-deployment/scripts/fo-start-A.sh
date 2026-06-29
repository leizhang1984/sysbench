#!/usr/bin/env bash
# Start the failover probe in the background on clientvm02 for scenario A (kill -9).
cd /tmp
rm -f /tmp/fo_requests_scenarioA.csv /tmp/fo_state_scenarioA.csv /tmp/fo_scenarioA.log
nohup /opt/rally-venv/bin/python /tmp/fo-probe.py 50 scenarioA > /tmp/fo_scenarioA.log 2>&1 &
echo "PROBE_STARTED pid=$! at=$(date +%H:%M:%S.%N)"
