# VerifyPolicyEffects.ps1
# Checks all Key Vault policy assignments to verify they're using supported effects
# References: KEYVAULT_POLICY_REFERENCE.md

param(
    [switch]$FixMismatch
)

Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Policy Effect Verification & Correction Tool                ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Get all Key Vault policy assignments
$assignments = Get-AzPolicyAssignment | Where-Object { 
    $_.Name -like "*keyvault*" -or $_.Name -like "*vault*" -or $_.Name -like "*secret*" -or $_.Name -like "*certificate*" -or $_.Name -like "*key*"
}

Write-Host "Found $($assignments.Count) Key Vault-related policy assignments`n" -ForegroundColor White

$issues = @()
$totalChecked = 0

foreach ($assignment in $assignments) {
    $totalChecked++
    
    # Get the policy definition
    $policyDefId = $assignment.PolicyDefinitionId
    
    try {
        # Use REST API to get full definition with effect parameters
        $token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token
        $headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
        $uri = "https://management.azure.com$policyDefId`?api-version=2021-06-01"
        $policyDef = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
        
        $policyName = $policyDef.properties.displayName
        $allowedEffects = $policyDef.properties.parameters.effect.allowedValues
        $defaultEffect = $policyDef.properties.parameters.effect.defaultValue
        
        # Get assigned effect
        $assignedEffect = $assignment.Parameter.effect.value
        if (-not $assignedEffect) {
            $assignedEffect = $defaultEffect
        }
        
        # Check if assigned effect is in allowed list
        if ($allowedEffects -and $assignedEffect -and ($allowedEffects -notcontains $assignedEffect)) {
            $issue = [PSCustomObject]@{
                AssignmentName = $assignment.Name
                PolicyName = $policyName
                AssignedEffect = $assignedEffect
                AllowedEffects = ($allowedEffects -join ', ')
                DefaultEffect = $defaultEffect
                AssignmentId = $assignment.Id
                Action = "Need to change to: $defaultEffect"
            }
            $issues += $issue
            
            Write-Host "❌ MISMATCH: $($assignment.Name.Substring(0, [Math]::Min(50, $assignment.Name.Length)))" -ForegroundColor Red
            Write-Host "   Assigned: $assignedEffect | Allowed: $($allowedEffects -join ', ')" -ForegroundColor Yellow
            Write-Host "   Should use: $defaultEffect`n" -ForegroundColor Cyan
        }
        else {
            Write-Host "✓ OK: $($policyName.Substring(0, [Math]::Min(60, $policyName.Length)))" -ForegroundColor Green
            Write-Host "   Effect: $assignedEffect" -ForegroundColor Gray
        }
        
    }
    catch {
        Write-Host "⚠️  Failed to check: $($assignment.Name)" -ForegroundColor Yellow
        Write-Host "   Error: $($_.Exception.Message.Substring(0, [Math]::Min(100, $_.Exception.Message.Length)))" -ForegroundColor Gray
    }
}

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Total assignments checked: $totalChecked" -ForegroundColor White
Write-Host "Issues found: $($issues.Count)" -ForegroundColor $(if($issues.Count -gt 0){'Red'}else{'Green'})

if ($issues.Count -gt 0) {
    Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║  POLICIES WITH EFFECT MISMATCHES                             ║" -ForegroundColor Red
    Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Red
    
    $issues | Format-Table -Property PolicyName, AssignedEffect, AllowedEffects, Action -AutoSize
    
    if ($FixMismatch) {
        Write-Host "`n🔧 FIXING MISMATCHES...`n" -ForegroundColor Yellow
        
        foreach ($issue in $issues) {
            Write-Host "Updating: $($issue.PolicyName)" -ForegroundColor Cyan
            
            try {
                $params = @{
                    effect = @{ value = $issue.DefaultEffect }
                }
                
                Set-AzPolicyAssignment -Id $issue.AssignmentId -PolicyParameter $params -ErrorAction Stop
                Write-Host "  ✓ Updated to effect=$($issue.DefaultEffect)`n" -ForegroundColor Green
            }
            catch {
                Write-Host "  ✗ Failed: $($_.Exception.Message)`n" -ForegroundColor Red
            }
        }
        
        Write-Host "`n✓ Fix complete! Retest vault creation.`n" -ForegroundColor Green
    }
    else {
        Write-Host "`nTo automatically fix these issues, run:" -ForegroundColor Yellow
        Write-Host "  .\VerifyPolicyEffects.ps1 -FixMismatch`n" -ForegroundColor White
    }
}
else {
    Write-Host "`n✓ All policy assignments are using supported effects!`n" -ForegroundColor Green
}

# Export results
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$issues | Export-Csv -Path "PolicyEffectMismatches-$timestamp.csv" -NoTypeInformation
Write-Host "Results exported to: PolicyEffectMismatches-$timestamp.csv`n" -ForegroundColor Gray
