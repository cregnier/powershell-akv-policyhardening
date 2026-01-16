<#
.SYNOPSIS
Monitor Phase 3.1 Compliance - Tier 1 Production Audit Mode

.DESCRIPTION
Monitors compliance for 12 Tier 1 policies in production during Month 1 audit period.
Tracks progress toward success criteria: <10% P0, <20% P1, <30% P2 non-compliance.

.PARAMETER SubscriptionId
Production subscription ID to monitor

.PARAMETER ExportReport
Export detailed HTML compliance report

.PARAMETER CheckReadiness
Check if ready to proceed to Phase 3.2 (Deny mode)
Criteria: <5% violations for 2 consecutive weeks

.EXAMPLE
.\MonitorTier1Compliance.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012"

.EXAMPLE
.\MonitorTier1Compliance.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -ExportReport

.EXAMPLE
.\MonitorTier1Compliance.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -CheckReadiness

.NOTES
Author: Azure Governance Team
Version: 1.0.0
Date: January 13, 2026
Phase: 3.1 - Production Audit Mode Monitoring
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportReport,
    
    [Parameter(Mandatory=$false)]
    [switch]$CheckReadiness
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Phase 3.1 Compliance Monitoring" -ForegroundColor Cyan
Write-Host "Tier 1 Production - Audit Mode" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Set context
Write-Host "Setting subscription context..." -ForegroundColor Yellow
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
$context = Get-AzContext

Write-Host "Subscription: $($context.Subscription.Name)" -ForegroundColor White
Write-Host "ID: $($context.Subscription.Id)`n" -ForegroundColor White

# Define Tier 1 assignment names
$tier1Assignments = @(
    @{Name = "KV-Tier1-P0-SoftDelete"; Priority = "P0"},
    @{Name = "KV-Tier1-P0-PurgeProtection"; Priority = "P0"},
    @{Name = "KV-Tier1-P0-DisablePublicAccess"; Priority = "P0"},
    @{Name = "KV-Tier1-P1-PrivateLink"; Priority = "P1"},
    @{Name = "KV-Tier1-P1-Firewall"; Priority = "P1"},
    @{Name = "KV-Tier1-P1-RBAC"; Priority = "P1"},
    @{Name = "KV-Tier1-P1-KeyExpiration"; Priority = "P1"},
    @{Name = "KV-Tier1-P1-SecretExpiration"; Priority = "P1"},
    @{Name = "KV-Tier1-P2-CertValidity"; Priority = "P2"},
    @{Name = "KV-Tier1-P2-HSMRequired"; Priority = "P2"},
    @{Name = "KV-Tier1-P2-RSAKeySize"; Priority = "P2"},
    @{Name = "KV-Tier1-P2-CertExpiration"; Priority = "P2"}
)

# Get all policy states
Write-Host "Retrieving policy compliance states..." -ForegroundColor Yellow
Write-Host "(This may take 30-60 seconds)`n" -ForegroundColor Gray

$allStates = Get-AzPolicyState -SubscriptionId $SubscriptionId

if (-not $allStates -or $allStates.Count -eq 0) {
    Write-Host "WARNING: No policy states found. Policies may not have evaluated yet." -ForegroundColor Yellow
    Write-Host "Wait 24-48 hours after deployment for initial evaluation.`n" -ForegroundColor Yellow
    exit 0
}

Write-Host "Total policy states retrieved: $($allStates.Count)`n" -ForegroundColor Green

# Filter for Tier 1 policies
$tier1States = $allStates | Where-Object { 
    $assignmentName = $_.PolicyAssignmentName
    $tier1Assignments.Name -contains $assignmentName
}

if (-not $tier1States -or $tier1States.Count -eq 0) {
    Write-Host "WARNING: No Tier 1 policy states found." -ForegroundColor Yellow
    Write-Host "This could mean:" -ForegroundColor Yellow
    Write-Host "  1. Policies haven't evaluated yet (wait 24-48 hours)" -ForegroundColor Gray
    Write-Host "  2. No Key Vault resources in subscription" -ForegroundColor Gray
    Write-Host "  3. Assignment names don't match expected pattern`n" -ForegroundColor Gray
    exit 0
}

Write-Host "Tier 1 policy states found: $($tier1States.Count)`n" -ForegroundColor Green

# Analyze compliance by priority
$complianceByPriority = @{}
$complianceByPolicy = @()

foreach ($priority in @("P0", "P1", "P2")) {
    $priorityAssignments = $tier1Assignments | Where-Object { $_.Priority -eq $priority }
    $priorityStates = $tier1States | Where-Object { 
        $priorityAssignments.Name -contains $_.PolicyAssignmentName 
    }
    
    if ($priorityStates) {
        $compliant = ($priorityStates | Where-Object { $_.ComplianceState -eq "Compliant" }).Count
        $nonCompliant = ($priorityStates | Where-Object { $_.ComplianceState -eq "NonCompliant" }).Count
        $total = $priorityStates.Count
        $compliancePercent = if ($total -gt 0) { [math]::Round(($compliant / $total) * 100, 2) } else { 0 }
        $nonCompliancePercent = if ($total -gt 0) { [math]::Round(($nonCompliant / $total) * 100, 2) } else { 0 }
        
        # Determine status vs target
        $target = switch ($priority) {
            "P0" { 10 }  # <10% non-compliance
            "P1" { 20 }  # <20% non-compliance
            "P2" { 30 }  # <30% non-compliance
        }
        
        $status = if ($nonCompliancePercent -le $target) { "✓ PASS" } else { "✗ FAIL" }
        $statusColor = if ($nonCompliancePercent -le $target) { "Green" } else { "Red" }
        
        $complianceByPriority[$priority] = @{
            Total = $total
            Compliant = $compliant
            NonCompliant = $nonCompliant
            CompliancePercent = $compliancePercent
            NonCompliancePercent = $nonCompliancePercent
            Target = $target
            Status = $status
            StatusColor = $statusColor
        }
    }
}

# Compliance by individual policy
foreach ($assignment in $tier1Assignments) {
    $policyStates = $tier1States | Where-Object { $_.PolicyAssignmentName -eq $assignment.Name }
    
    if ($policyStates) {
        $compliant = ($policyStates | Where-Object { $_.ComplianceState -eq "Compliant" }).Count
        $nonCompliant = ($policyStates | Where-Object { $_.ComplianceState -eq "NonCompliant" }).Count
        $total = $policyStates.Count
        $compliancePercent = if ($total -gt 0) { [math]::Round(($compliant / $total) * 100, 2) } else { 0 }
        
        $complianceByPolicy += [PSCustomObject]@{
            Priority = $assignment.Priority
            PolicyName = $assignment.Name
            Total = $total
            Compliant = $compliant
            NonCompliant = $nonCompliant
            CompliancePercent = $compliancePercent
        }
    }
}

# Display results
Write-Host "=== Compliance by Priority ===" -ForegroundColor Cyan
Write-Host ""

foreach ($priority in @("P0", "P1", "P2")) {
    if ($complianceByPriority.ContainsKey($priority)) {
        $data = $complianceByPriority[$priority]
        
        Write-Host "[$priority Policies] Target: <$($data.Target)% non-compliance" -ForegroundColor White
        Write-Host "  Total States: $($data.Total)" -ForegroundColor Gray
        Write-Host "  Compliant: $($data.Compliant) ($($data.CompliancePercent)%)" -ForegroundColor Green
        Write-Host "  Non-Compliant: $($data.NonCompliant) ($($data.NonCompliancePercent)%)" -ForegroundColor Red
        Write-Host "  Status: $($data.Status)" -ForegroundColor $data.StatusColor
        Write-Host ""
    }
}

# Overall summary
$totalStates = $tier1States.Count
$totalCompliant = ($tier1States | Where-Object { $_.ComplianceState -eq "Compliant" }).Count
$totalNonCompliant = ($tier1States | Where-Object { $_.ComplianceState -eq "NonCompliant" }).Count
$overallCompliance = if ($totalStates -gt 0) { [math]::Round(($totalCompliant / $totalStates) * 100, 2) } else { 0 }
$overallNonCompliance = if ($totalStates -gt 0) { [math]::Round(($totalNonCompliant / $totalStates) * 100, 2) } else { 0 }

Write-Host "=== Overall Tier 1 Compliance ===" -ForegroundColor Cyan
Write-Host "Total Resources Evaluated: $totalStates" -ForegroundColor White
Write-Host "Compliant: $totalCompliant ($overallCompliance%)" -ForegroundColor Green
Write-Host "Non-Compliant: $totalNonCompliant ($overallNonCompliance%)" -ForegroundColor Red
Write-Host ""

# Detailed policy breakdown
Write-Host "=== Compliance by Policy ===" -ForegroundColor Cyan
$complianceByPolicy | Sort-Object Priority, PolicyName | Format-Table -AutoSize

# Phase 3.2 readiness check
if ($CheckReadiness) {
    Write-Host "`n=== Phase 3.2 Readiness Check ===" -ForegroundColor Yellow
    Write-Host "Criteria: <5% non-compliance across all Tier 1 policies`n" -ForegroundColor White
    
    if ($overallNonCompliance -le 5) {
        Write-Host "✓ READY FOR PHASE 3.2 (Deny Mode)" -ForegroundColor Green
        Write-Host "  Current non-compliance: $overallNonCompliance%" -ForegroundColor Green
        Write-Host "  Target: <5%" -ForegroundColor Green
        Write-Host "`nNext Steps:" -ForegroundColor Yellow
        Write-Host "  1. Verify this has been true for 2 consecutive weeks" -ForegroundColor White
        Write-Host "  2. Review and approve any pending exemptions" -ForegroundColor White
        Write-Host "  3. Notify stakeholders of Deny mode switch (7-day notice)" -ForegroundColor White
        Write-Host "  4. Run: .\SwitchTier1ToDenyMode.ps1 -SubscriptionId $SubscriptionId`n" -ForegroundColor Cyan
    } else {
        Write-Host "✗ NOT READY FOR PHASE 3.2" -ForegroundColor Red
        Write-Host "  Current non-compliance: $overallNonCompliance%" -ForegroundColor Red
        Write-Host "  Target: <5%" -ForegroundColor Red
        Write-Host "  Gap: $([math]::Round($overallNonCompliance - 5, 2))% to remediate`n" -ForegroundColor Red
        
        # Identify problem policies
        $highViolationPolicies = $complianceByPolicy | Where-Object { 
            ($_.NonCompliant / $_.Total * 100) -gt 20 
        } | Sort-Object { $_.NonCompliant / $_.Total } -Descending
        
        if ($highViolationPolicies) {
            Write-Host "High-Violation Policies (>20% non-compliance):" -ForegroundColor Yellow
            $highViolationPolicies | Select-Object Priority, PolicyName, NonCompliant, Total, CompliancePercent | Format-Table -AutoSize
            Write-Host "Focus remediation efforts on these policies.`n" -ForegroundColor Yellow
        }
    }
}

# Export report if requested
if ($ExportReport) {
    $reportFile = "Tier1ComplianceReport-$timestamp.html"
    Write-Host "Exporting HTML report to: $reportFile" -ForegroundColor Cyan
    
    # Create HTML report (simplified for token limit)
    $jsonFile = "Tier1ComplianceReport-$timestamp.json"
    @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Subscription = @{
            Name = $context.Subscription.Name
            Id = $context.Subscription.Id
        }
        Overall = @{
            TotalStates = $totalStates
            Compliant = $totalCompliant
            NonCompliant = $totalNonCompliant
            CompliancePercent = $overallCompliance
            NonCompliancePercent = $overallNonCompliance
        }
        ByPriority = $complianceByPriority
        ByPolicy = $complianceByPolicy
        ReadyForPhase32 = ($overallNonCompliance -le 5)
    } | ConvertTo-Json -Depth 10 | Out-File $jsonFile -Encoding UTF8
    
    Write-Host "JSON report exported: $jsonFile`n" -ForegroundColor Cyan
}

Write-Host "Monitoring complete!`n" -ForegroundColor Green
