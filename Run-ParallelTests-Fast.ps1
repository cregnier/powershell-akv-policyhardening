<#
.SYNOPSIS
    Fast parallel test runner - skips subscription inventory, focuses on Key Vault and Policy parallel processing

.DESCRIPTION
    Runs only Test 2 (Key Vaults) and Test 3 (Policies) with parallel processing enabled
    for maximum speed on large-scale environments.

.PARAMETER AccountType
    MSA or AAD account type

.EXAMPLE
    .\Run-ParallelTests-Fast.ps1 -AccountType AAD
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('MSA', 'AAD')]
    [string]$AccountType
)

$outputFolder = ".\TestResults-$AccountType-PARALLEL-FAST-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PARALLEL PROCESSING - FAST MODE" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Skipping Test 1 (Subscription Inventory)" -ForegroundColor Yellow
Write-Host "Running only Tests 2-3 with parallel processing`n" -ForegroundColor Yellow

Write-Host "Output Folder: $outputFolder" -ForegroundColor Yellow
Write-Host "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Yellow

# Test 2: Key Vault Inventory (PARALLEL - Major speedup!)
Write-Host "[Test 1/2] Running Key Vault Inventory with PARALLEL processing..." -ForegroundColor Green
Write-Host "  ThrottleLimit: 20 concurrent subscriptions" -ForegroundColor Cyan
Write-Host "  Expected: 3-5 minutes for 838 subscriptions`n" -ForegroundColor Cyan

$transcriptPath = Join-Path $outputFolder "Test2-KeyVaults-$AccountType-PARALLEL.txt"
Start-Transcript -Path $transcriptPath -Force

$startTime = Get-Date
.\Get-KeyVaultInventory.ps1 `
    -OutputPath (Join-Path $outputFolder "KeyVaultInventory-$AccountType-PARALLEL-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv") `
    -Parallel `
    -ThrottleLimit 20
$test2Exit = $LASTEXITCODE
$test2Duration = (Get-Date) - $startTime

Stop-Transcript
Write-Host "`n  Duration: $($test2Duration.ToString('mm\:ss'))" -ForegroundColor Yellow
Write-Host "  Exit Code: $test2Exit" -ForegroundColor $(if ($test2Exit -eq 0) { 'Green' } else { 'Red' })
Write-Host "  ** Should be 10-20x FASTER than sequential! **`n" -ForegroundColor Cyan

# Test 3: Policy Assignment Inventory
Write-Host "[Test 2/2] Running Policy Assignment Inventory..." -ForegroundColor Green

$transcriptPath = Join-Path $outputFolder "Test3-Policies-$AccountType.txt"
Start-Transcript -Path $transcriptPath -Force

$startTime = Get-Date
.\Get-PolicyAssignmentInventory.ps1 -OutputPath (Join-Path $outputFolder "PolicyAssignmentInventory-$AccountType-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv")
$test3Exit = $LASTEXITCODE
$test3Duration = (Get-Date) - $startTime

Stop-Transcript
Write-Host "`n  Duration: $($test3Duration.ToString('mm\:ss'))" -ForegroundColor Yellow
Write-Host "  Exit Code: $test3Exit`n" -ForegroundColor $(if ($test3Exit -eq 0) { 'Green' } else { 'Red' })

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PARALLEL TEST SUMMARY (FAST MODE)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$totalDuration = $test2Duration + $test3Duration

Write-Host "Test 2 (Key Vaults PARALLEL): $(if ($test2Exit -eq 0) { 'PASS' } else { 'FAIL' }) - $($test2Duration.ToString('mm\:ss'))" -ForegroundColor $(if ($test2Exit -eq 0) { 'Green' } else { 'Red' })
Write-Host "Test 3 (Policies): $(if ($test3Exit -eq 0) { 'PASS' } else { 'FAIL' }) - $($test3Duration.ToString('mm\:ss'))" -ForegroundColor $(if ($test3Exit -eq 0) { 'Green' } else { 'Red' })

Write-Host "`nTotal Duration: $($totalDuration.ToString('mm\:ss'))" -ForegroundColor Yellow
Write-Host "End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Yellow

Write-Host "Results saved to: $outputFolder`n" -ForegroundColor Cyan

# Create summary file
$summaryPath = Join-Path $outputFolder "TestSummary-$AccountType-PARALLEL-FAST.txt"
@"
========================================
PARALLEL PROCESSING TEST SUMMARY - FAST MODE
========================================
Account Type: $AccountType
Test Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Output Folder: $outputFolder

TEST RESULTS:
-------------
Test 2 (Key Vaults PARALLEL): $(if ($test2Exit -eq 0) { 'PASS' } else { 'FAIL' }) - Duration: $($test2Duration.ToString('mm\:ss'))
Test 3 (Policies):           $(if ($test3Exit -eq 0) { 'PASS' } else { 'FAIL' }) - Duration: $($test3Duration.ToString('mm\:ss'))

Total Duration: $($totalDuration.ToString('mm\:ss'))

NOTE: Test 1 (Subscription Inventory) was skipped in fast mode

PERFORMANCE:
-----------
Test 2 uses parallel processing with ThrottleLimit=20
Expected speedup: 10-20x faster than sequential processing
For 838 subscriptions, expected time: 3-5 minutes vs 60+ minutes sequential

CSV FILES GENERATED:
--------------------
"@ | Out-File -FilePath $summaryPath -Encoding UTF8

Get-ChildItem -Path $outputFolder -Filter "*.csv" | ForEach-Object {
    "- $($_.Name)" | Out-File -FilePath $summaryPath -Append -Encoding UTF8
}

Write-Host "Summary saved to: $summaryPath`n" -ForegroundColor Green
