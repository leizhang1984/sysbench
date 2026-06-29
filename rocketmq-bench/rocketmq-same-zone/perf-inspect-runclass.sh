#!/bin/bash
grep -nE 'JAVA_OPT|UseCMS|UseConcMark|UseParNew|PermSize|UseG1|Xms|Xmx' /opt/rocketmq-4.9.7/benchmark/runclass.sh
echo "----- tools.sh GC opts (if used) -----"
grep -nE 'UseCMS|UseConcMark|UseParNew|PermSize|UseG1' /opt/rocketmq-4.9.7/bin/tools.sh 2>/dev/null || true
