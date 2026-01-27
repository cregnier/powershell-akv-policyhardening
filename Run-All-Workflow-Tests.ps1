# Run All 9 Workflow Tests with Output Capture
# This script executes all 9 workflow scenarios and captures output to text files
# Date: 2026-01-20
# Purpose: Comprehensive workflow validation with automated output capture

$ErrorActionPreference = 'Continue'
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Running All 9 Workflow Tests with Output Capture           ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Test 1: DevTestBaseline (30 policies)
Write-Host "=== Test 1/9: DevTestBaseline (30 policies) ===" -ForegroundColor Green
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest.json `
    -DryRun `
    -SkipRBACCheck `
    -IdentityResourceId $identityId `
    2>&1 | Tee-Object -FilePath ".\workflow-test-1-DevTestBaseline.txt"

Write-Host "`n✅ Test 1 Complete - Output saved to workflow-test-1-DevTestBaseline.txt`n" -ForegroundColor Green
Start-Sleep -Seconds 2

# Test 2: DevTestFull (46 policies)
Write-Host "=== Test 2/9: DevTestFull (46 policies) ===" -ForegroundColor Green
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full.json `
    -DryRun `
    -SkipRBACCheck `
    -IdentityResourceId $identityId `
    2>&1 | Tee-Object -FilePath ".\workflow-test-2-DevTestFull.txt"

Write-Host "`n✅ Test 2 Complete - Output saved to workflow-test-2-DevTestFull.txt`n" -ForegroundColor Green
Start-Sleep -Seconds 2

# Test 3: DevTestRemediation (46 policies + auto-remediation)
Write-Host "=== Test 3/9: DevTestRemediation (46 policies + auto-remediation) ===" -ForegroundColor Green
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -DryRun `
    -SkipRBACCheck `
    -IdentityResourceId $identityId `
    2>&1 | Tee-Object -FilePath ".\workflow-test-3-DevTestRemediation.txt"

Write-Host "`n✅ Test 3 Complete - Output saved to workflow-test-3-DevTestRemediation.txt`n" -ForegroundColor Green
Start-Sleep -Seconds 2

# Test 4: ProductionAudit (46 policies - monitoring only)
Write-Host "=== Test 4/9: ProductionAudit (46 policies - monitoring) ===" -ForegroundColor Green
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -DryRun `
    -SkipRBACCheck `
    -IdentityResourceId $identityId `
    2>&1 | Tee-Object -FilePath ".\workflow-test-4-ProductionAudit.txt"

Write-Host "`n✅ Test 4 Complete - Output saved to workflow-test-4-ProductionAudit.txt`n" -ForegroundColor Green
Start-Sleep -Seconds 2

# Test 5: ProductionDeny (requires parameter file creation)
Write-Host "=== Test 5/9: ProductionDeny ===" -ForegroundColor Yellow
if (Test-Path ".\PolicyParameters-Production-Deny.json") {
    .\AzPolicyImplScript.ps1 `
        -ParameterFile .\PolicyParameters-Production-Deny.json `
        -DryRun `
        -SkipRBACCheck `
        -IdentityResourceId $identityId `
        2>&1 | Tee-Object -FilePath ".\workflow-test-5-ProductionDeny.txt"
    Write-Host "`n✅ Test 5 Complete - Output saved to workflow-test-5-ProductionDeny.txt`n" -ForegroundColor Green
} else {
    Write-Host "⚠️  SKIPPED: PolicyParameters-Production-Deny.json does not exist" -ForegroundColor Yellow
    Write-Host "   Create this file to test maximum enforcement mode`n" -ForegroundColor Yellow
    "Test 5 SKIPPED: PolicyParameters-Production-Deny.json not found" | Out-File -FilePath ".\workflow-test-5-ProductionDeny.txt"
}
Start-Sleep -Seconds 2

# Test 6: ProductionRemediation (46 policies + auto-fix)
Write-Host "=== Test 6/9: ProductionRemediation (46 policies + auto-fix) ===" -ForegroundColor Green
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -DryRun `
    -SkipRBACCheck `
    -IdentityResourceId $identityId `
    2>&1 | Tee-Object -FilePath ".\workflow-test-6-ProductionRemediation.txt"

Write-Host "`n✅ Test 6 Complete - Output saved to workflow-test-6-ProductionRemediation.txt`n" -ForegroundColor Green
Start-Sleep -Seconds 2

# Test 7: ResourceGroupScope
Write-Host "=== Test 7/9: ResourceGroupScope ===" -ForegroundColor Green
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest.json `
    -ScopeType ResourceGroup `
    -ResourceGroupName "rg-policy-keyvault-test" `
    -DryRun `
    -SkipRBACCheck `
    -IdentityResourceId $identityId `
    2>&1 | Tee-Object -FilePath ".\workflow-test-7-ResourceGroupScope.txt"

Write-Host "`n✅ Test 7 Complete - Output saved to workflow-test-7-ResourceGroupScope.txt`n" -ForegroundColor Green
Start-Sleep -Seconds 2

# Test 8: ManagementGroupScope (requires MG ID)
Write-Host "=== Test 8/9: ManagementGroupScope ===" -ForegroundColor Yellow
Write-Host "⚠️  NOTE: This test requires a Management Group ID" -ForegroundColor Yellow
Write-Host "   Skipping for now - uncomment and provide MG ID to run`n" -ForegroundColor Yellow
"Test 8 SKIPPED: Management Group ID not provided. To run this test, edit Run-All-Workflow-Tests.ps1 and provide your Management Group ID." | Out-File -FilePath ".\workflow-test-8-ManagementGroupScope.txt"

# Uncomment and provide your Management Group ID to run:
# $mgId = "<YOUR-MANAGEMENT-GROUP-ID>"
# .\AzPolicyImplScript.ps1 `
#     -ParameterFile .\PolicyParameters-Production.json `
#     -ScopeType ManagementGroup `
#     -ManagementGroupId $mgId `
#     -DryRun `
#     -SkipRBACCheck `
#     -IdentityResourceId $identityId `
#     2>&1 | Tee-Object -FilePath ".\workflow-test-8-ManagementGroupScope.txt"

Start-Sleep -Seconds 2

# Test 9: Rollback
Write-Host "=== Test 9/9: Rollback ===" -ForegroundColor Green
.\AzPolicyImplScript.ps1 `
    -Rollback `
    -DryRun `
    2>&1 | Tee-Object -FilePath ".\workflow-test-9-Rollback.txt"

Write-Host "`n✅ Test 9 Complete - Output saved to workflow-test-9-Rollback.txt`n" -ForegroundColor Green

# Summary
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Workflow Testing Complete - Summary                         ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "Test Results Saved to:" -ForegroundColor White
Get-ChildItem ".\workflow-test-*.txt" | ForEach-Object {
    $size = [math]::Round($_.Length / 1KB, 2)
    Write-Host "  ✓ $($_.Name) ($size KB)" -ForegroundColor Green
}

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "  1. Review output files for any errors or warnings" -ForegroundColor White
Write-Host "  2. Verify no interactive prompts appeared (should be fully automated)" -ForegroundColor White
Write-Host "  3. Check that all 46 policies were processed in each test" -ForegroundColor White
Write-Host "  4. Confirm parameter file effects were used (not user input)" -ForegroundColor White
Write-Host "`n  To search for issues:" -ForegroundColor Yellow
Write-Host "    Get-ChildItem workflow-test-*.txt | Select-String 'ERROR|WARN|Skipping'" -ForegroundColor Cyan
Write-Host ""
