$RG = "es-rg"
$samplerPath  = "C:\Users\leizha\es-deployment\scripts\hostmetrics-sampler.sh"
$templatePath = "C:\Users\leizha\es-deployment\scripts\start-sampler.template.sh"
$combinedPath = "C:\Users\leizha\es-deployment\scripts\start-sampler.combined.sh"

$sampler  = Get-Content -Raw -LiteralPath $samplerPath
$template = Get-Content -Raw -LiteralPath $templatePath
$combined = $template.Replace("__SAMPLER_BODY__", $sampler.TrimEnd())
# write LF line endings
$combined = $combined -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($combinedPath, $combined)

$nodes = @(
  "dsv5esmasterdata01","dsv5esmasterdata02","dsv5esmasterdata03",
  "dsv6esmasterdata01","dsv6esmasterdata02","dsv6esmasterdata03"
)
foreach ($n in $nodes) {
  Write-Host "======================== $n ========================"
  az vm run-command invoke -g $RG -n $n --command-id RunShellScript `
    --scripts "@$combinedPath" --query "value[0].message" -o tsv
  Write-Host ""
}
