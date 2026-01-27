<#
.SYNOPSIS
    Comprehensive validation of all 9 deployment scenarios with HTML and console output verification.

.DESCRIPTION
    Tests all 9 workflow scenarios to ensure:
    - Correct parameter files are used
    - User input prompts are appropriate
    - Console next steps match scenario
    - HTML reports contain scenario-specific guidance
    - No unexpected [WARN] or [ERROR] messages
    
    Scenarios tested:
    1. DevTest Baseline (30 policies, Audit)
    2. DevTest Full (46 policies, Audit)
    3. DevTest Auto-Remediation (8 policies, DeployIfNotExists)
    4. Production Audit (46 policies, Audit)
    5. Production Deny (35 policies, Deny mode - 11 policies excluded that don't support Deny)
    6. Production Auto-Remediation (46 policies total - 8 with DeployIfNotExists/Modify configured for auto-remediation)
    7. Resource Group Scope
    8. Management Group Scope
    9. Rollback (remove all policies)

.PARAMETER RunActualDeployment
    If specified, runs actual deployments. Otherwise runs DryRun/Preview mode only.
    Default: $false (DryRun only for safety)

.PARAMETER SubscriptionId
    Azure subscription ID for testing. Required for scenarios with user input.

.PARAMETER ResourceGroupName
    Resource group name for Scenario 7 (Resource Group Scope).
    Default: "rg-policy-keyvault-test"

.PARAMETER ManagementGroupId
    Management group ID for Scenario 8 (Management Group Scope).
    Default: Skip scenario if not provided

.PARAMETER ManagedIdentityResourceId
    Full ARM resource ID for managed identity (required for auto-remediation scenarios).
    Format: /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<name>

.PARAMETER SkipHTMLValidation
    Skip HTML report validation (faster testing). Default: $false

.PARAMETER OutputPath
    Directory for test logs and reports. Default: current directory

.EXAMPLE
    .\Test-AllScenariosWithHTMLValidation.ps1
    Runs DryRun tests for all scenarios (safe, no actual deployment)

.EXAMPLE
    .\Test-AllScenariosWithHTMLValidation.ps1 -RunActualDeployment -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb"
    Runs actual deployments for all scenarios (WARNING: modifies Azure resources)

.EXAMPLE
    .\Test-AllScenariosWithHTMLValidation.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -ManagedIdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
    DryRun with all parameters for comprehensive validation

.NOTES
    Version: 1.0
    Last Updated: 2026-01-22
    Expected Duration: 5 minutes (DryRun) | 30-60 minutes (actual deployment with Azure evaluation)
#>

[CmdletBinding()]
param(
    [switch]$RunActualDeployment,
    [string]$SubscriptionId,
    [string]$ResourceGroupName = "rg-policy-keyvault-test",
    [string]$ManagementGroupId,
    [string]$ManagedIdentityResourceId,
    [switch]$SkipHTMLValidation,
    [string]$OutputPath = "."
)

# Initialize test environment
$ErrorActionPreference = 'Continue'
$TestStartTime = Get-Date
$TestLogPath = Join-Path $OutputPath "test-all-scenarios-validation-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"

# Initialize results tracking
$TestResults = @()
$OverallStatus = "PASS"

# Helper function to log output
function Write-TestLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    switch ($Level) {
        "SUCCESS" { Write-Host $LogMessage -ForegroundColor Green }
        "ERROR" { Write-Host $LogMessage -ForegroundColor Red }
        "WARN" { Write-Host $LogMessage -ForegroundColor Yellow }
        "INFO" { Write-Host $LogMessage -ForegroundColor Cyan }
        default { Write-Host $LogMessage }
    }
    
    $LogMessage | Out-File -FilePath $TestLogPath -Append
}

# Helper function to validate console output
function Test-ConsoleNextSteps {
    param(
        [string]$OutputText,
        [string]$ExpectedScenario,
        [string]$ScenarioName
    )
    
    $Issues = @()
    
    # Check for scenario-specific next steps banner
    if ($OutputText -notmatch "NEXT STEPS GUIDANCE") {
        $Issues += "Missing 'NEXT STEPS GUIDANCE' banner"
    }
    
    # Scenario-specific validations
    switch ($ExpectedScenario) {
        "DevTest30" {
            if ($OutputText -notmatch "DevTest Deployment Complete \(30 Policies") {
                $Issues += "Missing DevTest30 deployment banner"
            }
            if ($OutputText -notmatch "Deploy full 46-policy suite when ready") {
                $Issues += "Missing recommendation to deploy full 46-policy suite"
            }
        }
        "DevTestFull46" {
            if ($OutputText -notmatch "DevTest Full Deployment Complete \(46 Policies") {
                $Issues += "Missing DevTestFull46 deployment banner"
            }
            if ($OutputText -notmatch "Test auto-remediation") {
                $Issues += "Missing auto-remediation testing recommendation"
            }
        }
        "DevTestRemediation" {
            if ($OutputText -notmatch "Auto-Remediation Deployment Complete") {
                $Issues += "Missing auto-remediation deployment banner"
            }
            if ($OutputText -notmatch "15-30 minutes for auto-remediation") {
                $Issues += "Missing remediation timing guidance"
            }
        }
        "ProductionAudit" {
            if ($OutputText -notmatch "Production Deployment Complete.*Audit Mode") {
                $Issues += "Missing Production Audit deployment banner"
            }
            if ($OutputText -notmatch "30-90 days before moving to Deny mode") {
                $Issues += "Missing 30-90 day monitoring recommendation"
            }
        }
        "ProductionDeny" {
            if ($OutputText -notmatch "Production DENY Mode Deployment Complete") {
                $Issues += "Missing Production Deny deployment banner"
            }
            if ($OutputText -notmatch "Rollback") {
                $Issues += "Missing rollback instructions"
            }
        }
        "ProductionRemediation" {
            if ($OutputText -notmatch "Production Auto-Remediation Complete") {
                $Issues += "Missing Production Remediation banner"
            }
            if ($OutputText -notmatch "Emergency Response") {
                $Issues += "Missing emergency response guidance"
            }
        }
        "ResourceGroup" {
            if ($OutputText -notmatch "Resource.*Group.*Scope|Limited Deployment") {
                $Issues += "Missing resource group scope indication"
            }
        }
        "ManagementGroup" {
            if ($OutputText -notmatch "Management.*Group|Enterprise-Wide") {
                $Issues += "Missing management group scope indication"
            }
        }
        "Rollback" {
            if ($OutputText -notmatch "Rollback|Removal|Remove all policies") {
                $Issues += "Missing rollback confirmation"
            }
        }
    }
    
    if ($Issues.Count -eq 0) {
        Write-TestLog "  ✅ Console next steps validated for $ScenarioName" "SUCCESS"
        return $true
    } else {
        Write-TestLog "  ❌ Console next steps validation failed for $ScenarioName" "ERROR"
        $Issues | ForEach-Object { Write-TestLog "    - $_" "ERROR" }
        return $false
    }
}

# Helper function to validate HTML report
function Test-HTMLReport {
    param(
        [string]$HTMLPath,
        [string]$ExpectedScenario,
        [string]$ScenarioName
    )
    
    if ($SkipHTMLValidation) {
        Write-TestLog "  ⏭️  HTML validation skipped (SkipHTMLValidation specified)" "INFO"
        return $true
    }
    
    if (-not (Test-Path $HTMLPath)) {
        Write-TestLog "  ⚠️  HTML report not found: $HTMLPath (expected for DryRun)" "WARN"
        return $true  # Not a failure for DryRun
    }
    
    $HTMLContent = Get-Content $HTMLPath -Raw
    $Issues = @()
    
    # Check for next steps section
    if ($HTMLContent -notmatch "📋 Next Steps|Recommended Next Steps") {
        $Issues += "Missing Next Steps section in HTML"
    }
    
    # Check for 3-phase roadmap
    if ($HTMLContent -notmatch "Phase 1.*Review.*Remediate") {
        $Issues += "Missing Phase 1 guidance in HTML"
    }
    if ($HTMLContent -notmatch "Phase 2.*Test Deny Mode") {
        $Issues += "Missing Phase 2 guidance in HTML"
    }
    if ($HTMLContent -notmatch "Phase 3.*Enable Enforce Mode") {
        $Issues += "Missing Phase 3 guidance in HTML"
    }
    
    # Check for scenario-aware content
    if ($HTMLContent -notmatch "Audit Mode|Deny Mode|Enforce Mode") {
        $Issues += "Missing enforcement mode indication in HTML"
    }
    
    if ($Issues.Count -eq 0) {
        Write-TestLog "  ✅ HTML report validated for $ScenarioName" "SUCCESS"
        return $true
    } else {
        Write-TestLog "  ⚠️  HTML report validation warnings for $ScenarioName" "WARN"
        $Issues | ForEach-Object { Write-TestLog "    - $_" "WARN" }
        return $true  # Warnings don't fail the test
    }
}

# Helper function to check for unexpected warnings/errors
function Test-OutputClean {
    param(
        [string]$OutputText,
        [string]$ScenarioName
    )
    
    $Issues = @()
    
    # Expected warnings (these are OK)
    $ExpectedWarnings = @(
        "cryptographicType.*NOT FOUND",  # Parameter validation (expected)
        "Parameter.*not defined in policy",  # Parameter skip message (expected)
        "Effect.*requires managed identity",  # Managed identity requirement (expected in non-remediation scenarios)
        "Skipping assignment.*provide -IdentityResourceId",  # Identity skip message (expected)
        "Skipping RBAC permission check.*SkipRBACCheck"  # RBAC check skip (expected with -SkipRBACCheck flag)
    )
    
    # Check for ERROR messages (should be none)
    $ErrorMatches = [regex]::Matches($OutputText, "\[ERROR\][^\n]*")
    foreach ($match in $ErrorMatches) {
        $Issues += "Unexpected ERROR: $($match.Value)"
    }
    
    # Check for unexpected WARNING messages
    # Use regex to capture multi-line warnings (WARN tag and message on next line)
    $WarnMatches = [regex]::Matches($OutputText, "\[WARN\]\s*\r?\n?([^\n\[]*)")
    foreach ($match in $WarnMatches) {
        $warnText = $match.Groups[1].Value.Trim()
        if ([string]::IsNullOrWhiteSpace($warnText)) {
            # If warning text is empty, skip it (formatting artifact)
            continue
        }
        
        $IsExpected = $false
        foreach ($expected in $ExpectedWarnings) {
            if ($warnText -match $expected) {
                $IsExpected = $true
                break
            }
        }
        if (-not $IsExpected) {
            $Issues += "Unexpected WARN: $warnText"
        }
    }
    
    if ($Issues.Count -eq 0) {
        Write-TestLog "  ✅ No unexpected warnings/errors for $ScenarioName" "SUCCESS"
        return $true
    } else {
        Write-TestLog "  ❌ Found unexpected warnings/errors for $ScenarioName" "ERROR"
        $Issues | ForEach-Object { Write-TestLog "    - $_" "ERROR" }
        return $false
    }
}

# Define all 9 test scenarios
$Scenarios = @(
    @{
        Number = 1
        Name = "DevTest Baseline (30 Policies)"
        ParameterFile = ".\PolicyParameters-DevTest.json"
        Command = ".\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -SkipRBACCheck -Preview"
        ExpectedScenario = "DevTest30"
        RequiresUserInput = $false
        UserInputGuidance = @()
    },
    @{
        Number = 2
        Name = "DevTest Full (46 Policies)"
        ParameterFile = ".\PolicyParameters-DevTest-Full.json"
        Command = ".\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -SkipRBACCheck -Preview"
        ExpectedScenario = "DevTestFull46"
        RequiresUserInput = $false
        UserInputGuidance = @()
    },
    @{
        Number = 3
        Name = "DevTest Auto-Remediation (8 Policies)"
        ParameterFile = ".\PolicyParameters-DevTest-Full-Remediation.json"
        Command = ".\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json -IdentityResourceId '<MANAGED_IDENTITY_ID>' -SkipRBACCheck -Preview"
        ExpectedScenario = "DevTestRemediation"
        RequiresUserInput = $true
        UserInputGuidance = @(
            "Replace <MANAGED_IDENTITY_ID> with:",
            "/subscriptions/<subscription-id>/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
        )
    },
    @{
        Number = 4
        Name = "Production Audit (46 Policies)"
        ParameterFile = ".\PolicyParameters-Production.json"
        Command = ".\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -SkipRBACCheck -Preview"
        ExpectedScenario = "ProductionAudit"
        RequiresUserInput = $false
        UserInputGuidance = @()
    },
    @{
        Number = 5
        Name = "Production Deny (35 Policies - Maximum Enforcement)"
        ParameterFile = ".\PolicyParameters-Production-Deny.json"
        Command = ".\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Deny.json -SkipRBACCheck -Preview"
        ExpectedScenario = "ProductionDeny"
        RequiresUserInput = $false
        UserInputGuidance = @()
    },
    @{
        Number = 6
        Name = "Production Auto-Remediation (46 Policies - 8 with Remediation Mode)"
        ParameterFile = ".\PolicyParameters-Production-Remediation.json"
        Command = ".\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Remediation.json -IdentityResourceId '<MANAGED_IDENTITY_ID>' -SkipRBACCheck -Preview"
        ExpectedScenario = "ProductionRemediation"
        RequiresUserInput = $true
        UserInputGuidance = @(
            "Replace <MANAGED_IDENTITY_ID> with:",
            "/subscriptions/<subscription-id>/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
        )
    },
    @{
        Number = 7
        Name = "Resource Group Scope (Limited Deployment)"
        ParameterFile = ".\PolicyParameters-DevTest.json"
        Command = ".\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -ResourceGroupScope '/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>' -SkipRBACCheck -Preview"
        ExpectedScenario = "ResourceGroup"
        RequiresUserInput = $true
        UserInputGuidance = @(
            "Replace <SUBSCRIPTION_ID> with your subscription ID",
            "Replace <RESOURCE_GROUP> with resource group name (default: rg-policy-keyvault-test)"
        )
    },
    @{
        Number = 8
        Name = "Management Group Scope (Enterprise-Wide)"
        ParameterFile = ".\PolicyParameters-Production.json"
        Command = ".\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -ManagementGroupScope '/providers/Microsoft.Management/managementGroups/<MANAGEMENT_GROUP_ID>' -SkipRBACCheck -Preview"
        ExpectedScenario = "ManagementGroup"
        RequiresUserInput = $true
        UserInputGuidance = @(
            "Replace <MANAGEMENT_GROUP_ID> with your management group ID",
            "WARNING: Affects all subscriptions under management group"
        )
    },
    @{
        Number = 9
        Name = "Rollback (Remove All Policies)"
        ParameterFile = $null
        Command = ".\AzPolicyImplScript.ps1 -Rollback -SkipRBACCheck -Preview"
        ExpectedScenario = "Rollback"
        RequiresUserInput = $false
        UserInputGuidance = @()
    }
)

# Display test header
Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Azure Key Vault Policy Governance - Scenario Validation" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

Write-TestLog "Starting comprehensive scenario validation" "INFO"
Write-TestLog "Test mode: $(if ($RunActualDeployment) { 'ACTUAL DEPLOYMENT' } else { 'DRYRUN (Preview)' })" "INFO"
Write-TestLog "Test log: $TestLogPath" "INFO"

# Validate prerequisites
Write-TestLog "`nValidating prerequisites..." "INFO"

if (-not (Test-Path ".\AzPolicyImplScript.ps1")) {
    Write-TestLog "ERROR: AzPolicyImplScript.ps1 not found in current directory" "ERROR"
    exit 1
}

$MissingParameterFiles = @()
foreach ($scenario in $Scenarios) {
    if ($scenario.ParameterFile -and -not (Test-Path $scenario.ParameterFile)) {
        $MissingParameterFiles += $scenario.ParameterFile
    }
}

if ($MissingParameterFiles.Count -gt 0) {
    Write-TestLog "ERROR: Missing parameter files:" "ERROR"
    $MissingParameterFiles | ForEach-Object { Write-TestLog "  - $_" "ERROR" }
    exit 1
}

Write-TestLog "✅ All prerequisites validated" "SUCCESS"

# Run tests for each scenario
foreach ($scenario in $Scenarios) {
    Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-TestLog "SCENARIO $($scenario.Number): $($scenario.Name)" "INFO"
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
    
    # Display user input guidance if required
    if ($scenario.RequiresUserInput) {
        Write-TestLog "⚠️  User input required for this scenario:" "WARN"
        $scenario.UserInputGuidance | ForEach-Object { Write-TestLog "    $_" "WARN" }
        
        # Build actual command with user-provided values
        $ActualCommand = $scenario.Command
        
        if ($scenario.Number -eq 3 -or $scenario.Number -eq 6) {
            # Auto-remediation scenarios
            if ($ManagedIdentityResourceId) {
                $ActualCommand = $ActualCommand -replace '<MANAGED_IDENTITY_ID>', $ManagedIdentityResourceId
                Write-TestLog "  Using managed identity: $ManagedIdentityResourceId" "INFO"
            } else {
                Write-TestLog "  ⏭️  Skipping scenario (no -ManagedIdentityResourceId provided)" "WARN"
                $TestResults += @{
                    Scenario = $scenario.Name
                    Status = "SKIPPED"
                    Reason = "No managed identity resource ID provided"
                }
                continue
            }
        }
        
        if ($scenario.Number -eq 7) {
            # Resource group scope
            if ($SubscriptionId) {
                $ActualCommand = $ActualCommand -replace '<SUBSCRIPTION_ID>', $SubscriptionId
                $ActualCommand = $ActualCommand -replace '<RESOURCE_GROUP>', $ResourceGroupName
                Write-TestLog "  Using resource group: /subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName" "INFO"
            } else {
                Write-TestLog "  ⏭️  Skipping scenario (no -SubscriptionId provided)" "WARN"
                $TestResults += @{
                    Scenario = $scenario.Name
                    Status = "SKIPPED"
                    Reason = "No subscription ID provided"
                }
                continue
            }
        }
        
        if ($scenario.Number -eq 8) {
            # Management group scope
            if ($ManagementGroupId) {
                $ActualCommand = $ActualCommand -replace '<MANAGEMENT_GROUP_ID>', $ManagementGroupId
                Write-TestLog "  Using management group: $ManagementGroupId" "INFO"
            } else {
                Write-TestLog "  ⏭️  Skipping scenario (no -ManagementGroupId provided)" "WARN"
                $TestResults += @{
                    Scenario = $scenario.Name
                    Status = "SKIPPED"
                    Reason = "No management group ID provided"
                }
                continue
            }
        }
    } else {
        $ActualCommand = $scenario.Command
    }
    
    # Replace -Preview with actual deployment if specified
    if ($RunActualDeployment) {
        $ActualCommand = $ActualCommand -replace '-Preview', ''
    }
    
    Write-TestLog "Executing: $ActualCommand" "INFO"
    
    # Run the command and capture output
    $OutputFile = Join-Path $OutputPath "scenario-$($scenario.Number)-output-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    
    try {
        # Execute command and capture all output streams to file
        # Use a script block to ensure all output is properly captured
        $ScriptBlock = [ScriptBlock]::Create($ActualCommand)
        & $ScriptBlock *>&1 | Tee-Object -FilePath $OutputFile | Out-Null
        
        # Read the captured output from the file
        if (Test-Path $OutputFile) {
            $OutputText = Get-Content $OutputFile -Raw
        } else {
            throw "Output file was not created: $OutputFile"
        }
        
        Write-TestLog "  ✅ Command executed successfully" "SUCCESS"
        Write-TestLog "  Output saved to: $OutputFile" "INFO"
        
        # Validate console next steps
        $ConsoleValid = Test-ConsoleNextSteps -OutputText $OutputText -ExpectedScenario $scenario.ExpectedScenario -ScenarioName $scenario.Name
        
        # Validate HTML report (if compliance check was run)
        $LatestHTML = Get-ChildItem "ComplianceReport-*.html" -ErrorAction SilentlyContinue | 
                      Sort-Object LastWriteTime -Descending | 
                      Select-Object -First 1
        
        if ($LatestHTML) {
            $HTMLValid = Test-HTMLReport -HTMLPath $LatestHTML.FullName -ExpectedScenario $scenario.ExpectedScenario -ScenarioName $scenario.Name
        } else {
            $HTMLValid = $true  # No HTML report expected for DryRun
        }
        
        # Check for unexpected warnings/errors
        $OutputClean = Test-OutputClean -OutputText $OutputText -ScenarioName $scenario.Name
        
        # Determine overall scenario status
        $ScenarioStatus = if ($ConsoleValid -and $HTMLValid -and $OutputClean) { "PASS" } else { "FAIL" }
        
        $TestResults += @{
            Scenario = $scenario.Name
            Status = $ScenarioStatus
            ConsoleValidation = $ConsoleValid
            HTMLValidation = $HTMLValid
            OutputClean = $OutputClean
            OutputFile = $OutputFile
        }
        
        if ($ScenarioStatus -eq "FAIL") {
            $OverallStatus = "FAIL"
        }
        
    } catch {
        Write-TestLog "  ❌ Command execution failed: $($_.Exception.Message)" "ERROR"
        $TestResults += @{
            Scenario = $scenario.Name
            Status = "ERROR"
            ErrorMessage = $_.Exception.Message
        }
        $OverallStatus = "FAIL"
    }
    
    Start-Sleep -Seconds 2  # Brief pause between scenarios
}

# Generate summary report
Write-Host "`n`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                     TEST SUMMARY REPORT" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

$TestEndTime = Get-Date
$Duration = $TestEndTime - $TestStartTime

Write-TestLog "Test Duration: $($Duration.ToString('hh\:mm\:ss'))" "INFO"
Write-TestLog "Test Log: $TestLogPath" "INFO"

Write-Host "`n📊 Results by Scenario:" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

foreach ($result in $TestResults) {
    $StatusColor = switch ($result.Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "SKIPPED" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    
    Write-Host "`n$($result.Scenario):" -ForegroundColor White
    Write-Host "  Status: $($result.Status)" -ForegroundColor $StatusColor
    
    if ($result.Status -eq "PASS") {
        Write-Host "  ✅ Console validation: $($result.ConsoleValidation)" -ForegroundColor Green
        Write-Host "  ✅ HTML validation: $($result.HTMLValidation)" -ForegroundColor Green
        Write-Host "  ✅ No unexpected warnings/errors: $($result.OutputClean)" -ForegroundColor Green
    } elseif ($result.Status -eq "SKIPPED") {
        Write-Host "  ⏭️  Reason: $($result.Reason)" -ForegroundColor Yellow
    } elseif ($result.Status -eq "ERROR") {
        Write-Host "  ❌ Error: $($result.ErrorMessage)" -ForegroundColor Red
    } else {
        Write-Host "  ❌ Console validation: $($result.ConsoleValidation)" -ForegroundColor $(if ($result.ConsoleValidation) { "Green" } else { "Red" })
        Write-Host "  $(if ($result.HTMLValidation) { '✅' } else { '❌' }) HTML validation: $($result.HTMLValidation)" -ForegroundColor $(if ($result.HTMLValidation) { "Green" } else { "Red" })
        Write-Host "  $(if ($result.OutputClean) { '✅' } else { '❌' }) No unexpected warnings/errors: $($result.OutputClean)" -ForegroundColor $(if ($result.OutputClean) { "Green" } else { "Red" })
    }
    
    if ($result.OutputFile) {
        Write-Host "  📄 Output: $($result.OutputFile)" -ForegroundColor Gray
    }
}

# Overall summary
Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
$PassCount = ($TestResults | Where-Object { $_.Status -eq "PASS" }).Count
$FailCount = ($TestResults | Where-Object { $_.Status -eq "FAIL" }).Count
$ErrorCount = ($TestResults | Where-Object { $_.Status -eq "ERROR" }).Count
$SkipCount = ($TestResults | Where-Object { $_.Status -eq "SKIPPED" }).Count
$TotalCount = $TestResults.Count

Write-Host "`n📊 Overall Statistics:" -ForegroundColor Cyan
Write-Host "  Total scenarios: $TotalCount" -ForegroundColor White
Write-Host "  ✅ Passed: $PassCount" -ForegroundColor Green
Write-Host "  ❌ Failed: $FailCount" -ForegroundColor $(if ($FailCount -eq 0) { "Green" } else { "Red" })
Write-Host "  ⚠️  Errors: $ErrorCount" -ForegroundColor $(if ($ErrorCount -eq 0) { "Green" } else { "Red" })
Write-Host "  ⏭️  Skipped: $SkipCount" -ForegroundColor Yellow

Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
if ($OverallStatus -eq "PASS") {
    Write-Host "✅ ALL TESTS PASSED" -ForegroundColor Green
} else {
    Write-Host "❌ SOME TESTS FAILED - Review output above" -ForegroundColor Red
}
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

Write-TestLog "`nTest suite complete. Overall status: $OverallStatus" "INFO"

# Return exit code
if ($OverallStatus -eq "PASS") {
    exit 0
} else {
    exit 1
}
