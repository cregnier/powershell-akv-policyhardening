# Quick Status Check for Scenario 7 Auto-Remediation
# Run this script every 5-10 minutes to monitor progress

param(
    [switch]$Detailed
)

$deploymentTime = Get-Date "2026-01-27 14:10:17"
$elapsed = [math]::Round(((Get-Date) - $deploymentTime).TotalMinutes, 1)

Write-Host "`n╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  SCENARIO 7 STATUS CHECK - $elapsed minutes elapsed" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# 1. Compliance Check
Write-Host "`n📊 COMPLIANCE STATUS:" -ForegroundColor Yellow
$states = Get-AzPolicyState -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -Top 500
$compliant = ($states | Where-Object { $_.ComplianceState -eq 'Compliant' }).Count
$nonCompliant = ($states | Where-Object { $_.ComplianceState -eq 'NonCompliant' }).Count
$total = $compliant + $nonCompliant
$percent = if ($total -gt 0) { [math]::Round(($compliant / $total) * 100, 2) } else { 0 }

Write-Host "   • Compliant: $compliant" -ForegroundColor Green
Write-Host "   • Non-Compliant: $nonCompliant" -ForegroundColor Red
Write-Host "   • Compliance: $percent%" -ForegroundColor $(if($percent -gt 50){'Green'}elseif($percent -gt 30){'Yellow'}else{'Red'})
Write-Host "   • Total Evaluations: $total" -ForegroundColor White

# 2. Remediation Tasks Check
Write-Host "`n🔧 REMEDIATION TASKS:" -ForegroundColor Yellow
$remediations = Get-AzPolicyRemediation -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb" -ErrorAction SilentlyContinue |
    Where-Object { $_.CreatedOn -gt $deploymentTime }

if ($remediations) {
    Write-Host "   ✅ Found $($remediations.Count) remediation tasks!" -ForegroundColor Green
    $remediations | Select-Object Name, ProvisioningState, 
        @{N='ResourcesFixed';E={$_.DeploymentSummary.SuccessfulDeployments}},
        @{N='Failed';E={$_.DeploymentSummary.FailedDeployments}},
        CreatedOn | Format-Table -AutoSize
} else {
    Write-Host "   ⏳ No remediation tasks created yet" -ForegroundColor Yellow
    if ($elapsed -lt 75) {
        Write-Host "   ℹ️  Normal - tasks typically appear at 75-90 minutes" -ForegroundColor Gray
    } else {
        Write-Host "   ⚠️  Remediation overdue - may need manual trigger" -ForegroundColor Red
    }
}

# 3. Timeline Progress
Write-Host "`n⏱️  TIMELINE PROGRESS:" -ForegroundColor Yellow
$phases = @(
    @{ Time=0; Milestone="Deployment Start"; Status="✅ Complete" },
    @{ Time=60; Milestone="Resource Evaluation"; Status=$(if($elapsed -gt 60){"✅ Complete"}else{"⏳ In Progress"}) },
    @{ Time=75; Milestone="Remediation Task Creation"; Status=$(if($remediations.Count -gt 0){"✅ Complete"}elseif($elapsed -gt 75){"⏳ Starting"}else{"⏳ Pending"}) },
    @{ Time=85; Milestone="Remediation Execution"; Status=$(if($elapsed -gt 85){"⏳ Should be running"}else{"⏳ Pending"}) },
    @{ Time=90; Milestone="Compliance Improvement"; Status=$(if($percent -gt 50){"✅ Improved"}else{"⏳ Pending"}) }
)

foreach ($phase in $phases) {
    $color = if ($phase.Status -like "*Complete*") { 'Green' } elseif ($phase.Status -like "*Progress*" -or $phase.Status -like "*Starting*") { 'Yellow' } else { 'Gray' }
    Write-Host "   $($phase.Time) min: $($phase.Milestone) - $($phase.Status)" -ForegroundColor $color
}

# 4. Key Vault Inspection (if detailed)
if ($Detailed) {
    Write-Host "`n🔑 KEY VAULT CONFIGURATIONS:" -ForegroundColor Yellow
    $vaults = Get-AzKeyVault | Select-Object -First 5
    foreach ($vault in $vaults) {
        $detail = Get-AzKeyVault -VaultName $vault.VaultName -ResourceGroupName $vault.ResourceGroupName
        Write-Host "`n   📦 $($vault.VaultName):" -ForegroundColor Cyan
        Write-Host "      • Public Access: $(if($detail.PublicNetworkAccess -eq 'Disabled'){'Disabled ✅'}else{'Enabled ⚠️'})" -ForegroundColor $(if($detail.PublicNetworkAccess -eq 'Disabled'){'Green'}else{'Yellow'})
        Write-Host "      • Private Endpoints: $($detail.PrivateEndpointConnections.Count)" -ForegroundColor $(if($detail.PrivateEndpointConnections.Count -gt 0){'Green'}else{'Gray'})
        Write-Host "      • Firewall: $(if($detail.NetworkAcls.DefaultAction -eq 'Deny'){'Enabled ✅'}else{'Disabled ⚠️'})" -ForegroundColor $(if($detail.NetworkAcls.DefaultAction -eq 'Deny'){'Green'}else{'Yellow'})
    }
}

# 5. Recommendation
Write-Host "`n💡 NEXT STEPS:" -ForegroundColor Cyan
if ($elapsed -lt 75) {
    $waitTime = [math]::Ceiling(75 - $elapsed)
    Write-Host "   ⏱️  Wait $waitTime more minutes, then run this script again" -ForegroundColor White
    Write-Host "   📋 Expected: Remediation tasks will appear at 75-80 min" -ForegroundColor Gray
} elseif ($remediations.Count -eq 0 -and $elapsed -gt 90) {
    Write-Host "   ⚠️  Remediation overdue - consider manual trigger:" -ForegroundColor Yellow
    Write-Host "      .\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan" -ForegroundColor White
} elseif ($remediations.Count -gt 0) {
    Write-Host "   ✅ Remediation in progress - wait 10-15 min for tasks to complete" -ForegroundColor Green
    Write-Host "   📊 Then regenerate compliance report to see improvements" -ForegroundColor White
} else {
    Write-Host "   ⏱️  Check again in 5 minutes" -ForegroundColor White
}

Write-Host "`n📄 View latest compliance report:" -ForegroundColor Cyan
$latestReport = Get-ChildItem "ComplianceReport-*.html" -ErrorAction SilentlyContinue | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1
if ($latestReport) {
    Write-Host "   $($latestReport.Name) - $($latestReport.LastWriteTime.ToString('HH:mm:ss'))" -ForegroundColor White
    Write-Host "   To open: Start-Process '$($latestReport.FullName)'" -ForegroundColor Gray
}

Write-Host ""
