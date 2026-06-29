$RG = "es-rg"
$nodes = @(
  @{vm="dsv5esmasterdata01"; disk="dsv5esmasterdata01-datadisk"},
  @{vm="dsv5esmasterdata02"; disk="dsv5esmasterdata02-datadisk"},
  @{vm="dsv5esmasterdata03"; disk="dsv5esmasterdata03-datadisk"},
  @{vm="dsv6esmasterdata01"; disk="dsv6esmasterdata01-datadisk"},
  @{vm="dsv6esmasterdata02"; disk="dsv6esmasterdata02-datadisk"},
  @{vm="dsv6esmasterdata03"; disk="dsv6esmasterdata03-datadisk"}
)
foreach ($n in $nodes) {
  Write-Host "Attaching $($n.disk) -> $($n.vm) ..."
  az vm disk attach -g $RG --vm-name $n.vm --disk $n.disk --output none
  if ($LASTEXITCODE -eq 0) { Write-Host "  OK" } else { Write-Host "  FAILED (exit $LASTEXITCODE)" }
}
Write-Host ""
Write-Host "=== Final resource summary ==="
az vm list -g $RG --query "[].{VM:name, Zone:zones[0], OS:storageProfile.imageReference.offer, State:provisioningState}" -o table
