#!/bin/bash
# Runs ON rocketmq-client01 (pushed via az vm run-command).
# Installs RocketMQ 4.9.7 distribution (client/benchmark/mqadmin) and creates test topics.
# JDK 11 already installed by client-jdk-setup.sh.
set -euo pipefail
LOG=/var/log/rocketmq-client-setup.log
exec >>"$LOG" 2>&1
echo "=== [$(date)] CLIENT setup start ==="

RMQ_VERSION=4.9.7
RMQ_HOME=/opt/rocketmq-${RMQ_VERSION}
NAMESRV="10.161.0.4:9876;10.161.0.5:9876;10.161.0.6:9876"
CLUSTER_NAME="RocketMQCluster"

export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export PATH=$JAVA_HOME/bin:$PATH
java -version 2>&1 | head -1

command -v unzip >/dev/null 2>&1 || dnf -y install unzip
command -v wget  >/dev/null 2>&1 || dnf -y install wget

### RocketMQ 4.9.7 distribution ###
cd /opt
if [ ! -d "$RMQ_HOME" ]; then
  wget -q https://archive.apache.org/dist/rocketmq/${RMQ_VERSION}/rocketmq-all-${RMQ_VERSION}-bin-release.zip -O rocketmq.zip
  unzip -q rocketmq.zip
  mv rocketmq-all-${RMQ_VERSION}-bin-release "$RMQ_HOME"
  rm -f rocketmq.zip
fi
echo "RMQ_HOME=$RMQ_HOME installed"
ls -la "$RMQ_HOME/bin/mqadmin" "$RMQ_HOME/benchmark/runclass.sh"

### Tune client tool heap (mqadmin/runclass default may be large); D16s_v6 has 64GB so fine ###
export ROCKETMQ_HOME=$RMQ_HOME

### Create test topics across all 3 broker groups ###
# Performance topic (perf benchmark)
"$RMQ_HOME/bin/mqadmin" updateTopic -n "$NAMESRV" -c "$CLUSTER_NAME" -t BenchTopic_1K -w 8 -r 8
# Failover topic
"$RMQ_HOME/bin/mqadmin" updateTopic -n "$NAMESRV" -c "$CLUSTER_NAME" -t ft_topic -w 8 -r 8

sleep 3
echo "=== topic route: BenchTopic_1K ==="
"$RMQ_HOME/bin/mqadmin" topicRoute -n "$NAMESRV" -t BenchTopic_1K || true
echo "=== topic route: ft_topic ==="
"$RMQ_HOME/bin/mqadmin" topicRoute -n "$NAMESRV" -t ft_topic || true

echo "=== [$(date)] CLIENT setup done ==="
