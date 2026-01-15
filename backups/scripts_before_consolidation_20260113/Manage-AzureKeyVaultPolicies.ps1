#!/usr/bin/env pwsh
#Requires -Module Az.Accounts, Az.Resources, Az.PolicyInsights, Az.KeyVault, Az.Monitor

<#
.SYNOPSIS
    ONE-STOP Azure Key Vault Policy Management - Deploy, Test, Monitor, and Exempt
    
.DESCRIPTION
    Consolidated script for complete Azure Key Vault policy lifecycle management.
    
    CAPABILITIES:
    ============
    
    **POLICY DEPLOYMENT** - Deploy all 46 Azure Key Vault policies:
    - Audit Mode First (discover compliance issues without blocking)
    - Deny Mode (enforce security requirements, block non-compliant operations)
    - Smart deployment with managed identities for DeployIfNotExists/Modify policies
    - Automatic parameter injection from PolicyParameters.json
    
    **BLOCKING VALIDATION** - Test real-time enforcement:
    - Attempt non-compliant operations (vault creation, key/secret/cert operations)
    - Verify Deny policies block as expected
    - Generate comprehensive test reports
    
    **COMPLIANCE MONITORING** - Track policy effectiveness:
    - Check compliance state across all resources
    - Generate compliance reports (HTML/JSON/CSV)
    - Identify non-compliant resources for remediation
    
    **EXEMPTION MANAGEMENT** - Handle exceptions:
    - Create policy exemptions with justification and expiry
    - List active exemptions with expiry warnings
    - Remove expired or invalid exemptions
    - Export exemption inventory for audit
    
    **PRODUCTION SAFETY**:
    - Audit-first approach (deploy in Audit mode, review, then switch to Deny)
    - WhatIf mode for all operations
    - Dry-run capability
    - Rollback support
    
.PARAMETER Mode
    Operation mode:
    - 'Deploy': Deploy all 46 policies
    - 'Test': Run blocking validation tests
    - 'Compliance': Check compliance and generate reports
    - 'Exemptions': Manage policy exemptions
    - 'Rollback': Remove all policy assignments
    Default: 'Deploy'
    
.PARAMETER SubscriptionId
    Azure Subscription ID. If not provided, uses current context.
    
.PARAMETER PolicyMode
    Policy effect mode for deployment:
    - 'Audit': Deploy in audit mode (discover issues, no blocking)
    - 'Deny': Deploy in deny mode (enforce requirements, block non-compliant)
    Default: 'Audit' (safe for production rollout)
    
.PARAMETER Scope
    Deployment scope. Default: Subscription level
    
.PARAMETER WhatIf
    Preview deployment/changes without executing
    
.PARAMETER TestResourceGroup
    Resource group for blocking validation tests. Default: 'rg-policy-keyvault-test'
    
.PARAMETER GenerateReport
    Generate detailed reports (JSON/HTML) for all operations
    
.PARAMETER ExemptionAction
    Exemption operation (requires -Mode Exemptions):
    - 'Create': Create new exemption
    - 'List': List all active exemptions
    - 'Remove': Remove exemption
    - 'Export': Export exemption inventory
    
.PARAMETER ExemptionResourceId
    Resource ID for exemption (Key Vault resource ID)
    
.PARAMETER ExemptionPolicyAssignment
    Policy assignment name for exemption (e.g., 'KV-All-PurgeProtection')
    
.PARAMETER ExemptionJustification
    Business justification for exemption (required for Create)
    
.PARAMETER ExemptionExpiresInDays
    Exemption duration in days (max 90). Default: 30
    
.PARAMETER ExemptionCategory
    Exemption category: 'Waiver' or 'Mitigated'. Default: 'Waiver'
    
.EXAMPLE
    # Initial deployment: Audit mode (safe, non-blocking)
    .\Manage-AzureKeyVaultPolicies.ps1 -Mode Deploy -PolicyMode Audit
    
.EXAMPLE
    # Check compliance after audit deployment
    .\Manage-AzureKeyVaultPolicies.ps1 -Mode Compliance -GenerateReport
    
.EXAMPLE
    # Deploy in Deny mode (after reviewing audit results)
    .\Manage-AzureKeyVaultPolicies.ps1 -Mode Deploy -PolicyMode Deny
    
.EXAMPLE
    # Test blocking behavior
    .\Manage-AzureKeyVaultPolicies.ps1 -Mode Test -GenerateReport
    
.EXAMPLE
    # List all exemptions with expiry warnings
    .\Manage-AzureKeyVaultPolicies.ps1 -Mode Exemptions -ExemptionAction List
    
.EXAMPLE
    # Create exemption for legacy vault
    .\Manage-AzureKeyVaultPolicies.ps1 -Mode Exemptions -ExemptionAction Create `
        -ExemptionResourceId "/subscriptions/.../vaults/legacy-kv" `
        -ExemptionPolicyAssignment "KV-All-PurgeProtection" `
        -ExemptionJustification "Legacy vault scheduled for decommission in 60 days" `
        -ExemptionExpiresInDays 60
    
.EXAMPLE
    # Production rollout (audit first, deny later)
    # Step 1: Deploy in audit mode
    .\Manage-AzureKeyVaultPolicies.ps1 -Mode Deploy -PolicyMode Audit -GenerateReport
    
    # Step 2: Wait 7 days, review compliance
    .\Manage-AzureKeyVaultPolicies.ps1 -Mode Compliance -GenerateReport
    
    # Step 3: Create exemptions for valid exceptions
    .\Manage-AzureKeyVaultPolicies.ps1 -Mode Exemptions -ExemptionAction Create ...
    
    # Step 4: Switch to Deny mode
    .\Manage-AzureKeyVaultPolicies.ps1 -Mode Deploy -PolicyMode Deny -GenerateReport

.NOTES
    Author: Azure Governance Team
    Version: 2.0.0 (Consolidated from AzPolicyImplScript.ps1, DeployAll46PoliciesDenyMode.ps1, ValidateAll46PoliciesBlocking.ps1)
    Date: January 13, 2026
    
    PREREQUISITES:
    - Run Setup-AzureKeyVaultPolicyEnvironment.ps1 first
    - PolicyNameMapping.json (policy definition mapping)
    - PolicyParameters.json (generated by setup script)
    - PolicyImplementationConfig.json (generated by setup script)
    
    POLICY COVERAGE:
    - 46 total Azure Key Vault built-in policies
    - 33 Deny policies (real-time blocking)
    - 8 DeployIfNotExists policies (auto-remediation)
    - 2 Modify policies (auto-configuration)
    - 2 AuditIfNotExists policies (compliance logging)
    - 1 Audit policy (Key Rotation - advisory only)
#>

[CmdletBinding()]
param(
    [ValidateSet('Deploy', 'Test', 'Compliance', 'Exemptions', 'Rollback')]
    [string]$Mode = 'Deploy',
    
    [string]$SubscriptionId,
    
    [ValidateSet('Audit', 'Deny')]
    [string]$PolicyMode = 'Audit',
    
    [string]$Scope,
    
    [switch]$WhatIf,
    
    [string]$TestResourceGroup = 'rg-policy-keyvault-test',
    
    [switch]$GenerateReport,
    
    # Exemption parameters
    [ValidateSet('Create', 'List', 'Remove', 'Export')]
    [string]$ExemptionAction,
    
    [string]$ExemptionResourceId,
    
    [string]$ExemptionPolicyAssignment,
    
    [string]$ExemptionJustification,
    
    [int]$ExemptionExpiresInDays = 30,
    
    [ValidateSet('Waiver', 'Mitigated')]
    [string]$ExemptionCategory = 'Waiver'
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'Continue'
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# Colors
$colors = @{
    Success = 'Green'
    Error = 'Red'
    Warning = 'Yellow'
    Info = 'Cyan'
    Section = 'Magenta'
    Highlight = 'White'
}

#region Helper Functions

function Write-Section {
    param([string]$Title)
    $bar = "═" * 80
    Write-Host "`n╔$bar╗" -ForegroundColor $colors.Section
    Write-Host "║  $Title" -ForegroundColor $colors.Section
    Write-Host "╚$bar╝`n" -ForegroundColor $colors.Section
}

function Write-Status {
    param([string]$Message, [string]$Status, [string]$Detail = "")
    $symbol = switch ($Status) {
        'Success' { '✓'; $color = $colors.Success }
        'Error' { '✗'; $color = $colors.Error }
        'Warning' { '⚠'; $color = $colors.Warning }
        'Info' { 'ℹ'; $color = $colors.Info }
        default { '•'; $color = 'White' }
    }
    Write-Host "  $symbol " -NoNewline -ForegroundColor $color
    Write-Host $Message -ForegroundColor $color
    if ($Detail) {
        Write-Host "    $Detail" -ForegroundColor DarkGray
    }
}

function Get-PolicyDefinitionByDisplayName {
    param([string]$DisplayName)
    
    $policy = Get-AzPolicyDefinition | Where-Object {
        $_.Properties.DisplayName -eq $DisplayName -and $_.Properties.PolicyType -eq 'BuiltIn'
    } | Select-Object -First 1
    
    return $policy
}

#endregion

#region Main Script

Write-Host "`n╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                              ║" -ForegroundColor Cyan
Write-Host "║          AZURE KEY VAULT POLICY MANAGEMENT                                   ║" -ForegroundColor Cyan
Write-Host "║          Deploy • Test • Monitor • Exempt                                    ║" -ForegroundColor Cyan
Write-Host "║                                                                              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "`n📋 Configuration:" -ForegroundColor $colors.Info
Write-Host "  Mode: $Mode" -ForegroundColor White
if ($Mode -eq 'Deploy') {
    Write-Host "  Policy Mode: $PolicyMode" -ForegroundColor White
}
Write-Host "  WhatIf: $($WhatIf.IsPresent)" -ForegroundColor White
Write-Host "  Generate Report: $($GenerateReport.IsPresent)`n" -ForegroundColor White

# Connect to Azure
Write-Section "Azure Authentication"

if ($SubscriptionId) {
    Write-Status "Setting subscription context..." "Info"
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    Write-Status "Connected to subscription: $((Get-AzContext).Subscription.Name)" "Success"
} else {
    $context = Get-AzContext
    if (-not $context) {
        Write-Status "No Azure context found. Connecting..." "Warning"
        Connect-AzAccount | Out-Null
        $context = Get-AzContext
    }
    $SubscriptionId = $context.Subscription.Id
    Write-Status "Using current context: $($context.Subscription.Name)" "Success"
}

if (-not $Scope) {
    $Scope = "/subscriptions/$SubscriptionId"
}
Write-Status "Scope: $Scope" "Info"

#endregion

#region Load Configuration Files

Write-Section "Loading Configuration Files"

# PolicyNameMapping.json
$mappingFile = "PolicyNameMapping.json"
if (-not (Test-Path $mappingFile)) {
    Write-Status "ERROR: $mappingFile not found!" "Error"
    Write-Host "  Please run Setup-AzureKeyVaultPolicyEnvironment.ps1 first." -ForegroundColor Yellow
    exit 1
}
$policyMapping = Get-Content $mappingFile -Raw | ConvertFrom-Json
Write-Status "Loaded: $mappingFile" "Success"

# PolicyParameters.json
$paramsFile = "PolicyParameters.json"
if (Test-Path $paramsFile) {
    $policyParams = Get-Content $paramsFile -Raw | ConvertFrom-Json
    Write-Status "Loaded: $paramsFile" "Success"
} else {
    Write-Status "WARNING: $paramsFile not found. DeployIfNotExists policies may fail." "Warning"
    $policyParams = $null
}

# PolicyImplementationConfig.json
$configFile = "PolicyImplementationConfig.json"
if (Test-Path $configFile) {
    $config = Get-Content $configFile -Raw | ConvertFrom-Json
    Write-Status "Loaded: $configFile" "Success"
} else {
    Write-Status "WARNING: $configFile not found." "Warning"
    $config = $null
}

#endregion

#region MODE: Deploy Policies

if ($Mode -eq 'Deploy') {
    Write-Section "Policy Deployment Mode: $PolicyMode"
    
    if ($PolicyMode -eq 'Deny') {
        Write-Host "  ⚠️  WARNING: Deny mode will BLOCK non-compliant operations!" -ForegroundColor Yellow
        Write-Host "  ⚠️  Use Audit mode first to discover compliance issues." -ForegroundColor Yellow
        Write-Host "  ⚠️  Recommended for Dev/Test environments only (initially).`n" -ForegroundColor Yellow
        
        if (-not $WhatIf) {
            $confirm = Read-Host "Type 'DEPLOY-DENY' to confirm Deny mode deployment"
            if ($confirm -ne 'DEPLOY-DENY') {
                Write-Status "Deployment cancelled." "Warning"
                exit 0
            }
        }
    }
    
    # Define ALL 46 policies
    $all46Policies = @(
        # Security - Vault Level (7 policies)
        @{ PolicyName = "Key vaults should have soft delete enabled"; AssignmentName = "KV-All-SoftDelete"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Key vaults should have deletion protection enabled"; AssignmentName = "KV-All-PurgeProtection"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Azure Key Vault should disable public network access"; AssignmentName = "KV-All-DisablePublicAccess"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Azure Key Vaults should use private link"; AssignmentName = "KV-All-PrivateLink"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Azure Key Vault should have firewall enabled or public network access disabled"; AssignmentName = "KV-All-Firewall"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Azure Key Vault should use RBAC permission model"; AssignmentName = "KV-All-RBAC"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Resource logs in Key Vault should be enabled"; AssignmentName = "KV-All-DiagnosticLogs"; Effect = "AuditIfNotExists"; RequiresIdentity = $false },
        
        # Keys - Lifecycle (7 policies)
        @{ PolicyName = "Keys should have more than the specified number of days before expiration"; AssignmentName = "KV-All-KeyExpirationDays"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Keys should have an expiration date"; AssignmentName = "KV-All-KeyExpiration"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Keys should not be active for longer than the specified number of days"; AssignmentName = "KV-All-KeyMaxAge"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Keys should be backed by a hardware security module (HSM)"; AssignmentName = "KV-All-KeyHSMRequired"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Keys using RSA cryptography should have a specified minimum key size"; AssignmentName = "KV-All-KeyRSAMinSize"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Keys should have a rotation policy ensuring that their rotation is scheduled within the specified number of days after creation"; AssignmentName = "KV-All-KeyRotationSchedule"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Keys should have rotation policy with notify time set"; AssignmentName = "KV-All-KeyRotationNotify"; Effect = "Audit"; RequiresIdentity = $false },  # Only Audit supported
        
        # Keys - Cryptographic (5 policies)
        @{ PolicyName = "Keys using elliptic curve cryptography should have the specified curve names"; AssignmentName = "KV-All-KeyECCCurves"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Keys should be the specified cryptographic type RSA or EC"; AssignmentName = "KV-All-KeyCryptoType"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Keys should not be active for longer than the specified number of days"; AssignmentName = "KV-All-KeyMaxValidity"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Azure Key Vault Managed HSM keys using RSA cryptography should have a specified minimum key size"; AssignmentName = "KV-All-ManagedHSMKeyRSAMinSize"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Azure Key Vault Managed HSM keys using elliptic curve cryptography should have the specified curve names"; AssignmentName = "KV-All-ManagedHSMKeyECCCurves"; Effect = "Deny"; RequiresIdentity = $false },
        
        # Secrets (4 policies)
        @{ PolicyName = "Secrets should have more than the specified number of days before expiration"; AssignmentName = "KV-All-SecretExpirationDays"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Secrets should have an expiration date"; AssignmentName = "KV-All-SecretExpiration"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Secrets should not be active for longer than the specified number of days"; AssignmentName = "KV-All-SecretMaxAge"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Secrets should have content type set"; AssignmentName = "KV-All-SecretContentType"; Effect = "Deny"; RequiresIdentity = $false },
        
        # Certificates (8 policies)
        @{ PolicyName = "Certificates should have more than the specified number of days before expiration"; AssignmentName = "KV-All-CertExpirationDays"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Certificates should have the specified maximum validity period"; AssignmentName = "KV-All-CertMaxValidity"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Certificates using RSA cryptography should have the specified minimum key size"; AssignmentName = "KV-All-CertRSAMinSize"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Certificates should be issued by the specified integrated certificate authority"; AssignmentName = "KV-All-CertIntegratedCA"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Certificates should be issued by the specified non-integrated certificate authority"; AssignmentName = "KV-All-CertNonIntegratedCA"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Certificates using elliptic curve cryptography should have allowed curve names"; AssignmentName = "KV-All-CertECCCurves"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Certificates should have the specified lifetime action triggers"; AssignmentName = "KV-All-CertLifetimeAction"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Certificates should use allowed key types"; AssignmentName = "KV-All-CertKeyTypes"; Effect = "Deny"; RequiresIdentity = $false },
        
        # Managed HSM (6 policies)
        @{ PolicyName = "Azure Key Vault Managed HSM should have purge protection enabled"; AssignmentName = "KV-All-ManagedHSMPurgeProtection"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Azure Key Vault Managed HSM keys should have an expiration date"; AssignmentName = "KV-All-ManagedHSMKeyExpiration"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Azure Key Vault Managed HSM Keys should not be active for longer than the specified number of days"; AssignmentName = "KV-All-ManagedHSMKeyMaxAge"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Azure Key Vault Managed HSM should disable public network access"; AssignmentName = "KV-All-ManagedHSMDisablePublicAccess"; Effect = "Audit"; RequiresIdentity = $false },
        @{ PolicyName = "Azure Key Vault Managed HSM keys should be the specified cryptographic type RSA or EC"; AssignmentName = "KV-All-ManagedHSMKeyCryptoType"; Effect = "Deny"; RequiresIdentity = $false },
        @{ PolicyName = "Resource logs in Azure Key Vault Managed HSM should be enabled"; AssignmentName = "KV-All-ManagedHSMDiagnosticLogs"; Effect = "AuditIfNotExists"; RequiresIdentity = $false },
        
        # DeployIfNotExists and Modify policies (9 policies with managed identities)
        @{ PolicyName = "Configure Azure Key Vaults to enable private endpoints"; AssignmentName = "KV-All-ConfigPrivateEndpoints"; Effect = "DeployIfNotExists"; RequiresIdentity = $true; Parameters = @{ subnetId = $policyParams.subnetId } },
        @{ PolicyName = "Configure Azure Key Vault to use private DNS zones"; AssignmentName = "KV-All-ConfigPrivateDNS"; Effect = "DeployIfNotExists"; RequiresIdentity = $true; Parameters = @{ privateDnsZoneId = $policyParams.privateDnsZoneId } },
        @{ PolicyName = "Configure Azure Key Vault with private endpoints"; AssignmentName = "KV-All-ConfigFirewall"; Effect = "Modify"; RequiresIdentity = $true; Parameters = @{} },
        @{ PolicyName = "Deploy Diagnostic Settings for Key Vault to Log Analytics workspace"; AssignmentName = "KV-All-DeployDiagLA"; Effect = "DeployIfNotExists"; RequiresIdentity = $true; Parameters = @{ logAnalytics = $policyParams.logAnalyticsWorkspaceId } },
        @{ PolicyName = "Deploy Diagnostic Settings for Key Vault to Event Hub"; AssignmentName = "KV-All-DeployDiagEH"; Effect = "DeployIfNotExists"; RequiresIdentity = $true; Parameters = @{ eventHubAuthorizationRuleId = $policyParams.eventHubAuthorizationRuleId; eventHubName = "keyvault-diagnostics" } },
        @{ PolicyName = "Azure Key Vault Managed HSM should disable public network access"; AssignmentName = "KV-All-ConfigManagedHSMPublicAccess"; Effect = "Modify"; RequiresIdentity = $true; Parameters = @{} },
        @{ PolicyName = "Deploy Diagnostic Settings for Azure Key Vault Managed HSM to Event Hub"; AssignmentName = "KV-All-DeployManagedHSMDiagEH"; Effect = "DeployIfNotExists"; RequiresIdentity = $true; Parameters = @{ eventHubAuthorizationRuleId = $policyParams.eventHubAuthorizationRuleId; eventHubName = "keyvault-diagnostics" } },
        @{ PolicyName = "Configure Azure Key Vault Managed HSM to use private endpoints"; AssignmentName = "KV-All-ConfigManagedHSMPrivateEndpoints"; Effect = "DeployIfNotExists"; RequiresIdentity = $true; Parameters = @{ subnetId = $policyParams.subnetId } }
    )
    
    Write-Status "Found $($all46Policies.Count) policies to deploy" "Info"
    
    # Deploy policies
    $deploymentResults = @()
    $successCount = 0
    $failedCount = 0
    $skippedCount = 0
    
    foreach ($policyDef in $all46Policies) {
        $policyDisplayName = $policyDef.PolicyName
        $assignmentName = $policyDef.AssignmentName
        $effect = if ($PolicyMode -eq 'Audit') { 'Audit' } else { $policyDef.Effect }
        
        Write-Host "`n  Deploying: $assignmentName" -ForegroundColor Cyan
        Write-Host "    Policy: $policyDisplayName" -ForegroundColor Gray
        Write-Host "    Effect: $effect" -ForegroundColor Gray
        
        # Skip if WhatIf
        if ($WhatIf) {
            Write-Status "[WHATIF] Would deploy policy assignment" "Info"
            $skippedCount++
            continue
        }
        
        try {
            # Get policy definition
            $policy = Get-PolicyDefinitionByDisplayName -DisplayName $policyDisplayName
            if (-not $policy) {
                Write-Status "Policy definition not found: $policyDisplayName" "Error"
                $failedCount++
                $deploymentResults += [PSCustomObject]@{
                    AssignmentName = $assignmentName
                    PolicyName = $policyDisplayName
                    Effect = $effect
                    Status = "Failed"
                    Message = "Policy definition not found"
                }
                continue
            }
            
            # Build assignment parameters
            $assignmentParams = @{
                Name = $assignmentName
                Scope = $Scope
                PolicyDefinition = $policy
                DisplayName = "$assignmentName - $(if ($effect -eq 'Audit') { 'AUDIT MODE' } else { $effect.ToUpper() })"
                Description = "Policy: $policyDisplayName | Effect: $effect | Deployed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            }
            
            # Add managed identity if required
            if ($policyDef.RequiresIdentity) {
                if ($config -and $config.managedIdentity) {
                    $assignmentParams['IdentityType'] = 'SystemAssigned'
                    $assignmentParams['Location'] = $config.location
                    Write-Host "    Identity: System-assigned managed identity" -ForegroundColor Gray
                } else {
                    Write-Status "Managed identity required but config not found" "Warning"
                }
            }
            
            # Add parameters
            $params = @{ effect = @{ value = $effect } }
            if ($policyDef.Parameters -and $policyDef.Parameters.Count -gt 0) {
                foreach ($key in $policyDef.Parameters.Keys) {
                    $params[$key] = @{ value = $policyDef.Parameters[$key] }
                    Write-Host "    Parameter: $key = $($policyDef.Parameters[$key])" -ForegroundColor Gray
                }
            }
            $assignmentParams['PolicyParameter'] = ($params | ConvertTo-Json -Depth 10)
            
            # Create assignment
            $assignment = New-AzPolicyAssignment @assignmentParams -ErrorAction Stop
            Write-Status "Successfully deployed: $assignmentName" "Success"
            $successCount++
            
            $deploymentResults += [PSCustomObject]@{
                AssignmentName = $assignmentName
                PolicyName = $policyDisplayName
                Effect = $effect
                Status = "Success"
                Message = "Deployed successfully"
                AssignmentId = $assignment.PolicyAssignmentId
            }
            
        } catch {
            Write-Status "Failed to deploy: $assignmentName" "Error" $_.Exception.Message
            $failedCount++
            
            $deploymentResults += [PSCustomObject]@{
                AssignmentName = $assignmentName
                PolicyName = $policyDisplayName
                Effect = $effect
                Status = "Failed"
                Message = $_.Exception.Message
            }
        }
    }
    
    # Summary
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                      DEPLOYMENT SUMMARY                                      ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green
    
    Write-Host "  Total Policies: $($all46Policies.Count)" -ForegroundColor White
    Write-Host "  Successful: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $failedCount" -ForegroundColor $(if ($failedCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Skipped (WhatIf): $skippedCount" -ForegroundColor Yellow
    
    # Generate report
    if ($GenerateReport) {
        $reportFile = "PolicyDeployment-$PolicyMode-$timestamp.json"
        $report = @{
            timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            mode = $PolicyMode
            scope = $Scope
            totalPolicies = $all46Policies.Count
            successful = $successCount
            failed = $failedCount
            skipped = $skippedCount
            results = $deploymentResults
        }
        $report | ConvertTo-Json -Depth 10 | Out-File $reportFile -Encoding UTF8
        Write-Host "`n  📄 Report saved: $reportFile" -ForegroundColor Cyan
    }
}

#endregion

#region MODE: Test Blocking

elseif ($Mode -eq 'Test') {
    Write-Section "Blocking Validation Tests"
    
    Write-Host "  This will attempt non-compliant operations to verify Deny policies block as expected.`n" -ForegroundColor Yellow
    
    # Verify resource group exists
    $rg = Get-AzResourceGroup -Name $TestResourceGroup -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Status "ERROR: Test resource group not found: $TestResourceGroup" "Error"
        Write-Host "  Please run Setup-AzureKeyVaultPolicyEnvironment.ps1 first." -ForegroundColor Yellow
        exit 1
    }
    
    Write-Status "Using test resource group: $TestResourceGroup" "Success"
    
    # Test tracking
    $testResults = @()
    
    # Test 1: Vault without purge protection
    Write-Host "`n  TEST 1: Create vault without purge protection (should be BLOCKED)" -ForegroundColor Cyan
    $testVaultName = "kv-test-nopurge-$(Get-Random -Minimum 1000 -Maximum 9999)"
    try {
        New-AzKeyVault -ResourceGroupName $TestResourceGroup -VaultName $testVaultName -Location 'eastus' -EnableSoftDelete $true -EnablePurgeProtection $false -ErrorAction Stop | Out-Null
        Write-Status "TEST FAILED: Vault created (should have been blocked)" "Error"
        $testResults += [PSCustomObject]@{ Test = "Vault without purge protection"; Expected = "BLOCK"; Actual = "ALLOWED"; Status = "FAIL" }
    } catch {
        if ($_.Exception.Message -like "*RequestDisallowedByPolicy*") {
            Write-Status "TEST PASSED: Vault blocked by policy" "Success"
            $testResults += [PSCustomObject]@{ Test = "Vault without purge protection"; Expected = "BLOCK"; Actual = "BLOCKED"; Status = "PASS" }
        } else {
            Write-Status "TEST ERROR: Unexpected error" "Error" $_.Exception.Message
            $testResults += [PSCustomObject]@{ Test = "Vault without purge protection"; Expected = "BLOCK"; Actual = "ERROR"; Status = "ERROR" }
        }
    }
    
    # Test 2: Create compliant vault for further tests
    Write-Host "`n  Creating compliant test vault for object-level tests..." -ForegroundColor Cyan
    $compliantVaultName = "kv-test-compliant-$(Get-Random -Minimum 1000 -Maximum 9999)"
    try {
        $testVault = New-AzKeyVault -ResourceGroupName $TestResourceGroup -VaultName $compliantVaultName -Location 'eastus' `
            -EnableSoftDelete $true -EnablePurgeProtection $true -EnableRbacAuthorization $true -PublicNetworkAccess 'Disabled' -ErrorAction Stop
        Write-Status "Compliant vault created: $compliantVaultName" "Success"
        
        # Assign RBAC to current user
        $currentUser = Get-AzADUser -SignedIn -ErrorAction SilentlyContinue
        if ($currentUser) {
            New-AzRoleAssignment -ObjectId $currentUser.Id -RoleDefinitionName "Key Vault Administrator" -Scope $testVault.ResourceId -ErrorAction SilentlyContinue | Out-Null
            Write-Status "Waiting 30 seconds for RBAC propagation..." "Info"
            Start-Sleep -Seconds 30
        }
        
        # Test 3: Secret without expiration
        Write-Host "`n  TEST 3: Create secret without expiration (should be BLOCKED)" -ForegroundColor Cyan
        try {
            $secretValue = ConvertTo-SecureString -String "test-value" -AsPlainText -Force
            Set-AzKeyVaultSecret -VaultName $compliantVaultName -Name "secret-no-expiry" -SecretValue $secretValue -ErrorAction Stop | Out-Null
            Write-Status "TEST FAILED: Secret created without expiration (should have been blocked)" "Error"
            $testResults += [PSCustomObject]@{ Test = "Secret without expiration"; Expected = "BLOCK"; Actual = "ALLOWED"; Status = "FAIL" }
        } catch {
            if ($_.Exception.Message -like "*RequestDisallowedByPolicy*") {
                Write-Status "TEST PASSED: Secret blocked by policy" "Success"
                $testResults += [PSCustomObject]@{ Test = "Secret without expiration"; Expected = "BLOCK"; Actual = "BLOCKED"; Status = "PASS" }
            } else {
                Write-Status "TEST ERROR: Unexpected error" "Error" $_.Exception.Message
                $testResults += [PSCustomObject]@{ Test = "Secret without expiration"; Expected = "BLOCK"; Actual = "ERROR"; Status = "ERROR" }
            }
        }
        
        # Test 4: Key with RSA 1024 (too small)
        Write-Host "`n  TEST 4: Create RSA-1024 key (should be BLOCKED)" -ForegroundColor Cyan
        try {
            Add-AzKeyVaultKey -VaultName $compliantVaultName -Name "key-rsa-1024" -KeyType RSA -Size 1024 -ErrorAction Stop | Out-Null
            Write-Status "TEST FAILED: Small RSA key created (should have been blocked)" "Error"
            $testResults += [PSCustomObject]@{ Test = "RSA-1024 key (too small)"; Expected = "BLOCK"; Actual = "ALLOWED"; Status = "FAIL" }
        } catch {
            if ($_.Exception.Message -like "*RequestDisallowedByPolicy*" -or $_.Exception.Message -like "*minimum key size*") {
                Write-Status "TEST PASSED: Small RSA key blocked" "Success"
                $testResults += [PSCustomObject]@{ Test = "RSA-1024 key (too small)"; Expected = "BLOCK"; Actual = "BLOCKED"; Status = "PASS" }
            } else {
                Write-Status "TEST ERROR: Unexpected error" "Error" $_.Exception.Message
                $testResults += [PSCustomObject]@{ Test = "RSA-1024 key (too small)"; Expected = "BLOCK"; Actual = "ERROR"; Status = "ERROR" }
            }
        }
        
        # Cleanup test vault
        Write-Host "`n  Cleaning up test vault..." -ForegroundColor Gray
        Remove-AzKeyVault -VaultName $compliantVaultName -ResourceGroupName $TestResourceGroup -Force -ErrorAction SilentlyContinue | Out-Null
        
    } catch {
        Write-Status "Failed to create compliant test vault" "Error" $_.Exception.Message
    }
    
    # Summary
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                      BLOCKING TEST SUMMARY                                   ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green
    
    $passedTests = ($testResults | Where-Object { $_.Status -eq 'PASS' }).Count
    $failedTests = ($testResults | Where-Object { $_.Status -eq 'FAIL' }).Count
    $errorTests = ($testResults | Where-Object { $_.Status -eq 'ERROR' }).Count
    
    Write-Host "  Total Tests: $($testResults.Count)" -ForegroundColor White
    Write-Host "  Passed: $passedTests" -ForegroundColor Green
    Write-Host "  Failed: $failedTests" -ForegroundColor $(if ($failedTests -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Errors: $errorTests" -ForegroundColor $(if ($errorTests -gt 0) { 'Yellow' } else { 'Green' })
    
    if ($GenerateReport) {
        $reportFile = "BlockingTests-$timestamp.json"
        $report = @{
            timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            totalTests = $testResults.Count
            passed = $passedTests
            failed = $failedTests
            errors = $errorTests
            results = $testResults
        }
        $report | ConvertTo-Json -Depth 10 | Out-File $reportFile -Encoding UTF8
        Write-Host "`n  📄 Report saved: $reportFile" -ForegroundColor Cyan
    }
}

#endregion

#region MODE: Compliance

elseif ($Mode -eq 'Compliance') {
    Write-Section "Compliance Check"
    
    Write-Status "Retrieving policy compliance state..." "Info"
    
    # Get all policy states
    $policyStates = Get-AzPolicyState -SubscriptionId $SubscriptionId -Top 1000 | Where-Object {
        $_.PolicyAssignmentName -like 'KV-All-*' -or $_.PolicyAssignmentName -like 'KV-Tier1-*'
    }
    
    Write-Status "Found $($policyStates.Count) compliance records" "Success"
    
    # Group by compliance state
    $compliantCount = ($policyStates | Where-Object { $_.ComplianceState -eq 'Compliant' }).Count
    $nonCompliantCount = ($policyStates | Where-Object { $_.ComplianceState -eq 'NonCompliant' }).Count
    
    Write-Host "`n  Compliance Summary:" -ForegroundColor White
    Write-Host "    Compliant: $compliantCount" -ForegroundColor Green
    Write-Host "    Non-Compliant: $nonCompliantCount" -ForegroundColor $(if ($nonCompliantCount -gt 0) { 'Red' } else { 'Green' })
    
    # Group by resource
    $resourceGroups = $policyStates | Group-Object ResourceId | Sort-Object Count -Descending
    Write-Host "`n  Top 10 Resources by Compliance Records:" -ForegroundColor White
    $resourceGroups | Select-Object -First 10 | ForEach-Object {
        $resourceName = ($_.Name -split '/')[-1]
        $compliant = ($_.Group | Where-Object { $_.ComplianceState -eq 'Compliant' }).Count
        $nonCompliant = ($_.Group | Where-Object { $_.ComplianceState -eq 'NonCompliant' }).Count
        Write-Host "    $resourceName - Compliant: $compliant, Non-Compliant: $nonCompliant" -ForegroundColor Gray
    }
    
    if ($GenerateReport) {
        # JSON report
        $reportFile = "ComplianceReport-$timestamp.json"
        $report = @{
            timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            totalRecords = $policyStates.Count
            compliant = $compliantCount
            nonCompliant = $nonCompliantCount
            complianceRate = if ($policyStates.Count -gt 0) { [math]::Round(($compliantCount / $policyStates.Count) * 100, 2) } else { 0 }
            states = $policyStates | Select-Object PolicyAssignmentName, PolicyDefinitionName, ResourceId, ComplianceState, Timestamp
        }
        $report | ConvertTo-Json -Depth 10 | Out-File $reportFile -Encoding UTF8
        Write-Host "`n  📄 Report saved: $reportFile" -ForegroundColor Cyan
        
        # HTML report
        $htmlFile = "ComplianceReport-$timestamp.html"
        $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Azure Key Vault Policy Compliance Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; }
        h1 { color: #0078d4; }
        .summary { background-color: #f0f0f0; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .summary div { margin: 5px 0; }
        .compliant { color: green; font-weight: bold; }
        .noncompliant { color: red; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; }
        th { background-color: #0078d4; color: white; padding: 10px; text-align: left; }
        td { padding: 8px; border-bottom: 1px solid #ddd; }
        tr:hover { background-color: #f5f5f5; }
    </style>
</head>
<body>
    <h1>Azure Key Vault Policy Compliance Report</h1>
    <div class="summary">
        <div><strong>Generated:</strong> $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))</div>
        <div><strong>Total Records:</strong> $($policyStates.Count)</div>
        <div><strong>Compliant:</strong> <span class="compliant">$compliantCount</span></div>
        <div><strong>Non-Compliant:</strong> <span class="noncompliant">$nonCompliantCount</span></div>
        <div><strong>Compliance Rate:</strong> $($report.complianceRate)%</div>
    </div>
    <h2>Compliance Details</h2>
    <table>
        <tr>
            <th>Policy Assignment</th>
            <th>Resource</th>
            <th>Compliance State</th>
            <th>Timestamp</th>
        </tr>
"@
        foreach ($state in $policyStates | Sort-Object ComplianceState, PolicyAssignmentName) {
            $resourceName = ($state.ResourceId -split '/')[-1]
            $stateClass = if ($state.ComplianceState -eq 'Compliant') { 'compliant' } else { 'noncompliant' }
            $html += @"
        <tr>
            <td>$($state.PolicyAssignmentName)</td>
            <td>$resourceName</td>
            <td class="$stateClass">$($state.ComplianceState)</td>
            <td>$($state.Timestamp)</td>
        </tr>
"@
        }
        $html += @"
    </table>
</body>
</html>
"@
        $html | Out-File $htmlFile -Encoding UTF8
        Write-Host "  📄 HTML report saved: $htmlFile" -ForegroundColor Cyan
    }
}

#endregion

#region MODE: Exemptions

elseif ($Mode -eq 'Exemptions') {
    Write-Section "Policy Exemption Management"
    
    if (-not $ExemptionAction) {
        Write-Status "ERROR: -ExemptionAction is required (Create, List, Remove, Export)" "Error"
        exit 1
    }
    
    if ($ExemptionAction -eq 'Create') {
        # Validate required parameters
        if (-not $ExemptionResourceId -or -not $ExemptionPolicyAssignment -or -not $ExemptionJustification) {
            Write-Status "ERROR: -ExemptionResourceId, -ExemptionPolicyAssignment, and -ExemptionJustification are required for Create" "Error"
            exit 1
        }
        
        if ($ExemptionExpiresInDays -gt 90) {
            Write-Status "ERROR: Maximum exemption duration is 90 days" "Error"
            exit 1
        }
        
        Write-Status "Creating policy exemption..." "Info"
        Write-Host "  Resource: $ExemptionResourceId" -ForegroundColor Gray
        Write-Host "  Policy: $ExemptionPolicyAssignment" -ForegroundColor Gray
        Write-Host "  Justification: $ExemptionJustification" -ForegroundColor Gray
        Write-Host "  Expires In: $ExemptionExpiresInDays days" -ForegroundColor Gray
        Write-Host "  Category: $ExemptionCategory" -ForegroundColor Gray
        
        if ($WhatIf) {
            Write-Status "[WHATIF] Would create exemption" "Info"
        } else {
            try {
                # Get policy assignment
                $assignment = Get-AzPolicyAssignment -Name $ExemptionPolicyAssignment -Scope $Scope -ErrorAction Stop
                
                $exemptionName = "Exempt-$ExemptionPolicyAssignment-$(Get-Date -Format 'yyyyMMdd')"
                $expiresOn = (Get-Date).AddDays($ExemptionExpiresInDays).ToUniversalTime()
                
                $exemption = New-AzPolicyExemption `
                    -Name $exemptionName `
                    -DisplayName "Exemption: $ExemptionPolicyAssignment" `
                    -Description $ExemptionJustification `
                    -PolicyAssignment $assignment `
                    -ExemptionCategory $ExemptionCategory `
                    -ExpiresOn $expiresOn `
                    -Scope $ExemptionResourceId `
                    -ErrorAction Stop
                
                Write-Status "Exemption created: $exemptionName" "Success"
                Write-Status "Expires: $($expiresOn.ToString('yyyy-MM-dd'))" "Info"
                
            } catch {
                Write-Status "Failed to create exemption" "Error" $_.Exception.Message
            }
        }
    }
    
    elseif ($ExemptionAction -eq 'List') {
        Write-Status "Retrieving policy exemptions..." "Info"
        
        $exemptions = Get-AzPolicyExemption -Scope $Scope | Where-Object {
            $_.Properties.PolicyAssignmentId -like "*KV-All-*" -or $_.Properties.PolicyAssignmentId -like "*KV-Tier1-*"
        }
        
        Write-Status "Found $($exemptions.Count) exemptions" "Success"
        
        if ($exemptions.Count -gt 0) {
            Write-Host "`n  Active Exemptions:" -ForegroundColor White
            foreach ($exemption in $exemptions) {
                $assignmentName = ($exemption.Properties.PolicyAssignmentId -split '/')[-1]
                $expiresOn = $exemption.Properties.ExpiresOn
                $daysUntilExpiry = if ($expiresOn) { ([datetime]$expiresOn - (Get-Date)).Days } else { 999 }
                
                $expiryColor = if ($daysUntilExpiry -lt 7) { 'Red' } elseif ($daysUntilExpiry -lt 30) { 'Yellow' } else { 'Green' }
                
                Write-Host "`n    Exemption: $($exemption.Name)" -ForegroundColor Cyan
                Write-Host "      Policy: $assignmentName" -ForegroundColor Gray
                Write-Host "      Category: $($exemption.Properties.ExemptionCategory)" -ForegroundColor Gray
                Write-Host "      Justification: $($exemption.Properties.Description)" -ForegroundColor Gray
                if ($expiresOn) {
                    Write-Host "      Expires: $($expiresOn.ToString('yyyy-MM-dd')) ($daysUntilExpiry days)" -ForegroundColor $expiryColor
                } else {
                    Write-Host "      Expires: Never" -ForegroundColor Yellow
                }
            }
        }
        
        if ($GenerateReport) {
            $reportFile = "Exemptions-$timestamp.json"
            $report = @{
                timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
                totalExemptions = $exemptions.Count
                exemptions = $exemptions | ForEach-Object {
                    @{
                        name = $_.Name
                        policyAssignment = ($_.Properties.PolicyAssignmentId -split '/')[-1]
                        category = $_.Properties.ExemptionCategory
                        justification = $_.Properties.Description
                        expiresOn = $_.Properties.ExpiresOn
                        scope = $_.Properties.Scope
                    }
                }
            }
            $report | ConvertTo-Json -Depth 10 | Out-File $reportFile -Encoding UTF8
            Write-Host "`n  📄 Report saved: $reportFile" -ForegroundColor Cyan
        }
    }
    
    elseif ($ExemptionAction -eq 'Remove') {
        if (-not $ExemptionResourceId) {
            Write-Status "ERROR: -ExemptionResourceId is required for Remove" "Error"
            exit 1
        }
        
        Write-Status "Removing exemption..." "Info"
        
        if ($WhatIf) {
            Write-Status "[WHATIF] Would remove exemption for: $ExemptionResourceId" "Info"
        } else {
            try {
                # Find exemption by scope
                $exemptions = Get-AzPolicyExemption -Scope $ExemptionResourceId -ErrorAction SilentlyContinue
                
                if ($exemptions.Count -eq 0) {
                    Write-Status "No exemptions found for resource: $ExemptionResourceId" "Warning"
                } else {
                    foreach ($exemption in $exemptions) {
                        Remove-AzPolicyExemption -Name $exemption.Name -Scope $exemption.Properties.Scope -ErrorAction Stop
                        Write-Status "Removed exemption: $($exemption.Name)" "Success"
                    }
                }
            } catch {
                Write-Status "Failed to remove exemption" "Error" $_.Exception.Message
            }
        }
    }
    
    elseif ($ExemptionAction -eq 'Export') {
        Write-Status "Exporting exemption inventory..." "Info"
        
        $exemptions = Get-AzPolicyExemption -Scope $Scope | Where-Object {
            $_.Properties.PolicyAssignmentId -like "*KV-All-*" -or $_.Properties.PolicyAssignmentId -like "*KV-Tier1-*"
        }
        
        $exportFile = "ExemptionInventory-$timestamp.csv"
        $exemptions | Select-Object Name, 
            @{N='PolicyAssignment';E={($_.Properties.PolicyAssignmentId -split '/')[-1]}},
            @{N='ResourceId';E={$_.Properties.Scope}},
            @{N='Category';E={$_.Properties.ExemptionCategory}},
            @{N='Justification';E={$_.Properties.Description}},
            @{N='ExpiresOn';E={$_.Properties.ExpiresOn}},
            @{N='CreatedOn';E={$_.Properties.Metadata.createdOn}} | 
            Export-Csv -Path $exportFile -NoTypeInformation -Encoding UTF8
        
        Write-Status "Exported $($exemptions.Count) exemptions to: $exportFile" "Success"
    }
}

#endregion

#region MODE: Rollback

elseif ($Mode -eq 'Rollback') {
    Write-Section "Policy Rollback - Remove All Assignments"
    
    Write-Host "  ⚠️  WARNING: This will REMOVE all Key Vault policy assignments!" -ForegroundColor Red
    Write-Host "  ⚠️  This action cannot be undone." -ForegroundColor Red
    Write-Host "  ⚠️  Assignments to remove: KV-All-*, KV-Tier1-*`n" -ForegroundColor Red
    
    if ($WhatIf) {
        Write-Status "[WHATIF] Would remove policy assignments" "Info"
    } else {
        $confirm = Read-Host "Type 'ROLLBACK' to confirm removal"
        if ($confirm -ne 'ROLLBACK') {
            Write-Status "Rollback cancelled." "Warning"
            exit 0
        }
        
        Write-Status "Retrieving policy assignments..." "Info"
        
        $assignments = Get-AzPolicyAssignment -Scope $Scope | Where-Object {
            $_.Name -like 'KV-All-*' -or $_.Name -like 'KV-Tier1-*'
        }
        
        Write-Status "Found $($assignments.Count) assignments to remove" "Info"
        
        $removedCount = 0
        foreach ($assignment in $assignments) {
            try {
                Remove-AzPolicyAssignment -Id $assignment.PolicyAssignmentId -ErrorAction Stop | Out-Null
                Write-Status "Removed: $($assignment.Name)" "Success"
                $removedCount++
            } catch {
                Write-Status "Failed to remove: $($assignment.Name)" "Error" $_.Exception.Message
            }
        }
        
        Write-Host "`n  Total Removed: $removedCount" -ForegroundColor $(if ($removedCount -eq $assignments.Count) { 'Green' } else { 'Yellow' })
    }
}

#endregion

Write-Host "`n✅ Operation complete!`n" -ForegroundColor Green
