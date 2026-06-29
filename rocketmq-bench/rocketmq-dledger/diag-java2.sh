#!/bin/bash
set +e
echo "=== java version ==="
java -version 2>&1
echo "=== existing module flags in runbroker.sh ==="
grep -nE 'add-exports|add-opens' /opt/rocketmq-4.9.7/bin/runbroker.sh
echo "=== tail of JAVA_OPT block (lines 90-110) ==="
sed -n '90,115p' /opt/rocketmq-4.9.7/bin/runbroker.sh
