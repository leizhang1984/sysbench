# Deploy only DSv6 cluster on clientvm02 (TiUP already present offline)
param(
  [string]$Sub = "166157a8-9ce9-400b-91c7-1d42482b83d6",
  [string]$Rg  = "tidb-rg",
  [string]$Ver = "v8.5.6"
)
$ErrorActionPreference = "Continue"
$tmpDir = "C:\Users\leizha\tidb-bench\scripts\_tmp"
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
$topo = "C:\Users\leizha\tidb-bench\topology\topology-dv6.yaml"
$b64  = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($topo)))

$deploy = @"
#!/bin/bash
set -e
export HOME=/root
export TIUP_HOME=/root/.tiup
TIUP=/root/.tiup/bin/tiup
mkdir -p /home/azureadmin/.ssh && chmod 700 /home/azureadmin/.ssh
PUB=`$(cat /root/.ssh/id_rsa.pub)
touch /home/azureadmin/.ssh/authorized_keys
grep -qF "`$PUB" /home/azureadmin/.ssh/authorized_keys || echo "`$PUB" >> /home/azureadmin/.ssh/authorized_keys
chmod 600 /home/azureadmin/.ssh/authorized_keys
chown -R azureadmin:azureadmin /home/azureadmin/.ssh
command -v restorecon >/dev/null 2>&1 && restorecon -R /home/azureadmin/.ssh || true
echo '$b64' | base64 -d > /root/topology.yaml
if `$TIUP cluster list 2>/dev/null | grep -q 'tidb-dsv6'; then
  echo 'cluster exists'
else
  `$TIUP cluster deploy tidb-dsv6 $Ver /root/topology.yaml -u azureadmin -i /root/.ssh/id_rsa -y
fi
`$TIUP cluster start tidb-dsv6
echo DEPLOY_DONE
"@
$p = Join-Path $tmpDir "deploy-dsv6.sh"
[IO.File]::WriteAllText($p, ($deploy -replace "`r`n","`n"))
$msg = az vm run-command invoke -g $Rg -n clientvm02 --subscription $Sub `
  --command-id RunShellScript --scripts "@$p" --query "value[0].message" -o tsv 2>&1
Write-Host (($msg -split "`n" | Select-Object -Last 45) -join "`n")
