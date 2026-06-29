#!/bin/bash
F=/opt/rocketmq-4.9.7/bin/runbroker.sh
if ! grep -q 'jdk.internal.ref' "$F"; then
  sed -i 's#JAVA_OPT="${JAVA_OPT} -server -Xms8g -Xmx8g"#JAVA_OPT="${JAVA_OPT} -server -Xms8g -Xmx8g --add-opens=java.base/jdk.internal.ref=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED"#' "$F"
fi
grep -c 'jdk.internal.ref' "$F"
systemctl stop rmq-broker; sleep 2
rm -rf /datadisk/rocketmq/store/index
systemctl reset-failed rmq-broker; systemctl start rmq-broker
sleep 18
echo "active=$(systemctl is-active rmq-broker)"; ss -lnt | grep -q 10911 && echo UP || echo DOWN
