#!/usr/bin/env bash
# Scenario A (self-contained, runs on clientvm02):
#   start probe -> wait 15s baseline -> kill -9 ES on node01 (via remote curl trick won't work,
#   so we kill over SSH-less path: use a small remote trigger file approach is overkill).
# Instead: this runs ON node01? No -- probe must run on clientvm02 (the client).
# So this script orchestrates from clientvm02 and triggers the kill on node01 through a
# pre-staged marker that a watcher on node01 consumes. Simpler: run probe here, and the
# caller injects kill separately but we lengthen the window to 180s so timing is forgiving.
cd /tmp
rm -f /tmp/fo_requests_scenarioA.csv /tmp/fo_state_scenarioA.csv /tmp/fo_scenarioA.log
nohup /opt/rally-venv/bin/python /tmp/fo-probe.py 180 scenarioA > /tmp/fo_scenarioA.log 2>&1 &
echo "PROBE_STARTED pid=$! at=$(date +%H:%M:%S.%N)"
