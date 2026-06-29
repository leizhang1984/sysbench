#!/bin/bash
set +e
MQ=/opt/rocketmq-4.9.7
echo "=== HOST: $(hostname) ==="

echo "--- grow data filesystem to full 500G ---"
DEV=/dev/nvme0n2
growpart $DEV 1 2>&1 | tail -1
xfs_growfs /datadisk 2>&1 | tail -1
df -h /datadisk | tail -1

echo "--- write broker-dledger.conf (selfId=n2) ---"
cat > $MQ/conf/broker-dledger.conf <<'EOF'
brokerClusterName=RocketMQCluster
brokerName=broker-b
listenPort=10911
namesrvAddr=10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876
flushDiskType=ASYNC_FLUSH
storePathRootDir=/datadisk/rocketmq/store
storePathCommitLog=/datadisk/rocketmq/store/commitlog
enableDLegerCommitLog=true
dLegerGroup=broker-b
dLegerPeers=n0-10.170.0.13:40911;n1-10.170.0.14:40911;n2-10.170.0.15:40911
dLegerSelfId=n2
sendMessageThreadPoolNums=16
autoCreateTopicEnable=true
preferredLeaderId=n1
EOF

echo "--- write start-broker.sh ---"
cat > $MQ/bin/start-broker.sh <<'EOF'
#!/bin/bash
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
exec "$ROCKETMQ_HOME/bin/mqbroker" -c "$ROCKETMQ_HOME/conf/broker-dledger.conf"
EOF
chmod +x $MQ/bin/start-broker.sh

echo "--- inject JVM module flags into runbroker.sh ---"
RB=$MQ/bin/runbroker.sh
if grep -q "add-exports=java.base/jdk.internal.ref" "$RB"; then
  echo "flags already present"
else
  cp "$RB" "$RB.bak.$(date +%s)"
  sed -i '/-XX:-UseLargePages -XX:-UseBiasedLocking"/a JAVA_OPT="${JAVA_OPT} --add-exports=java.base/jdk.internal.ref=ALL-UNNAMED --add-exports=java.base/sun.nio.ch=ALL-UNNAMED --add-exports=java.management/sun.management=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED"' "$RB"
  echo "INJECTED flags"
fi
grep -c "add-exports=java.base/jdk.internal.ref" "$RB"

echo "--- write systemd unit ---"
cat > /etc/systemd/system/rocketmq-broker.service <<'EOF'
[Unit]
Description=Apache RocketMQ Broker (DLedger) 4.9.7
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/rocketmq-4.9.7/bin/start-broker.sh
Restart=on-failure
RestartSec=10
User=root
LimitNOFILE=655350

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable rocketmq-broker.service 2>&1 | tail -1
systemctl reset-failed rocketmq-broker.service 2>/dev/null
systemctl restart rocketmq-broker.service
echo "--- wait 35s for startup + dledger sync ---"
sleep 35
echo "--- status ---"
systemctl is-active rocketmq-broker.service
pgrep -f BrokerStartup >/dev/null && echo "proc=UP" || echo "proc=DOWN"
ss -ltn 2>/dev/null | grep -E ':10911|:40911'
echo "--- broker log tail ---"
tail -15 /opt/rocketmq-4.9.7/logs/rocketmqlogs/broker.log 2>/dev/null
