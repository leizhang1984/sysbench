#!/bin/bash
echo "rocky:$(grep -o 'release [0-9.]*' /etc/redhat-release | head -1)"
if mountpoint -q /datadisk; then echo "datadisk:MOUNTED"; else echo "datadisk:NO"; fi
echo "svc:$(systemctl is-active rocketmq-broker 2>/dev/null)"
if ss -ltn | grep -q ':10911'; then echo "p10911:UP"; else echo "p10911:DOWN"; fi
if ss -ltn | grep -q ':40911'; then echo "p40911:UP"; else echo "p40911:DOWN"; fi
echo "done:$(grep -c 'BROKER setup done' /var/log/rocketmq-setup.log 2>/dev/null)"
echo "running:$(pgrep -f '[b]roker-setup-run' | wc -l)"
echo "tail:$(tail -n 1 /var/log/rocketmq-setup.log 2>/dev/null)"
