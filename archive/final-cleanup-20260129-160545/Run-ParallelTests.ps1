<#
.SYNOPSIS
    Quick parallel test runner for AAD comprehensive tests

.DESCRIPTION
    Runs inventory scripts with -Parallel switch for 10-20x speed improvement
    on large-scale environments (hundreds of subscriptions)

.PARAMETER AccountType
    MSA or AAD account type

.PARAMETER OutputFolder
    Folder for test results and transcripts

.EXAMPLE
    .\Run-ParallelTests.ps1 -AccountType AAD
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('MSA', 'AAD')]
    [string]$AccountType,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputFolder = ".\TestResults-$AccountType-PARALLEL-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
)

# Create output folder
New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PARALLEL PROCESSING TEST - $AccountType Account" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Output Folder: $OutputFolder" -ForegroundColor Yellow
Write-Host "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Yellow

# Test 1: Subscription Inventory (already fast, no parallel needed)
Write-Host "[Test 1/3] Running Subscription Inventory..." -ForegroundColor Green
$transcriptPath = Join-Path $OutputFolder "Test1-Subscriptions-$AccountType.txt"
Start-Transcript -Path $transcriptPath -Force

$startTime = Get-Date
.\Get-AzureSubscriptionInventory.ps1 -OutputPath (Join-Path $OutputFolder "SubscriptionInventory-$AccountType-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv")
$test1Exit = $LASTEXITCODE
$test1Duration = (Get-Date) - $startTime

Stop-Transcript
Write-Host "  Duration: $($test1Duration.ToString('mm\:ss'))" -ForegroundColor Yellow
Write-Host "  Exit Code: $test1Exit`n" -ForegroundColor $(if ($test1Exit -eq 0) { 'Green' } else { 'Red' })

# Test 2: Key Vault Inventory (PARALLEL - Major speedup!)
Write-Host "[Test 2/3] Running Key Vault Inventory with PARALLEL processing..." -ForegroundColor Green
$transcriptPath = Join-Path $OutputFolder "Test2-KeyVaults-$AccountType-PARALLEL.txt"
Start-Transcript -Path $transcriptPath -Force

$startTime = Get-Date
.\Get-KeyVaultInventory.ps1 `
    -OutputPath (Join-Path $OutputFolder "KeyVaultInventory-$AccountType-PARALLEL-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv") `
    -Parallel `
    -ThrottleLimit 20
$test2Exit = $LASTEXITCODE
$test2Duration = (Get-Date) - $startTime

Stop-Transcript
Write-Host "  Duration: $($test2Duration.ToString('mm\:ss'))" -ForegroundColor Yellow
Write-Host "  Exit Code: $test2Exit" -ForegroundColor $(if ($test2Exit -eq 0) { 'Green' } else { 'Red' })
Write-Host "  ** Expected 10-20x FASTER than sequential! **`n" -ForegroundColor Cyan

# Test 3: Policy Assignment Inventory (already fast, no parallel needed)
Write-Host "[Test 3/3] Running Policy Assignment Inventory..." -ForegroundColor Green
$transcriptPath = Join-Path $OutputFolder "Test3-Policies-$AccountType.txt"
Start-Transcript -Path $transcriptPath -Force

$startTime = Get-Date
.\Get-PolicyAssignmentInventory.ps1 -OutputPath (Join-Path $OutputFolder "PolicyAssignmentInventory-$AccountType-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv")
$test3Exit = $LASTEXITCODE
$test3Duration = (Get-Date) - $startTime

Stop-Transcript
Write-Host "  Duration: $($test3Duration.ToString('mm\:ss'))" -ForegroundColor Yellow
Write-Host "  Exit Code: $test3Exit`n" -ForegroundColor $(if ($test3Exit -eq 0) { 'Green' } else { 'Red' })

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PARALLEL TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$totalDuration = $test1Duration + $test2Duration + $test3Duration

Write-Host "Test 1 (Subscriptions): $(if ($test1Exit -eq 0) { 'PASS' } else { 'FAIL' }) - $($test1Duration.ToString('mm\:ss'))" -ForegroundColor $(if ($test1Exit -eq 0) { 'Green' } else { 'Red' })
Write-Host "Test 2 (Key Vaults PARALLEL): $(if ($test2Exit -eq 0) { 'PASS' } else { 'FAIL' }) - $($test2Duration.ToString('mm\:ss'))" -ForegroundColor $(if ($test2Exit -eq 0) { 'Green' } else { 'Red' })
Write-Host "Test 3 (Policies): $(if ($test3Exit -eq 0) { 'PASS' } else { 'FAIL' }) - $($test3Duration.ToString('mm\:ss'))" -ForegroundColor $(if ($test3Exit -eq 0) { 'Green' } else { 'Red' })

Write-Host "`nTotal Duration: $($totalDuration.ToString('hh\:mm\:ss'))" -ForegroundColor Yellow
Write-Host "End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Yellow

Write-Host "Results saved to: $OutputFolder`n" -ForegroundColor Cyan

# Create summary file
$summaryPath = Join-Path $OutputFolder "TestSummary-$AccountType-PARALLEL.txt"
@"
========================================
PARALLEL PROCESSING TEST SUMMARY
========================================
Account Type: $AccountType
Test Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Output Folder: $OutputFolder

TEST RESULTS:
-------------
Test 1 (Subscriptions):      $(if ($test1Exit -eq 0) { 'PASS' } else { 'FAIL' }) - Duration: $($test1Duration.ToString('mm\:ss'))
Test 2 (Key Vaults PARALLEL): $(if ($test2Exit -eq 0) { 'PASS' } else { 'FAIL' }) - Duration: $($test2Duration.ToString('mm\:ss'))
Test 3 (Policies):           $(if ($test3Exit -eq 0) { 'PASS' } else { 'FAIL' }) - Duration: $($test3Duration.ToString('mm\:ss'))

Total Duration: $($totalDuration.ToString('hh\:mm\:ss'))

PERFORMANCE NOTE:
-----------------
Test 2 uses parallel processing with ThrottleLimit=20
Expected speedup: 10-20x faster than sequential processing
For 838 subscriptions, expected time: 3-5 minutes vs 60+ minutes sequential

CSV FILES GENERATED:
--------------------
"@ | Out-File -FilePath $summaryPath -Encoding UTF8

Get-ChildItem -Path $OutputFolder -Filter "*.csv" | ForEach-Object {
    "- $($_.Name)" | Out-File -FilePath $summaryPath -Append -Encoding UTF8
}

Write-Host "Summary saved to: $summaryPath`n" -ForegroundColor Green
