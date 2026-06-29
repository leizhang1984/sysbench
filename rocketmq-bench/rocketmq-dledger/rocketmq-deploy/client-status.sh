#!/bin/bash
echo "rocky:$(grep -o 'release [0-9.]*' /etc/redhat-release | head -1)"
echo "java:$(java -version 2>&1 | head -1)"
echo "rmq:$(ls -d /opt/rocketmq-4.9.7 2>/dev/null || echo NO)"
echo "mqadmin:$(test -x /usr/local/bin/mqadmin && echo YES || echo NO)"
echo "profile:$(test -f /etc/profile.d/rocketmq.sh && echo YES || echo NO)"
echo "done:$(grep -c 'CLIENT setup done' /var/log/rocketmq-setup.log 2>/dev/null)"
echo "unit:$(systemctl is-active rocketmq-client-setup.service 2>/dev/null)"
echo "tail:$(tail -n 1 /var/log/rocketmq-setup.log 2>/dev/null)"
