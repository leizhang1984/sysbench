#!/bin/bash
# Pin DLedger leader to n1 (AZ-2). Arg1: "restart" to restart the broker.
set -e
CONF=/opt/rocketmq-4.9.7/conf/broker-dledger.conf
sed -i '/^preferredLeaderId=/d' "$CONF"
echo "preferredLeaderId=n1" >> "$CONF"
echo "--- updated conf ---"
grep -E 'dLegerSelfId|preferredLeaderId' "$CONF"
if [ "${1:-no}" = "restart" ]; then
  systemctl restart rocketmq-broker
  for i in $(seq 1 40); do
    sleep 2
    if ss -ltn | grep -q ':40911'; then break; fi
  done
  if ss -ltn | grep -q ':40911'; then P=UP; else P=DOWN; fi
  echo "svc:$(systemctl is-active rocketmq-broker) p40911:$P"
fi
