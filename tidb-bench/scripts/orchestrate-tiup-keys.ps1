# =============================================================================
# Step 3: install TiUP on both control machines, generate keypair,
#         distribute each control machine's pubkey to azureadmin on its 6 nodes.
# Mapping:
#   clientvm01 (DSv5 control) -> dv5tidb01/02/03, dv5tikv01/02/03
#   clientvm02 (DSv6 control) -> dv6tidb01/02/03, dv6tikv01/02/03
# =============================================================================
param(
  [string]$Sub = "166157a8-9ce9-400b-91c7-1d42482b83d6",
  [string]$Rg  = "tidb-rg"
)
$ErrorActionPreference = "Continue"
$installScript = "C:\Users\leizha\tidb-bench\scripts\10-install-tiup.sh"

$map = @{
  "clientvm01" = @("dv5tidb01","dv5tidb02","dv5tidb03","dv5tikv01","dv5tikv02","dv5tikv03")
  "clientvm02" = @("dv6tidb01","dv6tidb02","dv6tidb03","dv6tikv01","dv6tikv02","dv6tikv03")
}

foreach ($control in $map.Keys) {
  Write-Host "==================== Control: $control ===================="
  Write-Host ">>> Installing TiUP + generating key on $control ..."
  $msg = az vm run-command invoke -g $Rg -n $control --subscription $Sub `
           --command-id RunShellScript --scripts "@$installScript" `
           --query "value[0].message" -o tsv 2>&1

  # Extract pubkey between markers
  $lines = $msg -split "`n"
  $capture = $false; $pub = ""
  foreach ($l in $lines) {
    if ($l -match "PUBKEY_BEGIN") { $capture = $true; continue }
    if ($l -match "PUBKEY_END")   { $capture = $false; continue }
    if ($capture) { $pub += ($l.Trim() + " ") }
  }
  $pub = $pub.Trim()
  if (-not $pub.StartsWith("ssh-rsa")) {
    Write-Host "!!! Failed to capture pubkey from $control. Raw tail:"
    Write-Host (($lines | Select-Object -Last 20) -join "`n")
    continue
  }
  Write-Host ">>> Captured pubkey: $($pub.Substring(0,[Math]::Min(50,$pub.Length)))..."

  # Distribute to azureadmin authorized_keys on each target node (parallel)
  $nodes = $map[$control]
  $distScript = {
    param($vm, $rg, $sub, $pub)
    $remote = @"
set -e
mkdir -p /home/azureadmin/.ssh
chmod 700 /home/azureadmin/.ssh
touch /home/azureadmin/.ssh/authorized_keys
grep -qF '$pub' /home/azureadmin/.ssh/authorized_keys || echo '$pub' >> /home/azureadmin/.ssh/authorized_keys
chmod 600 /home/azureadmin/.ssh/authorized_keys
chown -R azureadmin:azureadmin /home/azureadmin/.ssh
echo DISTRIBUTED_OK
"@
    $r = az vm run-command invoke -g $rg -n $vm --subscription $sub `
           --command-id RunShellScript --scripts "$remote" `
           --query "value[0].message" -o tsv 2>&1
    return "[$vm] $r"
  }
  $jobs = @()
  foreach ($n in $nodes) {
    $jobs += Start-Job -ScriptBlock $distScript -ArgumentList $n,$Rg,$Sub,$pub
  }
  $jobs | Wait-Job | Out-Null
  foreach ($j in $jobs) {
    $res = Receive-Job $j
    $tail = ($res -split "`n" | Select-Object -Last 3) -join " "
    Write-Host $tail
  }
  $jobs | Remove-Job
}
Write-Host ">>> Step 3 done (TiUP installed, keys distributed)"
