#!/bin/bash
set +e
SL=/root/logs/rocketmqlogs/store.log
echo "=== exception stack: lines 677016..677065 ==="
awk 'NR>=677016 && NR<=677065' "$SL" 2>/dev/null
