#!/bin/bash
set +e
echo "=== java version ==="
java -version 2>&1
echo "=== which java ==="
readlink -f "$(command -v java)"
echo "=== runbroker.sh JAVA_OPT add-exports/add-opens lines ==="
grep -nE 'add-exports|add-opens|jdk.internal' /opt/rocketmq-4.9.7/bin/runbroker.sh 2>/dev/null
echo "=== runbroker.sh JAVA version detection block (head 80) ==="
sed -n '1,90p' /opt/rocketmq-4.9.7/bin/runbroker.sh 2>/dev/null
