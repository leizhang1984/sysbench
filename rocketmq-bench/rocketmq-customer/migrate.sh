#!/bin/bash
cd /mnt/c/Users/leizha/rocketmq-bench
S=rocketmq-same-zone; D=rocketmq-customer
files="client-jdk-setup.sh client-rmq-setup.sh probe-deploy.sh perf-test.sh perf-agg.sh perf-wait.sh recreate-ft-topic.sh ft-produce.sh ft-verify.sh ft-wait.sh ft-wall.sh ft-failwin.sh fault-sigstop.sh fault-graceful.sh power-fault.sh ns-log.sh ns-log2.sh check-broker.sh heal-broker.sh"
miss=0
for f in $files; do
  cat "$S/$f" > "$D/$f"
  sed -i 's/10\.161\.0/10.163.0/g; s/\r$//' "$D/$f"
  test -f "$D/$f" && echo "OK $f" || { echo "MISS $f"; miss=1; }
done
echo "miss=$miss"
