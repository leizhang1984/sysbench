#!/bin/bash
# Fault D: hard power-off (sysrq reboot, no sync/flush) of broker-a Leader VM.
# Run ON the Leader VM. setsid so the run-command returns before the box dies.
echo "T0_POWEROFF=$(date -u +%H:%M:%S.%3N) host=$(hostname)"
setsid bash -c 'sleep 2; echo 1 > /proc/sys/kernel/sysrq; echo b > /proc/sysrq-trigger' >/dev/null 2>&1 < /dev/null &
echo "sysrq reboot scheduled in 2s"
