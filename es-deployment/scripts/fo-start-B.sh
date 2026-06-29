#!/usr/bin/env bash
# Scenario B probe launcher (clientvm02): 180s window.
cd /tmp
rm -f /tmp/fo_requests_scenarioB.csv /tmp/fo_state_scenarioB.csv /tmp/fo_scenarioB.log
nohup /opt/rally-venv/bin/python /tmp/fo-probe.py 180 scenarioB > /tmp/fo_scenarioB.log 2>&1 &
echo "PROBE_STARTED pid=$! at=$(date +%H:%M:%S.%N)"
