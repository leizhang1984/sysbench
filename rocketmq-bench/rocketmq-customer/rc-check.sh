#!/bin/bash
RG=rocketmq-customer
NS=v6rocketmqnamesvr01
read -r -d '' S <<'EOF'
systemctl is-active rmq-namesrv
ss -lnt | grep 9876 || echo noport
java -version 2>&1 | head -1
ls /opt
EOF
az vm run-command invoke -g "$RG" -n "$NS" --command-id RunShellScript --scripts "$S" --query 'value[0].message' -o tsv
