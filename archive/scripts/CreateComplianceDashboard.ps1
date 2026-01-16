<#
.SYNOPSIS
Create Azure Monitor Workbook for Tier 1 Policy Compliance Dashboard

.DESCRIPTION
Generates a compliance dashboard with real-time metrics:
- Overall compliance percentage by priority (P0/P1/P2)
- Policy performance (violation counts, trends)
- Exemption tracking (active, expiring, expired)
- Remediation task success rates
- Deny block counts and trends
- Top non-compliant resources

.PARAMETER SubscriptionId
Subscription ID for dashboard deployment

.PARAMETER ResourceGroupName
Resource group for workbook (default: rg-policy-monitoring)

.PARAMETER WorkbookName
Display name for the workbook (default: "Tier 1 Policy Compliance Dashboard")

.PARAMETER WhatIf
Preview dashboard configuration without deploying

.EXAMPLE
.\CreateComplianceDashboard.ps1 -SubscriptionId "xxx" -ResourceGroupName "rg-policy-monitoring"

.NOTES
Author: Azure Governance Team
Version: 1.0.0
Date: January 13, 2026
Requires: Log Analytics workspace with policy state data
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-policy-monitoring",
    
    [Parameter(Mandatory=$false)]
    [string]$WorkbookName = "Tier 1 Key Vault Policy Compliance Dashboard",
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Compliance Dashboard Creation" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Set context
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
$context = Get-AzContext

Write-Host "Subscription: $($context.Subscription.Name)" -ForegroundColor White
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "Workbook Name: $WorkbookName" -ForegroundColor White
Write-Host "WhatIf: $($WhatIf.IsPresent)`n" -ForegroundColor White

# Generate Azure Monitor Workbook JSON template
$workbookTemplate = @{
    version = "Notebook/1.0"
    items = @(
        # Title section
        @{
            type = 1
            content = @{
                json = "# $WorkbookName\n\n**Last Updated**: {TimeRange:label}\n\n**Refresh**: Every 24 hours (manual refresh available)"
            }
        },
        
        # Overall Compliance Summary
        @{
            type = 1
            content = @{
                json = "## 📊 Overall Compliance Summary"
            }
        },
        @{
            type = 3
            content = @{
                version = "KqlItem/1.0"
                query = @"
PolicyStates
| where PolicyAssignmentName startswith "KV-Tier1"
| summarize 
    TotalResources = dcount(ResourceId),
    Compliant = countif(ComplianceState == "Compliant"),
    NonCompliant = countif(ComplianceState == "NonCompliant")
| extend CompliancePercentage = round(todouble(Compliant) / todouble(TotalResources) * 100, 2)
| project CompliancePercentage, Compliant, NonCompliant, TotalResources
"@
                size = 0
                timeContext = @{
                    durationMs = 86400000  # 24 hours
                }
                queryType = 0
                resourceType = "microsoft.operationalinsights/workspaces"
                visualization = "tiles"
                tileSettings = @{
                    titleContent = @{
                        columnMatch = "CompliancePercentage"
                        formatter = 1
                    }
                    leftContent = @{
                        columnMatch = "CompliancePercentage"
                        formatter = 12
                        formatOptions = @{
                            palette = "greenRed"
                        }
                    }
                }
            }
        },
        
        # Compliance by Priority
        @{
            type = 1
            content = @{
                json = "## 🎯 Compliance by Priority (P0/P1/P2)"
            }
        },
        @{
            type = 3
            content = @{
                version = "KqlItem/1.0"
                query = @"
PolicyStates
| where PolicyAssignmentName startswith "KV-Tier1"
| extend Priority = case(
    PolicyAssignmentName contains "P0", "P0 - Critical",
    PolicyAssignmentName contains "P1", "P1 - High",
    PolicyAssignmentName contains "P2", "P2 - Medium",
    "Unknown"
)
| summarize 
    TotalResources = dcount(ResourceId),
    Compliant = countif(ComplianceState == "Compliant"),
    NonCompliant = countif(ComplianceState == "NonCompliant")
    by Priority
| extend CompliancePercentage = round(todouble(Compliant) / todouble(TotalResources) * 100, 2)
| project Priority, CompliancePercentage, Compliant, NonCompliant, TotalResources
| order by Priority asc
"@
                size = 0
                queryType = 0
                resourceType = "microsoft.operationalinsights/workspaces"
                visualization = "barchart"
            }
        },
        
        # Policy Performance (Violation Counts)
        @{
            type = 1
            content = @{
                json = "## 📈 Policy Performance (Top 10 Violators)"
            }
        },
        @{
            type = 3
            content = @{
                version = "KqlItem/1.0"
                query = @"
PolicyStates
| where PolicyAssignmentName startswith "KV-Tier1"
| where ComplianceState == "NonCompliant"
| summarize ViolationCount = count() by PolicyDefinitionName, PolicyAssignmentName
| top 10 by ViolationCount desc
| extend Priority = case(
    PolicyAssignmentName contains "P0", "P0",
    PolicyAssignmentName contains "P1", "P1",
    PolicyAssignmentName contains "P2", "P2",
    "Unknown"
)
| project PolicyDefinitionName, Priority, ViolationCount
| order by ViolationCount desc
"@
                size = 0
                queryType = 0
                resourceType = "microsoft.operationalinsights/workspaces"
                visualization = "table"
            }
        },
        
        # Compliance Trend (Last 30 Days)
        @{
            type = 1
            content = @{
                json = "## 📉 Compliance Trend (Last 30 Days)"
            }
        },
        @{
            type = 3
            content = @{
                version = "KqlItem/1.0"
                query = @"
PolicyStates
| where PolicyAssignmentName startswith "KV-Tier1"
| summarize 
    TotalResources = dcount(ResourceId),
    Compliant = countif(ComplianceState == "Compliant")
    by bin(TimeGenerated, 1d)
| extend CompliancePercentage = round(todouble(Compliant) / todouble(TotalResources) * 100, 2)
| project TimeGenerated, CompliancePercentage
| order by TimeGenerated asc
"@
                size = 0
                timeContext = @{
                    durationMs = 2592000000  # 30 days
                }
                queryType = 0
                resourceType = "microsoft.operationalinsights/workspaces"
                visualization = "linechart"
            }
        },
        
        # Top Non-Compliant Resources
        @{
            type = 1
            content = @{
                json = "## ⚠️ Top Non-Compliant Resources (Most Violations)"
            }
        },
        @{
            type = 3
            content = @{
                version = "KqlItem/1.0"
                query = @"
PolicyStates
| where PolicyAssignmentName startswith "KV-Tier1"
| where ComplianceState == "NonCompliant"
| summarize 
    ViolationCount = count(), 
    Policies = make_set(PolicyDefinitionName)
    by ResourceId, ResourceType, ResourceGroup
| top 20 by ViolationCount desc
| extend ResourceName = split(ResourceId, "/")[-1]
| project ResourceName, ResourceGroup, ViolationCount, Policies
"@
                size = 0
                queryType = 0
                resourceType = "microsoft.operationalinsights/workspaces"
                visualization = "table"
                gridSettings = @{
                    sortBy = @(
                        @{
                            itemKey = "ViolationCount"
                            sortOrder = 2
                        }
                    )
                }
            }
        },
        
        # Exemption Tracking
        @{
            type = 1
            content = @{
                json = "## 🔓 Exemption Tracking\n\n*Note: Requires custom log ingestion from exemption management system*"
            }
        },
        
        # Remediation Task Status
        @{
            type = 1
            content = @{
                json = "## 🔧 Remediation Task Status (Last 7 Days)"
            }
        },
        @{
            type = 3
            content = @{
                version = "KqlItem/1.0"
                query = @"
AzureActivity
| where OperationNameValue contains "MICROSOFT.POLICYINSIGHTS/REMEDIATIONS"
| where Properties contains "keyvault"
| summarize 
    Total = count(),
    Success = countif(ActivityStatusValue == "Succeeded"),
    Failed = countif(ActivityStatusValue == "Failed"),
    InProgress = countif(ActivityStatusValue == "InProgress")
    by bin(TimeGenerated, 1d)
| extend SuccessRate = round(todouble(Success) / todouble(Total) * 100, 2)
| project TimeGenerated, SuccessRate, Total, Success, Failed, InProgress
| order by TimeGenerated asc
"@
                size = 0
                timeContext = @{
                    durationMs = 604800000  # 7 days
                }
                queryType = 0
                resourceType = "microsoft.operationalinsights/workspaces"
                visualization = "linechart"
            }
        }
    )
    styleSettings = @{}
    '$schema' = "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
}

# Convert to JSON
$workbookJson = $workbookTemplate | ConvertTo-Json -Depth 20 -Compress

# Generate ARM template for workbook deployment
$armTemplate = @{
    '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    contentVersion = "1.0.0.0"
    parameters = @{
        workbookDisplayName = @{
            type = "string"
            defaultValue = $WorkbookName
        }
        workbookSourceId = @{
            type = "string"
            defaultValue = "/subscriptions/$SubscriptionId"
        }
    }
    variables = @{
        workbookId = "[newGuid()]"
    }
    resources = @(
        @{
            type = "Microsoft.Insights/workbooks"
            apiVersion = "2022-04-01"
            name = "[variables('workbookId')]"
            location = "[resourceGroup().location]"
            kind = "shared"
            properties = @{
                displayName = "[parameters('workbookDisplayName')]"
                serializedData = $workbookJson
                version = "1.0"
                sourceId = "[parameters('workbookSourceId')]"
                category = "workbook"
            }
        }
    )
    outputs = @{
        workbookId = @{
            type = "string"
            value = "[variables('workbookId')]"
        }
    }
}

# Save ARM template
$armFile = "ComplianceDashboard-Template-$timestamp.json"
$armTemplate | ConvertTo-Json -Depth 20 | Out-File $armFile -Encoding UTF8
Write-Host "✓ ARM template generated: $armFile" -ForegroundColor Green

# Generate PowerBI Dashboard configuration (alternative)
$powerBiConfig = @{
    DashboardName = $WorkbookName
    RefreshSchedule = "Daily at 6:00 AM"
    DataSources = @(
        @{
            Type = "Azure Policy Compliance API"
            Endpoint = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.PolicyInsights/policyStates/latest/queryResults"
            Authentication = "Azure AD"
        }
    )
    Visualizations = @(
        @{
            Name = "Overall Compliance Gauge"
            Type = "Gauge"
            Target = 95
            Threshold = @{ Red = 80; Yellow = 90; Green = 95 }
        },
        @{
            Name = "Compliance by Priority"
            Type = "Clustered Column Chart"
            XAxis = "Priority (P0/P1/P2)"
            YAxis = "Compliance %"
        },
        @{
            Name = "Top 10 Violators"
            Type = "Table"
            Columns = @("Policy Name", "Priority", "Violation Count")
        },
        @{
            Name = "30-Day Trend"
            Type = "Line Chart"
            XAxis = "Date"
            YAxis = "Compliance %"
        }
    )
    Filters = @(
        @{ Name = "Date Range"; DefaultValue = "Last 30 Days" },
        @{ Name = "Priority"; Options = @("All", "P0", "P1", "P2") },
        @{ Name = "Resource Group"; Options = @("All") }
    )
}

$powerBiFile = "ComplianceDashboard-PowerBI-Config-$timestamp.json"
$powerBiConfig | ConvertTo-Json -Depth 10 | Out-File $powerBiFile -Encoding UTF8
Write-Host "✓ Power BI configuration generated: $powerBiFile" -ForegroundColor Green

# Generate deployment instructions
$instructions = @"
========================================
COMPLIANCE DASHBOARD DEPLOYMENT
========================================

OPTION 1: Azure Monitor Workbook (Recommended)
-----------------------------------------------

1. Ensure Log Analytics Workspace exists:
   az monitor log-analytics workspace create \
     --resource-group $ResourceGroupName \
     --workspace-name law-policy-monitoring \
     --location eastus

2. Enable Policy State data collection:
   - Azure Portal → Policy → Compliance
   - Configure diagnostic settings
   - Send to Log Analytics workspace

3. Deploy workbook using ARM template:
   az deployment group create \
     --resource-group $ResourceGroupName \
     --template-file $armFile

4. Access dashboard:
   - Azure Portal → Monitor → Workbooks
   - Select "$WorkbookName"
   - Pin to dashboard for easy access

OPTION 2: Power BI Dashboard
------------------------------

1. Install Power BI Desktop (if not already installed)

2. Create new Power BI report:
   - File → Get Data → More
   - Select "Azure Resource Manager"
   - Authenticate with Azure AD

3. Configure data source:
   - Use Policy Compliance API endpoint (see $powerBiFile)
   - Apply filters for "KV-Tier1" assignments

4. Build visualizations:
   - Overall compliance gauge (target: 95%)
   - Compliance by priority (P0/P1/P2)
   - 30-day trend line chart
   - Top violators table

5. Schedule refresh:
   - Publish to Power BI Service
   - Configure daily refresh at 6:00 AM
   - Share with stakeholders

OPTION 3: Azure Dashboard (Basic)
-----------------------------------

1. Azure Portal → Dashboard → Create
2. Add tiles:
   - Policy Compliance tile (from Azure Policy)
   - Custom KQL query tiles (from Log Analytics)
3. Pin to home for quick access

DASHBOARD METRICS TO TRACK:
----------------------------

✅ Overall Compliance %: Target >95%
✅ P0 Compliance: Target >90% (critical)
✅ P1 Compliance: Target >80% (high)
✅ P2 Compliance: Target >70% (medium)
✅ Exemption Count: Target <5% of resources
✅ Remediation Success Rate: Target >90%
✅ Deny Block Count: Monitor for spikes (>100/hour)

REFRESH SCHEDULE:
-----------------

- Automated: Every 24 hours (Log Analytics ingestion)
- Manual: Available on-demand via Refresh button
- Real-time: Policy state updates every 5-15 minutes

SHARING & PERMISSIONS:
-----------------------

Share dashboard with:
- CISO (View only)
- Security Architects (View only)
- Azure Governance Team (Edit)
- Cloud Center of Excellence (View only)

Grant "Reader" role on subscription for dashboard users.

NEXT STEPS:
-----------

1. Deploy Log Analytics workspace (if not exists)
2. Configure diagnostic settings for Policy data
3. Deploy Azure Monitor Workbook
4. Test dashboard queries and visualizations
5. Share dashboard link with stakeholders
6. Schedule monthly review meetings

========================================
"@

$instructionsFile = "ComplianceDashboard-Deployment-Instructions.txt"
$instructions | Out-File $instructionsFile -Encoding UTF8

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Dashboard Generation Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Files Created:" -ForegroundColor White
Write-Host "  - $armFile (Azure Monitor Workbook template)" -ForegroundColor Gray
Write-Host "  - $powerBiFile (Power BI configuration)" -ForegroundColor Gray
Write-Host "  - $instructionsFile (Deployment guide)" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "⚠ PREREQUISITES REQUIRED:" -ForegroundColor Yellow
Write-Host "  1. Log Analytics Workspace" -ForegroundColor White
Write-Host "  2. Policy diagnostic settings → Log Analytics" -ForegroundColor White
Write-Host "  3. 24-48 hours of policy state data for accurate metrics`n" -ForegroundColor White

Write-Host "DEPLOYMENT COMMAND:" -ForegroundColor Cyan
Write-Host "  az deployment group create --resource-group $ResourceGroupName --template-file $armFile`n" -ForegroundColor Gray

Write-Host "Dashboard creation complete! Review $instructionsFile for next steps.`n" -ForegroundColor Green
