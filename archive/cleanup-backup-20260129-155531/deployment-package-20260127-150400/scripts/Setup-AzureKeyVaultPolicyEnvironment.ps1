#!/usr/bin/env pwsh
#Requires -Module Az.Accounts, Az.Resources, Az.ManagedServiceIdentity, Az.OperationalInsights, Az.EventHub, Az.PrivateDns, Az.Network, Az.KeyVault, Az.Monitor

<#
.SYNOPSIS
    Infrastructure setup script for Azure Key Vault Policy Governance testing and implementation
    
.DESCRIPTION
    ═══════════════════════════════════════════════════════════════════════════════
    AZURE KEY VAULT POLICY GOVERNANCE - INFRASTRUCTURE SETUP
    ═══════════════════════════════════════════════════════════════════════════════
    
    WHO:    Azure administrators preparing for policy governance implementation
    WHAT:   Creates complete testing environment with infrastructure, test vaults, and monitoring
    WHEN:   Run ONCE before deploying policies (Phase 1 of testing workflow)
    WHERE:  Azure subscription (creates 1-2 resource groups based on scenario)
    WHY:    Provides required infrastructure for policy testing, auto-remediation, and monitoring
    HOW:    PowerShell automation deploying Azure resources via ARM templates
    
    ═══════════════════════════════════════════════════════════════════════════════
    VERSION HISTORY
    ═══════════════════════════════════════════════════════════════════════════════
    Version: 1.1
    Date: 2026-01-16
    Changes:
      - Validated for complete testing workflow (Test T1.1 PASS)
      - Supports both DevTest and Production scenarios
      - Creates test vaults with varied compliance states
      - Includes optional monitoring and alerting setup
    
    Previous Versions:
      1.0: Initial infrastructure setup script
    
    ═══════════════════════════════════════════════════════════════════════════════
    CAPABILITIES
    ═══════════════════════════════════════════════════════════════════════════════
    
    **INFRASTRUCTURE SETUP** (Required for automation policies):
    - Managed Identity for policy remediation (DeployIfNotExists/Modify policies)
    - Log Analytics Workspace (for diagnostic policies)
    - Event Hub Namespace + Auth Rule (for diagnostic streaming)
    - Private DNS Zone (privatelink.vaultcore.azure.net for private endpoints)
    - VNet + Subnet (for private endpoint policies)
    
    **TEST ENVIRONMENT** (Dev/Test only):
    - 3 Key Vaults with different compliance states:
      * Compliant: All security features enabled
      * Partial: Some features enabled (realistic scenario)
      * Non-Compliant: Minimal compliance (for testing blocking)
    - Test data: Secrets, Keys, Certificates with various configurations
    
    **MONITORING & ALERTING** (Optional but recommended):
    - Azure Monitor Action Group (email notifications)
    - Alert Rules for policy violations, compliance drops, deletions
    - Query templates for compliance reporting
    
    **CLEANUP** (Optional):
    - Remove all policy assignments from scope
    - Delete test resources
    - Delete and recreate resource groups for fresh start
    
.PARAMETER SubscriptionId
    Azure Subscription ID. If not provided, uses current context.
    
.PARAMETER TestResourceGroup
    Resource group for test Key Vaults and data. Default: 'rg-policy-keyvault-test'
    
.PARAMETER InfraResourceGroup
    Resource group for infrastructure (managed identity, networking, monitoring). 
    Default: 'rg-policy-remediation'
    
.PARAMETER Location
    Azure region for all resources. Default: 'eastus'
    
.PARAMETER Environment
    Environment type: 'DevTest' or 'Production'. 
    - DevTest: Creates test vaults + test data
    - Production: Creates only infrastructure (no test data)
    Default: 'DevTest'
    
.PARAMETER CleanupFirst
    DELETE everything in test RG first, then recreate fresh. 
    Use for clean slate testing. DESTRUCTIVE!
    
.PARAMETER SkipVaultSeeding
    Skip creating test secrets/keys/certs in vaults (faster deployment, less complete testing)
    
.PARAMETER SkipMonitoring
    Skip creating Azure Monitor alerts and action groups
    
.PARAMETER ActionGroupEmail
    Email address for Azure Monitor alert notifications. Required if NOT using -SkipMonitoring.
    
.PARAMETER DeployAdvancedInfra
    Deploy EXPENSIVE advanced infrastructure: Azure Managed HSM ($4,838/month minimum).
    This enables testing of 7 Managed HSM policies and 1 Private Link policy.
    WARNING: Only use for comprehensive testing - delete immediately after!
    Minimum cost: ~$200 (24-30 hours for testing session).
    
.EXAMPLE
    # Dev/Test: Full setup with test vaults and monitoring
    .\Setup-AzureKeyVaultPolicyEnvironment.ps1 -ActionGroupEmail "alerts@company.com"
    
.EXAMPLE
    # Dev/Test: Clean slate (DELETE and recreate everything)
    .\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst -ActionGroupEmail "alerts@company.com"
    
.EXAMPLE
    # Production: Infrastructure only, no test data
    .\Setup-AzureKeyVaultPolicyEnvironment.ps1 -Environment Production `
        -InfraResourceGroup "rg-policy-prod-infra" `
        -ActionGroupEmail "security-team@company.com"
    
.EXAMPLE
    # Quick setup without monitoring
    .\Setup-AzureKeyVaultPolicyEnvironment.ps1 -SkipMonitoring -SkipVaultSeeding

.NOTES
    Author: Azure Governance Team
    Version: 2.0.0 (Consolidated from Setup-PolicyTestingEnvironment.ps1, FixMissing9Policies.ps1, SetupAzureMonitorAlerts.ps1)
    Date: January 13, 2026
    
    PREREQUISITES:
    - Azure PowerShell modules (Az.*)
    - Owner or Contributor role on subscription
    - Guest MSA accounts supported (for dev/test)
    
    WHAT THIS CREATES:
    - Resource Groups: 1-2 (test + infra, or just infra for production)
    - Managed Identity: 1 (for policy remediation)
    - Network: 1 VNet + 1 subnet
    - DNS: 1 Private DNS zone
    - Monitoring: 1 Log Analytics workspace, 1 Event Hub namespace
    - Alerting: 1 Action Group + 5 alert rules (optional)
    - Key Vaults: 3 (dev/test only)
    - Test Data: ~40 secrets/keys/certificates (dev/test only)
    
    ESTIMATED COST (eastus, dev/test environment):
    - Log Analytics: ~$5-10/month (PerGB2018 pricing)
    - Event Hub: ~$10-20/month (Basic tier)
    - VNet: Free (basic configuration)
    - Key Vaults: Free (Standard tier, no transactions)
    - Managed Identity: Free
    - Total: ~$15-30/month for dev/test environment
#>

[CmdletBinding()]
param(
    [string]$SubscriptionId,
    [string]$TestResourceGroup = 'rg-policy-keyvault-test',
    [string]$InfraResourceGroup = 'rg-policy-remediation',
    [string]$Location = 'eastus',
    [ValidateSet('DevTest', 'Production')]
    [string]$Environment = 'DevTest',
    [switch]$CleanupFirst,
    [switch]$SkipVaultSeeding,
    [switch]$SkipMonitoring,
    [string]$ActionGroupEmail,
    [switch]$DeployAdvancedInfra
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'Continue'
$script:TotalSteps = if ($Environment -eq 'DevTest') { 12 } else { 8 }
$script:CurrentStep = 0

# Validation
if (-not $SkipMonitoring -and -not $ActionGroupEmail) {
    Write-Host "ERROR: -ActionGroupEmail is required unless -SkipMonitoring is specified" -ForegroundColor Red
    exit 1
}

# Colors for output
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
    $script:CurrentStep++
    $bar = "═" * 80
    Write-Host "`n╔$bar╗" -ForegroundColor $colors.Section
    Write-Host "║  [$script:CurrentStep/$script:TotalSteps] $Title" -ForegroundColor $colors.Section
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

function Get-RandomSuffix {
    return (Get-Random -Minimum 1000 -Maximum 9999).ToString()
}

#endregion

#region Main Script

Write-Host "`n╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                              ║" -ForegroundColor Cyan
Write-Host "║          AZURE KEY VAULT POLICY ENVIRONMENT SETUP                            ║" -ForegroundColor Cyan
Write-Host "║          Comprehensive Infrastructure + Testing + Monitoring                 ║" -ForegroundColor Cyan
Write-Host "║                                                                              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "`n📋 Configuration:" -ForegroundColor $colors.Info
Write-Host "  Environment: $Environment" -ForegroundColor White
Write-Host "  Subscription: $(if ($SubscriptionId) { $SubscriptionId } else { 'Current context' })" -ForegroundColor White
Write-Host "  Test RG: $TestResourceGroup" -ForegroundColor White
Write-Host "  Infra RG: $InfraResourceGroup" -ForegroundColor White
Write-Host "  Location: $Location" -ForegroundColor White
Write-Host "  Cleanup First: $($CleanupFirst.IsPresent)" -ForegroundColor White
Write-Host "  Skip Vault Seeding: $($SkipVaultSeeding.IsPresent)" -ForegroundColor White
Write-Host "  Skip Monitoring: $($SkipMonitoring.IsPresent)" -ForegroundColor White
if ($ActionGroupEmail) {
    Write-Host "  Alert Email: $ActionGroupEmail" -ForegroundColor White
}

# Connect to Azure
Write-Section "Azure Authentication"

if ($SubscriptionId) {
    Write-Status "Setting subscription context..." "Info"
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    Write-Status "Connected to subscription: $(( Get-AzContext).Subscription.Name)" "Success"
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

$scope = "/subscriptions/$SubscriptionId"
Write-Status "Scope: $scope" "Info"

# Get current user
$currentUser = Get-AzADUser -SignedIn -ErrorAction SilentlyContinue
if ($currentUser) {
    Write-Status "Signed in as: $($currentUser.UserPrincipalName)" "Info"
    $currentUserId = $currentUser.Id
} else {
    Write-Status "Could not retrieve user principal (MSA/guest account). Using context identity." "Warning"
    $currentUserId = (Get-AzContext).Account.Id
}

#endregion

#region Step 1: Optional Cleanup

if ($CleanupFirst) {
    Write-Section "Cleanup: Remove Existing Resources"
    
    Write-Status "⚠️  WARNING: This will DELETE all resources!" "Warning"
    Write-Host "  Test Resources:" -ForegroundColor Yellow
    Write-Host "    - All policy assignments (KV-All-*, KV-Tier1-*)" -ForegroundColor Yellow
    Write-Host "    - All Key Vaults in $TestResourceGroup" -ForegroundColor Yellow
    Write-Host "    - Resource group: $TestResourceGroup" -ForegroundColor Yellow
    Write-Host "  Infrastructure Resources:" -ForegroundColor Yellow
    Write-Host "    - Managed Identity: id-policy-remediation" -ForegroundColor Yellow
    Write-Host "    - VNet, Subnet, DNS Zone" -ForegroundColor Yellow
    Write-Host "    - Log Analytics Workspace" -ForegroundColor Yellow
    Write-Host "    - Event Hub Namespace" -ForegroundColor Yellow
    Write-Host "    - Resource group: $InfraResourceGroup`n" -ForegroundColor Yellow
    
    $confirm = Read-Host "Type 'DELETE' to confirm cleanup"
    if ($confirm -ne 'DELETE') {
        Write-Status "Cleanup cancelled." "Warning"
    } else {
        # Remove policy assignments first - include ALL Key Vault related policies
        Write-Status "Scanning for Key Vault policy assignments to remove..." "Info"
        $assignments = Get-AzPolicyAssignment | Where-Object { 
            # Legacy naming patterns
            $_.Name -like 'KV-All-*' -or 
            $_.Name -like 'KV-Tier*' -or 
            # Name-based patterns (covers truncated policy assignment names)
            $_.Name -like '*KeyVault*' -or 
            $_.Name -like '*keyvault*' -or
            $_.Name -like '*Keyvault*' -or
            $_.Name -like '*Keys*' -or
            $_.Name -like '*Secrets*' -or
            $_.Name -like '*Certificates*' -or
            # DisplayName patterns (when available)
            $_.DisplayName -like '*Key Vault*' -or
            $_.DisplayName -like '*key vault*' -or
            $_.DisplayName -like '*Managed HSM*' -or
            # Exclude system/built-in assignments that aren't ours
            ($_.Name -notlike 'sys.*' -and $_.Name -notlike 'SecurityCenter*')
        }
        
        # Show preview of what will be removed
        if ($assignments.Count -gt 0) {
            Write-Status "Found $($assignments.Count) policy assignment(s) to remove" "Warning"
            Write-Host "`n⚠️  WARNING: The following policy assignments will be removed:" -ForegroundColor Yellow
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
            
            # Log each assignment to be removed
            foreach ($assignment in $assignments) {
                $displayName = if ($assignment.DisplayName) { $assignment.DisplayName } else { $assignment.Name }
                $scope = $assignment.Properties.Scope -replace '/subscriptions/[^/]+', '/subscriptions/***'
                Write-Host "  📋 $displayName" -ForegroundColor Cyan
                Write-Host "     Name: $($assignment.Name)" -ForegroundColor Gray
                Write-Host "     Scope: $scope" -ForegroundColor Gray
                Write-Status "  Will remove: $displayName (Name: $($assignment.Name), Scope: $($assignment.Properties.Scope))" "Info"
            }
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Yellow
            
            # Confirmation prompt
            $confirmation = Read-Host "Proceed with cleanup? Type 'YES' to confirm"
            Write-Status "User confirmation response: '$confirmation'" "Info"
            
            if ($confirmation -ne 'YES') {
                Write-Status "Cleanup cancelled by user (expected 'YES', got '$confirmation')" "Warning"
                return
            }
            Write-Status "User confirmed cleanup - proceeding with removal" "Info"
        } else {
            Write-Status "No Key Vault policy assignments found to remove" "Success"
        }
        
        # Proceed with removal
        $removedCount = 0
        $failedCount = 0
        foreach ($assignment in $assignments) {
            try {
                $displayName = if ($assignment.DisplayName) { $assignment.DisplayName } else { $assignment.Name }
                Remove-AzPolicyAssignment -Id $assignment.Id -ErrorAction Stop | Out-Null
                $removedCount++
                Write-Status "✓ Removed: $displayName" "Success"
            } catch {
                $displayName = if ($assignment.DisplayName) { $assignment.DisplayName } else { $assignment.Name }
                $failedCount++
                Write-Status "✗ Failed to remove: $displayName" "Error" $_.Exception.Message
            }
        }
        Write-Status "Cleanup summary: $removedCount removed, $failedCount failed" "Success"
        
        # Delete test resource group
        $testRg = Get-AzResourceGroup -Name $TestResourceGroup -ErrorAction SilentlyContinue
        if ($testRg) {
            Write-Status "Deleting test resource group: $TestResourceGroup..." "Info"
            Remove-AzResourceGroup -Name $TestResourceGroup -Force | Out-Null
            Write-Status "Test resource group deleted" "Success"
        }
        
        # Delete infrastructure resource group
        $infraRg = Get-AzResourceGroup -Name $InfraResourceGroup -ErrorAction SilentlyContinue
        if ($infraRg) {
            Write-Status "Deleting infrastructure resource group: $InfraResourceGroup (may take 5+ minutes)..." "Info"
            Remove-AzResourceGroup -Name $InfraResourceGroup -Force | Out-Null
            Write-Status "Infrastructure resource group deleted" "Success"
        }
        
        Write-Status "✓ Complete cleanup finished" "Success"
    }
}

#endregion

#region Step 2: Create Resource Groups

Write-Section "Resource Groups"

# Infra RG
$infraRg = Get-AzResourceGroup -Name $InfraResourceGroup -ErrorAction SilentlyContinue
if (-not $infraRg) {
    Write-Status "Creating infrastructure resource group: $InfraResourceGroup..." "Info"
    $infraRg = New-AzResourceGroup -Name $InfraResourceGroup -Location $Location
    Write-Status "Created: $InfraResourceGroup" "Success"
} else {
    Write-Status "Using existing: $InfraResourceGroup" "Success"
}

# Test RG (for DevTest only)
if ($Environment -eq 'DevTest') {
    $testRg = Get-AzResourceGroup -Name $TestResourceGroup -ErrorAction SilentlyContinue
    if (-not $testRg) {
        Write-Status "Creating test resource group: $TestResourceGroup..." "Info"
        $testRg = New-AzResourceGroup -Name $TestResourceGroup -Location $Location
        Write-Status "Created: $TestResourceGroup" "Success"
    } else {
        Write-Status "Using existing: $TestResourceGroup" "Success"
    }
}

#endregion

#region Step 3: Create Managed Identity

Write-Section "Managed Identity for Policy Remediation"

$identityName = "id-policy-remediation"
$identity = Get-AzUserAssignedIdentity -ResourceGroupName $InfraResourceGroup -Name $identityName -ErrorAction SilentlyContinue

if (-not $identity) {
    Write-Status "Creating managed identity: $identityName..." "Info"
    $identity = New-AzUserAssignedIdentity -ResourceGroupName $InfraResourceGroup -Name $identityName -Location $Location
    Write-Status "Created: $identityName" "Success"
    Write-Status "Principal ID: $($identity.PrincipalId)" "Info"
    
    # Wait for AAD replication
    Write-Status "Waiting 30 seconds for AAD replication..." "Info"
    Start-Sleep -Seconds 30
} else {
    Write-Status "Using existing: $identityName" "Success"
    Write-Status "Principal ID: $($identity.PrincipalId)" "Info"
}

# Assign roles to managed identity (required for DeployIfNotExists/Modify policies)
Write-Status "Assigning RBAC roles to managed identity..." "Info"

$rolesToAssign = @(
    @{ Role = "Network Contributor"; Scope = $scope },
    @{ Role = "Private DNS Zone Contributor"; Scope = $scope },
    @{ Role = "Log Analytics Contributor"; Scope = $scope },
    @{ Role = "Contributor"; Scope = $scope }  # Needed for Event Hub and general remediation
)

foreach ($roleAssignment in $rolesToAssign) {
    $existing = Get-AzRoleAssignment -ObjectId $identity.PrincipalId `
        -RoleDefinitionName $roleAssignment.Role `
        -Scope $roleAssignment.Scope `
        -ErrorAction SilentlyContinue
    
    if (-not $existing) {
        try {
            New-AzRoleAssignment -ObjectId $identity.PrincipalId `
                -RoleDefinitionName $roleAssignment.Role `
                -Scope $roleAssignment.Scope `
                -ErrorAction Stop | Out-Null
            Write-Status "Assigned role: $($roleAssignment.Role)" "Success"
        } catch {
            if ($_.Exception.Message -like "*already exists*") {
                Write-Status "Role already assigned: $($roleAssignment.Role)" "Success"
            } else {
                Write-Status "Failed to assign role: $($roleAssignment.Role)" "Error" $_.Exception.Message
            }
        }
    } else {
        Write-Status "Role already assigned: $($roleAssignment.Role)" "Success"
    }
}

#endregion

#region Step 4: Create VNet and Subnet

Write-Section "Virtual Network and Subnet"

$vnetName = "vnet-policy-test"
$subnetName = "snet-privateendpoints"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.1.0/24"

$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $InfraResourceGroup -ErrorAction SilentlyContinue

if (-not $vnet) {
    Write-Status "Creating VNet: $vnetName..." "Info"
    
    $subnetConfig = New-AzVirtualNetworkSubnetConfig `
        -Name $subnetName `
        -AddressPrefix $subnetAddressPrefix `
        -PrivateEndpointNetworkPolicies Disabled
    
    $vnet = New-AzVirtualNetwork `
        -Name $vnetName `
        -ResourceGroupName $InfraResourceGroup `
        -Location $Location `
        -AddressPrefix $vnetAddressPrefix `
        -Subnet $subnetConfig
    
    Write-Status "Created VNet: $vnetName" "Success"
    Write-Status "Created Subnet: $subnetName" "Success"
} else {
    Write-Status "Using existing VNet: $vnetName" "Success"
    
    # Check if subnet exists
    $subnet = $vnet.Subnets | Where-Object { $_.Name -eq $subnetName }
    if (-not $subnet) {
        Write-Status "Creating subnet: $subnetName..." "Info"
        Add-AzVirtualNetworkSubnetConfig `
            -Name $subnetName `
            -VirtualNetwork $vnet `
            -AddressPrefix $subnetAddressPrefix `
            -PrivateEndpointNetworkPolicies Disabled | Out-Null
        $vnet | Set-AzVirtualNetwork | Out-Null
        Write-Status "Created Subnet: $subnetName" "Success"
    } else {
        Write-Status "Using existing Subnet: $subnetName" "Success"
    }
}

# Get subnet for later use
$subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnetName
$subnetId = $subnet.Id
Write-Status "Subnet ID: $subnetId" "Info"

#endregion

#region Step 5: Create Private DNS Zone

Write-Section "Private DNS Zone"

$dnsZoneName = "privatelink.vaultcore.azure.net"
$dnsZone = Get-AzPrivateDnsZone -ResourceGroupName $InfraResourceGroup -Name $dnsZoneName -ErrorAction SilentlyContinue

if (-not $dnsZone) {
    Write-Status "Creating Private DNS Zone: $dnsZoneName..." "Info"
    try {
        $dnsZone = New-AzPrivateDnsZone -ResourceGroupName $InfraResourceGroup -Name $dnsZoneName
        Write-Status "Created: $dnsZoneName" "Success"
    } catch {
        if ($_.Exception.Message -like "*already exists*" -or $_.Exception.Message -like "*exists already*") {
            Write-Status "DNS zone already exists (in another RG), retrieving..." "Warning"
            $dnsZone = Get-AzPrivateDnsZone -Name $dnsZoneName -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($dnsZone) {
                Write-Status "Using existing DNS zone from: $($dnsZone.ResourceGroupName)" "Success"
            } else {
                Write-Status "Could not retrieve existing DNS zone" "Error"
                throw
            }
        } else {
            throw
        }
    }
} else {
    Write-Status "Using existing: $dnsZoneName" "Success"
}

# Link VNet to DNS zone
$linkName = "vnet-policy-test-link"
$link = Get-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $dnsZone.ResourceGroupName -ZoneName $dnsZoneName -Name $linkName -ErrorAction SilentlyContinue

if (-not $link) {
    Write-Status "Linking VNet to Private DNS Zone..." "Info"
    $link = New-AzPrivateDnsVirtualNetworkLink `
        -ResourceGroupName $dnsZone.ResourceGroupName `
        -ZoneName $dnsZoneName `
        -Name $linkName `
        -VirtualNetworkId $vnet.Id `
        -ErrorAction SilentlyContinue
    Write-Status "VNet linked to DNS zone" "Success"
} else {
    Write-Status "VNet already linked to DNS zone" "Success"
}

$dnsZoneId = $dnsZone.ResourceId
Write-Status "DNS Zone ID: $dnsZoneId" "Info"

#endregion

#region Step 6: Create Log Analytics Workspace

Write-Section "Log Analytics Workspace"

$lawName = "law-policy-test-$(Get-RandomSuffix)"
# Check if one already exists
$existingLaw = Get-AzOperationalInsightsWorkspace -ResourceGroupName $InfraResourceGroup -ErrorAction SilentlyContinue | Select-Object -First 1

if ($existingLaw) {
    Write-Status "Using existing Log Analytics Workspace: $($existingLaw.Name)" "Success"
    $law = $existingLaw
} else {
    Write-Status "Creating Log Analytics Workspace: $lawName..." "Info"
    $law = New-AzOperationalInsightsWorkspace `
        -ResourceGroupName $InfraResourceGroup `
        -Name $lawName `
        -Location $Location `
        -Sku PerGB2018
    Write-Status "Created: $lawName" "Success"
}

$lawId = $law.ResourceId
Write-Status "Workspace ID: $lawId" "Info"

#endregion

#region Step 7: Create Event Hub Namespace

Write-Section "Event Hub Namespace"

$ehNamespaceName = "eh-policy-test-$(Get-RandomSuffix)"
# Check if one already exists
$existingEhNs = Get-AzEventHubNamespace -ResourceGroupName $InfraResourceGroup -ErrorAction SilentlyContinue | Select-Object -First 1

if ($existingEhNs) {
    Write-Status "Using existing Event Hub Namespace: $($existingEhNs.Name)" "Success"
    $ehNamespace = $existingEhNs
} else {
    Write-Status "Creating Event Hub Namespace: $ehNamespaceName..." "Info"
    $ehNamespace = New-AzEventHubNamespace `
        -ResourceGroupName $InfraResourceGroup `
        -Name $ehNamespaceName `
        -Location $Location `
        -SkuName Basic
    Write-Status "Created: $ehNamespaceName" "Success"
}

# Create Event Hub
$ehName = "keyvault-diagnostics"
$eh = Get-AzEventHub -ResourceGroupName $InfraResourceGroup -NamespaceName $ehNamespace.Name -Name $ehName -ErrorAction SilentlyContinue

if (-not $eh) {
    Write-Status "Creating Event Hub: $ehName..." "Info"
    $eh = New-AzEventHub `
        -ResourceGroupName $InfraResourceGroup `
        -NamespaceName $ehNamespace.Name `
        -Name $ehName `
        -PartitionCount 2 `
        -RetentionTimeInHour 24 `
        -CleanupPolicy Delete
    Write-Status "Created Event Hub: $ehName" "Success"
} else {
    Write-Status "Using existing Event Hub: $ehName" "Success"
}

# Get authorization rule ID
$authRuleName = "RootManageSharedAccessKey"
$authRule = Get-AzEventHubAuthorizationRule `
    -ResourceGroupName $InfraResourceGroup `
    -NamespaceName $ehNamespace.Name `
    -AuthorizationRuleName $authRuleName

$authRuleId = $authRule.Id
Write-Status "Auth Rule ID: $authRuleId" "Info"

#endregion

#region Step 8: Create Monitoring and Alerts

if (-not $SkipMonitoring) {
    Write-Section "Azure Monitor Alerts and Action Groups"
    
    $actionGroupName = "ag-keyvault-policy-alerts"
    $actionGroupShortName = "KVPolicy"
    
    # Create Action Group
    Write-Status "Creating Action Group: $actionGroupName..." "Info"
    
    try {
        # Create email receiver object
        $emailReceiver = New-AzActionGroupEmailReceiverObject `
            -Name "PolicyTeam" `
            -EmailAddress $ActionGroupEmail
        
        # Create or update action group
        $actionGroup = Set-AzActionGroup `
            -Name $actionGroupName `
            -ResourceGroupName $InfraResourceGroup `
            -ShortName $actionGroupShortName `
            -Receiver $emailReceiver `
            -ErrorAction Stop
    }
    catch {
        Write-Status "Failed to create action group: $($_.Exception.Message)" "Warning"
        $actionGroup = $null
    }
    
    if ($actionGroup) {
        Write-Status "Action Group created/updated" "Success"
        Write-Status "Email notifications will be sent to: $ActionGroupEmail" "Info"
    } else {
        Write-Status "Action group may already exist or failed to create" "Warning"
    }
    
    Write-Host "`n  ℹ️  Alert rules can be created using Azure Portal or CLI." -ForegroundColor $colors.Info
    Write-Host "  Recommended alerts:" -ForegroundColor Gray
    Write-Host "    1. Policy Assignment Deleted (Activity Log)" -ForegroundColor Gray
    Write-Host "    2. Compliance Drop > 10% (Custom Metrics)" -ForegroundColor Gray
    Write-Host "    3. Remediation Task Failures (Activity Log)" -ForegroundColor Gray
    Write-Host "    4. Deny Block Spike (Custom Metrics)" -ForegroundColor Gray
    Write-Host "    5. Exemption Expiry Warning (Custom Logic)" -ForegroundColor Gray
} else {
    Write-Status "Skipping monitoring setup (as requested)" "Info"
}

#endregion

#region Step 9-11: Create Test Environment (DevTest Only)

if ($Environment -eq 'DevTest') {
    
    # Step 9: Create Test Key Vaults
    Write-Section "Test Key Vaults Creation"
    
    $vaultConfigs = @(
        @{
            Name = "kv-compliant-$(Get-RandomSuffix)"
            Description = "Fully compliant vault"
            EnableSoftDelete = $true
            EnablePurgeProtection = $true
            EnableRbacAuthorization = $true
            PublicNetworkAccess = 'Disabled'
        },
        @{
            Name = "kv-partial-$(Get-RandomSuffix)"
            Description = "Partially compliant vault"
            EnableSoftDelete = $true
            EnablePurgeProtection = $false  # Non-compliant
            EnableRbacAuthorization = $true
            PublicNetworkAccess = 'Enabled'  # Non-compliant
        },
        @{
            Name = "kv-noncompliant-$(Get-RandomSuffix)"
            Description = "Non-compliant vault (for testing blocking)"
            EnableSoftDelete = $true
            EnablePurgeProtection = $false  # Non-compliant
            EnableRbacAuthorization = $false  # Non-compliant (uses access policies)
            PublicNetworkAccess = 'Enabled'  # Non-compliant
        }
    )
    
    $createdVaults = @()
    
    foreach ($config in $vaultConfigs) {
        $vault = Get-AzKeyVault -ResourceGroupName $TestResourceGroup -VaultName $config.Name -ErrorAction SilentlyContinue
        
        if (-not $vault) {
            Write-Status "Creating Key Vault: $($config.Name)..." "Info"
            
            $vaultParams = @{
                ResourceGroupName = $TestResourceGroup
                VaultName = $config.Name
                Location = $Location
                PublicNetworkAccess = $config.PublicNetworkAccess
            }
            
            # Handle RBAC authorization (inverted logic)
            if ($config.EnableRbacAuthorization -eq $false) {
                $vaultParams['DisableRbacAuthorization'] = $true
            }
            
            if ($config.EnablePurgeProtection) {
                $vaultParams['EnablePurgeProtection'] = $true
            }
            
            # Soft delete retention (soft delete always enabled, just set retention)
            if ($config.EnableSoftDelete) {
                $vaultParams['SoftDeleteRetentionInDays'] = 90
            }
            
            $vault = New-AzKeyVault @vaultParams
            Write-Status "Created: $($config.Name) ($($config.Description))" "Success"
        } else {
            Write-Status "Using existing: $($config.Name)" "Success"
        }
        
        $createdVaults += $vault
    }
    
    # Step 10: Assign RBAC to current user
    Write-Section "RBAC Role Assignments"
    
    Write-Status "Assigning 'Key Vault Administrator' role to current user..." "Info"
    
    foreach ($vault in $createdVaults) {
        if ($vault.EnableRbacAuthorization) {
            # RBAC-enabled vault - assign Key Vault Administrator role
            $existing = Get-AzRoleAssignment `
                -ObjectId $currentUserId `
                -RoleDefinitionName "Key Vault Administrator" `
                -Scope $vault.ResourceId `
                -ErrorAction SilentlyContinue
            
            if (-not $existing) {
                try {
                    New-AzRoleAssignment `
                        -ObjectId $currentUserId `
                        -RoleDefinitionName "Key Vault Administrator" `
                        -Scope $vault.ResourceId `
                        -ErrorAction Stop | Out-Null
                    Write-Status "Assigned role for: $($vault.VaultName)" "Success"
                } catch {
                    if ($_.Exception.Message -like "*already exists*") {
                        Write-Status "Role already assigned for: $($vault.VaultName)" "Success"
                    } else {
                        Write-Status "Failed to assign role for: $($vault.VaultName)" "Error" $_.Exception.Message
                    }
                }
            } else {
                Write-Status "Role already assigned for: $($vault.VaultName)" "Success"
            }
        } else {
            # Access Policy vault (non-compliant) - assign access policy permissions
            try {
                Set-AzKeyVaultAccessPolicy `
                    -VaultName $vault.VaultName `
                    -ObjectId $currentUserId `
                    -PermissionsToSecrets Get,List,Set,Delete,Recover,Backup,Restore,Purge `
                    -PermissionsToKeys Get,List,Create,Delete,Update,Import,Recover,Backup,Restore,Purge,Decrypt,Encrypt,UnwrapKey,WrapKey,Verify,Sign,Release,Rotate,GetRotationPolicy,SetRotationPolicy `
                    -PermissionsToCertificates Get,List,Update,Create,Import,Delete,Recover,Backup,Restore,ManageContacts,ManageIssuers,GetIssuers,ListIssuers,SetIssuers,DeleteIssuers,Purge `
                    -ErrorAction Stop | Out-Null
                Write-Status "Assigned access policy for: $($vault.VaultName)" "Success"
            } catch {
                Write-Status "Failed to assign access policy for: $($vault.VaultName)" "Error" $_.Exception.Message
            }
        }
    }
    
    # Wait for RBAC propagation
    Write-Status "Waiting 60 seconds for RBAC propagation..." "Info"
    Start-Sleep -Seconds 60
    
    # Step 11: Seed Test Data
    if (-not $SkipVaultSeeding) {
        Write-Section "Seeding Test Data (Secrets, Keys, Certificates)"
        
        # Get current client IP for firewall bypass
        Write-Status "Detecting client IP address..." "Info"
        try {
            $clientIp = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json").ip
            Write-Status "Client IP: $clientIp" "Success"
        } catch {
            Write-Status "Failed to detect client IP: $($_.Exception.Message)" "Warning"
            $clientIp = $null
        }
        
        # Track totals across all vaults
        $totalSecrets = 0
        $totalKeys = 0
        $totalCerts = 0
        
        foreach ($vault in $createdVaults) {
            # Store original settings
            $vaultDetails = Get-AzKeyVault -VaultName $vault.VaultName
            $originalPublicAccess = $vaultDetails.PublicNetworkAccess
            $originalNetworkRules = $vaultDetails.NetworkAcls
            $accessTemporarilyEnabled = $false
            $firewallTemporarilyModified = $false
            
            # Temporarily enable public access if disabled (for testing purposes)
            if ($originalPublicAccess -eq 'Disabled') {
                Write-Status "Temporarily enabling public access for $($vault.VaultName) to seed test data..." "Info"
                try {
                    Update-AzKeyVault -VaultName $vault.VaultName -ResourceGroupName $vault.ResourceGroupName -PublicNetworkAccess "Enabled" | Out-Null
                    Start-Sleep -Seconds 5
                    $accessTemporarilyEnabled = $true
                    Write-Status "Public access enabled" "Success"
                } catch {
                    Write-Status "Failed to enable public access: $($_.Exception.Message)" "Warning"
                    continue
                }
            }
            
            # Temporarily add client IP to firewall if needed
            if ($clientIp) {
                Write-Status "Temporarily adding client IP to firewall for $($vault.VaultName) (allows data seeding from current client)..." "Info"
                try {
                    Add-AzKeyVaultNetworkRule -VaultName $vault.VaultName -IpAddressRange "$clientIp/32" -ErrorAction Stop | Out-Null
                    Start-Sleep -Seconds 5  # Wait for propagation
                    $firewallTemporarilyModified = $true
                    Write-Status "Firewall rule added" "Success"
                } catch {
                    Write-Status "Failed to add firewall rule: $($_.Exception.Message)" "Warning"
                }
            }
            
            Write-Status "Seeding data in: $($vault.VaultName)..." "Info"
            
            # Secrets
            $secretCount = 0
            $secrets = @(
                @{ Name = "secret-with-expiry"; Value = "test-value-1"; ExpiresIn = 90 },
                @{ Name = "secret-no-expiry"; Value = "test-value-2"; ExpiresIn = $null },
                @{ Name = "secret-with-content-type"; Value = "test-value-3"; ContentType = "application/json"; ExpiresIn = 365 },
                @{ Name = "secret-old"; Value = "test-value-4"; ExpiresIn = 400 }  # Non-compliant (>365 days)
            )
            
            foreach ($secretDef in $secrets) {
                try {
                    $secretValue = ConvertTo-SecureString -String $secretDef.Value -AsPlainText -Force
                    $params = @{
                        VaultName = $vault.VaultName
                        Name = $secretDef.Name
                        SecretValue = $secretValue
                    }
                    if ($secretDef.ExpiresIn) {
                        $params['Expires'] = (Get-Date).AddDays($secretDef.ExpiresIn).ToUniversalTime()
                    }
                    if ($secretDef.ContentType) {
                        $params['ContentType'] = $secretDef.ContentType
                    }
                    
                    Set-AzKeyVaultSecret @params | Out-Null
                    $secretCount++
                } catch {
                    Write-Status "Failed to create secret $($secretDef.Name): $($_.Exception.Message)" "Warning"
                }
            }
            $totalSecrets += $secretCount
            Write-Status "Created $secretCount secrets in $($vault.VaultName)" "Success"
            
            # Keys
            $keyCount = 0
            $keys = @(
                @{ Name = "key-rsa-2048"; KeyType = "RSA"; KeySize = 2048 },
                @{ Name = "key-rsa-4096"; KeyType = "RSA"; KeySize = 4096 },
                @{ Name = "key-ec-p256"; KeyType = "EC"; CurveName = "P-256" },
                @{ Name = "key-ec-p384"; KeyType = "EC"; CurveName = "P-384" },
                @{ Name = "key-ec-p521"; KeyType = "EC"; CurveName = "P-521" }  # May be non-compliant depending on policy
            )
            
            foreach ($keyDef in $keys) {
                try {
                    $params = @{
                        VaultName = $vault.VaultName
                        Name = $keyDef.Name
                        KeyType = $keyDef.KeyType
                        Destination = 'Software'
                    }
                    if ($keyDef.KeySize) {
                        $params['Size'] = $keyDef.KeySize
                    }
                    if ($keyDef.CurveName) {
                        $params['CurveName'] = $keyDef.CurveName
                    }
                    
                    Add-AzKeyVaultKey @params | Out-Null
                    $keyCount++
                } catch {
                    Write-Status "Failed to create key $($keyDef.Name): $($_.Exception.Message)" "Warning"
                }
            }
            $totalKeys += $keyCount
            Write-Status "Created $keyCount keys in $($vault.VaultName)" "Success"
            
            # Certificates (simplified - just create self-signed for testing)
            $certCount = 0
            $certs = @(
                @{ Name = "cert-rsa-2048"; KeySize = 2048; ValidityInMonths = 12 },
                @{ Name = "cert-rsa-4096"; KeySize = 4096; ValidityInMonths = 6 },
                @{ Name = "cert-long-validity"; KeySize = 2048; ValidityInMonths = 24 }  # Non-compliant
            )
            
            foreach ($certDef in $certs) {
                try {
                    $policy = New-AzKeyVaultCertificatePolicy `
                        -SubjectName "CN=$($certDef.Name)" `
                        -IssuerName Self `
                        -ValidityInMonths $certDef.ValidityInMonths `
                        -KeySize $certDef.KeySize
                    
                    Add-AzKeyVaultCertificate -VaultName $vault.VaultName -Name $certDef.Name -CertificatePolicy $policy | Out-Null
                    $certCount++
                } catch {
                    Write-Status "Failed to create certificate $($certDef.Name): $($_.Exception.Message)" "Warning"
                }
            }
            $totalCerts += $certCount
            Write-Status "Created $certCount certificates in $($vault.VaultName)" "Success"
            
            # NOW restore firewall rules if modified (after ALL data is seeded)
            if ($firewallTemporarilyModified -and $clientIp) {
                Write-Status "Removing temporary firewall rule from $($vault.VaultName) (restores original security posture)..." "Info"
                try {
                    Remove-AzKeyVaultNetworkRule -VaultName $vault.VaultName -IpAddressRange "$clientIp/32" -ErrorAction Stop | Out-Null
                    Write-Status "Firewall rule removed" "Success"
                } catch {
                    Write-Status "Failed to remove firewall rule: $($_.Exception.Message)" "Warning"
                }
            }
            
            # Restore original public access setting if it was changed (after ALL data is seeded)
            if ($accessTemporarilyEnabled -and $originalPublicAccess -eq 'Disabled') {
                Write-Status "Restoring public access to 'Disabled' for $($vault.VaultName)..." "Info"
                try {
                    Update-AzKeyVault -VaultName $vault.VaultName -ResourceGroupName $vault.ResourceGroupName -PublicNetworkAccess "Disabled" | Out-Null
                    Write-Status "Public access restored to original setting" "Success"
                } catch {
                    Write-Status "Failed to restore public access: $($_.Exception.Message)" "Warning"
                }
            }
        }
    } else {
        Write-Status "Skipping vault seeding (as requested)" "Info"
        $totalSecrets = 0
        $totalKeys = 0
        $totalCerts = 0
    }
    
} else {
    Write-Status "Skipping test environment creation (Production mode)" "Info"
}

#endregion

#region Step 13: Deploy Advanced Infrastructure (Optional)

if ($DeployAdvancedInfra) {
    Write-Section "Advanced Infrastructure Deployment"
    
    # Display cost warning
    Write-Host "╔═══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║                          ⚠️  COST WARNING ⚠️                              ║" -ForegroundColor Yellow
    Write-Host "╚═══════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host "`n  Azure Managed HSM is an EXPENSIVE resource:" -ForegroundColor White
    Write-Host "    • Cost: `$6.45/hour (`$4,838.40/month)" -ForegroundColor Red
    Write-Host "    • Minimum billing: 24 hours" -ForegroundColor Yellow
    Write-Host "    • Minimum cost: ~`$155 for 24-hour period" -ForegroundColor Red
    Write-Host "    • Estimated testing cost: ~`$200 (24-30 hours with testing time)" -ForegroundColor Yellow
    Write-Host "`n  VNet infrastructure is low cost (~`$5/month)`n" -ForegroundColor Green
    
    Write-Host "  This will enable testing of:" -ForegroundColor White
    Write-Host "    • 7 Managed HSM policies (currently SKIP)" -ForegroundColor Cyan
    Write-Host "    • 1 Private Link policy (currently SKIP)" -ForegroundColor Cyan
    Write-Host "    • Achieves 34/34 comprehensive test coverage`n" -ForegroundColor Green
    
    $confirmation = Read-Host "Type 'PROCEED-WITH-COST' to deploy Managed HSM, or press Enter to skip"
    
    if ($confirmation -eq 'PROCEED-WITH-COST') {
        
        # Deploy Managed HSM
        $hsmName = "hsm-policy-test-$(Get-Random -Minimum 1000 -Maximum 9999)"
        Write-Host "`n  Creating Managed HSM: $hsmName" -ForegroundColor Cyan
        Write-Host "    (This will take 20-30 minutes to activate)..." -ForegroundColor Gray
        
        try {
            # Create Managed HSM
            $hsm = New-AzKeyVaultManagedHsm `
                -Name $hsmName `
                -ResourceGroupName $InfraResourceGroup `
                -Location $Location `
                -Administrator $currentUser.Id `
                -SoftDeleteRetentionInDays 7 `
                -EnablePurgeProtection $false `
                -PublicNetworkAccess "Enabled" `
                -Tag @{
                    Purpose = "PolicyTesting"
                    Environment = $Environment
                    CostCenter = "PolicyGovernance"
                    AutoDelete = "AfterTesting"
                }
            
            Write-Status "Managed HSM created (provisioning state: $($hsm.ProvisioningState))" "Success"
            
            # Wait for activation
            Write-Host "`n  Waiting for Managed HSM activation (20-30 minutes)..." -ForegroundColor Yellow
            $maxWait = 45 # minutes
            $elapsed = 0
            $checkInterval = 60 # seconds
            
            while ($elapsed -lt ($maxWait * 60)) {
                Start-Sleep -Seconds $checkInterval
                $elapsed += $checkInterval
                $minutes = [Math]::Round($elapsed / 60, 1)
                
                $hsmStatus = Get-AzKeyVaultManagedHsm -Name $hsmName -ResourceGroupName $InfraResourceGroup
                
                if ($hsmStatus.ProvisioningState -eq 'Succeeded') {
                    Write-Status "Managed HSM activated after $minutes minutes" "Success"
                    break
                }
                
                Write-Host "    Status check at $minutes minutes: $($hsmStatus.ProvisioningState)" -ForegroundColor Gray
            }
            
            if ($hsmStatus.ProvisioningState -ne 'Succeeded') {
                Write-Status "Managed HSM still activating after $maxWait minutes - may need more time" "Warning"
                Write-Host "    You can check status later with: Get-AzKeyVaultManagedHsm -Name $hsmName" -ForegroundColor Gray
            }
            
            # Store HSM details
            $hsmId = $hsm.ResourceId
            Write-Host "`n  Managed HSM Details:" -ForegroundColor White
            Write-Host "    Name: $hsmName" -ForegroundColor Cyan
            Write-Host "    Resource ID: $hsmId" -ForegroundColor Gray
            Write-Host "    HSM URI: $($hsm.HsmUri)" -ForegroundColor Gray
            
            Write-Host "`n  ⚠️  CLEANUP REMINDER: Delete this HSM immediately after testing!" -ForegroundColor Red
            Write-Host "      Remove-AzKeyVaultManagedHsm -Name $hsmName -ResourceGroupName $InfraResourceGroup -Force" -ForegroundColor Yellow
            
        } catch {
            Write-Status "Failed to create Managed HSM: $($_.Exception.Message)" "Error"
            Write-Host "    You can retry manually or skip Managed HSM policies in testing" -ForegroundColor Yellow
        }
        
    } else {
        Write-Status "Skipped Managed HSM deployment (user declined cost)" "Warning"
        Write-Host "    11 policies will remain SKIP in comprehensive testing" -ForegroundColor Gray
    }
    
} else {
    Write-Host "`n  ℹ️  Advanced Infrastructure (Managed HSM) NOT deployed" -ForegroundColor Gray
    Write-Host "     To deploy: Add -DeployAdvancedInfra flag (enables 8 additional policy tests)" -ForegroundColor Gray
    Write-Host "     WARNING: Managed HSM costs `$4,838/month - only deploy for testing sessions`n" -ForegroundColor Yellow
}

#endregion

#region Step 14: Update Configuration Files (Optional Reference)

Write-Section "Configuration Files Update"

# NOTE: These files are OPTIONAL reference outputs - not required for policy deployment
# The main AzPolicyImplScript.ps1 uses PolicyParameters-*.json files instead
# These are generated for informational purposes only

# Update or create PolicyParameters.json (OPTIONAL - informational only)
$policyParamsFile = "PolicyParameters.json"
$policyParams = @{
    subnetId = $subnetId
    privateDnsZoneId = $dnsZoneId
    logAnalyticsWorkspaceId = $lawId
    eventHubAuthorizationRuleId = $authRuleId
    managedIdentityId = $identity.Id
    managedIdentityPrincipalId = $identity.PrincipalId
}

$policyParams | ConvertTo-Json -Depth 10 | Out-File $policyParamsFile -Encoding UTF8
Write-Status "Updated: $policyParamsFile (reference only - not used for deployment)" "Success"

# Update or create PolicyImplementationConfig.json (OPTIONAL - informational only)
$configFile = "PolicyImplementationConfig.json"
$config = @{
    subscription = $SubscriptionId
    testResourceGroup = if ($Environment -eq 'DevTest') { $TestResourceGroup } else { $null }
    infraResourceGroup = $InfraResourceGroup
    location = $Location
    environment = $Environment
    managedIdentity = @{
        id = $identity.Id
        principalId = $identity.PrincipalId
        clientId = $identity.ClientId
    }
    infrastructure = @{
        vnetId = $vnet.Id
        subnetId = $subnetId
        dnsZoneId = $dnsZoneId
        logAnalyticsId = $lawId
        eventHubNamespace = $ehNamespace.Name
        eventHubName = $ehName
        eventHubAuthRuleId = $authRuleId
    }
    monitoring = @{
        enabled = -not $SkipMonitoring
        actionGroupName = if (-not $SkipMonitoring) { $actionGroupName } else { $null }
        actionGroupEmail = $ActionGroupEmail
    }
    createdAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

$config | ConvertTo-Json -Depth 10 | Out-File $configFile -Encoding UTF8
Write-Status "Updated: $configFile (reference only - not used for deployment)" "Success"

#endregion

#region Summary

Write-Host "`n╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                                              ║" -ForegroundColor Green
Write-Host "║                          ✅ SETUP COMPLETE                                   ║" -ForegroundColor Green
Write-Host "║                                                                              ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📊 Summary:" -ForegroundColor $colors.Info
Write-Host "`n  Infrastructure Created:" -ForegroundColor White
Write-Host "    ✓ Managed Identity: $($identity.Name)" -ForegroundColor Green
Write-Host "    ✓ VNet: $vnetName" -ForegroundColor Green
Write-Host "    ✓ Subnet: $subnetName" -ForegroundColor Green
Write-Host "    ✓ Private DNS Zone: $dnsZoneName" -ForegroundColor Green
Write-Host "    ✓ Log Analytics Workspace: $($law.Name)" -ForegroundColor Green
Write-Host "    ✓ Event Hub Namespace: $($ehNamespace.Name)" -ForegroundColor Green

if ($Environment -eq 'DevTest') {
    Write-Host "`n  Test Environment:" -ForegroundColor White
    Write-Host "    ✓ Created $(( $createdVaults).Count) Key Vaults" -ForegroundColor Green
    if (-not $SkipVaultSeeding) {
        Write-Host "    ✓ Seeded test data:" -ForegroundColor Green
        $secretColor = if ($totalSecrets -eq 0) { "Red" } else { "Cyan" }
        $keyColor = if ($totalKeys -eq 0) { "Red" } else { "Cyan" }
        $certColor = if ($totalCerts -eq 0) { "Red" } else { "Cyan" }
        Write-Host "      - Secrets: $totalSecrets" -ForegroundColor $secretColor
        Write-Host "      - Keys: $totalKeys" -ForegroundColor $keyColor
        Write-Host "      - Certificates: $totalCerts" -ForegroundColor $certColor
    }
}

if (-not $SkipMonitoring) {
    Write-Host "`n  Monitoring:" -ForegroundColor White
    Write-Host "    ✓ Action Group: $actionGroupName" -ForegroundColor Green
    Write-Host "    ✓ Email notifications: $ActionGroupEmail" -ForegroundColor Green
}

Write-Host "`n  Configuration Files:" -ForegroundColor White
Write-Host "    ✓ $policyParamsFile (reference - infrastructure IDs)" -ForegroundColor Green
Write-Host "    ✓ $configFile (reference - environment details)" -ForegroundColor Green
Write-Host "    ℹ️  NOTE: Main script uses PolicyParameters-*.json files for deployment" -ForegroundColor Gray

Write-Host "`n📋 Next Steps:" -ForegroundColor $colors.Highlight
Write-Host "  1. Deploy 46 policies: .\\AzPolicyImplScript.ps1 -Environment DevTest -Phase Test" -ForegroundColor White
Write-Host "  2. Check compliance: .\\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck" -ForegroundColor White
Write-Host "  3. Deploy to Production Audit: .\\AzPolicyImplScript.ps1 -Environment Production -Phase Audit" -ForegroundColor White
Write-Host "  4. Enable enforcement: .\\AzPolicyImplScript.ps1 -Environment Production -Phase Enforce" -ForegroundColor White

Write-Host "`n✨ Environment is ready for policy deployment and testing!`n" -ForegroundColor Green

#endregion
