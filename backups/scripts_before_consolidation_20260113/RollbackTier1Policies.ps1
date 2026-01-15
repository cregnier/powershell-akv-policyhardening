<#
.SYNOPSIS
Rollback Tier 1 policies from Deny mode to Audit mode

.DESCRIPTION
Emergency rollback procedure for Tier 1 policies:
1. Switch from Deny mode back to Audit mode
2. OR disable enforcement entirely (DoNotEnforce mode)
3. Notify stakeholders
4. Generate rollback report

.PARAMETER SubscriptionId
Production subscription ID

.PARAMETER RollbackMode
Type of rollback:
- "Audit" = Switch effect parameter from Deny to Audit
- "Disable" = Set EnforcementMode to DoNotEnforce (policy still assigned but not evaluated)
- "Delete" = Remove policy assignments entirely (not recommended)

.PARAMETER Reason
Reason for rollback (required for audit trail)

.PARAMETER PolicyNames
Specific policy assignment names to rollback. If not specified, rolls back ALL Tier 1 policies.

.PARAMETER WhatIf
Preview rollback without making changes

.EXAMPLE
.\RollbackTier1Policies.ps1 -SubscriptionId "xxx" -RollbackMode "Audit" -Reason "High violation rate causing business impact" -WhatIf

.EXAMPLE
.\RollbackTier1Policies.ps1 -SubscriptionId "xxx" -RollbackMode "Disable" -Reason "Emergency - production outage" -PolicyNames "KV-Tier1-P0-SoftDelete","KV-Tier1-P0-PurgeProtection"

.NOTES
Author: Azure Governance Team
Version: 1.0.0
Date: January 13, 2026
CRITICAL: This is an emergency procedure. Document all rollbacks.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("Audit", "Disable", "Delete")]
    [string]$RollbackMode,
    
    [Parameter(Mandatory=$true)]
    [string]$Reason,
    
    [Parameter(Mandatory=$false)]
    [string[]]$PolicyNames,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "`n========================================" -ForegroundColor Red
Write-Host "!!! TIER 1 POLICY ROLLBACK !!!" -ForegroundColor Red
Write-Host "========================================`n" -ForegroundColor Red

Write-Host "⚠ WARNING: This will rollback Tier 1 policies" -ForegroundColor Yellow
Write-Host "Rollback Mode: $RollbackMode" -ForegroundColor White
Write-Host "Reason: $Reason" -ForegroundColor White
Write-Host "WhatIf: $($WhatIf.IsPresent)`n" -ForegroundColor White

if (-not $WhatIf) {
    $confirm = Read-Host "Type 'ROLLBACK' to confirm this action"
    if ($confirm -ne "ROLLBACK") {
        Write-Host "Rollback cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Set context
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
$context = Get-AzContext

Write-Host "`nSubscription: $($context.Subscription.Name)" -ForegroundColor White
Write-Host "ID: $($context.Subscription.Id)`n" -ForegroundColor White

# Get Tier 1 policy assignments
Write-Host "Retrieving Tier 1 policy assignments..." -ForegroundColor Yellow
$scope = "/subscriptions/$SubscriptionId"
$allAssignments = Get-AzPolicyAssignment -Scope $scope | Where-Object { $_.Name -like "KV-Tier1-*" }

if ($PolicyNames) {
    $assignments = $allAssignments | Where-Object { $PolicyNames -contains $_.Name }
    Write-Host "Found $($assignments.Count) matching assignments (filtered)" -ForegroundColor White
} else {
    $assignments = $allAssignments
    Write-Host "Found $($assignments.Count) total Tier 1 assignments" -ForegroundColor White
}

if (-not $assignments) {
    Write-Host "ERROR: No matching policy assignments found." -ForegroundColor Red
    exit 1
}

Write-Host "`nAssignments to rollback:" -ForegroundColor Cyan
$assignments | Select-Object Name, @{N='DisplayName';E={$_.Properties.DisplayName}} | Format-Table -AutoSize

# Rollback results
$rollbackResults = @()
$successCount = 0
$failureCount = 0

foreach ($assignment in $assignments) {
    Write-Host "`n--- Rolling back: $($assignment.Name) ---" -ForegroundColor Cyan
    
    $result = [PSCustomObject]@{
        AssignmentName = $assignment.Name
        DisplayName = $assignment.Properties.DisplayName
        RollbackMode = $RollbackMode
        PreviousEffect = "Unknown"
        NewEffect = "Unknown"
        Status = "Unknown"
        Message = ""
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    try {
        # Get current effect parameter
        $currentParams = $assignment.Properties.Parameters
        if ($currentParams.effect) {
            $result.PreviousEffect = $currentParams.effect.value
            Write-Host "  Current effect: $($result.PreviousEffect)" -ForegroundColor Gray
        }
        
        switch ($RollbackMode) {
            "Audit" {
                # Change effect parameter to Audit
                if ($WhatIf) {
                    Write-Host "  [WHATIF] Would change effect from $($result.PreviousEffect) to Audit" -ForegroundColor Magenta
                    $result.Status = "WhatIf"
                    $result.NewEffect = "Audit"
                    $result.Message = "Would change to Audit mode"
                } else {
                    # Update policy parameter
                    $newParams = $currentParams
                    $newParams.effect = @{value = "Audit"}
                    
                    $updated = Set-AzPolicyAssignment `
                        -Id $assignment.PolicyAssignmentId `
                        -PolicyParameter ($newParams | ConvertTo-Json -Depth 10) `
                        -ErrorAction Stop
                    
                    $result.Status = "Success"
                    $result.NewEffect = "Audit"
                    $result.Message = "Changed from $($result.PreviousEffect) to Audit"
                    $successCount++
                    Write-Host "  ✓ Rolled back to Audit mode" -ForegroundColor Green
                }
            }
            
            "Disable" {
                # Set EnforcementMode to DoNotEnforce
                if ($WhatIf) {
                    Write-Host "  [WHATIF] Would set EnforcementMode to DoNotEnforce" -ForegroundColor Magenta
                    $result.Status = "WhatIf"
                    $result.NewEffect = "DoNotEnforce"
                    $result.Message = "Would disable enforcement"
                } else {
                    $updated = Set-AzPolicyAssignment `
                        -Id $assignment.PolicyAssignmentId `
                        -EnforcementMode DoNotEnforce `
                        -ErrorAction Stop
                    
                    $result.Status = "Success"
                    $result.NewEffect = "DoNotEnforce"
                    $result.Message = "Enforcement disabled (policy not evaluated)"
                    $successCount++
                    Write-Host "  ✓ Enforcement disabled" -ForegroundColor Green
                }
            }
            
            "Delete" {
                # Remove assignment entirely
                if ($WhatIf) {
                    Write-Host "  [WHATIF] Would delete policy assignment" -ForegroundColor Magenta
                    $result.Status = "WhatIf"
                    $result.NewEffect = "Deleted"
                    $result.Message = "Would delete assignment"
                } else {
                    Remove-AzPolicyAssignment `
                        -Id $assignment.PolicyAssignmentId `
                        -ErrorAction Stop
                    
                    $result.Status = "Success"
                    $result.NewEffect = "Deleted"
                    $result.Message = "Assignment deleted"
                    $successCount++
                    Write-Host "  ✓ Assignment deleted" -ForegroundColor Green
                }
            }
        }
        
    } catch {
        Write-Host "  ✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $result.Status = "Failed"
        $result.Message = $_.Exception.Message
        $failureCount++
    }
    
    $rollbackResults += $result
}

# Generate rollback report
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Rollback Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Assignments: $($assignments.Count)" -ForegroundColor White
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failureCount" -ForegroundColor Red
Write-Host "========================================`n" -ForegroundColor Cyan

# Detailed results
Write-Host "Rollback Details:`n" -ForegroundColor Cyan
$rollbackResults | Format-Table -Property AssignmentName, PreviousEffect, NewEffect, Status, Message -AutoSize

# Export report
$reportFile = "Tier1Rollback-$timestamp.json"

$report = @{
    RollbackDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Subscription = @{
        Name = $context.Subscription.Name
        Id = $context.Subscription.Id
    }
    RollbackMode = $RollbackMode
    Reason = $Reason
    InitiatedBy = $context.Account.Id
    TotalAssignments = $assignments.Count
    SuccessCount = $successCount
    FailureCount = $failureCount
    WhatIfMode = $WhatIf.IsPresent
    Results = $rollbackResults
}

$report | ConvertTo-Json -Depth 10 | Out-File $reportFile -Encoding UTF8
Write-Host "Rollback report saved: $reportFile`n" -ForegroundColor Cyan

# Next steps
if ($successCount -gt 0 -and -not $WhatIf) {
    Write-Host "=== POST-ROLLBACK ACTIONS ===" -ForegroundColor Yellow
    Write-Host "1. Notify stakeholders immediately" -ForegroundColor White
    Write-Host "   - Email: CISO, Security Team, Cloud Center of Excellence" -ForegroundColor Gray
    Write-Host "   - Include: Reason, affected policies, timeline for resolution" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Begin Root Cause Analysis (RCA)" -ForegroundColor White
    Write-Host "   - Document what triggered the rollback" -ForegroundColor Gray
    Write-Host "   - Identify affected resources/users" -ForegroundColor Gray
    Write-Host "   - Determine corrective actions" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Create Remediation Plan" -ForegroundColor White
    Write-Host "   - Fix root cause issues" -ForegroundColor Gray
    Write-Host "   - Test in dev/test environment" -ForegroundColor Gray
    Write-Host "   - Schedule re-deployment" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. Monitor for 24-48 hours" -ForegroundColor White
    Write-Host "   - Verify rollback resolved issues" -ForegroundColor Gray
    Write-Host "   - Check for any new violations" -ForegroundColor Gray
    Write-Host "   - Run compliance report" -ForegroundColor Gray
    Write-Host ""
    Write-Host "5. Document Lessons Learned" -ForegroundColor White
    Write-Host "   - Update rollback procedures if needed" -ForegroundColor Gray
    Write-Host "   - Add to known issues documentation" -ForegroundColor Gray
    Write-Host "   - Share with team for future prevention`n" -ForegroundColor Gray
    
    # Generate stakeholder notification template
    $notificationFile = "RollbackNotification-$timestamp.txt"
    $notification = @"
SUBJECT: URGENT - Azure Key Vault Policy Rollback Notification

Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Initiated By: $($context.Account.Id)
Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))

=== ROLLBACK SUMMARY ===

Rollback Mode: $RollbackMode
Policies Affected: $successCount of $($assignments.Count) Tier 1 policies
Reason: $Reason

=== AFFECTED POLICIES ===

$($rollbackResults | Where-Object {$_.Status -eq "Success"} | ForEach-Object { "- $($_.AssignmentName): $($_.PreviousEffect) → $($_.NewEffect)" } | Out-String)

=== IMMEDIATE IMPACT ===

$( if ($RollbackMode -eq "Audit") { "Policies will no longer BLOCK non-compliant operations. Violations will be reported only." }
   elseif ($RollbackMode -eq "Disable") { "Policies will NOT be evaluated. No blocking, no auditing." }
   elseif ($RollbackMode -eq "Delete") { "Policies have been REMOVED. No governance enforcement." }
)

=== NEXT STEPS ===

1. Root Cause Analysis to begin immediately
2. Remediation plan required within 24 hours
3. Re-deployment timeline TBD after issue resolution
4. Daily compliance monitoring during rollback period

=== QUESTIONS/CONCERNS ===

Contact: Azure Governance Team
Incident Report: $reportFile

This is an automated notification. Please acknowledge receipt.
"@
    
    $notification | Out-File $notificationFile -Encoding UTF8
    Write-Host "Stakeholder notification template: $notificationFile" -ForegroundColor Cyan
    Write-Host "Review and send to: CISO, Security Team, Cloud CoE`n" -ForegroundColor Yellow
}

if ($WhatIf) {
    Write-Host "=== WHATIF MODE COMPLETE ===" -ForegroundColor Magenta
    Write-Host "No changes were made. Review output and re-run without -WhatIf to execute rollback.`n" -ForegroundColor Magenta
}

# Exit code
if ($failureCount -gt 0) {
    Write-Host "Rollback completed with errors. Review failed policies above." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Rollback completed successfully!" -ForegroundColor Green
    exit 0
}
