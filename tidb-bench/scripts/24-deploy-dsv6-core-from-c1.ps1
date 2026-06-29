param(
  [string]$Sub = "166157a8-9ce9-400b-91c7-1d42482b83d6",
  [string]$Rg  = "tidb-rg"
)
$ErrorActionPreference = "Continue"

# 1) fetch clientvm01 pubkey
$pubMsg = az vm run-command invoke -g $Rg -n clientvm01 --subscription $Sub --command-id RunShellScript --scripts "cat /root/.ssh/id_rsa.pub" --query "value[0].message" -o tsv 2>&1
$pub = ($pubMsg -split "`n" | Where-Object { $_ -match "^ssh-rsa" } | Select-Object -First 1).Trim()
if (-not $pub.StartsWith("ssh-rsa")) { throw "cannot get clientvm01 pubkey" }
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pub))

# 2) authorize clientvm01 key to 6 dv6 nodes
$nodes = @("dv6tidb01","dv6tidb02","dv6tidb03","dv6tikv01","dv6tikv02","dv6tikv03")
$add = @"
#!/bin/bash
set -e
PUB=`$(echo '$b64' | base64 -d)
mkdir -p /home/azureadmin/.ssh
chmod 700 /home/azureadmin/.ssh
touch /home/azureadmin/.ssh/authorized_keys
grep -qF "`$PUB" /home/azureadmin/.ssh/authorized_keys || echo "`$PUB" >> /home/azureadmin/.ssh/authorized_keys
chmod 600 /home/azureadmin/.ssh/authorized_keys
chown -R azureadmin:azureadmin /home/azureadmin/.ssh
command -v restorecon >/dev/null 2>&1 && restorecon -R /home/azureadmin/.ssh || true
echo KEY_OK
"@
$addPath = "C:\Users\leizha\tidb-bench\scripts\_tmp\add-c1-key-dv6.sh"
[IO.File]::WriteAllText($addPath, ($add -replace "`r`n","`n"))
foreach ($n in $nodes) {
  $r = az vm run-command invoke -g $Rg -n $n --subscription $Sub --command-id RunShellScript --scripts "@$addPath" --query "value[0].message" -o tsv 2>&1
  $m = (($r -split "`n" | Where-Object { $_ -match "KEY_OK|denied|rror" } | Select-Object -First 1))
  Write-Host "[$n] $m"
}

# 3) from clientvm01 deploy tidb-dsv6-core (only TiDB/PD/TiKV)
$remote = @"
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

if $TIUP cluster list 2>/dev/null | grep -q '^tidb-dsv6'; then
  echo "tidb-dsv6 already exists"
else
  $TIUP cluster deploy tidb-dsv6 v8.5.6 /root/topology-dsv6-core.yaml -u azureadmin -i /root/.ssh/id_rsa -y
fi
$TIUP cluster start tidb-dsv6
$TIUP cluster display tidb-dsv6 | head -40
echo DSV6_CORE_DONE
"@
$remotePath = "C:\Users\leizha\tidb-bench\scripts\_tmp\deploy-dsv6-core-on-c1.sh"
[IO.File]::WriteAllText($remotePath, ($remote -replace "`r`n","`n"))
$deployOut = az vm run-command invoke -g $Rg -n clientvm01 --subscription $Sub --command-id RunShellScript --scripts "@$remotePath" --query "value[0].message" -o tsv 2>&1
Write-Host (($deployOut -split "`n" | Select-Object -Last 80) -join "`n")
