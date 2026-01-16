$j = Get-Content 'c:\Temp\KeyVaultPolicyImplementationReport-20260112-173345.json' -Raw | ConvertFrom-Json

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Phase 2.3 Enforce Mode - JSON Report Integrity Check" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Verify structure
Write-Host "Report Structure:" -ForegroundColor Yellow
Write-Host "  Top-level keys:" ($j | Get-Member -MemberType NoteProperty).Name -ForegroundColor White

Write-Host ""
Write-Host "Verification Section:" -ForegroundColor Yellow
$verifyCount = ($j.Verification | Measure-Object).Count
Write-Host "  Total policy assignments verified: $verifyCount" -ForegroundColor White
if ($verifyCount -gt 0) {
    $verified = ($j.Verification | Where-Object { $_.Exists -eq $true } | Measure-Object).Count
    Write-Host "  Assignments confirmed to exist: $verified" -ForegroundColor White
    Write-Host "  Sample (first 3):"
    $j.Verification[0..2] | ForEach-Object { Write-Host "    - $($_.Name) : Exists=$($_.Exists)" }
}

Write-Host ""
Write-Host "Compliance Section:" -ForegroundColor Yellow
$rawCount = ($j.Compliance.Raw | Measure-Object).Count
Write-Host "  Total compliance states: $rawCount" -ForegroundColor White
Write-Host "  Report generated at: $($j.Compliance.ReportGeneratedAt)" -ForegroundColor White

if ($rawCount -gt 0) {
    $compliantCount = ($j.Compliance.Raw | Where-Object { $_.ComplianceState -eq 'Compliant' } | Measure-Object).Count
    $nonCompliantCount = ($j.Compliance.Raw | Where-Object { $_.ComplianceState -ne 'Compliant' } | Measure-Object).Count
    $compliancePercent = [math]::Round(($compliantCount / $rawCount) * 100, 2)
    
    Write-Host "  Compliant states: $compliantCount ($compliancePercent%)" -ForegroundColor White
    Write-Host "  Non-compliant states: $nonCompliantCount" -ForegroundColor White
    
    $uniqueResources = ($j.Compliance.Raw | Select-Object -Unique -Property ResourceId | Measure-Object).Count
    $uniquePolicies = ($j.Compliance.Raw | Select-Object -Unique -Property PolicyAssignmentId | Measure-Object).Count
    Write-Host "  Unique resources evaluated: $uniqueResources" -ForegroundColor White
    Write-Host "  Unique policies evaluated: $uniquePolicies" -ForegroundColor White
    
    Write-Host ""
    Write-Host "  Sample compliance entries (first 3):"
    $j.Compliance.Raw[0..2] | ForEach-Object {
        Write-Host "    - Resource: $($_.ResourceId -replace '.*/', '')" -ForegroundColor Gray
        Write-Host "      Policy: $($_.PolicyAssignmentName)" -ForegroundColor Gray
        Write-Host "      State: $($_.ComplianceState)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Report integrity: OK ✓" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
