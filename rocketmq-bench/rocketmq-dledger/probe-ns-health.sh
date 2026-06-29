#!/bin/bash
echo "=== HOST $(hostname) ==="
systemctl is-active rocketmq-nameserver.service 2>/dev/null || true
systemctl is-active rmqnamesrv.service 2>/dev/null || true
systemctl is-active rocketmq-namesrv.service 2>/dev/null || true
ps -ef | grep -E 'mqnamesrv|NamesrvStartup' | grep -v grep || true
ss -lntp 2>/dev/null | grep ':9876' || true
