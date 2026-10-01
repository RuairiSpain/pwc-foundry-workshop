<#
  Starts or stops lab VMs by TAG. Runs in Azure Automation under the
  Automation account's system-assigned managed identity.

  Only touches VMs tagged  schedule=auto  in the target resource group.
  Anything tagged schedule=manual (the instructor test VM) is never touched.
#>
param(
  [Parameter(Mandatory = $true)][ValidateSet('Start','Stop')][string] $Action,
  [Parameter(Mandatory = $true)][string] $ResourceGroupName,
  [string] $TagName  = 'schedule',
  [string] $TagValue = 'auto'
)

$ErrorActionPreference = 'Continue'
Write-Output "=== $Action lab VMs in $ResourceGroupName (tag $TagName=$TagValue) ==="
Write-Output "UTC now: $(Get-Date -Format o)"

try   { Connect-AzAccount -Identity | Out-Null }
catch { Write-Error "Managed identity sign-in failed: $_"; throw }

$vms = Get-AzVM -ResourceGroupName $ResourceGroupName -Status |
       Where-Object { $_.Tags[$TagName] -eq $TagValue }

if (-not $vms) { Write-Output "No VMs matched the tag. Nothing to do."; return }
Write-Output "Matched $($vms.Count) VM(s)."

$jobs = @()
foreach ($vm in $vms) {
  $state = ($vm.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).DisplayStatus
  if ($Action -eq 'Start') {
    if ($state -eq 'VM running') { Write-Output "  skip  $($vm.Name) (already running)"; continue }
    Write-Output "  start $($vm.Name)"
    $jobs += Start-Job -ScriptBlock {
      param($rg,$n) Start-AzVM -ResourceGroupName $rg -Name $n -NoWait | Out-Null
    } -ArgumentList $ResourceGroupName, $vm.Name
  }
  else {
    if ($state -eq 'VM deallocated') { Write-Output "  skip  $($vm.Name) (already deallocated)"; continue }
    Write-Output "  stop  $($vm.Name)"
    $jobs += Start-Job -ScriptBlock {
      param($rg,$n) Stop-AzVM -ResourceGroupName $rg -Name $n -Force -NoWait | Out-Null
    } -ArgumentList $ResourceGroupName, $vm.Name
  }
}

if ($jobs.Count -gt 0) {
  $jobs | Wait-Job -Timeout 600 | Out-Null
  $jobs | Receive-Job -ErrorAction Continue | Out-Null
  $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
}
Write-Output "=== $Action dispatched for $($vms.Count) VM(s) ==="
