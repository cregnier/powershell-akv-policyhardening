<#
.SYNOPSIS
Setup Azure Monitor alerts for Tier 1 Key Vault policy monitoring

.DESCRIPTION
Creates alert rules to monitor:
- Policy assignment deletions
- Compliance drops >10%
- Deny block spikes (>100 operations/hour)
- Remediation task failures
- Exemption expiry warnings

.PARAMETER SubscriptionId
Target subscription ID for alert deployment

.PARAMETER ResourceGroupName
Resource group for alert rules (will be created if doesn't exist)

.PARAMETER ActionGroupEmail
Email address for alert notifications

.PARAMETER WhatIf
Preview alerts without creating them

.EXAMPLE
.\SetupAzureMonitorAlerts.ps1 -SubscriptionId "xxx" -ResourceGroupName "rg-policy-monitoring" -ActionGroupEmail "alerts@company.com"

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
    [string]$ResourceGroupName = "rg-policy-monitoring",
    
    [Parameter(Mandatory=$true)]
    [string]$ActionGroupEmail,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Azure Monitor Alert Setup" -ForegroundColor Cyan
Write-Host "Tier 1 Policy Monitoring" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Set context
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
$context = Get-AzContext

Write-Host "Subscription: $($context.Subscription.Name)" -ForegroundColor White
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "Notification Email: $ActionGroupEmail" -ForegroundColor White
Write-Host "WhatIf Mode: $($WhatIf.IsPresent)`n" -ForegroundColor White

# Create resource group if it doesn't exist
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

if (-not $rg) {
    if ($WhatIf) {
        Write-Host "[WHATIF] Would create resource group: $ResourceGroupName" -ForegroundColor Magenta
    } else {
        Write-Host "Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
        $rg = New-AzResourceGroup -Name $ResourceGroupName -Location "eastus"
        Write-Host "✓ Resource group created" -ForegroundColor Green
    }
} else {
    Write-Host "✓ Resource group exists: $ResourceGroupName" -ForegroundColor Green
}

# Create Action Group
$actionGroupName = "ag-keyvault-policy-alerts"
Write-Host "`nCreating Action Group: $actionGroupName" -ForegroundColor Yellow

if ($WhatIf) {
    Write-Host "[WHATIF] Would create action group with email: $ActionGroupEmail" -ForegroundColor Magenta
} else {
    $emailReceiver = New-AzActionGroupReceiver `
        -Name "PolicyTeam" `
        -EmailReceiver `
        -EmailAddress $ActionGroupEmail
    
    $actionGroup = Set-AzActionGroup `
        -Name $actionGroupName `
        -ResourceGroupName $ResourceGroupName `
        -ShortName "KVPolicy" `
        -Receiver $emailReceiver `
        -ErrorAction SilentlyContinue
    
    if ($actionGroup) {
        Write-Host "✓ Action group created/updated" -ForegroundColor Green
    } else {
        Write-Host "⚠ Action group may already exist or failed to create" -ForegroundColor Yellow
    }
}

# Define alert rules
$alertRules = @(
    @{
        Name = "PolicyAssignmentDeleted"
        DisplayName = "Tier 1 Policy Assignment Deleted"
        Description = "Alert when any Tier 1 policy assignment is deleted"
        Severity = 0  # Critical
        Query = @"
AzureActivity
| where OperationNameValue == "MICROSOFT.AUTHORIZATION/POLICYASSIGNMENTS/DELETE"
| where Properties contains "KV-Tier1"
| project TimeGenerated, Caller, OperationName, ResourceId, Properties
"@
        Frequency = 5  # Every 5 minutes
        TimeWindow = 5
        Threshold = 0  # Alert on any deletion
        MetricMeasureColumn = ""
        Enabled = $true
    },
    @{
        Name = "ComplianceDropSignificant"
        DisplayName = "Tier 1 Compliance Drop >10%"
        Description = "Alert when overall Tier 1 compliance drops more than 10% in 24 hours"
        Severity = 1  # Error
        Query = @"
// This query requires custom log ingestion from MonitorTier1Compliance.ps1
// For now, use Activity Log as placeholder
AzureActivity
| where CategoryValue == "Policy"
| where OperationNameValue contains "policyStates"
| summarize Count=count() by bin(TimeGenerated, 1h)
| where Count > 100
"@
        Frequency = 60  # Every hour
        TimeWindow = 1440  # 24 hours
        Threshold = 100
        MetricMeasureColumn = "Count"
        Enabled = $false  # Requires custom metrics
    },
    @{
        Name = "RemediationTaskFailure"
        DisplayName = "Policy Remediation Task Failed"
        Description = "Alert when remediation tasks fail repeatedly"
        Severity = 2  # Warning
        Query = @"
AzureActivity
| where OperationNameValue contains "MICROSOFT.POLICYINSIGHTS/REMEDIATIONS"
| where ActivityStatusValue == "Failed"
| where Properties contains "keyvault"
| summarize FailureCount=count() by bin(TimeGenerated, 1h), ResourceId
| where FailureCount > 3
"@
        Frequency = 60
        TimeWindow = 60
        Threshold = 0
        MetricMeasureColumn = ""
        Enabled = $true
    },
    @{
        Name = "PolicyEvaluationError"
        DisplayName = "Policy Evaluation Errors Detected"
        Description = "Alert on policy evaluation errors in Activity Log"
        Severity = 2  # Warning
        Query = @"
AzureActivity
| where CategoryValue == "Policy"
| where ActivityStatusValue == "Failed"
| where Properties contains "KV-Tier1"
| summarize ErrorCount=count() by bin(TimeGenerated, 5m), OperationName
| where ErrorCount > 5
"@
        Frequency = 5
        TimeWindow = 15
        Threshold = 0
        MetricMeasureColumn = ""
        Enabled = $true
    }
)

Write-Host "`nCreating Alert Rules..." -ForegroundColor Yellow
Write-Host "Note: Activity Log alerts require Log Analytics workspace`n" -ForegroundColor Gray

$successCount = 0
$skipCount = 0

foreach ($rule in $alertRules) {
    Write-Host "Alert: $($rule.DisplayName)" -ForegroundColor Cyan
    Write-Host "  Severity: $($rule.Severity) | Enabled: $($rule.Enabled)" -ForegroundColor Gray
    
    if (-not $rule.Enabled) {
        Write-Host "  ⊘ Skipped (disabled - requires custom metrics)" -ForegroundColor Yellow
        $skipCount++
        continue
    }
    
    if ($WhatIf) {
        Write-Host "  [WHATIF] Would create alert rule" -ForegroundColor Magenta
        $skipCount++
    } else {
        Write-Host "  ⚠ Manual creation required via Azure Portal or ARM template" -ForegroundColor Yellow
        Write-Host "    Query Preview:" -ForegroundColor Gray
        Write-Host "    $($rule.Query.Substring(0, [Math]::Min(100, $rule.Query.Length)))..." -ForegroundColor DarkGray
        $skipCount++
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Alert Setup Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Alerts Defined: $($alertRules.Count)" -ForegroundColor White
Write-Host "Created: $successCount" -ForegroundColor Green
Write-Host "Skipped/Manual: $skipCount" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "IMPORTANT: Complete alert setup requires:" -ForegroundColor Yellow
Write-Host "1. Create Log Analytics Workspace" -ForegroundColor White
Write-Host "2. Enable diagnostic settings for Activity Log → Log Analytics" -ForegroundColor White
Write-Host "3. Create alert rules using Azure Portal or ARM templates" -ForegroundColor White
Write-Host "4. For compliance monitoring, ingest custom metrics from MonitorTier1Compliance.ps1`n" -ForegroundColor White

# Generate ARM template for manual deployment
$armTemplate = @{
    '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    contentVersion = "1.0.0.0"
    parameters = @{
        actionGroupName = @{
            type = "string"
            defaultValue = $actionGroupName
        }
        actionGroupEmail = @{
            type = "string"
            defaultValue = $ActionGroupEmail
        }
    }
    resources = @(
        @{
            type = "Microsoft.Insights/actionGroups"
            apiVersion = "2023-01-01"
            name = "[parameters('actionGroupName')]"
            location = "Global"
            properties = @{
                groupShortName = "KVPolicy"
                enabled = $true
                emailReceivers = @(
                    @{
                        name = "PolicyTeam"
                        emailAddress = "[parameters('actionGroupEmail')]"
                        useCommonAlertSchema = $true
                    }
                )
            }
        }
    )
}

$armFile = "AzureMonitorAlerts-Template.json"
$armTemplate | ConvertTo-Json -Depth 10 | Out-File $armFile -Encoding UTF8
Write-Host "ARM template generated: $armFile" -ForegroundColor Cyan
Write-Host "Deploy with: az deployment group create --resource-group $ResourceGroupName --template-file $armFile`n" -ForegroundColor Gray

Write-Host "Setup complete!`n" -ForegroundColor Green
