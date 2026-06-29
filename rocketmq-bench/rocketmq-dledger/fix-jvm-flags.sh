#!/bin/bash
set +e
RB=/opt/rocketmq-4.9.7/bin/runbroker.sh
echo "=== HOST: $(hostname) ==="

if grep -q 'add-exports=java.base/jdk.internal.ref' "$RB"; then
  echo "FLAGS already present, skip injection"
else
  cp -a "$RB" "${RB}.bak.$(date +%s)"
  # insert module flags right after the UseLargePages/UseBiasedLocking line
  sed -i '/-XX:-UseLargePages -XX:-UseBiasedLocking"/a JAVA_OPT="${JAVA_OPT} --add-exports=java.base/jdk.internal.ref=ALL-UNNAMED --add-exports=java.base/sun.nio.ch=ALL-UNNAMED --add-exports=java.management/sun.management=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED"' "$RB"
  echo "INJECTED flags"
fi

echo "=== verify ==="
grep -nE 'add-exports|add-opens' "$RB"

echo "=== reset systemd + restart ==="
systemctl reset-failed rocketmq-broker.service 2>/dev/null
systemctl restart rocketmq-broker.service 2>/dev/null &
sleep 30
echo "=== status after 30s ==="
systemctl is-active rocketmq-broker.service
pgrep -f BrokerStartup >/dev/null && echo "proc=UP" || echo "proc=DOWN"
ss -ltn 2>/dev/null | grep -E ':10911|:40911' || echo "ports not bound yet"
