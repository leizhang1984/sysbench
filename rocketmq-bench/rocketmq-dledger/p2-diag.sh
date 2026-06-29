#!/bin/bash
OUT=/tmp/p2bench
echo "===== timeline ====="
cat $OUT/timeline.log 2>/dev/null
echo "===== main_64x300.log (head 40) ====="
head -40 $OUT/main_64x300.log 2>/dev/null
echo "===== procs now ====="
ps -ef | grep -E 'producer|benchmark|run.sh' | grep -v grep || echo "none"
