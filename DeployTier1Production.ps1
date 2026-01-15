<#
.SYNOPSIS
Deploy Tier 1 Azure Key Vault Policies to Production - Phase 3.1 (Audit Mode)

.DESCRIPTION
Deploys 12 critical Tier 1 policies in Audit mode to production subscription.
This is Phase 3.1 of the production rollout strategy.

Timeline: Month 1 (30-90 day audit baseline)
Success Criteria: <10% non-compliance for P0, <20% for P1, <30% for P2

.PARAMETER ProductionSubscriptionId
Production subscription ID to deploy policies to

.PARAMETER Scope
Scope for policy assignments. Defaults to subscription scope.
Examples: "/subscriptions/xxx" or "/subscriptions/xxx/resourceGroups/rg-prod"

.PARAMETER WhatIf
Dry-run mode - show what would be deployed without actually deploying

.PARAMETER GenerateReport
Generate deployment report with all assignment details

.EXAMPLE
.\DeployTier1Production.ps1 -ProductionSubscriptionId "12345678-1234-1234-1234-123456789012" -WhatIf

.EXAMPLE
.\DeployTier1Production.ps1 -ProductionSubscriptionId "12345678-1234-1234-1234-123456789012" -GenerateReport

.NOTES
Author: Azure Governance Team
Version: 1.0.0
Date: January 13, 2026
Phase: 3.1 - Production Audit Mode Deployment
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ProductionSubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$Scope,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateReport
)

# Initialize
$ErrorActionPreference = "Stop"
$deploymentTimestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PHASE 3.1: Tier 1 Production Deployment" -ForegroundColor Cyan
Write-Host "Mode: AUDIT (Baseline Establishment)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Define Tier 1 Policies (12 Critical Security Policies)
$tier1Policies = @(
    # P0: Critical Security Policies
    @{
        Name = "KV-Tier1-P0-SoftDelete"
        DisplayName = "[Tier 1 P0] Key vaults should have soft delete enabled"
        PolicyName = "Key vaults should have soft delete enabled"
        Priority = "P0"
        Effect = "Audit"
        Parameters = @{}
        Description = "Prevent permanent deletion of key vaults"
    },
    @{
        Name = "KV-Tier1-P0-PurgeProtection"
        DisplayName = "[Tier 1 P0] Key vaults should have deletion protection enabled"
        PolicyName = "Key vaults should have deletion protection enabled"
        Priority = "P0"
        Effect = "Audit"
        Parameters = @{}
        Description = "Require purge protection to prevent permanent data loss"
    },
    @{
        Name = "KV-Tier1-P0-DisablePublicAccess"
        DisplayName = "[Tier 1 P0] Azure Key Vault should disable public network access"
        PolicyName = "Azure Key Vault should disable public network access"
        Priority = "P0"
        Effect = "Audit"
        Parameters = @{}
        Description = "Block public internet access to key vaults"
    },
    
    # P1: High Security Policies
    @{
        Name = "KV-Tier1-P1-PrivateLink"
        DisplayName = "[Tier 1 P1] Azure Key Vaults should use private link"
        PolicyName = "Azure Key Vaults should use private link"
        Priority = "P1"
        Effect = "Audit"
        Parameters = @{}
        Description = "Require private endpoint connectivity"
    },
    @{
        Name = "KV-Tier1-P1-Firewall"
        DisplayName = "[Tier 1 P1] Azure Key Vault should have firewall enabled"
        PolicyName = "Azure Key Vault should have firewall enabled or public network access disabled"
        Priority = "P1"
        Effect = "Audit"
        Parameters = @{}
        Description = "Require firewall or private access only"
    },
    @{
        Name = "KV-Tier1-P1-RBAC"
        DisplayName = "[Tier 1 P1] Azure Key Vault should use RBAC permission model"
        PolicyName = "Azure Key Vault should use RBAC permission model"
        Priority = "P1"
        Effect = "Audit"
        Parameters = @{}
        Description = "Enforce RBAC over legacy access policies"
    },
    @{
        Name = "KV-Tier1-P1-KeyExpiration"
        DisplayName = "[Tier 1 P1] Key Vault keys should have an expiration date"
        PolicyName = "Key Vault keys should have an expiration date"
        Priority = "P1"
        Effect = "Audit"
        Parameters = @{}
        Description = "Require expiration dates on all keys"
    },
    @{
        Name = "KV-Tier1-P1-SecretExpiration"
        DisplayName = "[Tier 1 P1] Key Vault secrets should have an expiration date"
        PolicyName = "Key Vault secrets should have an expiration date"
        Priority = "P1"
        Effect = "Audit"
        Parameters = @{}
        Description = "Require expiration dates on all secrets"
    },
    
    # P2: Medium Security Policies
    @{
        Name = "KV-Tier1-P2-CertValidity"
        DisplayName = "[Tier 1 P2] Certificates should have the specified maximum validity period"
        PolicyName = "Certificates should have the specified maximum validity period"
        Priority = "P2"
        Effect = "Audit"
        Parameters = @{
            maximumValidityInMonths = @{value = 12}  # 1 year max
        }
        Description = "Limit certificate validity to 12 months"
    },
    @{
        Name = "KV-Tier1-P2-HSMRequired"
        DisplayName = "[Tier 1 P2] Keys should be backed by a hardware security module (HSM)"
        PolicyName = "Keys should be backed by a hardware security module (HSM)"
        Priority = "P2"
        Effect = "Audit"
        Parameters = @{}
        Description = "Require HSM-backed keys for production"
    },
    @{
        Name = "KV-Tier1-P2-RSAKeySize"
        DisplayName = "[Tier 1 P2] Keys using RSA cryptography should have minimum key size"
        PolicyName = "Keys using RSA cryptography should have a specified minimum key size"
        Priority = "P2"
        Effect = "Audit"
        Parameters = @{
            minimumRSAKeySize = @{value = 2048}
        }
        Description = "Enforce 2048-bit minimum for RSA keys"
    },
    @{
        Name = "KV-Tier1-P2-CertExpiration"
        DisplayName = "[Tier 1 P2] Certificates should not expire within specified days"
        PolicyName = "Certificates should not expire within the specified number of days"
        Priority = "P2"
        Effect = "Audit"
        Parameters = @{
            daysToExpire = @{value = 30}  # 30-day warning
        }
        Description = "Alert on certificates expiring within 30 days"
    }
)

# Get current context
Write-Host "Checking Azure context..." -ForegroundColor Yellow
$currentContext = Get-AzContext
if (-not $currentContext) {
    Write-Host "ERROR: Not logged into Azure. Run Connect-AzAccount first." -ForegroundColor Red
    exit 1
}

# Determine target subscription
if ($ProductionSubscriptionId) {
    Write-Host "Switching to production subscription: $ProductionSubscriptionId" -ForegroundColor Yellow
    Set-AzContext -SubscriptionId $ProductionSubscriptionId | Out-Null
    $targetContext = Get-AzContext
} else {
    $targetContext = $currentContext
    Write-Host "WARNING: No ProductionSubscriptionId specified. Using current subscription:" -ForegroundColor Yellow
    Write-Host "  Subscription: $($targetContext.Subscription.Name)" -ForegroundColor Yellow
    Write-Host "  ID: $($targetContext.Subscription.Id)" -ForegroundColor Yellow
    
    $confirm = Read-Host "`nDeploy to this subscription? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "Deployment cancelled." -ForegroundColor Red
        exit 0
    }
}

# Determine scope
if (-not $Scope) {
    $Scope = "/subscriptions/$($targetContext.Subscription.Id)"
}

Write-Host "`n=== Deployment Configuration ===" -ForegroundColor Cyan
Write-Host "Subscription: $($targetContext.Subscription.Name)" -ForegroundColor White
Write-Host "Subscription ID: $($targetContext.Subscription.Id)" -ForegroundColor White
Write-Host "Scope: $Scope" -ForegroundColor White
Write-Host "Mode: AUDIT (Month 1 baseline)" -ForegroundColor Green
Write-Host "Policies: 12 Tier 1 policies" -ForegroundColor White
Write-Host "WhatIf Mode: $($WhatIf.IsPresent)" -ForegroundColor White
Write-Host "================================`n" -ForegroundColor Cyan

# Load policy mapping
Write-Host "Loading policy definitions..." -ForegroundColor Yellow
if (-not (Test-Path "PolicyNameMapping.json")) {
    Write-Host "ERROR: PolicyNameMapping.json not found. Run main script first to generate mappings." -ForegroundColor Red
    exit 1
}

$policyMapping = Get-Content "PolicyNameMapping.json" | ConvertFrom-Json
$deploymentResults = @()
$successCount = 0
$failureCount = 0
$skippedCount = 0

# Deploy each policy
foreach ($policyConfig in $tier1Policies) {
    Write-Host "`n--- Deploying: $($policyConfig.DisplayName) ---" -ForegroundColor Cyan
    Write-Host "Priority: $($policyConfig.Priority) | Effect: $($policyConfig.Effect)" -ForegroundColor Gray
    
    $result = [PSCustomObject]@{
        AssignmentName = $policyConfig.Name
        DisplayName = $policyConfig.DisplayName
        PolicyName = $policyConfig.PolicyName
        Priority = $policyConfig.Priority
        Effect = $policyConfig.Effect
        Status = "Unknown"
        Message = ""
        PolicyDefinitionId = ""
        AssignmentId = ""
    }
    
    try {
        # Find policy definition ID from mapping file (keyed by DisplayName)
        $policyDef = $policyMapping.($policyConfig.PolicyName)
        
        if (-not $policyDef) {
            # Try direct lookup from Azure
            Write-Host "  Searching for policy definition..." -ForegroundColor Gray
            $azPolicyDef = Get-AzPolicyDefinition | Where-Object { $_.Properties.DisplayName -eq $policyConfig.PolicyName }
            
            if (-not $azPolicyDef) {
                throw "Policy definition not found: $($policyConfig.PolicyName)"
            }
            
            $policyDefId = $azPolicyDef.PolicyDefinitionId
        } else {
            $policyDefId = $policyDef.Id
        }
        
        $result.PolicyDefinitionId = $policyDefId
        Write-Host "  Policy ID: $policyDefId" -ForegroundColor Gray
        
        # Check if already assigned
        $existingAssignment = Get-AzPolicyAssignment -Scope $Scope -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -eq $policyConfig.Name }
        
        if ($existingAssignment) {
            Write-Host "  Policy already assigned. Skipping." -ForegroundColor Yellow
            $result.Status = "Skipped"
            $result.Message = "Already assigned"
            $result.AssignmentId = $existingAssignment.PolicyAssignmentId
            $skippedCount++
        } elseif ($WhatIf) {
            Write-Host "  [WHATIF] Would create assignment: $($policyConfig.Name)" -ForegroundColor Magenta
            $result.Status = "WhatIf"
            $result.Message = "Would be created"
            $skippedCount++
        } else {
            # Create policy parameters
            $policyParams = @{
                effect = @{value = $policyConfig.Effect}
            }
            
            # Add custom parameters
            foreach ($paramKey in $policyConfig.Parameters.Keys) {
                $policyParams[$paramKey] = $policyConfig.Parameters[$paramKey]
            }
            
            # Create assignment
            Write-Host "  Creating policy assignment..." -ForegroundColor Green
            $assignment = New-AzPolicyAssignment `
                -Name $policyConfig.Name `
                -DisplayName $policyConfig.DisplayName `
                -Scope $Scope `
                -PolicyDefinition $policyDefId `
                -PolicyParameter ($policyParams | ConvertTo-Json -Depth 10) `
                -Description "$($policyConfig.Description) [Phase 3.1 - Audit Mode]" `
                -ErrorAction Stop
            
            $result.Status = "Success"
            $result.Message = "Created successfully"
            $result.AssignmentId = $assignment.PolicyAssignmentId
            $successCount++
            
            Write-Host "  ✓ Assignment created: $($assignment.PolicyAssignmentId)" -ForegroundColor Green
        }
        
    } catch {
        Write-Host "  ✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $result.Status = "Failed"
        $result.Message = $_.Exception.Message
        $failureCount++
    }
    
    $deploymentResults += $result
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deployment Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Policies: $($tier1Policies.Count)" -ForegroundColor White
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failureCount" -ForegroundColor Red
Write-Host "Skipped: $skippedCount" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

# Detailed results
Write-Host "`n--- Deployment Details ---`n" -ForegroundColor Cyan
$deploymentResults | Format-Table -Property Priority, DisplayName, Status, Message -AutoSize

# Generate report
if ($GenerateReport -or $failureCount -gt 0) {
    $reportFile = "Tier1ProductionDeployment-$deploymentTimestamp.json"
    
    $report = @{
        DeploymentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Phase = "3.1 - Production Audit Mode"
        TargetSubscription = $targetContext.Subscription.Id
        SubscriptionName = $targetContext.Subscription.Name
        Scope = $Scope
        TotalPolicies = $tier1Policies.Count
        SuccessCount = $successCount
        FailureCount = $failureCount
        SkippedCount = $skippedCount
        WhatIfMode = $WhatIf.IsPresent
        Results = $deploymentResults
    }
    
    $report | ConvertTo-Json -Depth 10 | Out-File $reportFile -Encoding UTF8
    Write-Host "Deployment report saved: $reportFile" -ForegroundColor Cyan
}

# Next steps
if ($successCount -gt 0 -and -not $WhatIf) {
    Write-Host "`n=== Next Steps ===`n" -ForegroundColor Yellow
    Write-Host "1. Wait 24-48 hours for initial policy evaluation" -ForegroundColor White
    Write-Host "2. Generate compliance report:" -ForegroundColor White
    Write-Host "   Get-AzPolicyState -SubscriptionId $($targetContext.Subscription.Id)" -ForegroundColor Gray
    Write-Host "3. Monitor compliance targets:" -ForegroundColor White
    Write-Host "   - P0 policies: <10% non-compliance" -ForegroundColor Gray
    Write-Host "   - P1 policies: <20% non-compliance" -ForegroundColor Gray
    Write-Host "   - P2 policies: <30% non-compliance" -ForegroundColor Gray
    Write-Host "4. Begin stakeholder outreach for remediation" -ForegroundColor White
    Write-Host "5. Run weekly compliance checks for 30-90 days" -ForegroundColor White
    Write-Host "6. When <5% violations for 2 weeks: Proceed to Phase 3.2 (Deny mode)`n" -ForegroundColor White
}

if ($WhatIf) {
    Write-Host "`n=== WhatIf Mode Complete ===" -ForegroundColor Magenta
    Write-Host "No changes were made. Review the output above and re-run without -WhatIf to deploy.`n" -ForegroundColor Magenta
}

# Exit code
if ($failureCount -gt 0) {
    Write-Host "Deployment completed with errors. Review failed policies above." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    exit 0
}
