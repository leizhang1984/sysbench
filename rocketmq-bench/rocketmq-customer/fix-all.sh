#!/bin/bash
cd /mnt/c/Users/leizha/rocketmq-bench/rocketmq-customer
sed -i 's/\r$//' fix-jdk11.sh
for vm in broker-a-1 broker-b-0 broker-b-1 broker-c-0 broker-c-1; do
  echo "== $vm =="
  az vm run-command create -g rocketmq-customer --vm-name $vm --run-command-name fix --async-execution false --timeout-in-seconds 90 --script @fix-jdk11.sh -o none
  az vm run-command show -g rocketmq-customer --vm-name $vm --run-command-name fix --instance-view --query instanceView.output -o tsv
done
