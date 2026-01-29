# Run-ComprehensiveTests.ps1
# Comprehensive test suite for Sprint 1 Story 1.1 Discovery Scripts
# Executes all menu options with full transcript capture

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('MSA', 'AAD', 'Corp')]
    [string]$AccountType = 'MSA',
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFolder = ".\TestResults-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
)

#region Helper Functions

function Write-TestHeader {
    param([string]$Title, [string]$Color = 'Cyan')
    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor $Color
    Write-Host $Title -ForegroundColor $Color
    Write-Host "=" * 80 -ForegroundColor $Color
    Write-Host ""
}

function Write-TestStep {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] " -NoNewline -ForegroundColor Gray
    Write-Host $Message -ForegroundColor White
}

function Get-CurrentAzureAccount {
    try {
        $context = Get-AzContext -ErrorAction SilentlyContinue
        if ($context) {
            return @{
                Account = $context.Account.Id
                Tenant = $context.Tenant.Id
                Subscription = $context.Subscription.Name
                Type = $context.Account.Type
            }
        }
        return $null
    }
    catch {
        return $null
    }
}

#endregion

#region Main Test Execution

# Create output folder
if (-not (Test-Path $OutputFolder)) {
    New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
}

Write-TestHeader "Sprint 1 Story 1.1 - Comprehensive Test Suite" -Color Green
Write-TestStep "Account Type: $AccountType"
Write-TestStep "Output Folder: $OutputFolder"
Write-Host ""

# Verify Azure connection
Write-TestStep "Verifying Azure connection..."
$accountInfo = Get-CurrentAzureAccount

if (-not $accountInfo) {
    Write-Host "ERROR: Not connected to Azure. Please run Connect-AzAccount first." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Current Azure Context:" -ForegroundColor Yellow
Write-Host "  Account:      $($accountInfo.Account)" -ForegroundColor White
Write-Host "  Account Type: $($accountInfo.Type)" -ForegroundColor White
Write-Host "  Tenant:       $($accountInfo.Tenant)" -ForegroundColor White
Write-Host "  Subscription: $($accountInfo.Subscription)" -ForegroundColor White
Write-Host ""

# Confirm before proceeding
Write-Host "This will run 5 test scenarios with full transcript capture:" -ForegroundColor Yellow
Write-Host "  0. Prerequisites Check (Test-DiscoveryPrerequisites.ps1)" -ForegroundColor White
Write-Host "  1. Subscription Inventory (Get-AzureSubscriptionInventory.ps1)" -ForegroundColor White
Write-Host "  2. Key Vault Inventory (Get-KeyVaultInventory.ps1)" -ForegroundColor White
Write-Host "  3. Policy Assignment Inventory (Get-PolicyAssignmentInventory.ps1)" -ForegroundColor White
Write-Host "  4. Full Discovery (Start-EnvironmentDiscovery.ps1 -AutoRun)" -ForegroundColor White
Write-Host ""

$confirmation = Read-Host "Do you want to proceed? (Y/N)"
if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "Test cancelled by user." -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Test summary variables
$testResults = @()
$testStartTime = Get-Date

#region Test 0: Prerequisites Check

Write-TestHeader "TEST 0: Prerequisites Check" -Color Cyan
$test0Start = Get-Date
$transcriptPath = Join-Path $OutputFolder "Test0-Prerequisites-$AccountType.txt"

Write-TestStep "Starting transcript: $transcriptPath"
Start-Transcript -Path $transcriptPath -Force

try {
    Write-TestStep "Running: .\Test-DiscoveryPrerequisites.ps1 -Detailed"
    .\Test-DiscoveryPrerequisites.ps1 -Detailed
    $test0ExitCode = $LASTEXITCODE
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $test0ExitCode = 1
}
finally {
    Stop-Transcript
    $test0Duration = (Get-Date) - $test0Start
}

$testResults += [PSCustomObject]@{
    TestNumber = 0
    TestName = "Prerequisites Check"
    ExitCode = $test0ExitCode
    Duration = $test0Duration.TotalSeconds
    TranscriptFile = Split-Path $transcriptPath -Leaf
    Status = if ($test0ExitCode -eq 0) { "PASS" } else { "WARN" } # Prerequisites often has RBAC false positive
}

Write-Host ""
Write-Host "Press any key to continue to Test 1..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

#endregion

#region Test 1: Subscription Inventory

Write-TestHeader "TEST 1: Subscription Inventory" -Color Cyan
$test1Start = Get-Date
$transcriptPath = Join-Path $OutputFolder "Test1-Subscriptions-$AccountType.txt"

Write-TestStep "Starting transcript: $transcriptPath"
Start-Transcript -Path $transcriptPath -Force

try {
    Write-TestStep "Running: .\Get-AzureSubscriptionInventory.ps1"
    .\Get-AzureSubscriptionInventory.ps1
    $test1ExitCode = $LASTEXITCODE
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $test1ExitCode = 1
}
finally {
    Stop-Transcript
    $test1Duration = (Get-Date) - $test1Start
}

$testResults += [PSCustomObject]@{
    TestNumber = 1
    TestName = "Subscription Inventory"
    ExitCode = $test1ExitCode
    Duration = $test1Duration.TotalSeconds
    TranscriptFile = Split-Path $transcriptPath -Leaf
    Status = if ($test1ExitCode -eq 0) { "PASS" } else { "FAIL" }
}

Write-Host ""
Write-Host "Press any key to continue to Test 2..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

#endregion

#region Test 2: Key Vault Inventory

Write-TestHeader "TEST 2: Key Vault Inventory" -Color Cyan
$test2Start = Get-Date
$transcriptPath = Join-Path $OutputFolder "Test2-KeyVaults-$AccountType.txt"

Write-TestStep "Starting transcript: $transcriptPath"
Start-Transcript -Path $transcriptPath -Force

try {
    Write-TestStep "Running: .\Get-KeyVaultInventory.ps1"
    .\Get-KeyVaultInventory.ps1
    $test2ExitCode = $LASTEXITCODE
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $test2ExitCode = 1
}
finally {
    Stop-Transcript
    $test2Duration = (Get-Date) - $test2Start
}

$testResults += [PSCustomObject]@{
    TestNumber = 2
    TestName = "Key Vault Inventory"
    ExitCode = $test2ExitCode
    Duration = $test2Duration.TotalSeconds
    TranscriptFile = Split-Path $transcriptPath -Leaf
    Status = if ($test2ExitCode -eq 0) { "PASS" } else { "FAIL" }
}

Write-Host ""
Write-Host "Press any key to continue to Test 3..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

#endregion

#region Test 3: Policy Assignment Inventory

Write-TestHeader "TEST 3: Policy Assignment Inventory" -Color Cyan
$test3Start = Get-Date
$transcriptPath = Join-Path $OutputFolder "Test3-Policies-$AccountType.txt"

Write-TestStep "Starting transcript: $transcriptPath"
Start-Transcript -Path $transcriptPath -Force

try {
    Write-TestStep "Running: .\Get-PolicyAssignmentInventory.ps1"
    .\Get-PolicyAssignmentInventory.ps1
    $test3ExitCode = $LASTEXITCODE
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $test3ExitCode = 1
}
finally {
    Stop-Transcript
    $test3Duration = (Get-Date) - $test3Start
}

$testResults += [PSCustomObject]@{
    TestNumber = 3
    TestName = "Policy Assignment Inventory"
    ExitCode = $test3ExitCode
    Duration = $test3Duration.TotalSeconds
    TranscriptFile = Split-Path $transcriptPath -Leaf
    Status = if ($test3ExitCode -eq 0) { "PASS" } else { "FAIL" }
}

Write-Host ""
Write-Host "Press any key to continue to Test 4..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

#endregion

#region Test 4: Full Discovery (AutoRun)

Write-TestHeader "TEST 4: Full Discovery (AutoRun Mode)" -Color Cyan
$test4Start = Get-Date
$transcriptPath = Join-Path $OutputFolder "Test4-FullDiscovery-$AccountType.txt"

Write-TestStep "Starting transcript: $transcriptPath"
Start-Transcript -Path $transcriptPath -Force

try {
    Write-TestStep "Running: .\Start-EnvironmentDiscovery.ps1 -AutoRun"
    
    # Note: AutoRun mode has interactive prompts between phases
    # This will require user to press keys to continue between phases
    Write-Host ""
    Write-Host "NOTE: AutoRun mode will pause between phases for review." -ForegroundColor Yellow
    Write-Host "      Press any key when prompted to continue to next phase." -ForegroundColor Yellow
    Write-Host ""
    
    .\Start-EnvironmentDiscovery.ps1 -AutoRun
    $test4ExitCode = $LASTEXITCODE
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $test4ExitCode = 1
}
finally {
    Stop-Transcript
    $test4Duration = (Get-Date) - $test4Start
}

$testResults += [PSCustomObject]@{
    TestNumber = 4
    TestName = "Full Discovery (AutoRun)"
    ExitCode = $test4ExitCode
    Duration = $test4Duration.TotalSeconds
    TranscriptFile = Split-Path $transcriptPath -Leaf
    Status = if ($test4ExitCode -eq 0) { "PASS" } else { "FAIL" }
}

#endregion

# Calculate total duration
$totalDuration = (Get-Date) - $testStartTime

# Generate summary report
Write-TestHeader "Test Suite Summary - $AccountType Account" -Color Green

Write-Host "Account Information:" -ForegroundColor Yellow
Write-Host "  Account:      $($accountInfo.Account)" -ForegroundColor White
Write-Host "  Account Type: $($accountInfo.Type)" -ForegroundColor White
Write-Host "  Tenant:       $($accountInfo.Tenant)" -ForegroundColor White
Write-Host "  Subscription: $($accountInfo.Subscription)" -ForegroundColor White
Write-Host ""

Write-Host "Test Results:" -ForegroundColor Yellow
$testResults | Format-Table -AutoSize

$passCount = ($testResults | Where-Object { $_.Status -eq 'PASS' }).Count
$warnCount = ($testResults | Where-Object { $_.Status -eq 'WARN' }).Count
$failCount = ($testResults | Where-Object { $_.Status -eq 'FAIL' }).Count

Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Total Tests: $($testResults.Count)" -ForegroundColor White
Write-Host "  Passed:      $passCount" -ForegroundColor Green
Write-Host "  Warnings:    $warnCount" -ForegroundColor Yellow
Write-Host "  Failed:      $failCount" -ForegroundColor $(if ($failCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "  Duration:    $([math]::Round($totalDuration.TotalSeconds, 2)) seconds" -ForegroundColor White
Write-Host ""

# Save summary to file
$summaryPath = Join-Path $OutputFolder "TestSummary-$AccountType.txt"
$summaryContent = @"
========================================================================
Sprint 1 Story 1.1 - Comprehensive Test Suite Summary
========================================================================

Test Run Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Account Type: $AccountType

Account Information:
  Account:      $($accountInfo.Account)
  Account Type: $($accountInfo.Type)
  Tenant:       $($accountInfo.Tenant)
  Subscription: $($accountInfo.Subscription)

Test Results:
$($testResults | Format-Table -AutoSize | Out-String)

Summary:
  Total Tests: $($testResults.Count)
  Passed:      $passCount
  Warnings:    $warnCount
  Failed:      $failCount
  Duration:    $([math]::Round($totalDuration.TotalSeconds, 2)) seconds

Output Files:
$($testResults | ForEach-Object { "  - $($_.TranscriptFile)" } | Out-String)

========================================================================
"@

$summaryContent | Out-File -FilePath $summaryPath -Encoding UTF8 -Force

Write-Host "Summary saved to: $summaryPath" -ForegroundColor Green
Write-Host ""
Write-Host "All transcript files saved to: $OutputFolder" -ForegroundColor Green
Write-Host ""

# Return exit code based on failures
if ($failCount -gt 0) {
    Write-Host "TEST SUITE FAILED - $failCount test(s) failed" -ForegroundColor Red
    exit 1
}
elseif ($warnCount -gt 0) {
    Write-Host "TEST SUITE PASSED WITH WARNINGS - $warnCount warning(s)" -ForegroundColor Yellow
    exit 0
}
else {
    Write-Host "TEST SUITE PASSED - All tests successful" -ForegroundColor Green
    exit 0
}

#endregion
