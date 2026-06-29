#!/bin/bash
LABEL="$1"
echo "=== wc ==="
wc -l /tmp/rally-$LABEL.log
echo "=== first 15 ==="
head -n 15 /tmp/rally-$LABEL.log
echo "=== last 40 ==="
tail -n 40 /tmp/rally-$LABEL.log
