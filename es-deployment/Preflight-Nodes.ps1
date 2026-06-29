$RG = "es-rg"
$SCRIPT = "C:\Users\leizha\es-deployment\scripts\preflight-nodes.sh"
$nodes = @(
  "dsv5esmasterdata01","dsv5esmasterdata02","dsv5esmasterdata03",
  "dsv6esmasterdata01","dsv6esmasterdata02","dsv6esmasterdata03"
)
foreach ($n in $nodes) {
  Write-Host "======================== $n ========================"
  az vm run-command invoke -g $RG -n $n --command-id RunShellScript `
    --scripts "@$SCRIPT" --query "value[0].message" -o tsv
  Write-Host ""
}
