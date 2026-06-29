# =============================================================================
# Step 4: deploy both TiDB clusters via TiUP on control machines.
#   - upload topology (base64) to control machine
#   - add control machine's own pubkey to its own authorized_keys (monitoring target)
#   - tiup cluster deploy + start  (non-interactive)
# =============================================================================
param(
  [string]$Sub = "166157a8-9ce9-400b-91c7-1d42482b83d6",
  [string]$Rg  = "tidb-rg",
  [string]$Ver = "v8.5.6"
)
$ErrorActionPreference = "Continue"
$tmpDir = "C:\Users\leizha\tidb-bench\scripts\_tmp"
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

$clusters = @(
  @{ control="clientvm01"; name="tidb-dsv5"; topo="C:\Users\leizha\tidb-bench\topology\topology-dv5.yaml" },
  @{ control="clientvm02"; name="tidb-dsv6"; topo="C:\Users\leizha\tidb-bench\topology\topology-dv6.yaml" }
)

foreach ($c in $clusters) {
  Write-Host "==================== Deploy $($c.name) on $($c.control) ===================="
  $topoText = [IO.File]::ReadAllText($c.topo)
  $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($topoText))

  $deploy = @"
#!/bin/bash
set -e
export HOME=/root
export TIUP_HOME=/root/.tiup
export PATH=/root/.tiup/bin:`$PATH
TIUP=/root/.tiup/bin/tiup
# 1) self pubkey into own authorized_keys (monitoring deploys to control machine itself)
mkdir -p /home/azureadmin/.ssh && chmod 700 /home/azureadmin/.ssh
PUB=`$(cat /root/.ssh/id_rsa.pub)
touch /home/azureadmin/.ssh/authorized_keys
grep -qF "`$PUB" /home/azureadmin/.ssh/authorized_keys || echo "`$PUB" >> /home/azureadmin/.ssh/authorized_keys
chmod 600 /home/azureadmin/.ssh/authorized_keys
chown -R azureadmin:azureadmin /home/azureadmin/.ssh
command -v restorecon >/dev/null 2>&1 && restorecon -R /home/azureadmin/.ssh || true
# 2) write topology
echo '$b64' | base64 -d > /root/topology.yaml
echo '----- topology head -----'; head -3 /root/topology.yaml
# 3) deploy (idempotent-ish)
if `$TIUP cluster list 2>/dev/null | grep -q '$($c.name)'; then
  echo 'cluster already exists, skipping deploy'
else
  `$TIUP cluster deploy $($c.name) $Ver /root/topology.yaml -u azureadmin -i /root/.ssh/id_rsa -y
fi
# 4) start
`$TIUP cluster start $($c.name)
echo 'DEPLOY_DONE'
"@
  $deployPath = Join-Path $tmpDir "deploy-$($c.name).sh"
  [IO.File]::WriteAllText($deployPath, ($deploy -replace "`r`n","`n"))

  $msg = az vm run-command invoke -g $Rg -n $c.control --subscription $Sub `
           --command-id RunShellScript --scripts "@$deployPath" `
           --query "value[0].message" -o tsv 2>&1
  # print tail
  $tail = ($msg -split "`n" | Select-Object -Last 40) -join "`n"
  Write-Host $tail
}
Write-Host ">>> Step 4 done"
