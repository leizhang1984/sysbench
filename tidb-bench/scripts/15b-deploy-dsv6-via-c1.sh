#!/bin/bash
set -e
cat >/tmp/remote-deploy-dsv6.sh <<'EOF_REMOTE'
#!/bin/bash
set -e
export HOME=/root
export TIUP_HOME=/root/.tiup
TIUP=/root/.tiup/bin/tiup

if [ ! -x "$TIUP" ]; then
  echo "NO_TIUP_ON_CLIENTVM02"
  exit 2
fi

cat > /root/topology-dv6.yaml <<'EOF_TOPO'
# =============================================================================
# TiUP 拓扑文件 - DSv6 集群 (Rocky 9.6 -> 最新)
# =============================================================================
global:
  user: "tidb"
  ssh_port: 22
  deploy_dir: "/tidb/deploy"
  data_dir: "/tidb/data"
  arch: "amd64"
  os: "linux"
server_configs:
  pd:
    replication.location-labels: ["zone", "host"]
    replication.max-replicas: 3
    log.file.filename: "/tidb/log/pd.log"
  tidb:
    log.level: "info"
    log.file.filename: "/tidb/log/tidb.log"
    log.slow-query-file: "/tidb/log/tidb-slow.log"
  tikv:
    storage.block-cache.capacity: "14GB"
    log.file.filename: "/tidb/log/tikv.log"
pd_servers:
  - host: 10.142.0.31
    name: "pd-1"
  - host: 10.142.0.32
    name: "pd-2"
  - host: 10.142.0.33
    name: "pd-3"
tidb_servers:
  - host: 10.142.0.31
  - host: 10.142.0.32
  - host: 10.142.0.33
tikv_servers:
  - host: 10.142.0.41
    config:
      server.labels: { zone: "az1", host: "dv6tikv01" }
  - host: 10.142.0.42
    config:
      server.labels: { zone: "az2", host: "dv6tikv02" }
  - host: 10.142.0.43
    config:
      server.labels: { zone: "az3", host: "dv6tikv03" }
monitoring_servers:
  - host: 10.142.0.52
grafana_servers:
  - host: 10.142.0.52
alertmanager_servers:
  - host: 10.142.0.52
EOF_TOPO

mkdir -p /home/azureadmin/.ssh && chmod 700 /home/azureadmin/.ssh
PUB=$(cat /root/.ssh/id_rsa.pub)
touch /home/azureadmin/.ssh/authorized_keys
grep -qF "$PUB" /home/azureadmin/.ssh/authorized_keys || echo "$PUB" >> /home/azureadmin/.ssh/authorized_keys
chmod 600 /home/azureadmin/.ssh/authorized_keys
chown -R azureadmin:azureadmin /home/azureadmin/.ssh
command -v restorecon >/dev/null 2>&1 && restorecon -R /home/azureadmin/.ssh || true

if $TIUP cluster list 2>/dev/null | grep -q "tidb-dsv6"; then
  echo "tidb-dsv6 already exists"
else
  $TIUP cluster deploy tidb-dsv6 v8.5.6 /root/topology-dv6.yaml -u azureadmin -i /root/.ssh/id_rsa -y
fi
$TIUP cluster start tidb-dsv6
$TIUP cluster display tidb-dsv6 | head -35
echo "DSV6_DEPLOY_DONE"
EOF_REMOTE

chmod +x /tmp/remote-deploy-dsv6.sh
scp -o StrictHostKeyChecking=no -o BatchMode=yes -i /root/.ssh/id_rsa /tmp/remote-deploy-dsv6.sh azureadmin@10.142.0.52:/tmp/remote-deploy-dsv6.sh
ssh -o StrictHostKeyChecking=no -o BatchMode=yes -i /root/.ssh/id_rsa azureadmin@10.142.0.52 'sudo bash /tmp/remote-deploy-dsv6.sh'
