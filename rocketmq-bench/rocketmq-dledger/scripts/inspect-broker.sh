#!/bin/bash
RMQ=/opt/rocketmq-4.9.7
echo "=== conf dir ==="
ls -R $RMQ/conf 2>/dev/null
echo "=== running broker cmdline ==="
ps -ef | grep -i 'broker\|BrokerStartup' | grep -v grep
echo "=== conf files content ==="
for f in $(find $RMQ/conf -name '*.conf' -o -name '*.properties' 2>/dev/null); do
  echo "---- $f ----"
  cat "$f"
done
echo "=== systemd unit ==="
systemctl cat rocketmq-broker 2>/dev/null || systemctl list-units --type=service 2>/dev/null | grep -i rocket
echo "=== NAMESRV in env ==="
grep -r NAMESRV /etc/profile.d/ /home/azureadmin/.bashrc 2>/dev/null
