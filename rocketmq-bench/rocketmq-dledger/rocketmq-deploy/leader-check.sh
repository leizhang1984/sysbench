#!/bin/bash
# Parse clusterList and report each group's leader (BID 0) IP and its AZ.
. /etc/profile.d/rocketmq.sh
az_of() {
  case "$1" in
    10.170.0.10|10.170.0.13) echo "AZ-1" ;;
    10.170.0.11|10.170.0.14) echo "AZ-2" ;;
    10.170.0.12|10.170.0.15) echo "AZ-3" ;;
    *) echo "AZ-?" ;;
  esac
}
OUT=$(mqadmin clusterList -n "$NAMESRV_ADDR" 2>/dev/null)
A=$(echo "$OUT" | awk '$2=="broker-a" && $3=="0"{print $4}' | cut -d: -f1)
B=$(echo "$OUT" | awk '$2=="broker-b" && $3=="0"{print $4}' | cut -d: -f1)
echo "broker-a leader=$A $(az_of "$A")"
echo "broker-b leader=$B $(az_of "$B")"
if [ "$(az_of "$A")" = "$(az_of "$B")" ]; then
  echo "SAME_ZONE=$(az_of "$A")"
else
  echo "SAME_ZONE=NO (a=$(az_of "$A") b=$(az_of "$B"))"
fi
