<#
.SYNOPSIS
Deploy all 46 Key Vault policies in Deny mode for comprehensive testing

.DESCRIPTION
Deploys ALL 46 Key Vault policies to test subscription in DENY MODE.
This enables complete validation of blocking behavior and security enforcement.

WARNING: This will BLOCK non-compliant operations. Use in test environment only.

.PARAMETER SubscriptionId
Target subscription ID for policy deployment

.PARAMETER Scope
Scope for policy assignments (default: subscription level)

.PARAMETER WhatIf
Preview deployment without making changes

.PARAMETER GenerateReport
Generate deployment report JSON

.EXAMPLE
.\DeployAll46PoliciesDenyMode.ps1 -SubscriptionId "xxx" -WhatIf
.\DeployAll46PoliciesDenyMode.ps1 -SubscriptionId "xxx" -GenerateReport

.NOTES
Author: Azure Governance Team
Version: 1.0.0
Date: January 13, 2026
Purpose: Phase 3 - Comprehensive Deny Mode Validation
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$Scope = "/subscriptions/$SubscriptionId",
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateReport
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "DEPLOY ALL 46 KEY VAULT POLICIES" -ForegroundColor Cyan
Write-Host "Phase 3 - Comprehensive Validation" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if (-not $WhatIf) {
    Write-Host "⚠️  WARNING: This will deploy ALL 46 Key Vault policies" -ForegroundColor Yellow
    Write-Host "⚠️  Includes Deny, Audit, and DeployIfNotExists policies" -ForegroundColor Yellow
    Write-Host "⚠️  Non-compliant operations will be BLOCKED by Deny policies" -ForegroundColor Yellow
    Write-Host "⚠️  Use in TEST ENVIRONMENT ONLY`n" -ForegroundColor Yellow
    
    $confirm = Read-Host "Type 'DEPLOY' to confirm"
    if ($confirm -ne 'DEPLOY') {
        Write-Host "Deployment cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Set Azure context
Write-Host "Setting Azure context..." -ForegroundColor Yellow
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
$context = Get-AzContext

Write-Host "✓ Connected to subscription: $($context.Subscription.Name)" -ForegroundColor Green
Write-Host "  ID: $($context.Subscription.Id)" -ForegroundColor Gray
Write-Host "  Scope: $Scope" -ForegroundColor Gray
Write-Host "  WhatIf: $($WhatIf.IsPresent)`n" -ForegroundColor Gray

# Load policy mapping
$mappingFile = "PolicyNameMapping.json"
if (-not (Test-Path $mappingFile)) {
    Write-Host "ERROR: Policy mapping file not found: $mappingFile" -ForegroundColor Red
    exit 1
}

Write-Host "Loading policy mapping from $mappingFile..." -ForegroundColor Yellow
$policyMapping = Get-Content $mappingFile -Raw | ConvertFrom-Json
Write-Host "✓ Policy mapping loaded`n" -ForegroundColor Green

# Define ALL 46 policies - EXACT names from DefinitionListExport.csv
$all46Policies = @(
    # Security - Vault Level (7 Audit/Deny policies)
    @{ PolicyName = "Key vaults should have soft delete enabled"; AssignmentName = "KV-All-SoftDelete"; Effect = "Deny" },
    @{ PolicyName = "Key vaults should have deletion protection enabled"; AssignmentName = "KV-All-PurgeProtection"; Effect = "Deny" },
    @{ PolicyName = "Azure Key Vault should disable public network access"; AssignmentName = "KV-All-DisablePublicAccess"; Effect = "Deny" },
    @{ PolicyName = "Azure Key Vaults should use private link"; AssignmentName = "KV-All-PrivateLink"; Effect = "Deny" },
    @{ PolicyName = "Azure Key Vault should have firewall enabled or public network access disabled"; AssignmentName = "KV-All-Firewall"; Effect = "Deny" },
    @{ PolicyName = "Azure Key Vault should use RBAC permission model"; AssignmentName = "KV-All-RBAC"; Effect = "Deny" },
    @{ PolicyName = "Resource logs in Key Vault should be enabled"; AssignmentName = "KV-All-DiagnosticLogs"; Effect = "AuditIfNotExists" },
    
    # Security - Vault Level (6 Deploy/Configure policies - DeployIfNotExists/Modify effects)
    @{ PolicyName = "Configure Azure Key Vaults with private endpoints"; AssignmentName = "KV-All-ConfigPrivateEndpoints"; Effect = "DeployIfNotExists" },
    @{ PolicyName = "Configure Azure Key Vaults to use private DNS zones"; AssignmentName = "KV-All-ConfigPrivateDNS"; Effect = "DeployIfNotExists" },
    @{ PolicyName = "Configure key vaults to enable firewall"; AssignmentName = "KV-All-ConfigFirewall"; Effect = "Modify" },
    @{ PolicyName = "Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace"; AssignmentName = "KV-All-DeployDiagLA"; Effect = "DeployIfNotExists" },
    @{ PolicyName = "Deploy Diagnostic Settings for Key Vault to Event Hub"; AssignmentName = "KV-All-DeployDiagEH"; Effect = "DeployIfNotExists" },
    @{ PolicyName = "Deploy - Configure diagnostic settings to an Event Hub to be enabled on Azure Key Vault Managed HSM"; AssignmentName = "KV-All-DeployManagedHSMDiagEH"; Effect = "DeployIfNotExists"; DisplayName = "Deploy Managed HSM Diag to Event Hub" },
    @{ PolicyName = "[Preview]: Configure Azure Key Vault Managed HSM to disable public network access"; AssignmentName = "KV-All-ConfigManagedHSMPublicAccess"; Effect = "Modify" },
    @{ PolicyName = "[Preview]: Configure Azure Key Vault Managed HSM with private endpoints"; AssignmentName = "KV-All-ConfigManagedHSMPrivateEndpoints"; Effect = "DeployIfNotExists" },
    
    # Keys (9 policies)
    @{ PolicyName = "Key Vault keys should have an expiration date"; AssignmentName = "KV-All-KeyExpiration"; Effect = "Deny" },
    @{ PolicyName = "Keys should not be active for longer than the specified number of days"; AssignmentName = "KV-All-KeyMaxAge"; Effect = "Deny"; Parameters = @{ maximumValidityInDays = 365 } },
    @{ PolicyName = "Keys using RSA cryptography should have a specified minimum key size"; AssignmentName = "KV-All-RSAKeySize"; Effect = "Deny"; Parameters = @{ minimumRSAKeySize = 2048 } },
    @{ PolicyName = "Keys should be backed by a hardware security module (HSM)"; AssignmentName = "KV-All-HSMRequired"; Effect = "Deny" },
    @{ PolicyName = "Keys should have more than the specified number of days before expiration"; AssignmentName = "KV-All-KeyExpirationWarning"; Effect = "Deny"; Parameters = @{ minimumDaysBeforeExpiration = 30 } },
    @{ PolicyName = "Keys using elliptic curve cryptography should have the specified curve names"; AssignmentName = "KV-All-ECCCurveNames"; Effect = "Deny"; Parameters = @{ allowedECNames = @("P-256", "P-384", "P-521") } },
    @{ PolicyName = "Keys should have a rotation policy ensuring that their rotation is scheduled within the specified number of days after creation."; AssignmentName = "KV-All-KeyRotationPolicy"; Effect = "Deny"; Parameters = @{ maximumDaysToRotate = 90 }; DisplayName = "Keys Rotation Policy" },
    @{ PolicyName = "Keys should have the specified maximum validity period"; AssignmentName = "KV-All-KeyMaxValidity"; Effect = "Deny"; Parameters = @{ maximumValidityInDays = 730 } },
    @{ PolicyName = "Keys should be the specified cryptographic type RSA or EC"; AssignmentName = "KV-All-KeyCryptoType"; Effect = "Deny"; Parameters = @{ allowedKeyTypes = @("RSA", "EC") } },
    
    # Secrets (5 policies)
    @{ PolicyName = "Key Vault secrets should have an expiration date"; AssignmentName = "KV-All-SecretExpiration"; Effect = "Deny" },
    @{ PolicyName = "Secrets should not be active for longer than the specified number of days"; AssignmentName = "KV-All-SecretMaxAge"; Effect = "Deny"; Parameters = @{ maximumValidityInDays = 365 } },
    @{ PolicyName = "Secrets should have more than the specified number of days before expiration"; AssignmentName = "KV-All-SecretExpirationWarning"; Effect = "Deny"; Parameters = @{ minimumDaysBeforeExpiration = 30 } },
    @{ PolicyName = "Secrets should have content type set"; AssignmentName = "KV-All-SecretContentType"; Effect = "Deny" },
    @{ PolicyName = "Secrets should have the specified maximum validity period"; AssignmentName = "KV-All-SecretMaxValidity"; Effect = "Deny"; Parameters = @{ maximumValidityInDays = 365 } },
    
    # Certificates (10 policies)
    @{ PolicyName = "Certificates should have the specified maximum validity period"; AssignmentName = "KV-All-CertValidity"; Effect = "Deny"; Parameters = @{ maximumValidityInMonths = 12 } },
    @{ PolicyName = "Certificates should not expire within the specified number of days"; AssignmentName = "KV-All-CertExpiration"; Effect = "Deny"; Parameters = @{ daysToExpire = 30 } },
    @{ PolicyName = "Certificates using RSA cryptography should have the specified minimum key size"; AssignmentName = "KV-All-CertRSAKeySize"; Effect = "Deny"; Parameters = @{ minimumRSAKeySize = 2048 } },
    @{ PolicyName = "Certificates should use allowed key types"; AssignmentName = "KV-All-CertKeyTypes"; Effect = "Deny"; Parameters = @{ allowedKeyTypes = @("RSA", "EC") } },
    @{ PolicyName = "Certificates using elliptic curve cryptography should have allowed curve names"; AssignmentName = "KV-All-CertECCCurves"; Effect = "Deny"; Parameters = @{ allowedECNames = @("P-256", "P-384", "P-521") } },
    @{ PolicyName = "Certificates should have the specified lifetime action triggers"; AssignmentName = "KV-All-CertLifetimeAction"; Effect = "Deny"; Parameters = @{ minimumDaysBeforeExpiry = 30; maximumPercentageLife = 80 } },
    @{ PolicyName = "Certificates should be issued by the specified integrated certificate authority"; AssignmentName = "KV-All-IntegratedCA"; Effect = "Deny"; Parameters = @{ allowedCAs = @("DigiCert", "GlobalSign") } },
    @{ PolicyName = "Certificates should be issued by the specified non-integrated certificate authority"; AssignmentName = "KV-All-NonIntegratedCA"; Effect = "Deny"; Parameters = @{ caCommonName = "CN=CustomCA" } },
    @{ PolicyName = "Certificates should be issued by one of the specified non-integrated certificate authorities"; AssignmentName = "KV-All-CertNonIntegratedCAOneOf"; Effect = "Deny"; Parameters = @{ caCommonNames = @("CN=CustomCA","CN=AnotherCA") } },
    
    # Managed HSM Deny-capable (5 policies)
    @{ PolicyName = "Azure Key Vault Managed HSM should have purge protection enabled"; AssignmentName = "KV-All-ManagedHSMPurgeProtection"; Effect = "Deny" },
    @{ PolicyName = "[Preview]: Azure Key Vault Managed HSM keys should have an expiration date"; AssignmentName = "KV-All-ManagedHSMKeyExpiration"; Effect = "Deny" },
    @{ PolicyName = "[Preview]: Azure Key Vault Managed HSM Keys should have more than the specified number of days before expiration"; AssignmentName = "KV-All-ManagedHSMKeyExpWarning"; Effect = "Deny"; Parameters = @{ minimumDaysBeforeExpiration = 30 }; DisplayName = "Managed HSM Keys Expiration Warning" },
    @{ PolicyName = "[Preview]: Azure Key Vault Managed HSM keys using RSA cryptography should have a specified minimum key size"; AssignmentName = "KV-All-ManagedHSMRSASize"; Effect = "Deny"; Parameters = @{ minimumRSAKeySize = 2048 }; DisplayName = "Managed HSM RSA Key Size" },
    @{ PolicyName = "[Preview]: Azure Key Vault Managed HSM keys using elliptic curve cryptography should have the specified curve names"; AssignmentName = "KV-All-ManagedHSMECCCurves"; Effect = "Deny"; Parameters = @{ allowedECNames = @("P-256", "P-384", "P-521") }; DisplayName = "Managed HSM ECC Curve Names" },
    
    # Managed HSM Audit-only (3 policies)
    @{ PolicyName = "[Preview]: Azure Key Vault Managed HSM should disable public network access"; AssignmentName = "KV-All-ManagedHSMPublicAccess"; Effect = "Audit" },
    @{ PolicyName = "Resource logs in Azure Key Vault Managed HSM should be enabled"; AssignmentName = "KV-All-ManagedHSMLogs"; Effect = "AuditIfNotExists" },
    @{ PolicyName = "[Preview]: Azure Key Vault Managed HSM should use private link"; AssignmentName = "KV-All-ManagedHSMPrivateLink"; Effect = "Audit" }
)

Write-Host "Total policies to deploy: $($all46Policies.Count)" -ForegroundColor Cyan
Write-Host "Deny mode: $($($all46Policies | Where-Object { $_.Effect -eq 'Deny' }).Count)" -ForegroundColor Yellow
Write-Host "Audit mode: $($($all46Policies | Where-Object { $_.Effect -eq 'Audit' }).Count)" -ForegroundColor Yellow
Write-Host "DeployIfNotExists/Modify: $($($all46Policies | Where-Object { $_.Effect -in @('DeployIfNotExists','Modify') }).Count)`n" -ForegroundColor Yellow

# Deployment tracking
$deploymentResults = @()
$successCount = 0
$failureCount = 0
$skippedCount = 0

foreach ($policyConfig in $all46Policies) {
    $assignmentName = $policyConfig.AssignmentName
    $policyName = $policyConfig.PolicyName
    $effect = $policyConfig.Effect
    
    Write-Host "--- Deploying: $assignmentName ---" -ForegroundColor Cyan
    Write-Host "  Policy: $policyName" -ForegroundColor Gray
    Write-Host "  Effect: $effect" -ForegroundColor $(if ($effect -eq 'Deny') { 'Yellow' } else { 'Gray' })
    
    $result = [PSCustomObject]@{
        AssignmentName = $assignmentName
        PolicyName = $policyName
        Effect = $effect
        Status = "Unknown"
        Message = ""
        PolicyDefinitionId = ""
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    try {
        # Check if assignment already exists
        $existing = Get-AzPolicyAssignment -Name $assignmentName -Scope $Scope -ErrorAction SilentlyContinue
        
        if ($existing) {
            Write-Host "  ⚠ Assignment already exists. Updating..." -ForegroundColor Yellow
            
            if ($WhatIf) {
                Write-Host "  [WHATIF] Would update existing assignment" -ForegroundColor Magenta
                $result.Status = "WhatIf-Update"
                $result.Message = "Would update existing assignment"
                $skippedCount++
            } else {
                # Update with new effect parameter
                $params = @{ effect = @{ value = $effect } }
                
                if ($policyConfig.Parameters) {
                    foreach ($key in $policyConfig.Parameters.Keys) {
                        $params[$key] = @{ value = $policyConfig.Parameters[$key] }
                    }
                }
                
                $updated = Set-AzPolicyAssignment `
                    -Id $existing.Id `
                    -PolicyParameter ($params | ConvertTo-Json -Depth 10) `
                    -ErrorAction Stop
                
                $result.Status = "Updated"
                $result.Message = "Updated existing assignment to effect=$effect"
                $result.PolicyDefinitionId = $existing.Properties.PolicyDefinitionId
                $successCount++
                Write-Host "  ✓ Updated to effect=$effect" -ForegroundColor Green
            }
            
            $deploymentResults += $result
            continue
        }
        
        # Lookup policy definition
        $policyDef = $policyMapping.($policyConfig.PolicyName)
        
        if (-not $policyDef) {
            Write-Host "  ✗ ERROR: Policy definition not found in mapping file" -ForegroundColor Red
            $result.Status = "Failed"
            $result.Message = "Policy definition not found: $policyName"
            $failureCount++
            $deploymentResults += $result
            continue
        }
        
        $policyDefId = $policyDef.Id
        $result.PolicyDefinitionId = $policyDefId
        Write-Host "  Found policy ID: $policyDefId" -ForegroundColor Gray
        
        # Build parameters
        $params = @{ effect = @{ value = $effect } }
        
        if ($policyConfig.Parameters) {
            foreach ($key in $policyConfig.Parameters.Keys) {
                $params[$key] = @{ value = $policyConfig.Parameters[$key] }
            }
            Write-Host "  Custom parameters: $($policyConfig.Parameters.Keys -join ', ')" -ForegroundColor Gray
        }
        
        if ($WhatIf) {
            Write-Host "  [WHATIF] Would create assignment:" -ForegroundColor Magenta
            Write-Host "    Name: $assignmentName" -ForegroundColor Magenta
            Write-Host "    Effect: $effect" -ForegroundColor Magenta
            Write-Host "    Policy: $policyDefId" -ForegroundColor Magenta
            
            $result.Status = "WhatIf"
            $result.Message = "Would create assignment with effect=$effect"
            $skippedCount++
        } else {
            # Use custom DisplayName if provided, otherwise use policy name (truncated if needed)
            $displayName = if ($policyConfig.DisplayName) { $policyConfig.DisplayName } else { $policyName }
            if ($displayName.Length -gt 128) { $displayName = $displayName.Substring(0, 125) + "..." }
            
            # Create assignment
            $assignment = New-AzPolicyAssignment `
                -Name $assignmentName `
                -DisplayName $displayName `
                -Scope $Scope `
                -PolicyDefinition $policyDefId `
                -PolicyParameter ($params | ConvertTo-Json -Depth 10) `
                -ErrorAction Stop
            
            $result.Status = "Success"
            $result.Message = "Created assignment with effect=$effect"
            $successCount++
            Write-Host "  ✓ Deployment successful" -ForegroundColor Green
        }
        
    } catch {
        Write-Host "  ✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $result.Status = "Failed"
        $result.Message = $_.Exception.Message
        $failureCount++
    }
    
    $deploymentResults += $result
    Write-Host ""
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Policies: $($all46Policies.Count)" -ForegroundColor White
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failureCount" -ForegroundColor Red
Write-Host "Skipped/WhatIf: $skippedCount" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

# Detailed results
Write-Host "Deployment Details:`n" -ForegroundColor Cyan
$deploymentResults | Format-Table -Property AssignmentName, Effect, Status, Message -AutoSize

# Generate report
if ($GenerateReport -or $failureCount -gt 0) {
    $reportFile = "All46PoliciesDenyMode-$timestamp.json"
    
    $report = @{
        DeploymentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Subscription = @{
            Name = $context.Subscription.Name
            Id = $context.Subscription.Id
        }
        Scope = $Scope
        TotalPolicies = $all46Policies.Count
        SuccessCount = $successCount
        FailureCount = $failureCount
        SkippedCount = $skippedCount
        WhatIfMode = $WhatIf.IsPresent
        Results = $deploymentResults
    }
    
    $report | ConvertTo-Json -Depth 10 | Out-File $reportFile -Encoding UTF8
    Write-Host "Deployment report saved: $reportFile`n" -ForegroundColor Cyan
}

# Next steps
if ($successCount -gt 0 -and -not $WhatIf) {
    Write-Host "=== NEXT STEPS ===" -ForegroundColor Yellow
    Write-Host "1. Wait 24-48 hours for policy evaluation" -ForegroundColor White
    Write-Host "2. Run blocking validation tests:" -ForegroundColor White
    Write-Host "   .\ValidateAll46PoliciesBlocking.ps1 -SubscriptionId '$SubscriptionId'" -ForegroundColor Gray
    Write-Host "3. Monitor compliance:" -ForegroundColor White
    Write-Host "   Get-AzPolicyState -SubscriptionId '$SubscriptionId' | Where-Object { `$_.PolicyAssignmentName -like 'KV-All-*' }" -ForegroundColor Gray
    Write-Host "4. Review blocked operations in Activity Log`n" -ForegroundColor White
}

if ($WhatIf) {
    Write-Host "=== WHATIF MODE COMPLETE ===" -ForegroundColor Magenta
    Write-Host "No changes were made. Review output and re-run without -WhatIf to deploy.`n" -ForegroundColor Magenta
}

# Exit code
if ($failureCount -gt 0) {
    Write-Host "Deployment completed with errors. Review failed policies above." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    exit 0
}

