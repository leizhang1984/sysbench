$RG = "es-rg"
$SCRIPT = "C:\Users\leizha\es-deployment\scripts\aggregate-host.sh"
$nodes = @(
  "dsv5esmasterdata01","dsv5esmasterdata02","dsv5esmasterdata03",
  "dsv6esmasterdata01","dsv6esmasterdata02","dsv6esmasterdata03"
)
$out = "C:\Users\leizha\es-bench\report\data\host-agg.txt"
"" | Out-File -Encoding ascii $out
foreach ($n in $nodes) {
  $msg = az vm run-command invoke -g $RG -n $n --command-id RunShellScript `
    --scripts "@$SCRIPT" --query "value[0].message" -o tsv
  $line = ($msg -split "`n" | Where-Object { $_ -match "^host=" }) -join ""
  Write-Host "$n => $line"
  "$line" | Out-File -Encoding ascii -Append $out
}
