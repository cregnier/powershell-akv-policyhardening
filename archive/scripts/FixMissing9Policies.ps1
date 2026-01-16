<#
.SYNOPSIS
Fix deployment of the 9 missing policies with proper parameters and managed identities

.DESCRIPTION
Addresses the 9 failed policies from Phase 3 deployment:
1. DeployIfNotExists policies - Add required parameters (subnet, DNS, workspace, EventHub)
2. Modify policies - Add managed identity
3. Key Rotation Policy - Change from Deny to Audit (only supported effect)

.PARAMETER SubscriptionId
Target subscription ID for policy deployment

.PARAMETER ResourceGroupName
Resource group containing test resources (private endpoint subnet, Log Analytics, etc.)

.PARAMETER CreateTestResources
Create placeholder test resources if they don't exist (for parameter values)

.PARAMETER GenerateReport
Generate deployment report JSON

.EXAMPLE
.\FixMissing9Policies.ps1 -SubscriptionId "xxx" -GenerateReport
.\FixMissing9Policies.ps1 -SubscriptionId "xxx" -CreateTestResources

.NOTES
Author: Azure Governance Team
Version: 1.0.0
Date: January 13, 2026
Purpose: Complete Phase 3 - Deploy all 46 policies (37 + 9 fixes)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-policy-keyvault-test",
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateTestResources,
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateReport
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "FIX MISSING 9 POLICY DEPLOYMENTS" -ForegroundColor Cyan
Write-Host "Phase 3 - Complete All 46 Policies" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Set Azure context
Write-Host "Setting Azure context..." -ForegroundColor Yellow
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
$context = Get-AzContext
$scope = "/subscriptions/$SubscriptionId"

Write-Host "✓ Connected to subscription: $($context.Subscription.Name)" -ForegroundColor Green
Write-Host "  ID: $($context.Subscription.Id)" -ForegroundColor Gray
Write-Host "  Resource Group: $ResourceGroupName`n" -ForegroundColor Gray

# Load policy mapping
$mappingFile = "PolicyNameMapping.json"
if (-not (Test-Path $mappingFile)) {
    Write-Host "ERROR: Policy mapping file not found: $mappingFile" -ForegroundColor Red
    exit 1
}

$policyMapping = Get-Content $mappingFile -Raw | ConvertFrom-Json

# ====================================
# Step 1: Get/Create Required Resources
# ====================================

Write-Host "=== Step 1: Gathering Required Resources ===" -ForegroundColor Cyan

# Get current user for managed identity
$signedInUser = Get-AzADUser -SignedIn -ErrorAction SilentlyContinue
if (-not $signedInUser) {
    Write-Host "⚠ Could not get signed-in user. Managed identity will use subscription context." -ForegroundColor Yellow
}

# Check if resource group exists
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    if ($CreateTestResources) {
        Write-Host "Creating resource group: $ResourceGroupName..." -ForegroundColor Yellow
        $rg = New-AzResourceGroup -Name $ResourceGroupName -Location "eastus"
        Write-Host "✓ Resource group created" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Resource group not found: $ResourceGroupName" -ForegroundColor Red
        Write-Host "Run with -CreateTestResources to create it." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "✓ Resource group found: $ResourceGroupName" -ForegroundColor Green
}

$location = $rg.Location

# Get or create VNet and Subnet for Private Endpoints
Write-Host "`nChecking for private endpoint subnet..." -ForegroundColor Yellow
$vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $vnet) {
    if ($CreateTestResources) {
        Write-Host "Creating VNet for private endpoints..." -ForegroundColor Yellow
        $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name "snet-privateendpoints" -AddressPrefix "10.0.1.0/24"
        $vnet = New-AzVirtualNetwork -Name "vnet-policy-test" -ResourceGroupName $ResourceGroupName -Location $location -AddressPrefix "10.0.0.0/16" -Subnet $subnetConfig
        Write-Host "✓ VNet created: $($vnet.Name)" -ForegroundColor Green
    } else {
        Write-Host "⚠ No VNet found. Private endpoint policies will use placeholder." -ForegroundColor Yellow
        $privateEndpointSubnetId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/virtualNetworks/vnet-placeholder/subnets/snet-privateendpoints"
    }
}

if ($vnet) {
    $subnet = $vnet.Subnets | Where-Object { $_.Name -like "*private*" -or $_.Name -like "*endpoint*" } | Select-Object -First 1
    if (-not $subnet) { $subnet = $vnet.Subnets[0] }
    $privateEndpointSubnetId = $subnet.Id
    Write-Host "✓ Using subnet: $($subnet.Name)" -ForegroundColor Green
    Write-Host "  ID: $privateEndpointSubnetId" -ForegroundColor Gray
}

# Get or create Log Analytics Workspace
Write-Host "`nChecking for Log Analytics workspace..." -ForegroundColor Yellow
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $workspace) {
    if ($CreateTestResources) {
        Write-Host "Creating Log Analytics workspace..." -ForegroundColor Yellow
        $workspaceName = "law-policy-test-$((Get-Random -Minimum 1000 -Maximum 9999))"
        $workspace = New-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $workspaceName -Location $location -Sku "PerGB2018"
        Start-Sleep -Seconds 5  # Allow workspace to initialize
        Write-Host "✓ Workspace created: $($workspace.Name)" -ForegroundColor Green
    } else {
        Write-Host "⚠ No Log Analytics workspace found. Using placeholder." -ForegroundColor Yellow
        $logAnalyticsId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/law-placeholder"
    }
}

if ($workspace) {
    $logAnalyticsId = $workspace.ResourceId
    Write-Host "✓ Using workspace: $($workspace.Name)" -ForegroundColor Green
    Write-Host "  ID: $logAnalyticsId" -ForegroundColor Gray
}

# Get or create Event Hub for diagnostics
Write-Host "`nChecking for Event Hub namespace..." -ForegroundColor Yellow
$ehNamespace = Get-AzEventHubNamespace -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $ehNamespace) {
    if ($CreateTestResources) {
        Write-Host "Creating Event Hub namespace (this may take a few minutes)..." -ForegroundColor Yellow
        $ehNamespaceName = "eh-policy-test-$((Get-Random -Minimum 1000 -Maximum 9999))"
        $ehNamespace = New-AzEventHubNamespace -ResourceGroupName $ResourceGroupName -Name $ehNamespaceName -Location $location -SkuName "Standard"
        
        # Create Event Hub
        $ehName = "keyvault-diagnostics"
        $eventHub = New-AzEventHub -ResourceGroupName $ResourceGroupName -NamespaceName $ehNamespaceName -Name $ehName -RetentionTimeInHour 24
        
        # Create authorization rule
        $authRule = New-AzEventHubAuthorizationRule -ResourceGroupName $ResourceGroupName -NamespaceName $ehNamespaceName -Name "DiagnosticsRule" -Rights @("Listen","Send")
        
        Write-Host "✓ Event Hub created: $ehName" -ForegroundColor Green
    } else {
        Write-Host "⚠ No Event Hub found. Using placeholder." -ForegroundColor Yellow
        $eventHubRuleId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.EventHub/namespaces/eh-placeholder/authorizationRules/DiagnosticsRule"
    }
}

if ($ehNamespace) {
    # Get first event hub and auth rule
    $eventHub = Get-AzEventHub -ResourceGroupName $ResourceGroupName -NamespaceName $ehNamespace.Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $eventHub) {
        try {
            Write-Host "  Creating Event Hub in namespace..." -ForegroundColor Yellow
            $eventHub = New-AzEventHub -ResourceGroupName $ResourceGroupName -NamespaceName $ehNamespace.Name -Name "keyvault-diagnostics" -PartitionCount 2 -ErrorAction Stop
        } catch {
            Write-Host "  ⚠ Event Hub creation failed (may already exist), continuing..." -ForegroundColor Yellow
            $eventHub = Get-AzEventHub -ResourceGroupName $ResourceGroupName -NamespaceName $ehNamespace.Name -ErrorAction SilentlyContinue | Select-Object -First 1
        }
    }
    
    $authRule = Get-AzEventHubAuthorizationRule -ResourceGroupName $ResourceGroupName -NamespaceName $ehNamespace.Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $authRule) {
        $authRule = New-AzEventHubAuthorizationRule -ResourceGroupName $ResourceGroupName -NamespaceName $ehNamespace.Name -Name "DiagnosticsRule" -Rights @("Listen","Send")
    }
    
    $eventHubRuleId = $authRule.Id
    $eventHubName = if ($eventHub) { $eventHub.Name } else { "keyvault-diagnostics" }
    Write-Host "✓ Using Event Hub: $eventHubName" -ForegroundColor Green
    Write-Host "  Rule ID: $eventHubRuleId" -ForegroundColor Gray
}

# Get or create Private DNS Zone
Write-Host "`nChecking for Private DNS zone..." -ForegroundColor Yellow
$dnsZone = Get-AzPrivateDnsZone -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*vault.azure.net" } | Select-Object -First 1

if (-not $dnsZone) {
    if ($CreateTestResources) {
        Write-Host "Creating Private DNS zone for Key Vault..." -ForegroundColor Yellow
        try {
            $dnsZone = New-AzPrivateDnsZone -ResourceGroupName $ResourceGroupName -Name "privatelink.vaultcore.azure.net" -ErrorAction Stop
            Write-Host "✓ DNS zone created: $($dnsZone.Name)" -ForegroundColor Green
        } catch {
            if ($_.Exception.Message -like "*exists already*") {
                Write-Host "  DNS zone already exists, retrieving..." -ForegroundColor Yellow
                $dnsZone = Get-AzPrivateDnsZone -ResourceGroupName $ResourceGroupName -Name "privatelink.vaultcore.azure.net"
            } else {
                throw
            }
        }
    } else {
        Write-Host "⚠ No Private DNS zone found. Using placeholder." -ForegroundColor Yellow
        $privateDnsZoneId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
    }
}

if ($dnsZone) {
    $privateDnsZoneId = $dnsZone.ResourceId
    Write-Host "✓ Using DNS zone: $($dnsZone.Name)" -ForegroundColor Green
    Write-Host "  ID: $privateDnsZoneId" -ForegroundColor Gray
}

Write-Host "`n✓ Resource collection complete`n" -ForegroundColor Green

# ====================================
# Step 2: Define 9 Missing Policies
# ====================================

Write-Host "=== Step 2: Defining 9 Missing Policies ===" -ForegroundColor Cyan

$missing9Policies = @(
    # 1. Configure Private Endpoints (DeployIfNotExists - needs subnet)
    @{
        PolicyName = "Configure Azure Key Vaults with private endpoints"
        AssignmentName = "KV-All-ConfigPrivateEndpoints"
        Effect = "DeployIfNotExists"
        RequiresManagedIdentity = $true
        Parameters = @{
            privateEndpointSubnetId = $privateEndpointSubnetId
        }
    },
    
    # 2. Configure Private DNS (DeployIfNotExists - needs DNS zone)
    @{
        PolicyName = "Configure Azure Key Vaults to use private DNS zones"
        AssignmentName = "KV-All-ConfigPrivateDNS"
        Effect = "DeployIfNotExists"
        RequiresManagedIdentity = $true
        Parameters = @{
            privateDnsZoneId = $privateDnsZoneId
        }
    },
    
    # 3. Configure Firewall (Modify - needs managed identity)
    @{
        PolicyName = "Configure key vaults to enable firewall"
        AssignmentName = "KV-All-ConfigFirewall"
        Effect = "Modify"
        RequiresManagedIdentity = $true
        Parameters = @{}
    },
    
    # 4. Deploy Diagnostics to Log Analytics (DeployIfNotExists - needs workspace)
    @{
        PolicyName = "Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace"
        AssignmentName = "KV-All-DeployDiagLA"
        Effect = "DeployIfNotExists"
        RequiresManagedIdentity = $true
        Parameters = @{
            logAnalytics = $logAnalyticsId
        }
    },
    
    # 5. Deploy Diagnostics to Event Hub (DeployIfNotExists - needs Event Hub)
    @{
        PolicyName = "Deploy Diagnostic Settings for Key Vault to Event Hub"
        AssignmentName = "KV-All-DeployDiagEH"
        Effect = "DeployIfNotExists"
        RequiresManagedIdentity = $true
        Parameters = @{
            eventHubRuleId = $eventHubRuleId
        }
    },
    
    # 6. Deploy Managed HSM Diagnostics to Event Hub (DeployIfNotExists)
    @{
        PolicyName = "Deploy - Configure diagnostic settings to an Event Hub to be enabled on Azure Key Vault Managed HSM"
        AssignmentName = "KV-All-DeployManagedHSMDiagEH"
        Effect = "DeployIfNotExists"
        RequiresManagedIdentity = $true
        Parameters = @{
            eventHubRuleId = $eventHubRuleId
        }
    },
    
    # 7. Configure Managed HSM Public Access (Modify - needs managed identity)
    @{
        PolicyName = "[Preview]: Configure Azure Key Vault Managed HSM to disable public network access"
        AssignmentName = "KV-All-ConfigManagedHSMPublicAccess"
        Effect = "Modify"
        RequiresManagedIdentity = $true
        Parameters = @{}
    },
    
    # 8. Configure Managed HSM Private Endpoints (DeployIfNotExists - needs subnet)
    @{
        PolicyName = "[Preview]: Configure Azure Key Vault Managed HSM with private endpoints"
        AssignmentName = "KV-All-ConfigManagedHSMPrivateEndpoints"
        Effect = "DeployIfNotExists"
        RequiresManagedIdentity = $true
        Parameters = @{
            privateEndpointSubnetId = $privateEndpointSubnetId
        }
    },
    
    # 9. Key Rotation Policy (CHANGE TO AUDIT - Deny not supported)
    @{
        PolicyName = "Keys should have a rotation policy ensuring that their rotation is scheduled within the specified number of days after creation."
        AssignmentName = "KV-All-KeyRotationPolicy"
        Effect = "Audit"  # Changed from Deny (not supported)
        RequiresManagedIdentity = $false
        Parameters = @{
            maximumDaysToRotate = 90
        }
    }
)

Write-Host "Total policies to fix: $($missing9Policies.Count)" -ForegroundColor Cyan
Write-Host "  DeployIfNotExists: $($($missing9Policies | Where-Object { $_.Effect -eq 'DeployIfNotExists' }).Count)" -ForegroundColor Yellow
Write-Host "  Modify: $($($missing9Policies | Where-Object { $_.Effect -eq 'Modify' }).Count)" -ForegroundColor Yellow
Write-Host "  Audit: $($($missing9Policies | Where-Object { $_.Effect -eq 'Audit' }).Count)`n" -ForegroundColor Yellow

# ====================================
# Step 3: Deploy Policies
# ====================================

Write-Host "=== Step 3: Deploying Policies ===" -ForegroundColor Cyan

$deploymentResults = @()
$successCount = 0
$failureCount = 0

foreach ($policyConfig in $missing9Policies) {
    $assignmentName = $policyConfig.AssignmentName
    $policyName = $policyConfig.PolicyName
    $effect = $policyConfig.Effect
    $requiresIdentity = $policyConfig.RequiresManagedIdentity
    
    Write-Host "`n--- Deploying: $assignmentName ---" -ForegroundColor Cyan
    Write-Host "  Policy: $policyName" -ForegroundColor Gray
    Write-Host "  Effect: $effect" -ForegroundColor Yellow
    Write-Host "  Managed Identity: $requiresIdentity" -ForegroundColor Gray
    
    $result = [PSCustomObject]@{
        AssignmentName = $assignmentName
        PolicyName = $policyName
        Effect = $effect
        RequiresManagedIdentity = $requiresIdentity
        Status = "Unknown"
        Message = ""
        PolicyDefinitionId = ""
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    try {
        # Check if assignment already exists
        $existing = Get-AzPolicyAssignment -Name $assignmentName -Scope $scope -ErrorAction SilentlyContinue
        
        if ($existing) {
            Write-Host "  ⚠ Assignment exists. Removing and recreating with managed identity..." -ForegroundColor Yellow
            Remove-AzPolicyAssignment -Id $existing.Id -ErrorAction Stop
            Start-Sleep -Seconds 2
        }
        
        # Lookup policy definition
        $policyDef = $policyMapping.($policyConfig.PolicyName)
        
        if (-not $policyDef) {
            throw "Policy definition not found in mapping: $policyName"
        }
        
        $policyDefId = $policyDef.Id
        $result.PolicyDefinitionId = $policyDefId
        Write-Host "  Policy ID: $policyDefId" -ForegroundColor Gray
        
        # Build parameters
        $params = @{ effect = @{ value = $effect } }
        
        if ($policyConfig.Parameters -and $policyConfig.Parameters.Count -gt 0) {
            foreach ($key in $policyConfig.Parameters.Keys) {
                $value = $policyConfig.Parameters[$key]
                $params[$key] = @{ value = $value }
                Write-Host "  Parameter: $key = $value" -ForegroundColor Gray
            }
        }
        
        # Create assignment (with or without managed identity)
        $assignmentParams = @{
            Name = $assignmentName
            DisplayName = $policyName.Substring(0, [Math]::Min(128, $policyName.Length))
            Scope = $scope
            PolicyDefinition = $policyDefId
            PolicyParameter = ($params | ConvertTo-Json -Depth 10)
        }
        
        if ($requiresIdentity) {
            Write-Host "  Creating with System-Assigned Managed Identity..." -ForegroundColor Yellow
            $assignmentParams['IdentityType'] = 'SystemAssigned'
            $assignmentParams['Location'] = $location
        }
        
        $assignment = New-AzPolicyAssignment @assignmentParams -ErrorAction Stop
        
        $result.Status = "Success"
        $result.Message = "Deployed with effect=$effect" + $(if ($requiresIdentity) { " + Managed Identity" } else { "" })
        $successCount++
        Write-Host "  ✓ Deployment successful" -ForegroundColor Green
        
        if ($requiresIdentity -and $assignment.Identity) {
            Write-Host "  Managed Identity Principal ID: $($assignment.Identity.PrincipalId)" -ForegroundColor Gray
        }
        
    } catch {
        Write-Host "  ✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $result.Status = "Failed"
        $result.Message = $_.Exception.Message
        $failureCount++
    }
    
    $deploymentResults += $result
}

# ====================================
# Summary
# ====================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "DEPLOYMENT SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Policies: $($missing9Policies.Count)" -ForegroundColor White
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failureCount" -ForegroundColor Red
Write-Host "========================================`n" -ForegroundColor Cyan

# Detailed results
$deploymentResults | Format-Table -Property AssignmentName, Effect, Status, Message -AutoSize

# Generate report
if ($GenerateReport -or $failureCount -gt 0) {
    $reportFile = "Missing9PoliciesFix-$timestamp.json"
    
    $report = @{
        DeploymentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Subscription = @{
            Name = $context.Subscription.Name
            Id = $context.Subscription.Id
        }
        Scope = $scope
        ResourceGroupName = $ResourceGroupName
        Resources = @{
            PrivateEndpointSubnet = $privateEndpointSubnetId
            LogAnalyticsWorkspace = $logAnalyticsId
            EventHubRule = $eventHubRuleId
            PrivateDnsZone = $privateDnsZoneId
        }
        TotalPolicies = $missing9Policies.Count
        SuccessCount = $successCount
        FailureCount = $failureCount
        Results = $deploymentResults
    }
    
    $report | ConvertTo-Json -Depth 10 | Out-File $reportFile -Encoding UTF8
    Write-Host "Deployment report saved: $reportFile`n" -ForegroundColor Cyan
}

# Calculate total deployment
Write-Host "=== COMPLETE POLICY DEPLOYMENT STATUS ===" -ForegroundColor Yellow
Write-Host "Previous deployment: 37/46 policies" -ForegroundColor White
Write-Host "This fix: $successCount/9 policies" -ForegroundColor White
Write-Host "TOTAL: $($37 + $successCount)/46 policies deployed" -ForegroundColor $(if (($37 + $successCount) -eq 46) { 'Green' } else { 'Yellow' })
Write-Host "========================================`n" -ForegroundColor Yellow

# Next steps
if ($successCount -gt 0) {
    Write-Host "=== NEXT STEPS ===" -ForegroundColor Cyan
    Write-Host "1. DeployIfNotExists/Modify policies create resources via remediation tasks" -ForegroundColor White
    Write-Host "2. Create remediation tasks for non-compliant resources:" -ForegroundColor White
    Write-Host "   Start-AzPolicyRemediation -PolicyAssignmentName 'KV-All-ConfigPrivateEndpoints' -Name 'PrivateEndpoint-Remediation'" -ForegroundColor Gray
    Write-Host "3. Monitor policy compliance:" -ForegroundColor White
    Write-Host "   Get-AzPolicyState | Where-Object { `$_.PolicyAssignmentName -like 'KV-All-*' } | Group-Object ComplianceState" -ForegroundColor Gray
    Write-Host "4. Re-run blocking validation:" -ForegroundColor White
    Write-Host "   .\ValidateAll46PoliciesBlocking.ps1 -SubscriptionId '$SubscriptionId'`n" -ForegroundColor Gray
}

# Exit code
if ($failureCount -gt 0) {
    Write-Host "Deployment completed with errors." -ForegroundColor Red
    exit 1
} else {
    Write-Host "✓ All 9 policies deployed successfully!" -ForegroundColor Green
    exit 0
}
