$RG = "es-rg"
$SCRIPT = "C:\Users\leizha\es-deployment\scripts\install-rally-venv.sh"
foreach ($n in @("clientvm01","clientvm02")) {
  Write-Host "======================== $n ========================"
  az vm run-command invoke -g $RG -n $n --command-id RunShellScript `
    --scripts "@$SCRIPT" --query "value[0].message" -o tsv
  Write-Host ""
}
