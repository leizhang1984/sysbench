#!/bin/bash
ls -la /opt/probe/Probe.class 2>/dev/null || echo "NO Probe.class"
java -version 2>&1 | head -1
/opt/rocketmq-4.9.7/bin/mqadmin topicList -n 10.163.0.4:9876 2>/dev/null | grep -E 'BenchTopic_1K|ft_topic' || echo "topics?"
