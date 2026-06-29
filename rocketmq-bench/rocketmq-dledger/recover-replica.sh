#!/bin/bash
# Recover a broker replica: grow filesystem + inject JVM flags + restart + verify
set +e
MQ=/opt/rocketmq-4.9.7
echo "=== HOST: $(hostname) ==="

echo "--- grow filesystem ---"
DEV=$(findmnt -no SOURCE /datadisk 2>/dev/null)
echo "datadisk dev=$DEV"
# grow partition + xfs
PART=$(echo "$DEV" | grep -oE '[0-9]+$')
DISK=$(echo "$DEV" | sed -E 's/p?[0-9]+$//')
growpart "$DISK" "$PART" 2>&1 | tail -1
xfs_growfs /datadisk 2>&1 | tail -1
df -h /datadisk | tail -1

echo "--- inject JVM flags ---"
RB=$MQ/bin/runbroker.sh
if grep -q "add-exports=java.base/jdk.internal.ref" "$RB"; then
  echo "flags already present"
else
  cp "$RB" "$RB.bak.$(date +%s)"
  sed -i '/-XX:-UseLargePages -XX:-UseBiasedLocking"/a JAVA_OPT="${JAVA_OPT} --add-exports=java.base/jdk.internal.ref=ALL-UNNAMED --add-exports=java.base/sun.nio.ch=ALL-UNNAMED --add-exports=java.management/sun.management=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED"' "$RB"
  echo "INJECTED flags"
fi
grep -n "add-exports=java.base/jdk.internal.ref" "$RB" | head -1

echo "--- restart broker ---"
systemctl reset-failed rocketmq-broker.service 2>/dev/null
systemctl restart rocketmq-broker.service
sleep 30
echo "--- status ---"
systemctl is-active rocketmq-broker.service
pgrep -f BrokerStartup >/dev/null && echo "proc=UP" || echo "proc=DOWN"
ss -ltn 2>/dev/null | grep -E ':10911|:40911'
