#!/bin/bash
# P2 benchmark orchestrator - runs detached, writes per-run logs.
# Main: 64 threads x 300s ; Scan: 16/32/64/128 x 120s each. 1KB messages, topic BenchTopic_1K.
MQ=/opt/rocketmq-4.9.7
NS="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"
TOPIC=BenchTopic_1K
OUT=/tmp/p2bench
mkdir -p $OUT
RUNNER="$OUT/run.sh"
cat > "$RUNNER" <<'EOS'
#!/bin/bash
MQ=/opt/rocketmq-4.9.7
NS="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"
TOPIC=BenchTopic_1K
OUT=/tmp/p2bench
cd $MQ/benchmark
run() { # threads seconds tag
  local w=$1 sec=$2 tag=$3
  echo "=== RUN $tag : $w threads x ${sec}s @ $(date -u +%H:%M:%S) ===" >> $OUT/timeline.log
  timeout ${sec} sh ./producer.sh -t $TOPIC -w $w -s 1024 -n "$NS" > $OUT/$tag.log 2>&1
  echo "=== DONE $tag @ $(date -u +%H:%M:%S) ===" >> $OUT/timeline.log
  sleep 5
}
echo "P2 START $(date -u)" > $OUT/timeline.log
# main test first
run 64 300 main_64x300
# concurrency scan
run 16 120 scan_16
run 32 120 scan_32
run 64 120 scan_64
run 128 120 scan_128
echo "P2 ALL DONE $(date -u)" >> $OUT/timeline.log
EOS
chmod +x "$RUNNER"
setsid bash "$RUNNER" >/dev/null 2>&1 < /dev/null &
sleep 3
echo "launched P2 benchmark sequence, pid group started"
cat $OUT/timeline.log
ps -ef | grep -E 'producer|benchmark' | grep -v grep | head -3
