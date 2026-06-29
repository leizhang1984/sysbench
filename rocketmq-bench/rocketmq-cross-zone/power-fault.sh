#!/bin/bash
# Simulate sudden power loss: immediate kernel reboot WITHOUT syncing page cache.
# This drops un-flushed (ASYNC_FLUSH) messages still in OS page cache => real RPO.
# Args: DELAY (seconds before the simulated power cut)
DELAY="${1:-5}"
setsid bash -c "sleep ${DELAY}; echo 1 > /proc/sys/kernel/sysrq; echo b > /proc/sysrq-trigger" >/dev/null 2>&1 < /dev/null &
echo "POWER-CUT scheduled in ${DELAY}s (sysrq 'b' reboot, no flush) at $(date -u +%H:%M:%S)"
