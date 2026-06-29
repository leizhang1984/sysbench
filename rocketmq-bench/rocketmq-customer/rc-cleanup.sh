#!/bin/bash
cd /mnt/c/Users/leizha/rocketmq-bench/rocketmq-customer
VM=${1:-rocketmq-client01}
for rc in $(az vm run-command list -g rocketmq-customer --vm-name $VM --query "[].name" -o tsv); do
  echo "del $rc"; az vm run-command delete -g rocketmq-customer --vm-name $VM --run-command-name $rc --yes -o none 2>/dev/null
done
echo "remaining:"; az vm run-command list -g rocketmq-customer --vm-name $VM --query "length(@)" -o tsv
