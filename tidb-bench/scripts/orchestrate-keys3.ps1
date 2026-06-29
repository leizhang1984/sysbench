# =============================================================================
# Step 3c (robust): capture each control machine's pubkey, base64-encode it,
# bake into a per-node script that decodes & appends to authorized_keys.
# Avoids az run-command --parameters '=' splitting that corrupted the key.
# =============================================================================
param(
  [string]$Sub = "166157a8-9ce9-400b-91c7-1d42482b83d6",
  [string]$Rg  = "tidb-rg"
)
$ErrorActionPreference = "Continue"
$installScript = "C:\Users\leizha\tidb-bench\scripts\10-install-tiup.sh"
$tmpDir = "C:\Users\leizha\tidb-bench\scripts\_tmp"
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

$map = @{
  "clientvm01" = @("dv5tidb01","dv5tidb02","dv5tidb03","dv5tikv01","dv5tikv02","dv5tikv03")
  "clientvm02" = @("dv6tidb01","dv6tidb02","dv6tidb03","dv6tikv01","dv6tikv02","dv6tikv03")
}

foreach ($control in $map.Keys) {
  Write-Host "==================== Control: $control ===================="
  $msg = az vm run-command invoke -g $Rg -n $control --subscription $Sub `
           --command-id RunShellScript --scripts "@$installScript" `
           --query "value[0].message" -o tsv 2>&1
  $lines = $msg -split "`n"
  $capture = $false; $pub = ""
  foreach ($l in $lines) {
    if ($l -match "PUBKEY_BEGIN") { $capture = $true; continue }
    if ($l -match "PUBKEY_END")   { $capture = $false; continue }
    if ($capture) { $pub += ($l.Trim() + " ") }
  }
  $pub = $pub.Trim()
  if (-not $pub.StartsWith("ssh-rsa")) { Write-Host "!!! no pubkey from $control"; continue }
  Write-Host ">>> pubkey len=$($pub.Length)"

  # base64-encode the pubkey (UTF8) -> safe single token
  $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pub))

  # Build a node script with the b64 baked in (LF line endings)
  $nodeScript = @"
#!/bin/bash
set -e
mkdir -p /home/azureadmin/.ssh
chmod 700 /home/azureadmin/.ssh
PUB=`$(echo '$b64' | base64 -d)
touch /home/azureadmin/.ssh/authorized_keys
grep -qF "`$PUB" /home/azureadmin/.ssh/authorized_keys || echo "`$PUB" >> /home/azureadmin/.ssh/authorized_keys
chmod 600 /home/azureadmin/.ssh/authorized_keys
chown -R azureadmin:azureadmin /home/azureadmin/.ssh
command -v restorecon >/dev/null 2>&1 && restorecon -R /home/azureadmin/.ssh || true
echo "OK fields=`$(awk '{print NF}' /home/azureadmin/.ssh/authorized_keys | tail -1)"
"@
  $nodeScriptPath = Join-Path $tmpDir "addkey-$control.sh"
  # write with LF
  [IO.File]::WriteAllText($nodeScriptPath, ($nodeScript -replace "`r`n","`n"))

  $nodes = $map[$control]
  $distScript = {
    param($vm, $rg, $sub, $path)
    $r = az vm run-command invoke -g $rg -n $vm --subscription $sub `
           --command-id RunShellScript --scripts "@$path" `
           --query "value[0].message" -o tsv 2>&1
    $t = ($r -split "`n" | Where-Object { $_ -match "OK fields|denied|rror" } | Select-Object -First 1)
    return "[$vm] $t"
  }
  $jobs = @()
  foreach ($n in $nodes) {
    $jobs += Start-Job -ScriptBlock $distScript -ArgumentList $n,$Rg,$Sub,$nodeScriptPath
  }
  $jobs | Wait-Job | Out-Null
  foreach ($j in $jobs) { Write-Host (Receive-Job $j) }
  $jobs | Remove-Job
}
Write-Host ">>> Step 3c done"
