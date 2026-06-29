#!/bin/bash
echo '=== CONF DIR ==='
ls -la /opt/rocketmq-4.9.7/conf
echo '=== DLEDGER DIR ==='
ls -la /opt/rocketmq-4.9.7/conf/dledger 2>/dev/null
echo '=== 2m-2s / broker dirs ==='
find /opt/rocketmq-4.9.7/conf -maxdepth 2 -type d
echo '=== ALL PROPERTIES/CONF FILES ==='
for f in $(find /opt/rocketmq-4.9.7/conf -type f \( -name '*.properties' -o -name '*.conf' \) 2>/dev/null); do
  echo "##### FILE: $f"
  cat "$f"
  echo
done
echo '=== runbroker JAVA_HOME / heap ==='
grep -nE 'JAVA_HOME|Xms|Xmx|Xmn' /opt/rocketmq-4.9.7/bin/runbroker.sh | head
echo '=== systemd units ==='
ls -la /etc/systemd/system/ | grep -iE 'rocket|broker|namesrv|mq'
for u in $(ls /etc/systemd/system/ | grep -iE 'rocket|broker|namesrv|mq'); do
  echo "##### UNIT: $u"
  cat "/etc/systemd/system/$u"
  echo
done
echo '=== which start config is referenced (history/cmdline hints) ==='
grep -rnE 'mqbroker|namesrvAddr|enableDLegerCommitLog|dLeger' /opt/rocketmq-4.9.7/conf 2>/dev/null | head -n 40
echo '=== store path ==='
ls -la /datadisk/rocketmq 2>/dev/null
