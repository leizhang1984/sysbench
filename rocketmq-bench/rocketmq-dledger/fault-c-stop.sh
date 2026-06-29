#!/bin/bash
# Fault C: graceful stop of broker-a Leader service. Run ON the Leader VM.
echo "T0_STOP=$(date -u +%H:%M:%S.%3N) host=$(hostname)"
systemctl stop rocketmq-broker
echo "stopped is-active=$(systemctl is-active rocketmq-broker)"
echo "port 10911: $(ss -ltn 2>/dev/null | grep -c ':10911')"
