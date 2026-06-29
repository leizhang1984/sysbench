#!/bin/bash
echo "=== find broker logs ==="
find / -name 'broker.log' 2>/dev/null
echo "=== newest broker.log tail ==="
LOG=$(find / -name 'broker.log' 2>/dev/null | head -1)
echo "LOG=$LOG"
tail -n 40 "$LOG" 2>/dev/null
echo "=== dledger appendlog errors ==="
grep -iE 'error|exception|fail' "$LOG" 2>/dev/null | tail -20
