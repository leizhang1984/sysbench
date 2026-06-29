#!/bin/bash
# P2 prep: install JDK + RocketMQ + topics + Probe on client01 via managed run-command.
set -e
cd "$(dirname "$0")"
source ./00-vars.sh
az account set --subscription "$SUBSCRIPTION" >/dev/null
C=rocketmq-client01
run () {  # <name> <file>
  az vm run-command create -g "$RG" --vm-name "$C" --run-command-name "$1" \
    --async-execution false --timeout-in-seconds 1200 --script "@$2" -o none
  az vm run-command show -g "$RG" --vm-name "$C" --run-command-name "$1" \
    --instance-view --query 'instanceView.[executionState]' -o tsv
}
echo "== JDK =="; run jdk client-jdk-setup.sh
echo "== RMQ+topics =="; run rmq client-rmq-setup.sh
echo "== Probe =="; run probe probe-deploy.sh
echo "== done =="
