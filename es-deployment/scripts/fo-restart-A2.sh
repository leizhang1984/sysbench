#!/usr/bin/env bash
# Restart ES on node01 ~25s after kill, within the probe window.
sleep 25
echo "RESTART_AT=$(date +%H:%M:%S.%N)"
systemctl start elasticsearch
echo "started=$(systemctl is-active elasticsearch)"
