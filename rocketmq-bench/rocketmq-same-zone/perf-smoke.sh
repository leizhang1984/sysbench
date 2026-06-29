#!/bin/bash
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export PATH=$JAVA_HOME/bin:$PATH
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
NS="10.161.0.4:9876;10.161.0.5:9876;10.161.0.6:9876"
sh $ROCKETMQ_HOME/benchmark/runclass.sh org.apache.rocketmq.example.benchmark.Producer \
  -n "$NS" -t BenchTopic_1K -s 1024 -w 16 -d 12 2>&1 | tail -n 10
