# Comprehensive Next-Steps Validation Test Script
# Tests all 9 workflow types to verify context-aware guidance displays correctly

$ErrorActionPreference = 'Continue'
$env:SUPPRESS_AZURE_POWERSHELL_BREAKING_CHANGE_WARNINGS = 'true'

$testResults = @()
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputFile = "test-all-workflows-$timestamp.txt"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "CONTEXT-AWARE NEXT-STEPS VALIDATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Test 1: DevTest30 (30 policies, Audit mode)
Write-Host "[1/9] Testing DevTest30 workflow..." -ForegroundColor Yellow
$test1 = ".\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -DryRun -SkipRBACCheck 2>&1"
$output1 = Invoke-Expression $test1 | Out-String
$hasDevTest30 = $output1 -match "DevTest Deployment Complete|30 policies.*Audit mode"
$testResults += [PSCustomObject]@{
    Workflow = "DevTest30"
    ParameterFile = "PolicyParameters-DevTest.json"
    Passed = $hasDevTest30
    Evidence = if ($hasDevTest30) { "✅ DevTest30 next-steps detected" } else { "❌ Failed to detect DevTest30 guidance" }
}
Write-Host "  Result: $(if ($hasDevTest30) {'✅ PASS'} else {'❌ FAIL'})`n" -ForegroundColor $(if ($hasDevTest30) {'Green'} else {'Red'})

# Test 2: DevTestFull46 (46 policies, comprehensive monitoring)
Write-Host "[2/9] Testing DevTestFull46 workflow..." -ForegroundColor Yellow
$test2 = ".\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -DryRun -SkipRBACCheck 2>&1"
$output2 = Invoke-Expression $test2 | Out-String
$hasDevTestFull = $output2 -match "DevTest Full Deployment Complete|46 policies.*comprehensive monitoring"
$testResults += [PSCustomObject]@{
    Workflow = "DevTestFull46"
    ParameterFile = "PolicyParameters-DevTest-Full.json"
    Passed = $hasDevTestFull
    Evidence = if ($hasDevTestFull) { "✅ DevTestFull46 next-steps detected" } else { "❌ Failed to detect DevTestFull46 guidance" }
}
Write-Host "  Result: $(if ($hasDevTestFull) {'✅ PASS'} else {'❌ FAIL'})`n" -ForegroundColor $(if ($hasDevTestFull) {'Green'} else {'Red'})

# Test 3: DevTestRemediation (8 DeployIfNotExists policies)
Write-Host "[3/9] Testing DevTestRemediation workflow..." -ForegroundColor Yellow
if (Test-Path ".\PolicyParameters-DevTest-Full-Remediation.json") {
    $test3 = ".\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json -DryRun -SkipRBACCheck 2>&1"
    $output3 = Invoke-Expression $test3 | Out-String
    $hasRemediation = $output3 -match "DevTest Remediation Testing|8 auto-remediation policies|15-30 minute wait"
    $testResults += [PSCustomObject]@{
        Workflow = "DevTestRemediation"
        ParameterFile = "PolicyParameters-DevTest-Full-Remediation.json"
        Passed = $hasRemediation
        Evidence = if ($hasRemediation) { "✅ DevTestRemediation next-steps detected" } else { "❌ Failed to detect remediation guidance" }
    }
    Write-Host "  Result: $(if ($hasRemediation) {'✅ PASS'} else {'❌ FAIL'})`n" -ForegroundColor $(if ($hasRemediation) {'Green'} else {'Red'})
} else {
    Write-Host "  Result: ⏭️  SKIP (parameter file not found)`n" -ForegroundColor Gray
    $testResults += [PSCustomObject]@{
        Workflow = "DevTestRemediation"
        ParameterFile = "PolicyParameters-DevTest-Full-Remediation.json"
        Passed = $null
        Evidence = "⏭️ Parameter file not found"
    }
}

# Test 4: ProductionAudit (46 policies, Audit mode)
Write-Host "[4/9] Testing ProductionAudit workflow..." -ForegroundColor Yellow
if (Test-Path ".\PolicyParameters-Production.json") {
    $test4 = ".\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -DryRun -SkipRBACCheck 2>&1"
    $output4 = Invoke-Expression $test4 | Out-String
    $hasProdAudit = $output4 -match "Production Audit Mode|30-90 day monitoring|stakeholder communication"
    $testResults += [PSCustomObject]@{
        Workflow = "ProductionAudit"
        ParameterFile = "PolicyParameters-Production.json"
        Passed = $hasProdAudit
        Evidence = if ($hasProdAudit) { "✅ ProductionAudit next-steps detected" } else { "❌ Failed to detect production audit guidance" }
    }
    Write-Host "  Result: $(if ($hasProdAudit) {'✅ PASS'} else {'❌ FAIL'})`n" -ForegroundColor $(if ($hasProdAudit) {'Green'} else {'Red'})
} else {
    Write-Host "  Result: ⏭️  SKIP (parameter file not found)`n" -ForegroundColor Gray
    $testResults += [PSCustomObject]@{
        Workflow = "ProductionAudit"
        ParameterFile = "PolicyParameters-Production.json"
        Passed = $null
        Evidence = "⏭️ Parameter file not found"
    }
}

# Test 5: ProductionDeny (46 policies, Deny enforcement)
Write-Host "[5/9] Testing ProductionDeny workflow..." -ForegroundColor Yellow
Write-Host "  Note: Checking if Production.json has Deny effect parameters..." -ForegroundColor Gray
if (Test-Path ".\PolicyParameters-Production.json") {
    $prodContent = Get-Content ".\PolicyParameters-Production.json" -Raw | ConvertFrom-Json
    $hasDenyEffect = $prodContent.parameters.PSObject.Properties | Where-Object { $_.Value.value -eq "Deny" }
    
    if ($hasDenyEffect) {
        # This would show ProductionDeny guidance
        $test5 = ".\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -DryRun -SkipRBACCheck 2>&1"
        $output5 = Invoke-Expression $test5 | Out-String
        $hasProdDeny = $output5 -match "Production Enforcement Active|Deny mode enforcement|stakeholder notification"
        $testResults += [PSCustomObject]@{
            Workflow = "ProductionDeny"
            ParameterFile = "PolicyParameters-Production.json (Deny effect)"
            Passed = $hasProdDeny
            Evidence = if ($hasProdDeny) { "✅ ProductionDeny next-steps detected" } else { "❌ Failed to detect production deny guidance" }
        }
        Write-Host "  Result: $(if ($hasProdDeny) {'✅ PASS'} else {'❌ FAIL'})`n" -ForegroundColor $(if ($hasProdDeny) {'Green'} else {'Red'})
    } else {
        Write-Host "  Result: ⏭️  SKIP (Production.json has Audit effect, not Deny)`n" -ForegroundColor Gray
        $testResults += [PSCustomObject]@{
            Workflow = "ProductionDeny"
            ParameterFile = "PolicyParameters-Production.json"
            Passed = $null
            Evidence = "⏭️ Production.json configured for Audit mode"
        }
    }
} else {
    Write-Host "  Result: ⏭️  SKIP (parameter file not found)`n" -ForegroundColor Gray
    $testResults += [PSCustomObject]@{
        Workflow = "ProductionDeny"
        ParameterFile = "PolicyParameters-Production.json"
        Passed = $null
        Evidence = "⏭️ Parameter file not found"
    }
}

# Test 6: ProductionRemediation (8 policies in production)
Write-Host "[6/9] Testing ProductionRemediation workflow..." -ForegroundColor Yellow
if (Test-Path ".\PolicyParameters-Production-Remediation.json") {
    $test6 = ".\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Remediation.json -DryRun -SkipRBACCheck 2>&1"
    $output6 = Invoke-Expression $test6 | Out-String
    $hasProdRemediation = $output6 -match "Production Auto-Remediation|HIGH RISK|emergency response|change control"
    $testResults += [PSCustomObject]@{
        Workflow = "ProductionRemediation"
        ParameterFile = "PolicyParameters-Production-Remediation.json"
        Passed = $hasProdRemediation
        Evidence = if ($hasProdRemediation) { "✅ ProductionRemediation next-steps detected" } else { "❌ Failed to detect production remediation guidance" }
    }
    Write-Host "  Result: $(if ($hasProdRemediation) {'✅ PASS'} else {'❌ FAIL'})`n" -ForegroundColor $(if ($hasProdRemediation) {'Green'} else {'Red'})
} else {
    Write-Host "  Result: ⏭️  SKIP (parameter file not found)`n" -ForegroundColor Gray
    $testResults += [PSCustomObject]@{
        Workflow = "ProductionRemediation"
        ParameterFile = "PolicyParameters-Production-Remediation.json"
        Passed = $null
        Evidence = "⏭️ Parameter file not found"
    }
}

# Test 7: TierBased (phased rollout)
Write-Host "[7/9] Testing TierBased workflow..." -ForegroundColor Yellow
# Check for tier-based parameter files
$tierFiles = @(
    ".\PolicyParameters-Tier1.json",
    ".\PolicyParameters-Tier1-Production.json",
    ".\PolicyDeploymentTier1.json"
)
$tierFile = $tierFiles | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($tierFile) {
    $test7 = ".\AzPolicyImplScript.ps1 -ParameterFile $tierFile -DryRun -SkipRBACCheck 2>&1"
    $output7 = Invoke-Expression $test7 | Out-String
    $hasTierBased = $output7 -match "Tier.*Deployment|phased rollout|tier progression|Tier 2.*Tier 3"
    $testResults += [PSCustomObject]@{
        Workflow = "TierBased"
        ParameterFile = Split-Path $tierFile -Leaf
        Passed = $hasTierBased
        Evidence = if ($hasTierBased) { "✅ TierBased next-steps detected" } else { "❌ Failed to detect tier-based guidance" }
    }
    Write-Host "  Result: $(if ($hasTierBased) {'✅ PASS'} else {'❌ FAIL'})`n" -ForegroundColor $(if ($hasTierBased) {'Green'} else {'Red'})
} else {
    Write-Host "  Result: ⏭️  SKIP (no tier-based parameter files found)`n" -ForegroundColor Gray
    $testResults += [PSCustomObject]@{
        Workflow = "TierBased"
        ParameterFile = "None found (Tier1/Tier2/Tier3.json)"
        Passed = $null
        Evidence = "⏭️ No tier-based parameter files detected"
    }
}

# Test 8: Dry-Run mode (validation without deployment)
Write-Host "[8/9] Testing Dry-Run mode workflow..." -ForegroundColor Yellow
$test8 = ".\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -DryRun -SkipRBACCheck 2>&1"
$output8 = Invoke-Expression $test8 | Out-String
$hasDryRun = $output8 -match "Dry-Run Validation Complete|dry-run summary|Review dry-run summary|DryRunSummary"
$testResults += [PSCustomObject]@{
    Workflow = "Dry-Run"
    ParameterFile = "-DryRun flag (runtime mode)"
    Passed = $hasDryRun
    Evidence = if ($hasDryRun) { "✅ Dry-Run next-steps detected" } else { "❌ Failed to detect dry-run guidance" }
}
Write-Host "  Result: $(if ($hasDryRun) {'✅ PASS'} else {'❌ FAIL'})`n" -ForegroundColor $(if ($hasDryRun) {'Green'} else {'Red'})

# Test 9: Rollback (policy removal)
Write-Host "[9/9] Testing Rollback workflow..." -ForegroundColor Yellow
Write-Host "  Note: Running -Rollback with -WhatIf to avoid actual removal..." -ForegroundColor Gray
$test9 = ".\AzPolicyImplScript.ps1 -Rollback -WhatIf -SkipRBACCheck 2>&1"
$output9 = Invoke-Expression $test9 | Out-String
$hasRollback = $output9 -match "Policy Rollback Complete|rollback does NOT undo|re-deploy when ready|compliance state reset"
$testResults += [PSCustomObject]@{
    Workflow = "Rollback"
    ParameterFile = "-Rollback flag (runtime operation)"
    Passed = $hasRollback
    Evidence = if ($hasRollback) { "✅ Rollback next-steps detected" } else { "❌ Failed to detect rollback guidance" }
}
Write-Host "  Result: $(if ($hasRollback) {'✅ PASS'} else {'❌ FAIL'})`n" -ForegroundColor $(if ($hasRollback) {'Green'} else {'Red'})

# Summary Report
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$passedTests = ($testResults | Where-Object { $_.Passed -eq $true }).Count
$failedTests = ($testResults | Where-Object { $_.Passed -eq $false }).Count
$skippedTests = ($testResults | Where-Object { $_.Passed -eq $null }).Count
$totalTests = $testResults.Count

Write-Host "Total Tests:   $totalTests" -ForegroundColor White
Write-Host "Passed:        $passedTests" -ForegroundColor Green
Write-Host "Failed:        $failedTests" -ForegroundColor Red
Write-Host "Skipped:       $skippedTests" -ForegroundColor Gray
Write-Host "Success Rate:  $([math]::Round(($passedTests / ($totalTests - $skippedTests)) * 100, 1))%`n" -ForegroundColor Cyan

# Detailed Results
Write-Host "DETAILED RESULTS:" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────`n" -ForegroundColor Gray
$testResults | Format-Table -AutoSize -Property Workflow, ParameterFile, Evidence

# Save to file
$reportContent = @"
========================================
CONTEXT-AWARE NEXT-STEPS VALIDATION
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
========================================

SUMMARY:
  Total Tests:   $totalTests
  Passed:        $passedTests
  Failed:        $failedTests
  Skipped:       $skippedTests
  Success Rate:  $([math]::Round(($passedTests / ($totalTests - $skippedTests)) * 100, 1))%

DETAILED RESULTS:
$($testResults | Format-Table -AutoSize | Out-String)

TEST EVIDENCE:
──────────────────────────────────────────────────────────────────

"@

foreach ($result in $testResults) {
    $reportContent += "`n[$($result.Workflow)]`n"
    $reportContent += "  Parameter File: $($result.ParameterFile)`n"
    $reportContent += "  Result: $($result.Evidence)`n"
}

$reportContent | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "`n✅ Full test report saved to: $outputFile" -ForegroundColor Green
Write-Host "`n========================================`n" -ForegroundColor Cyan

# Return summary for further processing
return [PSCustomObject]@{
    TotalTests = $totalTests
    Passed = $passedTests
    Failed = $failedTests
    Skipped = $skippedTests
    SuccessRate = [math]::Round(($passedTests / ($totalTests - $skippedTests)) * 100, 1)
    Results = $testResults
    ReportFile = $outputFile
}
