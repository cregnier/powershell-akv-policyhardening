<#
.SYNOPSIS
    Comprehensive validation of Azure Policy scenario deployment

.DESCRIPTION
    Validates both the deployment process (transcript) and report content (HTML):
    - Transcript: Parameter file, policy count, console next steps, history tracking
    - HTML Report: Metrics, compliance data, sections, HTML next steps
    
.PARAMETER ScenarioNumber
    The scenario number (1-9) to validate

.PARAMETER TranscriptFile
    Path to the captured terminal output file

.PARAMETER ExpectedParameterFile
    Expected parameter file name (e.g., "PolicyParameters-DevTest.json")

.PARAMETER ExpectedPolicyCount
    Expected number of policies deployed/assigned

.PARAMETER ExpectedSkippedCount
    Expected number of policies skipped (e.g., DeployIfNotExists without identity)

.EXAMPLE
    .\Validate-Deployment.ps1 -ScenarioNumber 1 -TranscriptFile "scenario1-clean-test-20260122-172916.txt" -ExpectedParameterFile "PolicyParameters-DevTest.json" -ExpectedPolicyCount 30 -ExpectedSkippedCount 8
#>

param(
    [Parameter(Mandatory=$true)]
    [int]$ScenarioNumber,
    
    [Parameter(Mandatory=$true)]
    [string]$TranscriptFile,
    
    [Parameter(Mandatory=$true)]
    [string]$ExpectedParameterFile,
    
    [Parameter(Mandatory=$true)]
    [int]$ExpectedPolicyCount,
    
    [Parameter(Mandatory=$false)]
    [int]$ExpectedSkippedCount = 0
)

$ErrorActionPreference = 'Stop'

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Comprehensive Deployment Validation - Scenario $ScenarioNumber          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

$results = @{
    ScenarioNumber = $ScenarioNumber
    TranscriptValidation = @{
        ParameterFileCorrect = $false
        PolicyCountCorrect = $false
        NextStepsInConsole = $false
        HTMLReportGenerated = $false
        HistoryTracked = $false
    }
    HTMLValidation = @{
        HasOverallCompliance = $false
        HasPoliciesReporting = $false
        HasResourcesEvaluated = $false
        HasScope = $false
        HasDeploymentMetadata = $false
        HasComplianceOverview = $false
        HasPolicyAssignments = $false
        HasNextStepsInHTML = $false
    }
}

# ═══════════════════════════════════════════════════════════════
# PART 1: TRANSCRIPT VALIDATION (Deployment Process)
# ═══════════════════════════════════════════════════════════════

Write-Host "`n═══ Part 1: Transcript Validation (Console Output) ═══`n" -ForegroundColor Yellow

if (-not (Test-Path $TranscriptFile)) {
    Write-Host "❌ Transcript file not found: $TranscriptFile`n" -ForegroundColor Red
    return $results
}

$content = Get-Content $TranscriptFile -Raw

# Check 1: Parameter File
Write-Host "[1/5] Checking Parameter File Usage..." -ForegroundColor Cyan
if ($content -match "Loading policy parameter overrides from [^\r\n]*$($ExpectedParameterFile.Replace('\', '\\'))") {
    Write-Host "  ✅ Correct parameter file: $ExpectedParameterFile" -ForegroundColor Green
    $results.TranscriptValidation.ParameterFileCorrect = $true
} else {
    if ($content -match "Loading policy parameter overrides from ([^\r\n]+)") {
        Write-Host "  ❌ WRONG parameter file: $($Matches[1])" -ForegroundColor Red
    } else {
        Write-Host "  ❌ Could not determine parameter file" -ForegroundColor Red
    }
}

# Check 2: Policy Count
Write-Host "`n[2/5] Checking Policy Count..." -ForegroundColor Cyan
if ($content -match "Loaded (\d+) policies from parameter file") {
    $actualCount = [int]$Matches[1]
    if ($actualCount -eq $ExpectedPolicyCount) {
        Write-Host "  ✅ Correct policy count: $actualCount policies" -ForegroundColor Green
        $results.TranscriptValidation.PolicyCountCorrect = $true
        
        # Check skipped count
        $skippedMatches = [regex]::Matches($content, "Effect '' requires managed identity\. Skipping assignment")
        if ($skippedMatches.Count -eq $ExpectedSkippedCount) {
            Write-Host "  ✅ Correct number of policies skipped: $ExpectedSkippedCount (expected without identity)" -ForegroundColor Green
        } elseif ($ExpectedSkippedCount -gt 0) {
            Write-Host "  ⚠️  Skipped: $($skippedMatches.Count) (expected $ExpectedSkippedCount)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ❌ WRONG policy count: $actualCount (expected $ExpectedPolicyCount)" -ForegroundColor Red
    }
} else {
    Write-Host "  ❌ Could not determine policy count" -ForegroundColor Red
}

# Check 3: Next Steps in Console
Write-Host "`n[3/5] Checking Next Steps in Console Output..." -ForegroundColor Cyan
if ($content -match "NEXT STEPS GUIDANCE" -and ($content -match "Recommended Next Steps:" -or $content -match "Critical Next Steps:")) {
    Write-Host "  ✅ Next steps guidance present in console" -ForegroundColor Green
    $results.TranscriptValidation.NextStepsInConsole = $true
} else {
    Write-Host "  ❌ Next steps guidance NOT found in console" -ForegroundColor Red
}

# Check 4: HTML Report Generated
Write-Host "`n[4/5] Checking HTML Report Generation..." -ForegroundColor Cyan
$htmlFile = $null
if ($content -match "HTML report generated: \./([^\r\n]+\.html)") {
    $htmlFile = $Matches[1]
    if (Test-Path $htmlFile) {
        Write-Host "  ✅ HTML report generated: $htmlFile" -ForegroundColor Green
        $results.TranscriptValidation.HTMLReportGenerated = $true
    } else {
        Write-Host "  ⚠️  HTML file mentioned but not found: $htmlFile" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ❌ HTML report generation not found in output" -ForegroundColor Red
}

# Check 5: History Tracking
Write-Host "`n[5/5] Checking Deployment History..." -ForegroundColor Cyan
$historyFile = ".policy-deployment-history.json"
if (Test-Path $historyFile) {
    try {
        $history = Get-Content $historyFile -Raw | ConvertFrom-Json
        if ($history.PSObject.Properties.Name -contains "Scenario$ScenarioNumber") {
            $deployments = @($history."Scenario$ScenarioNumber".Deployments)
            if ($deployments.Count -gt 0) {
                $latest = $deployments | Select-Object -Last 1
                Write-Host "  ✅ Deployment history tracked" -ForegroundColor Green
                $results.TranscriptValidation.HistoryTracked = $true
                Write-Host "     • Timestamp: $($latest.Timestamp)" -ForegroundColor Gray
                Write-Host "     • Mode: $($latest.Mode)" -ForegroundColor Gray
            } else {
                Write-Host "  ❌ No deployments recorded for Scenario $ScenarioNumber" -ForegroundColor Red
            }
        } else {
            Write-Host "  ❌ No history found for Scenario $ScenarioNumber" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ❌ Error reading history: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  ⚠️  History file not found (minor issue)" -ForegroundColor Yellow
}

# ═══════════════════════════════════════════════════════════════
# PART 2: HTML REPORT VALIDATION (Report Content)
# ═══════════════════════════════════════════════════════════════

Write-Host "`n═══ Part 2: HTML Report Validation (Report Content) ═══`n" -ForegroundColor Yellow

if ($htmlFile -and (Test-Path $htmlFile)) {
    $html = Get-Content $htmlFile -Raw
    
    # Check 1: Overall Compliance
    Write-Host "[1/8] Overall Compliance..." -ForegroundColor Cyan
    if ($html -match '<div class="metric-value"[^>]*>(\d+\.?\d*)%</div>\s*<div class="metric-label">Overall Compliance</div>') {
        $results.HTMLValidation.HasOverallCompliance = $true
        Write-Host "  ✅ Found: $($Matches[1])%" -ForegroundColor Green
    } else {
        Write-Host "  ❌ NOT FOUND" -ForegroundColor Red
    }
    
    # Check 2: Policies Reporting
    Write-Host "`n[2/8] Policies Reporting..." -ForegroundColor Cyan
    if ($html -match '<tr><td>Policies Reporting</td><td>(\d+)</td></tr>') {
        $results.HTMLValidation.HasPoliciesReporting = $true
        Write-Host "  ✅ Found: $($Matches[1]) policies" -ForegroundColor Green
    } else {
        Write-Host "  ❌ NOT FOUND" -ForegroundColor Red
    }
    
    # Check 3: Resources Evaluated
    Write-Host "`n[3/8] Resources Evaluated..." -ForegroundColor Cyan
    if ($html -match '<tr><td>Compliant Resources</td><td[^>]*>(\d+)</td></tr>') {
        $compliantCount = [int]$Matches[1]
        if ($html -match '<tr><td>Non-Compliant Resources</td><td[^>]*>(\d+)</td></tr>') {
            $nonCompliantCount = [int]$Matches[1]
            $totalResources = $compliantCount + $nonCompliantCount
            $results.HTMLValidation.HasResourcesEvaluated = $true
            Write-Host "  ✅ Found: $totalResources total ($compliantCount compliant, $nonCompliantCount non-compliant)" -ForegroundColor Green
        }
    } else {
        Write-Host "  ❌ NOT FOUND" -ForegroundColor Red
    }
    
    # Check 4: Scope
    Write-Host "`n[4/8] Scope..." -ForegroundColor Cyan
    if ($html -match '<label>Scope</label>\s*<value>([^<]+)</value>') {
        $results.HTMLValidation.HasScope = $true
        Write-Host "  ✅ Found: $($Matches[1])" -ForegroundColor Green
    } else {
        Write-Host "  ❌ NOT FOUND" -ForegroundColor Red
    }
    
    # Check 5-8: Content Sections
    Write-Host "`n[5/8] Deployment Metadata..." -ForegroundColor Cyan
    if ($html -match '📋 Deployment Metadata') {
        $results.HTMLValidation.HasDeploymentMetadata = $true
        Write-Host "  ✅ Found" -ForegroundColor Green
    } else {
        Write-Host "  ❌ NOT FOUND" -ForegroundColor Red
    }
    
    Write-Host "`n[6/8] Compliance Overview..." -ForegroundColor Cyan
    if ($html -match '📊 Compliance Overview') {
        $results.HTMLValidation.HasComplianceOverview = $true
        Write-Host "  ✅ Found" -ForegroundColor Green
    } else {
        Write-Host "  ❌ NOT FOUND" -ForegroundColor Red
    }
    
    Write-Host "`n[7/8] Policy Assignments..." -ForegroundColor Cyan
    if ($html -match '✅ Successfully Assigned Policies') {
        $results.HTMLValidation.HasPolicyAssignments = $true
        Write-Host "  ✅ Found" -ForegroundColor Green
    } else {
        Write-Host "  ❌ NOT FOUND" -ForegroundColor Red
    }
    
    Write-Host "`n[8/8] Next Steps in HTML..." -ForegroundColor Cyan
    if ($html -match '(📋 NEXT STEPS GUIDANCE|Next Steps|Recommended Next Steps)') {
        $results.HTMLValidation.HasNextStepsInHTML = $true
        Write-Host "  ✅ Found" -ForegroundColor Green
    } else {
        Write-Host "  ❌ NOT FOUND" -ForegroundColor Red
    }
} else {
    Write-Host "⚠️  Skipping HTML validation - file not available`n" -ForegroundColor Yellow
}

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Validation Summary - Scenario $ScenarioNumber                           ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

$transcriptPassed = ($results.TranscriptValidation.Values | Where-Object { $_ -eq $true }).Count
$transcriptTotal = $results.TranscriptValidation.Count
$htmlPassed = ($results.HTMLValidation.Values | Where-Object { $_ -eq $true }).Count
$htmlTotal = $results.HTMLValidation.Count
$totalPassed = $transcriptPassed + $htmlPassed
$totalChecks = $transcriptTotal + $htmlTotal

Write-Host "`n📊 Overall Result: " -NoNewline
if ($totalPassed -eq $totalChecks) {
    Write-Host "✅ PASS ($totalPassed/$totalChecks checks)" -ForegroundColor Green
} elseif ($totalPassed -ge ($totalChecks * 0.75)) {
    Write-Host "⚠️  PARTIAL ($totalPassed/$totalChecks checks)" -ForegroundColor Yellow
} else {
    Write-Host "❌ FAIL ($totalPassed/$totalChecks checks)" -ForegroundColor Red
}

Write-Host "`n═══ Transcript Validation: $transcriptPassed/$transcriptTotal ═══" -ForegroundColor Yellow
Write-Host "  [1] Parameter File:       $(if ($results.TranscriptValidation.ParameterFileCorrect) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($results.TranscriptValidation.ParameterFileCorrect) { 'Green' } else { 'Red' })
Write-Host "  [2] Policy Count:         $(if ($results.TranscriptValidation.PolicyCountCorrect) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($results.TranscriptValidation.PolicyCountCorrect) { 'Green' } else { 'Red' })
Write-Host "  [3] Next Steps (Console): $(if ($results.TranscriptValidation.NextStepsInConsole) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($results.TranscriptValidation.NextStepsInConsole) { 'Green' } else { 'Red' })
Write-Host "  [4] HTML Report:          $(if ($results.TranscriptValidation.HTMLReportGenerated) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($results.TranscriptValidation.HTMLReportGenerated) { 'Green' } else { 'Red' })
Write-Host "  [5] History Tracking:     $(if ($results.TranscriptValidation.HistoryTracked) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($results.TranscriptValidation.HistoryTracked) { 'Green' } else { 'Red' })

Write-Host "`n═══ HTML Report Validation: $htmlPassed/$htmlTotal ═══" -ForegroundColor Yellow
Write-Host "  [1] Overall Compliance:   $(if ($results.HTMLValidation.HasOverallCompliance) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($results.HTMLValidation.HasOverallCompliance) { 'Green' } else { 'Red' })
Write-Host "  [2] Policies Reporting:   $(if ($results.HTMLValidation.HasPoliciesReporting) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($results.HTMLValidation.HasPoliciesReporting) { 'Green' } else { 'Red' })
Write-Host "  [3] Resources Evaluated:  $(if ($results.HTMLValidation.HasResourcesEvaluated) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($results.HTMLValidation.HasResourcesEvaluated) { 'Green' } else { 'Red' })
Write-Host "  [4] Scope:                $(if ($results.HTMLValidation.HasScope) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($results.HTMLValidation.HasScope) { 'Green' } else { 'Red' })
Write-Host "  [5] Deployment Metadata:  $(if ($results.HTMLValidation.HasDeploymentMetadata) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($results.HTMLValidation.HasDeploymentMetadata) { 'Green' } else { 'Red' })
Write-Host "  [6] Compliance Overview:  $(if ($results.HTMLValidation.HasComplianceOverview) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($results.HTMLValidation.HasComplianceOverview) { 'Green' } else { 'Red' })
Write-Host "  [7] Policy Assignments:   $(if ($results.HTMLValidation.HasPolicyAssignments) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($results.HTMLValidation.HasPolicyAssignments) { 'Green' } else { 'Red' })
Write-Host "  [8] Next Steps (HTML):    $(if ($results.HTMLValidation.HasNextStepsInHTML) { '✅ PASS' } else { '❌ FAIL' })`n" -ForegroundColor $(if ($results.HTMLValidation.HasNextStepsInHTML) { 'Green' } else { 'Red' })

return $results
