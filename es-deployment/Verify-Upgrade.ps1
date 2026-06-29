$RG = "es-rg"
$SCRIPT = "C:\Users\leizha\es-deployment\scripts\verify-upgrade.sh"
$rocky = @("dsv6esmasterdata01","dsv6esmasterdata02","dsv6esmasterdata03","clientvm01","clientvm02")
foreach ($n in $rocky) {
  Write-Host "======================== $n ========================"
  az vm run-command invoke -g $RG -n $n --command-id RunShellScript `
    --scripts "@$SCRIPT" --query "value[0].message" -o tsv
  Write-Host ""
}
