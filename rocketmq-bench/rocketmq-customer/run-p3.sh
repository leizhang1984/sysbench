#!/bin/bash
# P3 Failover B: SIGSTOP freeze broker-a master, two runs (retry=2 / retry=0).
set -e
cd "$(dirname "$0")"
source ./00-vars.sh
az account set --subscription "$SUBSCRIPTION" >/dev/null
C=rocketmq-client01; A0=broker-a-0
sed -i 's/\r$//' recreate-ft-topic.sh ft-produce.sh fault-sigstop.sh ft-wait.sh rc-cat-sig.sh 2>/dev/null || true
out () { az vm run-command show -g "$RG" --vm-name "$1" --run-command-name "$2" --instance-view --query instanceView.output -o tsv; }

echo "== recreate ft_topic =="
az vm run-command create -g "$RG" --vm-name "$C" --run-command-name ftopic --async-execution false --timeout-in-seconds 200 --script "@recreate-ft-topic.sh" -o none; out "$C" ftopic

do_round () { # runId retries
  echo "##### round $1 retries=$2 #####"
  az vm run-command create -g "$RG" --vm-name "$C" --run-command-name prod --async-execution false --timeout-in-seconds 120 --script "@ft-produce.sh" --parameters "$1" 180 8 50 "$2" -o none; out "$C" prod
  sleep 8
  az vm run-command create -g "$RG" --vm-name "$A0" --run-command-name sig --async-execution false --timeout-in-seconds 120 --script "@fault-sigstop.sh" --parameters 40 50 -o none; out "$A0" sig
  az vm run-command create -g "$RG" --vm-name "$C" --run-command-name wait --async-execution false --timeout-in-seconds 600 --script "@ft-wait.sh" --parameters "$1" -o none; out "$C" wait
}
do_round ftB 2
do_round ftB1 0
echo "== sigstop log =="
az vm run-command create -g "$RG" --vm-name "$A0" --run-command-name siglog --async-execution false --timeout-in-seconds 60 --script "@rc-cat-sig.sh" -o none; out "$A0" siglog
