#!/bin/bash
set -e
TS=$(date +%Y%m%d%H%M%S)
STORE=/datadisk/rocketmq/store
if systemctl list-unit-files | grep -q '^rocketmq-broker.service'; then
  systemctl stop rocketmq-broker.service || true
fi
if [ -d "$STORE" ]; then
  mv "$STORE" "/datadisk/rocketmq/store.bak.$TS"
fi
mkdir -p "$STORE/config"
chown -R root:root "$STORE"
echo "reset done on $(hostname), backup=/datadisk/rocketmq/store.bak.$TS"
