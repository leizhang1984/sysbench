#!/bin/bash
set -e
export HOME=/root
export TIUP_HOME=/root/.tiup
TIUP=/root/.tiup/bin/tiup

cat > /root/topology-dsv6-core.yaml <<'EOF'
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
EOF

echo "== cluster list before =="
$TIUP cluster list || true

if $TIUP cluster list 2>/dev/null | grep -q '^tidb-dsv6'; then
  echo "tidb-dsv6 exists; skip deploy"
else
  $TIUP cluster deploy tidb-dsv6 v8.5.6 /root/topology-dsv6-core.yaml -u azureadmin -i /root/.ssh/id_rsa -y
fi

$TIUP cluster start tidb-dsv6
$TIUP cluster display tidb-dsv6 | head -60
echo "DSV6_DONE"
