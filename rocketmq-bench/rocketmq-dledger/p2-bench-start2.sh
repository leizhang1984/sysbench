#!/bin/bash
# P2 benchmark orchestrator v2 - direct java invocation (bypass runclass.sh /usr/java hardcode).
MQ=/opt/rocketmq-4.9.7
OUT=/tmp/p2bench
mkdir -p $OUT
RUNNER="$OUT/run.sh"
cat > "$RUNNER" <<'EOS'
#!/bin/bash
MQ=/opt/rocketmq-4.9.7
NS="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"
TOPIC=BenchTopic_1K
OUT=/tmp/p2bench
JAVA_BIN=$(readlink -f "$(which java)")
export JAVA_HOME=$(dirname "$(dirname "$JAVA_BIN")")
CP=".:$MQ/conf:$MQ/lib/*"
run() { # threads seconds tag
  local w=$1 sec=$2 tag=$3
  echo "=== RUN $tag : $w threads x ${sec}s @ $(date -u +%H:%M:%S) ===" >> $OUT/timeline.log
  timeout ${sec} "$JAVA_HOME/bin/java" -server -Xms2g -Xmx2g -cp "$CP" \
    org.apache.rocketmq.example.benchmark.Producer \
    -t $TOPIC -w $w -s 1024 -n "$NS" > $OUT/$tag.log 2>&1
  echo "=== DONE $tag @ $(date -u +%H:%M:%S) ===" >> $OUT/timeline.log
  sleep 5
}
echo "P2 START $(date -u)  JAVA_HOME=$JAVA_HOME" > $OUT/timeline.log
run 64 300 main_64x300
run 16 120 scan_16
run 32 120 scan_32
run 64 120 scan_64
run 128 120 scan_128
echo "P2 ALL DONE $(date -u)" >> $OUT/timeline.log
EOS
chmod +x "$RUNNER"
setsid bash "$RUNNER" >/dev/null 2>&1 < /dev/null &
sleep 12
echo "===== timeline ====="
cat $OUT/timeline.log
echo "===== main log head ====="
head -8 $OUT/main_64x300.log 2>/dev/null
echo "===== procs ====="
ps -ef | grep -E 'benchmark.Producer' | grep -v grep | head -2 || echo "none"
