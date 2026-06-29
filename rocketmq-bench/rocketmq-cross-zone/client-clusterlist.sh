#!/bin/bash
# client-clusterlist.sh  —  Verify cluster health from rocketmq-client01.
# Ensures java + RocketMQ tools exist, then runs mqadmin clusterList.
set -uo pipefail

NS='10.162.0.4:9876;10.162.0.5:9876;10.162.0.6:9876'
RMQ=/opt/rocketmq-4.9.7

# Force IPv4 for dnf (mirrors resolve to IPv6 first; VMs are IPv4-only egress).
grep -q '^ip_resolve=4' /etc/dnf/dnf.conf 2>/dev/null || echo 'ip_resolve=4' >> /etc/dnf/dnf.conf

# java
if ! command -v java >/dev/null 2>&1; then
  dnf -y install java-11-openjdk-headless >/dev/null 2>&1
fi

# rocketmq tools
if [ ! -d "$RMQ" ]; then
  command -v unzip >/dev/null 2>&1 || dnf -y install unzip >/dev/null 2>&1
  command -v wget  >/dev/null 2>&1 || dnf -y install wget  >/dev/null 2>&1
  cd /opt
  wget -4 -q https://archive.apache.org/dist/rocketmq/4.9.7/rocketmq-all-4.9.7-bin-release.zip -O r.zip
  unzip -q r.zip
  mv rocketmq-all-4.9.7-bin-release "$RMQ"
  rm -f r.zip
fi

export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export ROCKETMQ_HOME="$RMQ"

echo "=== java ==="
java -version 2>&1 | head -1

echo "=== nameserver TCP reachability (9876) ==="
for ns in 10.162.0.4 10.162.0.5 10.162.0.6; do
  if timeout 3 bash -c "echo > /dev/tcp/$ns/9876" 2>/dev/null; then
    echo "  $ns:9876  OK"
  else
    echo "  $ns:9876  UNREACHABLE"
  fi
done

echo "=== clusterList (ns=$NS) ==="
sh "$RMQ/bin/mqadmin" clusterList -n "$NS" 2>/dev/null
