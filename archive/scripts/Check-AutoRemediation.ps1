# Auto-Remediation Status Checker for Scenario 3.3
# Run this script 30-60 minutes after deploying auto-remediation policies

param(
    [string]$SubscriptionId = "ab1336c7-687d-4107-b0f6-9649a0458adb"
)

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        Auto-Remediation Status Check - Scenario 3.3         ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "Checking time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Yellow

# 1. Check for remediation tasks
Write-Host "[1/5] Checking Remediation Tasks..." -ForegroundColor Yellow
$remediations = Get-AzPolicyRemediation -Scope "/subscriptions/$SubscriptionId" -ErrorAction SilentlyContinue

if ($remediations) {
    Write-Host "  ✓ Found $($remediations.Count) remediation task(s)" -ForegroundColor Green
    $remediations | Select-Object Name, ProvisioningState, 
        @{Name='Successful';Expression={$_.DeploymentSummary.TotalDeployments - $_.DeploymentSummary.FailedDeployments}},
        @{Name='Failed';Expression={$_.DeploymentSummary.FailedDeployments}},
        @{Name='Total';Expression={$_.DeploymentSummary.TotalDeployments}},
        CreatedOn | Format-Table -AutoSize
} else {
    Write-Host "  ⚠ No remediation tasks found yet. Azure may still be evaluating policies." -ForegroundColor Yellow
    Write-Host "    Wait another 15-30 minutes and try again.`n" -ForegroundColor Gray
}

# 2. Check diagnostic settings on test vaults
Write-Host "`n[2/5] Checking Diagnostic Settings on Key Vaults..." -ForegroundColor Yellow
$vaults = @("kv-compliant-2020", "kv-partial-1185", "kv-noncompliant-9503")
foreach ($vaultName in $vaults) {
    try {
        $vault = Get-AzKeyVault -VaultName $vaultName -ErrorAction Stop
        $diagnostics = Get-AzDiagnosticSetting -ResourceId $vault.ResourceId -ErrorAction SilentlyContinue
        
        if ($diagnostics) {
            Write-Host "  ✓ $vaultName : Diagnostics configured ($($diagnostics.Count) setting(s))" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ $vaultName : No diagnostic settings (not yet remediated)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ✗ $vaultName : Error checking vault" -ForegroundColor Red
    }
}

# 3. Check firewall status
Write-Host "`n[3/5] Checking Firewall Configuration..." -ForegroundColor Yellow
foreach ($vaultName in $vaults) {
    try {
        $vault = Get-AzKeyVault -VaultName $vaultName -ErrorAction Stop
        $firewallEnabled = $vault.NetworkAcls.DefaultAction -eq "Deny"
        
        if ($firewallEnabled) {
            Write-Host "  ✓ $vaultName : Firewall enabled (DefaultAction: Deny)" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ $vaultName : Firewall not enabled (DefaultAction: $($vault.NetworkAcls.DefaultAction))" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ✗ $vaultName : Error checking firewall" -ForegroundColor Red
    }
}

# 4. Check private endpoints
Write-Host "`n[4/5] Checking Private Endpoints..." -ForegroundColor Yellow
$privateEndpoints = Get-AzPrivateEndpoint -ResourceGroupName "rg-policy-keyvault-test" -ErrorAction SilentlyContinue

if ($privateEndpoints) {
    Write-Host "  ✓ Found $($privateEndpoints.Count) private endpoint(s)" -ForegroundColor Green
    $privateEndpoints | Select-Object Name, ProvisioningState, 
        @{Name='ConnectedTo';Expression={$_.PrivateLinkServiceConnections[0].PrivateLinkServiceId.Split('/')[-1]}} | 
        Format-Table -AutoSize
} else {
    Write-Host "  ⚠ No private endpoints found (not yet created by auto-remediation)" -ForegroundColor Yellow
}

# 5. Generate updated compliance report
Write-Host "`n[5/5] Generating Updated Compliance Report..." -ForegroundColor Yellow
try {
    .\AzPolicyImplScript.ps1 -CheckCompliance -SkipRBACCheck
    Write-Host "  ✓ Compliance report generated" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to generate report: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Auto-Remediation Status Check Complete" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  • If remediation tasks are 'Succeeded', check the HTML report for compliance improvement" -ForegroundColor White
Write-Host "  • If still 'In Progress', wait another 15 minutes and re-run this script" -ForegroundColor White
Write-Host "  • If 'Failed', check remediation task details for error messages`n" -ForegroundColor White
