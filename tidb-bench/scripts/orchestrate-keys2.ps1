# =============================================================================
# Step 3b: re-fetch each control machine's pubkey and distribute via file+params.
# =============================================================================
param(
  [string]$Sub = "166157a8-9ce9-400b-91c7-1d42482b83d6",
  [string]$Rg  = "tidb-rg"
)
$ErrorActionPreference = "Continue"
$installScript = "C:\Users\leizha\tidb-bench\scripts\10-install-tiup.sh"
$addKeyScript  = "C:\Users\leizha\tidb-bench\scripts\12-add-key.sh"

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
  # split into tokens for --parameters
  $tokens = $pub -split "\s+"
  Write-Host ">>> pubkey tokens: $($tokens.Count); head=$($tokens[0])"

  $nodes = $map[$control]
  $distScript = {
    param($vm, $rg, $sub, $addKeyScript, $tokens)
    $r = az vm run-command invoke -g $rg -n $vm --subscription $sub `
           --command-id RunShellScript --scripts "@$addKeyScript" `
           --parameters $tokens `
           --query "value[0].message" -o tsv 2>&1
    $t = ($r -split "`n" | Where-Object { $_ -match "DISTRIBUTED_OK|denied|error|Error" } | Select-Object -First 1)
    return "[$vm] $t"
  }
  $jobs = @()
  foreach ($n in $nodes) {
    $jobs += Start-Job -ScriptBlock $distScript -ArgumentList $n,$Rg,$Sub,$addKeyScript,$tokens
  }
  $jobs | Wait-Job | Out-Null
  foreach ($j in $jobs) { Write-Host (Receive-Job $j) }
  $jobs | Remove-Job
}
Write-Host ">>> Step 3b done"
