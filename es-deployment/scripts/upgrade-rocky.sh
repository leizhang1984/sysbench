#!/bin/bash
echo "=== upgrade $(hostname) ==="
echo "--- before ---"
cat /etc/rocky-release 2>/dev/null || cat /etc/redhat-release
echo "kernel: $(uname -r)"

echo "--- dnf upgrade ---"
dnf -y upgrade --refresh 2>&1 | tail -n 25

echo "--- after (package versions, reboot pending) ---"
cat /etc/rocky-release 2>/dev/null || cat /etc/redhat-release
needs-restarting -r 2>/dev/null || echo "(needs-restarting not available)"

# reboot in background so the run-command can return cleanly
echo "Scheduling reboot in 5s..."
( sleep 5; systemctl reboot ) &
echo "=== upgrade dispatched on $(hostname), rebooting ==="
