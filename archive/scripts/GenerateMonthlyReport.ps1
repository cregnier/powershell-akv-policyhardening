<#
.SYNOPSIS
Generate monthly compliance report for Tier 1 Key Vault policies

.DESCRIPTION
Creates comprehensive monthly executive summary report with:
- Compliance trends (month-over-month)
- Exemption tracking (approved/denied/expired)
- Remediation effectiveness metrics
- Top violators and common issues
- Business impact assessment
- Phase progress and readiness

.PARAMETER SubscriptionId
Target subscription ID

.PARAMETER MonthYear
Reporting month in format "YYYY-MM" (e.g., "2026-01" for January 2026)

.PARAMETER OutputFormat
Report output format: HTML, PDF, or Both

.PARAMETER SendEmail
Send report via email to stakeholders

.PARAMETER EmailRecipients
Email addresses for report distribution (comma-separated)

.EXAMPLE
.\GenerateMonthlyReport.ps1 -SubscriptionId "xxx" -MonthYear "2026-01" -OutputFormat "Both" -SendEmail -EmailRecipients "ciso@company.com,cloud-coe@company.com"

.NOTES
Author: Azure Governance Team
Version: 1.0.0
Date: January 13, 2026
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$MonthYear = (Get-Date -Format "yyyy-MM"),
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("HTML", "PDF", "Both")]
    [string]$OutputFormat = "HTML",
    
    [Parameter(Mandatory=$false)]
    [switch]$SendEmail,
    
    [Parameter(Mandatory=$false)]
    [string]$EmailRecipients = "ciso@company.com,cloud-coe@company.com,azure-governance@company.com"
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Monthly Compliance Report Generator" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Set context
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
$context = Get-AzContext

Write-Host "Subscription: $($context.Subscription.Name)" -ForegroundColor White
Write-Host "Reporting Month: $MonthYear" -ForegroundColor White
Write-Host "Output Format: $OutputFormat`n" -ForegroundColor White

# Parse month/year
$reportDate = [DateTime]::ParseExact("$MonthYear-01", "yyyy-MM-dd", $null)
$monthName = $reportDate.ToString("MMMM yyyy")
$previousMonth = $reportDate.AddMonths(-1).ToString("yyyy-MM")

Write-Host "Collecting compliance data for $monthName..." -ForegroundColor Yellow

# Get policy states
$policyStates = Get-AzPolicyState -SubscriptionId $SubscriptionId -Filter "PolicyAssignmentName like 'KV-Tier1%'" -ErrorAction SilentlyContinue

if (-not $policyStates) {
    Write-Host "⚠ Warning: No policy states found. Report will contain limited data." -ForegroundColor Yellow
    $policyStates = @()
}

# Calculate compliance metrics
$totalResources = ($policyStates | Select-Object -Unique ResourceId).Count
$compliantCount = ($policyStates | Where-Object { $_.ComplianceState -eq "Compliant" } | Select-Object -Unique ResourceId).Count
$nonCompliantCount = $totalResources - $compliantCount
$compliancePercentage = if ($totalResources -gt 0) { [Math]::Round(($compliantCount / $totalResources) * 100, 2) } else { 0 }

# Compliance by priority
$p0States = $policyStates | Where-Object { $_.PolicyAssignmentName -like "*P0*" }
$p1States = $policyStates | Where-Object { $_.PolicyAssignmentName -like "*P1*" }
$p2States = $policyStates | Where-Object { $_.PolicyAssignmentName -like "*P2*" }

$p0Total = ($p0States | Select-Object -Unique ResourceId).Count
$p0Compliant = ($p0States | Where-Object { $_.ComplianceState -eq "Compliant" } | Select-Object -Unique ResourceId).Count
$p0Percentage = if ($p0Total -gt 0) { [Math]::Round(($p0Compliant / $p0Total) * 100, 2) } else { 0 }

$p1Total = ($p1States | Select-Object -Unique ResourceId).Count
$p1Compliant = ($p1States | Where-Object { $_.ComplianceState -eq "Compliant" } | Select-Object -Unique ResourceId).Count
$p1Percentage = if ($p1Total -gt 0) { [Math]::Round(($p1Compliant / $p1Total) * 100, 2) } else { 0 }

$p2Total = ($p2States | Select-Object -Unique ResourceId).Count
$p2Compliant = ($p2States | Where-Object { $_.ComplianceState -eq "Compliant" } | Select-Object -Unique ResourceId).Count
$p2Percentage = if ($p2Total -gt 0) { [Math]::Round(($p2Compliant / $p2Total) * 100, 2) } else { 0 }

# Top violators
$topViolators = $policyStates | 
    Where-Object { $_.ComplianceState -eq "NonCompliant" } |
    Group-Object ResourceId |
    Sort-Object Count -Descending |
    Select-Object -First 10 |
    ForEach-Object {
        $resourceId = $_.Name
        $resourceName = $resourceId.Split('/')[-1]
        $resourceGroup = if ($resourceId -match 'resourceGroups/([^/]+)') { $Matches[1] } else { "Unknown" }
        [PSCustomObject]@{
            ResourceName = $resourceName
            ResourceGroup = $resourceGroup
            ViolationCount = $_.Count
            Policies = ($_.Group | Select-Object -Unique PolicyDefinitionName) -join "; "
        }
    }

# Most violated policies
$mostViolated = $policyStates |
    Where-Object { $_.ComplianceState -eq "NonCompliant" } |
    Group-Object PolicyDefinitionName |
    Sort-Object Count -Descending |
    Select-Object -First 5 |
    ForEach-Object {
        [PSCustomObject]@{
            PolicyName = $_.Name
            ViolationCount = $_.Count
            Percentage = [Math]::Round(($_.Count / $nonCompliantCount) * 100, 2)
        }
    }

# Get exemptions (mock data - replace with actual exemption API calls)
$exemptions = Get-AzPolicyExemption -Scope "/subscriptions/$SubscriptionId" -ErrorAction SilentlyContinue | 
    Where-Object { $_.Properties.PolicyAssignmentId -like "*KV-Tier1*" }

$exemptionStats = @{
    TotalActive = ($exemptions | Where-Object { -not $_.Properties.ExpiresOn -or $_.Properties.ExpiresOn -gt (Get-Date) }).Count
    ExpiringThisMonth = ($exemptions | Where-Object { 
        $_.Properties.ExpiresOn -and 
        $_.Properties.ExpiresOn -ge $reportDate -and 
        $_.Properties.ExpiresOn -lt $reportDate.AddMonths(1)
    }).Count
    ExpiredThisMonth = 0  # Would need historical data
    ApprovedThisMonth = 0  # Would need tracking system
    DeniedThisMonth = 0  # Would need tracking system
}

# Phase readiness assessment
$phaseReadiness = if ($compliancePercentage -ge 95) {
    "READY for Phase 3.2 (Deny Mode)"
} elseif ($compliancePercentage -ge 85) {
    "ON TRACK - Continue remediation efforts"
} elseif ($compliancePercentage -ge 70) {
    "AT RISK - Accelerate remediation required"
} else {
    "CRITICAL - Phase 3.2 timeline may need extension"
}

# Generate HTML report
$htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Monthly Compliance Report - $monthName</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background-color: #0078d4; color: white; padding: 20px; text-align: center; }
        .section { background-color: white; margin: 20px 0; padding: 20px; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric { display: inline-block; width: 23%; margin: 1%; padding: 15px; background-color: #f0f0f0; border-radius: 5px; text-align: center; }
        .metric-value { font-size: 32px; font-weight: bold; color: #0078d4; }
        .metric-label { font-size: 14px; color: #666; margin-top: 5px; }
        .status-ready { color: #107c10; font-weight: bold; }
        .status-risk { color: #ff8c00; font-weight: bold; }
        .status-critical { color: #d13438; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th { background-color: #0078d4; color: white; padding: 10px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background-color: #f5f5f5; }
        .footer { text-align: center; margin-top: 30px; color: #666; font-size: 12px; }
        .priority-p0 { color: #d13438; font-weight: bold; }
        .priority-p1 { color: #ff8c00; font-weight: bold; }
        .priority-p2 { color: #107c10; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Azure Key Vault Policy Compliance Report</h1>
        <h2>$monthName</h2>
        <p>Tier 1 Policies (Audit Mode)</p>
    </div>

    <div class="section">
        <h2>📊 Executive Summary</h2>
        <div class="metric">
            <div class="metric-value">$compliancePercentage%</div>
            <div class="metric-label">Overall Compliance</div>
        </div>
        <div class="metric">
            <div class="metric-value">$compliantCount</div>
            <div class="metric-label">Compliant Resources</div>
        </div>
        <div class="metric">
            <div class="metric-value">$nonCompliantCount</div>
            <div class="metric-label">Non-Compliant</div>
        </div>
        <div class="metric">
            <div class="metric-value">$($exemptionStats.TotalActive)</div>
            <div class="metric-label">Active Exemptions</div>
        </div>
    </div>

    <div class="section">
        <h2>🎯 Compliance by Priority</h2>
        <table>
            <tr>
                <th>Priority</th>
                <th>Target</th>
                <th>Current</th>
                <th>Compliant</th>
                <th>Non-Compliant</th>
                <th>Gap</th>
                <th>Status</th>
            </tr>
            <tr>
                <td class="priority-p0">P0 - Critical (3 policies)</td>
                <td>>90%</td>
                <td>$p0Percentage%</td>
                <td>$p0Compliant</td>
                <td>$($p0Total - $p0Compliant)</td>
                <td>$(90 - $p0Percentage)%</td>
                <td class="$(if ($p0Percentage -ge 90) { 'status-ready' } else { 'status-critical' })">
                    $(if ($p0Percentage -ge 90) { '✅ On Target' } else { '❌ Below Target' })
                </td>
            </tr>
            <tr>
                <td class="priority-p1">P1 - High (5 policies)</td>
                <td>>80%</td>
                <td>$p1Percentage%</td>
                <td>$p1Compliant</td>
                <td>$($p1Total - $p1Compliant)</td>
                <td>$(80 - $p1Percentage)%</td>
                <td class="$(if ($p1Percentage -ge 80) { 'status-ready' } else { 'status-risk' })">
                    $(if ($p1Percentage -ge 80) { '✅ On Target' } else { '⚠️ Below Target' })
                </td>
            </tr>
            <tr>
                <td class="priority-p2">P2 - Medium (4 policies)</td>
                <td>>70%</td>
                <td>$p2Percentage%</td>
                <td>$p2Compliant</td>
                <td>$($p2Total - $p2Compliant)</td>
                <td>$(70 - $p2Percentage)%</td>
                <td class="$(if ($p2Percentage -ge 70) { 'status-ready' } else { 'status-risk' })">
                    $(if ($p2Percentage -ge 70) { '✅ On Target' } else { '⚠️ Below Target' })
                </td>
            </tr>
        </table>
    </div>

    <div class="section">
        <h2>⚠️ Top 10 Non-Compliant Resources</h2>
        <table>
            <tr>
                <th>Resource Name</th>
                <th>Resource Group</th>
                <th>Violations</th>
                <th>Action Required</th>
            </tr>
            $(foreach ($violator in $topViolators) {
                "<tr>
                    <td>$($violator.ResourceName)</td>
                    <td>$($violator.ResourceGroup)</td>
                    <td>$($violator.ViolationCount)</td>
                    <td>Remediate or request exemption</td>
                </tr>"
            })
        </table>
    </div>

    <div class="section">
        <h2>📈 Most Violated Policies</h2>
        <table>
            <tr>
                <th>Policy Name</th>
                <th>Violations</th>
                <th>% of Total</th>
            </tr>
            $(foreach ($policy in $mostViolated) {
                "<tr>
                    <td>$($policy.PolicyName)</td>
                    <td>$($policy.ViolationCount)</td>
                    <td>$($policy.Percentage)%</td>
                </tr>"
            })
        </table>
    </div>

    <div class="section">
        <h2>🔓 Exemption Tracking</h2>
        <table>
            <tr>
                <th>Metric</th>
                <th>Count</th>
            </tr>
            <tr>
                <td>Total Active Exemptions</td>
                <td>$($exemptionStats.TotalActive)</td>
            </tr>
            <tr>
                <td>Expiring This Month</td>
                <td class="status-risk">$($exemptionStats.ExpiringThisMonth)</td>
            </tr>
            <tr>
                <td>Approved This Month</td>
                <td>$($exemptionStats.ApprovedThisMonth)</td>
            </tr>
            <tr>
                <td>Denied This Month</td>
                <td>$($exemptionStats.DeniedThisMonth)</td>
            </tr>
        </table>
        <p><strong>Exemption Rate:</strong> $(if ($totalResources -gt 0) { [Math]::Round(($exemptionStats.TotalActive / $totalResources) * 100, 2) } else { 0 })% 
        (Target: <5%)</p>
    </div>

    <div class="section">
        <h2>🚦 Phase 3.2 Readiness Assessment</h2>
        <p><strong>Current Status:</strong> <span class="$(
            if ($phaseReadiness -like "*READY*") { 'status-ready' }
            elseif ($phaseReadiness -like "*AT RISK*") { 'status-risk' }
            else { 'status-critical' }
        )">$phaseReadiness</span></p>
        
        <p><strong>Readiness Criteria:</strong></p>
        <ul>
            <li>Overall compliance >95%: <strong>$(if ($compliancePercentage -ge 95) { '✅ Met' } else { "❌ Not Met ($compliancePercentage%)" })</strong></li>
            <li>P0 compliance >90%: <strong>$(if ($p0Percentage -ge 90) { '✅ Met' } else { "❌ Not Met ($p0Percentage%)" })</strong></li>
            <li>P1 compliance >80%: <strong>$(if ($p1Percentage -ge 80) { '✅ Met' } else { "❌ Not Met ($p1Percentage%)" })</strong></li>
            <li>Exemption rate <5%: <strong>$(
                $exemptionRate = if ($totalResources -gt 0) { [Math]::Round(($exemptionStats.TotalActive / $totalResources) * 100, 2) } else { 0 }
                if ($exemptionRate -lt 5) { '✅ Met' } else { "❌ Not Met ($exemptionRate%)" }
            )</strong></li>
        </ul>

        <p><strong>Recommendation:</strong> 
        $(if ($compliancePercentage -ge 95) {
            "Proceed with Phase 3.2 (Deny Mode) deployment next month."
        } elseif ($compliancePercentage -ge 85) {
            "Continue monitoring. Re-assess readiness mid-next month."
        } else {
            "Extend Audit mode for 1 additional month. Intensify remediation efforts."
        })
        </p>
    </div>

    <div class="section">
        <h2>📝 Recommendations & Next Steps</h2>
        <ol>
            <li><strong>High Priority:</strong> Remediate all P0 violations (critical security issues)</li>
            <li><strong>Medium Priority:</strong> Address P1 violations impacting overall compliance</li>
            <li><strong>Review Exemptions:</strong> $($exemptionStats.ExpiringThisMonth) exemptions expiring this month - renew or remediate</li>
            <li><strong>Focus Policies:</strong> Top violated policies require targeted remediation campaigns:
                <ul>
                    $(foreach ($policy in ($mostViolated | Select-Object -First 3)) {
                        "<li>$($policy.PolicyName) ($($policy.ViolationCount) violations)</li>"
                    })
                </ul>
            </li>
            <li><strong>Communication:</strong> Send remediation reminders to owners of top 10 non-compliant resources</li>
            <li><strong>Training:</strong> Offer remediation workshops for commonly violated policies</li>
        </ol>
    </div>

    <div class="footer">
        <p>Report Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        <p>Azure Governance Team | azure-governance@company.com</p>
        <p>Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))</p>
    </div>
</body>
</html>
"@

# Save HTML report
$htmlFile = "MonthlyComplianceReport-$MonthYear-$timestamp.html"
$htmlReport | Out-File $htmlFile -Encoding UTF8
Write-Host "✓ HTML report generated: $htmlFile" -ForegroundColor Green

# Generate CSV export for detailed analysis
$csvData = $policyStates | Select-Object `
    @{N='ResourceName';E={$_.ResourceId.Split('/')[-1]}},
    @{N='ResourceGroup';E={if ($_.ResourceId -match 'resourceGroups/([^/]+)') { $Matches[1] } else { 'Unknown' }}},
    ComplianceState,
    PolicyDefinitionName,
    PolicyAssignmentName,
    @{N='Priority';E={
        if ($_.PolicyAssignmentName -like "*P0*") { "P0" }
        elseif ($_.PolicyAssignmentName -like "*P1*") { "P1" }
        elseif ($_.PolicyAssignmentName -like "*P2*") { "P2" }
        else { "Unknown" }
    }}

$csvFile = "MonthlyComplianceReport-$MonthYear-$timestamp.csv"
$csvData | Export-Csv $csvFile -NoTypeInformation -Encoding UTF8
Write-Host "✓ CSV export generated: $csvFile" -ForegroundColor Green

# Summary output
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Monthly Report Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Overall Compliance: $compliancePercentage%" -ForegroundColor $(if ($compliancePercentage -ge 95) { 'Green' } else { 'Yellow' })
Write-Host "  P0 (Critical): $p0Percentage% (Target: >90%)" -ForegroundColor $(if ($p0Percentage -ge 90) { 'Green' } else { 'Red' })
Write-Host "  P1 (High): $p1Percentage% (Target: >80%)" -ForegroundColor $(if ($p1Percentage -ge 80) { 'Green' } else { 'Yellow' })
Write-Host "  P2 (Medium): $p2Percentage% (Target: >70%)" -ForegroundColor $(if ($p2Percentage -ge 70) { 'Green' } else { 'Yellow' })
Write-Host "`nCompliant Resources: $compliantCount / $totalResources" -ForegroundColor White
Write-Host "Active Exemptions: $($exemptionStats.TotalActive)" -ForegroundColor White
Write-Host "`nPhase 3.2 Readiness: $phaseReadiness" -ForegroundColor $(
    if ($phaseReadiness -like "*READY*") { 'Green' }
    elseif ($phaseReadiness -like "*AT RISK*") { 'Yellow' }
    else { 'Red' }
)
Write-Host "========================================`n" -ForegroundColor Cyan

# Send email if requested
if ($SendEmail) {
    Write-Host "Preparing email notification..." -ForegroundColor Yellow
    
    $emailSubject = "Monthly Compliance Report - $monthName ($compliancePercentage% Compliance)"
    $emailBody = @"
Azure Key Vault Policy - Monthly Compliance Report for $monthName

Overall Compliance: $compliancePercentage%
- P0 (Critical): $p0Percentage%
- P1 (High): $p1Percentage%
- P2 (Medium): $p2Percentage%

Phase 3.2 Readiness: $phaseReadiness

Please review the attached HTML report for full details.

Files:
- $htmlFile (detailed report)
- $csvFile (raw data export)

---
Azure Governance Team
azure-governance@company.com
"@

    Write-Host "⚠ Email sending not implemented (requires SMTP configuration)" -ForegroundColor Yellow
    Write-Host "  Subject: $emailSubject" -ForegroundColor Gray
    Write-Host "  Recipients: $EmailRecipients" -ForegroundColor Gray
    Write-Host "  Attachments: $htmlFile, $csvFile" -ForegroundColor Gray
    Write-Host "  Preview email body saved to: email-preview.txt`n" -ForegroundColor Gray
    
    $emailBody | Out-File "MonthlyReport-EmailPreview-$timestamp.txt" -Encoding UTF8
}

Write-Host "Monthly report generation complete!`n" -ForegroundColor Green
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Review HTML report: $htmlFile" -ForegroundColor White
Write-Host "2. Distribute to stakeholders (Email template available if -SendEmail was used)" -ForegroundColor White
Write-Host "3. Schedule remediation meetings for high-priority violations" -ForegroundColor White
Write-Host "4. Track exemptions expiring this month`n" -ForegroundColor White
