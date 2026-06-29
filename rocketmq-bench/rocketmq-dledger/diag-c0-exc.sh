#!/bin/bash
set +e
SL=/root/logs/rocketmqlogs/store.log
echo "=== load exception full stack (lines 677010..677040) ==="
sed -n '677010,677040p' "$SL" 2>/dev/null
echo
echo "=== also 50 lines before the exception for context ==="
sed -n '676960,677016p' "$SL" 2>/dev/null
