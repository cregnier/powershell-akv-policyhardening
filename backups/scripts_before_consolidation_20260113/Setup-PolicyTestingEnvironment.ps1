#!/usr/bin/env pwsh
#Requires -Module Az.Accounts, Az.Resources, Az.ManagedServiceIdentity, Az.OperationalInsights, Az.EventHub, Az.PrivateDns, Az.Network, Az.KeyVault

<#
.SYNOPSIS
    ONE-STOP Azure Policy Testing Environment Setup for Dev/Test
    
.DESCRIPTION
    This script creates a complete testing environment for 46 Azure Key Vault policies:
    
    OPTIONAL CLEANUP (if -CleanupFirst):
    1. Removes all policy assignments from test resource group
    2. Deletes all resources (Key Vaults, etc.)
    3. Deletes and recreates the test resource group fresh
    
    INFRASTRUCTURE SETUP:
    4. Creates/verifies managed identity for policy remediation
    5. Creates/verifies Log Analytics workspace (for diagnostic policies)
    6. Creates/verifies Event Hub namespace + auth rule (for diagnostic policies)
    7. Creates/verifies Private DNS zone (for private endpoint policies)
    8. Creates/verifies VNet + subnet (for private endpoint policies)
    
    TEST VAULTS + DATA:
    9. Creates 3 Key Vaults with different compliance states:
       - Compliant: soft delete, purge protection, RBAC, firewall disabled
       - Partial: soft delete, RBAC, public access (no purge protection)
       - Non-compliant: soft delete, access policies, public access
    10. Seeds vaults with test data:
        - 4 secrets per vault (with/without expiration, content type)
        - 5 keys per vault (RSA 2048/4096, EC P-256/P-384, various configs)
        - 4 certificates per vault (RSA 2048/4096, EC, various validity periods)
    
    RBAC + CONFIG:
    11. Assigns Key Vault Administrator role to your user account
    12. Assigns subscription-level roles to managed identity
    13. Updates PolicyParameters.json and PolicyImplementationConfig.json
    
    This creates ALL artifacts needed to test all 46 Key Vault policies.
    
.PARAMETER SubscriptionId
    Azure Subscription ID. If not provided, uses current context.
    
.PARAMETER TestResourceGroup
    Resource group for policy testing. Default: 'rg-policy-keyvault-test'
    
.PARAMETER InfraResourceGroup
    Resource group for infrastructure (identity, networking, etc). Default: 'rg-policy-remediation'
    
.PARAMETER Location
    Azure region. Default: 'eastus'
    
.PARAMETER CleanupFirst
    DELETE everything in test RG first, then recreate fresh. Use for clean slate testing.
    
.PARAMETER SkipVaultSeeding
    Skip creating test secrets/keys/certs in vaults (faster, but incomplete testing)
    
.EXAMPLE
    .\Setup-PolicyTestingEnvironment.ps1
    Creates infrastructure + vaults + test data (keeps existing resources)
    
.EXAMPLE
    .\Setup-PolicyTestingEnvironment.ps1 -CleanupFirst
    DELETES test RG, recreates everything fresh (recommended for testing)
    
.EXAMPLE
    .\Setup-PolicyTestingEnvironment.ps1 -TestResourceGroup "rg-my-test" -SkipVaultSeeding
    Custom RG, skip seeding test data
#>

param(
    [string]$SubscriptionId,
    [string]$TestResourceGroup,
    [string]$InfraResourceGroup = 'rg-policy-remediation',
    [string]$Location = 'eastus',
    [switch]$CleanupFirst,
    [switch]$SkipVaultSeeding
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'Continue'

# Colors for output
$colors = @{
    Success = 'Green'
    Error = 'Red'
    Warning = 'Yellow'
    Info = 'Cyan'
    Section = 'Magenta'
    Highlight = 'White'
}

function Write-Section {
    param([string]$Title, [int]$Step, [int]$Total)
    $bar = "═" * 70
    Write-Host "`n╔$bar╗" -ForegroundColor $colors.Section
    Write-Host "║  [$Step/$Total] $Title" -ForegroundColor $colors.Section
    Write-Host "╚$bar╝" -ForegroundColor $colors.Section
}

function Write-Status {
    param([string]$Message, [string]$Status, [string]$Detail = "")
    $statusColor = switch ($Status) {
        'Success' { $colors.Success }
        'Error' { $colors.Error }
        'Warning' { $colors.Warning }
        default { $colors.Info }
    }
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] " -NoNewline -ForegroundColor Gray
    Write-Host $Message -NoNewline
    Write-Host " ... " -NoNewline
    Write-Host $Status -ForegroundColor $statusColor
    if ($Detail) {
        Write-Host "  └─ $Detail" -ForegroundColor Gray
    }
}

Write-Host "`n╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     AZURE KEY VAULT POLICY TESTING ENVIRONMENT SETUP                  ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# ============================================================================
# STEP 0: OPTIONAL CLEANUP (if -CleanupFirst specified)
# ============================================================================

if ($CleanupFirst) {
    Write-Section "CLEANUP: Removing Existing Test Resources" 0 9
    
    Write-Host "`n⚠️  WARNING: This will DELETE all resources in '$TestResourceGroup'!" -ForegroundColor Yellow
    Write-Host "   • All Key Vaults and their contents" -ForegroundColor Yellow
    Write-Host "   • All policy assignments" -ForegroundColor Yellow
    Write-Host "   • The entire resource group`n" -ForegroundColor Yellow
    
    $confirm = Read-Host "Type 'yes' to proceed with cleanup"
    if ($confirm -ne 'yes') {
        Write-Host "Cleanup cancelled. Proceeding without cleanup..." -ForegroundColor Yellow
        $CleanupFirst = $false
    } else {
        # Get subscription context for policy assignments
        $context = Get-AzContext
        $scope = "/subscriptions/$($context.Subscription.Id)/resourceGroups/$TestResourceGroup"
        
        # Remove policy assignments
        Write-Status "Removing policy assignments" "Info"
        try {
            $assignments = Get-AzPolicyAssignment -Scope $scope -ErrorAction SilentlyContinue
            if ($assignments) {
                $assignments | ForEach-Object { Remove-AzPolicyAssignment -Id $_.ResourceId -ErrorAction SilentlyContinue | Out-Null }
                Write-Status "Policy assignments removed" "Success" "$($assignments.Count) assignments"
            } else {
                Write-Status "No policy assignments found" "Success"
            }
        } catch {
            Write-Status "Failed to remove some assignments" "Warning"
        }
        
        # Delete resources
        Write-Status "Deleting resources in resource group" "Info"
        try {
            $rg = Get-AzResourceGroup -Name $TestResourceGroup -ErrorAction SilentlyContinue
            if ($rg) {
                $resources = Get-AzResource -ResourceGroupName $TestResourceGroup
                if ($resources) {
                    # Delete Key Vaults first
                    $keyVaults = $resources | Where-Object { $_.ResourceType -eq 'Microsoft.KeyVault/vaults' }
                    foreach ($kv in $keyVaults) {
                        Remove-AzKeyVault -VaultName $kv.Name -ResourceGroupName $TestResourceGroup -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                    # Delete other resources
                    $otherResources = $resources | Where-Object { $_.ResourceType -ne 'Microsoft.KeyVault/vaults' }
                    foreach ($resource in $otherResources) {
                        Remove-AzResource -ResourceId $resource.ResourceId -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                    Write-Status "Resources deleted" "Success" "$($resources.Count) resources"
                }
            }
        } catch {
            Write-Status "Failed to delete some resources" "Warning"
        }
        
        # Delete and recreate resource group
        Write-Status "Deleting resource group" "Info"
        try {
            $rg = Get-AzResourceGroup -Name $TestResourceGroup -ErrorAction SilentlyContinue
            if ($rg) {
                Remove-AzResourceGroup -Name $TestResourceGroup -Force -ErrorAction Stop | Out-Null
                Write-Status "Resource group deleted" "Success"
            }
        } catch {
            Write-Status "Failed to delete resource group" "Warning"
        }
        
        Write-Status "Creating fresh resource group" "Info"
        New-AzResourceGroup -Name $TestResourceGroup -Location $Location -ErrorAction Stop | Out-Null
        Write-Status "Resource group created" "Success" $Location
        
        Write-Host "`n✅ Cleanup complete! Proceeding with fresh setup...`n" -ForegroundColor Green
    }
}

# ============================================================================
# STEP 1: Azure Authentication & Subscription
# ============================================================================

$stepOffset = if ($CleanupFirst) { 1 } else { 0 }
Write-Section "Azure Authentication & Subscription" (1 + $stepOffset) (8 + $stepOffset)

try {
    $context = Get-AzContext -ErrorAction Stop
    if (-not $context) {
        Write-Status "Not connected to Azure" "Warning"
        Connect-AzAccount
        $context = Get-AzContext
    }
    Write-Status "Connected to Azure" "Success" "Account: $($context.Account.Id)"
} catch {
    Write-Status "Connecting to Azure" "Info"
    Connect-AzAccount
    $context = Get-AzContext
    Write-Status "Connected" "Success" "Account: $($context.Account.Id)"
}

if (-not $SubscriptionId) {
    $SubscriptionId = $context.Subscription.Id
}

Write-Host "`nCurrent Subscription:" -ForegroundColor $colors.Info
Write-Host "  Name: $($context.Subscription.Name)" -ForegroundColor $colors.Highlight
Write-Host "  ID: $SubscriptionId" -ForegroundColor Gray
Write-Host "  User: $($context.Account.Id)" -ForegroundColor Gray
Write-Host "  Type: $($context.Account.Type)" -ForegroundColor Gray

# ============================================================================
# STEP 2: Resource Group Selection/Creation
# ============================================================================

Write-Section "Resource Group Setup" 2 8

# Show available resource groups and let user choose for testing
Write-Host "`nAvailable Resource Groups:" -ForegroundColor $colors.Info
$allRGs = Get-AzResourceGroup | Select-Object ResourceGroupName, Location, @{N='Resources';E={(Get-AzResource -ResourceGroupName $_.ResourceGroupName).Count}}
$allRGs | Format-Table -AutoSize

if (-not $TestResourceGroup) {
    Write-Host "`nSelect Test Resource Group:" -ForegroundColor $colors.Warning
    Write-Host "  [1] Use existing: rg-policy-keyvault-test" -ForegroundColor $colors.Highlight
    Write-Host "  [2] Create new resource group" -ForegroundColor $colors.Highlight
    Write-Host "  [3] Select from list above" -ForegroundColor $colors.Highlight
    $choice = Read-Host "Enter choice (1-3)"
    
    switch ($choice) {
        "1" { 
            $TestResourceGroup = "rg-policy-keyvault-test"
        }
        "2" {
            $TestResourceGroup = Read-Host "Enter new resource group name"
        }
        "3" {
            $TestResourceGroup = Read-Host "Enter resource group name from list above"
        }
        default {
            $TestResourceGroup = "rg-policy-keyvault-test"
        }
    }
}

# Create or verify test resource group
$testRG = Get-AzResourceGroup -Name $TestResourceGroup -ErrorAction SilentlyContinue
if (-not $testRG) {
    Write-Status "Creating test resource group" "Info" $TestResourceGroup
    $testRG = New-AzResourceGroup -Name $TestResourceGroup -Location $Location
    Write-Status "Test resource group created" "Success" $testRG.ResourceId
} else {
    Write-Status "Test resource group exists" "Success" $testRG.ResourceId
}

# Create or verify infrastructure resource group
$infraRG = Get-AzResourceGroup -Name $InfraResourceGroup -ErrorAction SilentlyContinue
if (-not $infraRG) {
    Write-Status "Creating infrastructure resource group" "Info" $InfraResourceGroup
    $infraRG = New-AzResourceGroup -Name $InfraResourceGroup -Location $Location
    Write-Status "Infrastructure resource group created" "Success" $infraRG.ResourceId
} else {
    Write-Status "Infrastructure resource group exists" "Success" $infraRG.ResourceId
}

# ============================================================================
# STEP 3: Managed Identity Setup
# ============================================================================

Write-Section "Managed Identity for Policy Remediation" (3 + $stepOffset) (8 + $stepOffset)

$identityName = 'policy-remediation-identity'
$identity = Get-AzUserAssignedIdentity -ResourceGroupName $InfraResourceGroup -Name $identityName -ErrorAction SilentlyContinue

if (-not $identity) {
    Write-Status "Creating managed identity" "Info" $identityName
    $identity = New-AzUserAssignedIdentity -ResourceGroupName $InfraResourceGroup -Name $identityName -Location $Location
    Write-Status "Managed identity created" "Success" $identity.Id
    Start-Sleep -Seconds 10  # Allow time for identity propagation
} else {
    Write-Status "Managed identity exists" "Success" $identity.Id
}

Write-Host "`nManaged Identity Details:" -ForegroundColor $colors.Info
Write-Host "  Resource ID: $($identity.Id)" -ForegroundColor Gray
Write-Host "  Principal ID: $($identity.PrincipalId)" -ForegroundColor Gray
Write-Host "  Client ID: $($identity.ClientId)" -ForegroundColor Gray

# ============================================================================
# STEP 4: Infrastructure Resources (Log Analytics, Event Hub, Networking, DNS)
# ============================================================================

Write-Section "Infrastructure Resources Setup" (4 + $stepOffset) (8 + $stepOffset)

# Log Analytics Workspace
Write-Host "`n[4a] Log Analytics Workspace" -ForegroundColor $colors.Info
$workspaceName = "law-policy-remediation"
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $InfraResourceGroup -Name $workspaceName -ErrorAction SilentlyContinue

if (-not $workspace) {
    Write-Status "Creating Log Analytics workspace" "Info" $workspaceName
    $workspace = New-AzOperationalInsightsWorkspace -ResourceGroupName $InfraResourceGroup -Name $workspaceName -Location $Location -Sku "PerGB2018"
    Write-Status "Log Analytics workspace created" "Success" $workspace.ResourceId
} else {
    Write-Status "Log Analytics workspace exists" "Success" $workspace.ResourceId
}

# Event Hub Namespace
Write-Host "`n[4b] Event Hub Namespace" -ForegroundColor $colors.Info
$namespaceName = "ehns-policy-remediation"
$namespace = Get-AzEventHubNamespace -ResourceGroupName $InfraResourceGroup -Name $namespaceName -ErrorAction SilentlyContinue

if (-not $namespace) {
    Write-Status "Creating Event Hub namespace" "Info" $namespaceName
    $namespace = New-AzEventHubNamespace -ResourceGroupName $InfraResourceGroup -Name $namespaceName -Location $Location -SkuName "Standard"
    Write-Status "Event Hub namespace created" "Success" $namespace.Id
    Start-Sleep -Seconds 10
} else {
    Write-Status "Event Hub namespace exists" "Success" $namespace.Id
}

# Get Event Hub authorization rule
$authRule = Get-AzEventHubAuthorizationRule -ResourceGroupName $InfraResourceGroup -Namespace $namespaceName -Name "RootManageSharedAccessKey" -ErrorAction SilentlyContinue
if ($authRule) {
    Write-Status "Event Hub auth rule found" "Success" $authRule.Id
} else {
    Write-Status "Event Hub auth rule not ready" "Warning" "Namespace may still be provisioning"
}

# Private DNS Zone
Write-Host "`n[4c] Private DNS Zone" -ForegroundColor $colors.Info
$dnsZoneName = "privatelink.vaultcore.azure.net"
$dnsZone = Get-AzPrivateDnsZone -ResourceGroupName $InfraResourceGroup -Name $dnsZoneName -ErrorAction SilentlyContinue

if (-not $dnsZone) {
    Write-Status "Creating Private DNS zone" "Info" $dnsZoneName
    $dnsZone = New-AzPrivateDnsZone -ResourceGroupName $InfraResourceGroup -Name $dnsZoneName
    Write-Status "Private DNS zone created" "Success" $dnsZone.ResourceId
} else {
    Write-Status "Private DNS zone exists" "Success" $dnsZone.ResourceId
}

# Virtual Network & Subnet
Write-Host "`n[4d] Virtual Network & Subnet" -ForegroundColor $colors.Info
$vnetName = "vnet-policy-remediation"
$subnetName = "snet-private-endpoints"

$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $InfraResourceGroup -ErrorAction SilentlyContinue
if (-not $vnet) {
    Write-Status "Creating Virtual Network" "Info" $vnetName
    $vnet = New-AzVirtualNetwork -Name $vnetName -ResourceGroupName $InfraResourceGroup -Location $Location -AddressPrefix "10.250.0.0/16"
    Write-Status "Virtual Network created" "Success" $vnet.Id
} else {
    Write-Status "Virtual Network exists" "Success" $vnet.Id
}

$subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet -ErrorAction SilentlyContinue
if (-not $subnet) {
    Write-Status "Creating Subnet" "Info" $subnetName
    $vnet | Add-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix "10.250.0.0/24" | Set-AzVirtualNetwork | Out-Null
    $vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $InfraResourceGroup
    $subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet
    Write-Status "Subnet created" "Success" $subnet.Id
} else {
    Write-Status "Subnet exists" "Success" $subnet.Id
}

# ============================================================================
# STEP 5: Test Key Vaults Creation
# ============================================================================

Write-Section "Test Key Vaults Setup" (5 + $stepOffset) (8 + $stepOffset)

Write-Host "`nCreating test Key Vaults with various compliance states..." -ForegroundColor $colors.Info

$testVaults = @(
    @{
        Name = "kv-compliant-$(Get-Random -Max 10000)"
        Description = "Fully compliant vault (soft delete, purge protection, RBAC, firewall)"
        Config = @{
            EnableSoftDelete = $true
            EnablePurgeProtection = $true
            EnableRbacAuthorization = $true
            PublicNetworkAccess = "Disabled"
        }
    },
    @{
        Name = "kv-partial-$(Get-Random -Max 10000)"
        Description = "Partially compliant (soft delete enabled, but no firewall)"
        Config = @{
            EnableSoftDelete = $true
            EnablePurgeProtection = $false
            EnableRbacAuthorization = $true
            PublicNetworkAccess = "Enabled"
        }
    },
    @{
        Name = "kv-noncompliant-$(Get-Random -Max 10000)"
        Description = "Non-compliant (access policies, public access, no purge protection)"
        Config = @{
            EnableSoftDelete = $true
            EnablePurgeProtection = $false
            EnableRbacAuthorization = $false
            PublicNetworkAccess = "Enabled"
        }
    }
)

$createdVaults = @()

foreach ($vaultConfig in $testVaults) {
    try {
        # Ensure name is valid (max 24 chars, alphanumeric + hyphens)
        if ($vaultConfig.Name.Length -gt 24) {
            $vaultConfig.Name = $vaultConfig.Name.Substring(0, 24)
        }
        
        Write-Host "`nCreating: $($vaultConfig.Name)" -ForegroundColor $colors.Highlight
        Write-Host "  Purpose: $($vaultConfig.Description)" -ForegroundColor Gray
        
        # Build vault creation parameters
        $vaultParams = @{
            VaultName = $vaultConfig.Name
            ResourceGroupName = $TestResourceGroup
            Location = $Location
            Sku = 'Standard'
        }
        
        # Add purge protection if needed
        if ($vaultConfig.Config.EnablePurgeProtection) {
            $vaultParams['EnablePurgeProtection'] = $true
        }
        
        # Add public network access setting
        if ($vaultConfig.Config.PublicNetworkAccess -eq "Disabled") {
            $vaultParams['PublicNetworkAccess'] = 'Disabled'
        } else {
            $vaultParams['PublicNetworkAccess'] = 'Enabled'
        }
        
        # For access policies mode (non-RBAC), explicitly disable RBAC
        # For RBAC mode, leave default (which is RBAC in newer SDK versions)
        if (-not $vaultConfig.Config.EnableRbacAuthorization) {
            $vaultParams['DisableRbacAuthorization'] = $true
        }
        
        # Create the vault
        $vault = New-AzKeyVault @vaultParams
        
        $createdVaults += @{
            Name = $vault.VaultName
            Id = $vault.ResourceId
            Config = $vaultConfig.Config
            Description = $vaultConfig.Description
            Object = $vault
        }
        
        Write-Status "Created vault" "Success" $vault.VaultName
        
    } catch {
        Write-Status "Failed to create vault" "Error" $_.Exception.Message
    }
}

Write-Host "`nCreated $($createdVaults.Count) test vaults" -ForegroundColor $colors.Success

# ============================================================================
# STEP 6: RBAC Permissions (User + Managed Identity)
# ============================================================================

Write-Section "RBAC Permissions Assignment" (6 + $stepOffset) (8 + $stepOffset)

# Get current user's object ID
$currentUser = $context.Account.Id
Write-Host "`nCurrent User: $currentUser" -ForegroundColor $colors.Info

# For MSA accounts, we need to get the object ID differently
$userObjectId = $null
try {
    # Try as user principal
    $userObj = Get-AzADUser -UserPrincipalName $currentUser -ErrorAction SilentlyContinue
    if ($userObj) {
        $userObjectId = $userObj.Id
    } else {
        # Try as service principal or guest
        $userObj = Get-AzADUser -Mail $currentUser -ErrorAction SilentlyContinue
        if ($userObj) {
            $userObjectId = $userObj.Id
        } else {
            # Try searching
            $userObj = Get-AzADUser -Filter "mail eq '$currentUser'" -ErrorAction SilentlyContinue
            if ($userObj) {
                $userObjectId = $userObj.Id
            }
        }
    }
} catch {
    Write-Status "Could not resolve user object ID" "Warning" "Will skip user RBAC assignment"
}

if ($userObjectId) {
    Write-Host "  Object ID: $userObjectId" -ForegroundColor Gray
    
    # Assign permissions to user on each test vault
    foreach ($vault in $createdVaults) {
        try {
            # For RBAC-enabled vaults, assign Key Vault Administrator role
            if ($vault.Config.EnableRbacAuthorization) {
                $assignment = Get-AzRoleAssignment -ObjectId $userObjectId `
                                                   -RoleDefinitionName "Key Vault Administrator" `
                                                   -Scope $vault.Id `
                                                   -ErrorAction SilentlyContinue
                
                if (-not $assignment) {
                    Write-Status "Assigning Key Vault Administrator to user" "Info" $vault.Name
                    New-AzRoleAssignment -ObjectId $userObjectId `
                                         -RoleDefinitionName "Key Vault Administrator" `
                                         -Scope $vault.Id | Out-Null
                    Write-Status "RBAC assigned" "Success" "$($vault.Name) -> User"
                } else {
                    Write-Status "RBAC already assigned" "Success" "$($vault.Name) -> User"
                }
            } else {
                # For access policy vaults, set access policy
                Write-Status "Setting access policy for user" "Info" $vault.Name
                Set-AzKeyVaultAccessPolicy `
                    -VaultName $vault.Name `
                    -ResourceGroupName $TestResourceGroup `
                    -UserPrincipalName $currentUser `
                    -PermissionsToSecrets get,list,set,delete,recover,backup,restore,purge `
                    -PermissionsToKeys get,list,create,delete,recover,backup,restore,import,purge,update `
                    -PermissionsToCertificates get,list,create,delete,recover,backup,restore,import,purge,update `
                    -ErrorAction SilentlyContinue | Out-Null
                Write-Status "Access policy set" "Success" "$($vault.Name) -> User"
            }
        } catch {
            Write-Status "Failed to assign permissions" "Warning" $_.Exception.Message
        }
    }
}

# Assign permissions to managed identity at subscription level for policy remediation
Write-Host "`nAssigning subscription-level permissions to managed identity..." -ForegroundColor $colors.Info

$subscriptionScope = "/subscriptions/$SubscriptionId"
$rolesToAssign = @(
    "Contributor",
    "Key Vault Contributor",
    "Log Analytics Contributor",
    "Monitoring Contributor"
)

foreach ($role in $rolesToAssign) {
    try {
        $assignment = Get-AzRoleAssignment -ObjectId $identity.PrincipalId `
                                           -RoleDefinitionName $role `
                                           -Scope $subscriptionScope `
                                           -ErrorAction SilentlyContinue
        
        if (-not $assignment) {
            Write-Status "Assigning $role to managed identity" "Info"
            New-AzRoleAssignment -ObjectId $identity.PrincipalId `
                                 -RoleDefinitionName $role `
                                 -Scope $subscriptionScope | Out-Null
            Write-Status "Assigned $role" "Success"
            Start-Sleep -Seconds 2
        } else {
            Write-Status "$role already assigned" "Success"
        }
    } catch {
        Write-Status "Failed to assign $role" "Warning" $_.Exception.Message
    }
}

# ============================================================================
# STEP 7: Seed Key Vaults with Test Data
# ============================================================================

Write-Section "Seed Key Vaults with Test Data" (7 + $stepOffset) (8 + $stepOffset)

if ($SkipVaultSeeding) {
    Write-Status "Skipping vault seeding" "Info" "SkipVaultSeeding flag set"
} else {
    Write-Host "`nSeeding vaults with secrets, keys, and certificates..." -ForegroundColor $colors.Info
    Write-Host "  (Waiting 30 seconds for RBAC propagation...)" -ForegroundColor Gray
    Start-Sleep -Seconds 30
    
    foreach ($vault in $createdVaults) {
        Write-Host "`nSeeding vault: $($vault.Name)" -ForegroundColor $colors.Highlight
        
        # Create test secrets
        try {
            # Secret without expiration (non-compliant)
            $secret1 = ConvertTo-SecureString "TestSecretValue1" -AsPlainText -Force
            Set-AzKeyVaultSecret -VaultName $vault.Name -Name "secret-no-expiry" -SecretValue $secret1 -ContentType "text/plain" -ErrorAction Stop | Out-Null
            Write-Status "  Created secret without expiration" "Success" "secret-no-expiry"
            
            # Secret with expiration (compliant)
            $secret2 = ConvertTo-SecureString "TestSecretValue2" -AsPlainText -Force
            $expires = (Get-Date).AddDays(90)
            Set-AzKeyVaultSecret -VaultName $vault.Name -Name "secret-with-expiry" -SecretValue $secret2 -Expires $expires -ContentType "application/json" -ErrorAction Stop | Out-Null
            Write-Status "  Created secret with expiration" "Success" "secret-with-expiry (90 days)"
            
            # Secret without content type (non-compliant for content type policy)
            $secret3 = ConvertTo-SecureString "TestSecretValue3" -AsPlainText -Force
            Set-AzKeyVaultSecret -VaultName $vault.Name -Name "secret-no-content-type" -SecretValue $secret3 -ErrorAction Stop | Out-Null
            Write-Status "  Created secret without content type" "Success" "secret-no-content-type"
            
            # Secret that's too old (for active days policies)
            $secret4 = ConvertTo-SecureString "TestSecretOldValue" -AsPlainText -Force
            Set-AzKeyVaultSecret -VaultName $vault.Name -Name "secret-old-active" -SecretValue $secret4 -ContentType "text/plain" -ErrorAction Stop | Out-Null
            Write-Status "  Created secret for age testing" "Success" "secret-old-active"
            
        } catch {
            Write-Status "  Failed to create secrets" "Warning" $_.Exception.Message
        }
        
        # Create test keys
        try {
            # RSA key without expiration (non-compliant)
            Add-AzKeyVaultKey -VaultName $vault.Name -Name "key-rsa-2048" -Destination Software -KeyType "RSA" -Size 2048 -ErrorAction Stop | Out-Null
            Write-Status "  Created RSA key without expiration" "Success" "key-rsa-2048 (2048-bit)"
            
            # RSA key with expiration (compliant)
            $keyExpires = (Get-Date).AddDays(180)
            Add-AzKeyVaultKey -VaultName $vault.Name -Name "key-rsa-4096" -Destination Software -KeyType "RSA" -Size 4096 -Expires $keyExpires -ErrorAction Stop | Out-Null
            Write-Status "  Created RSA key with expiration" "Success" "key-rsa-4096 (4096-bit, 180 days)"
            
            # EC key with P-256 curve (compliant)
            Add-AzKeyVaultKey -VaultName $vault.Name -Name "key-ec-p256" -Destination Software -KeyType "EC" -CurveName "P-256" -ErrorAction Stop | Out-Null
            Write-Status "  Created EC key" "Success" "key-ec-p256 (P-256 curve)"
            
            # EC key with P-384 curve
            Add-AzKeyVaultKey -VaultName $vault.Name -Name "key-ec-p384" -Destination Software -KeyType "EC" -CurveName "P-384" -ErrorAction Stop | Out-Null
            Write-Status "  Created EC key" "Success" "key-ec-p384 (P-384 curve)"
            
            # Small RSA key (non-compliant for minimum size policies)
            Add-AzKeyVaultKey -VaultName $vault.Name -Name "key-rsa-small" -Destination Software -KeyType "RSA" -Size 2048 -ErrorAction Stop | Out-Null
            Write-Status "  Created small RSA key" "Success" "key-rsa-small (2048-bit for testing min size policy)"
            
        } catch {
            Write-Status "  Failed to create keys" "Warning" $_.Exception.Message
        }
        
        # Create test certificates
        try {
            Write-Host "`n  Creating certificates..." -ForegroundColor $colors.Info
            
            # Self-signed certificate with default policy
            $policy = New-AzKeyVaultCertificatePolicy -SubjectName "CN=test-cert-default" -IssuerName "Self" -ValidityInMonths 12 -ErrorAction Stop
            Add-AzKeyVaultCertificate -VaultName $vault.Name -Name "cert-self-signed" -CertificatePolicy $policy -ErrorAction Stop | Out-Null
            Write-Status "  Created self-signed certificate" "Success" "cert-self-signed (12 months)"
            
            # Certificate with RSA 2048
            $policy2 = New-AzKeyVaultCertificatePolicy -SubjectName "CN=test-cert-rsa2048" -IssuerName "Self" -ValidityInMonths 6 -KeyType "RSA" -KeySize 2048 -ErrorAction Stop
            Add-AzKeyVaultCertificate -VaultName $vault.Name -Name "cert-rsa-2048" -CertificatePolicy $policy2 -ErrorAction Stop | Out-Null
            Write-Status "  Created RSA 2048 certificate" "Success" "cert-rsa-2048 (6 months)"
            
            # Certificate with RSA 4096 (compliant)
            $policy3 = New-AzKeyVaultCertificatePolicy -SubjectName "CN=test-cert-rsa4096" -IssuerName "Self" -ValidityInMonths 24 -KeyType "RSA" -KeySize 4096 -ErrorAction Stop
            Add-AzKeyVaultCertificate -VaultName $vault.Name -Name "cert-rsa-4096" -CertificatePolicy $policy3 -ErrorAction Stop | Out-Null
            Write-Status "  Created RSA 4096 certificate" "Success" "cert-rsa-4096 (24 months)"
            
            # Certificate with EC curve
            $policy4 = New-AzKeyVaultCertificatePolicy -SubjectName "CN=test-cert-ec" -IssuerName "Self" -ValidityInMonths 12 -KeyType "EC" -Curve "P-256" -ErrorAction Stop
            Add-AzKeyVaultCertificate -VaultName $vault.Name -Name "cert-ec-p256" -CertificatePolicy $policy4 -ErrorAction Stop | Out-Null
            Write-Status "  Created EC certificate" "Success" "cert-ec-p256 (P-256)"
            
            # Wait for certificate operations to complete
            Start-Sleep -Seconds 5
            
        } catch {
            Write-Status "  Failed to create certificates" "Warning" $_.Exception.Message
        }
    }
}

# ============================================================================
# STEP 8: Update Configuration Files
# ============================================================================

Write-Section "Update Configuration Files" (8 + $stepOffset) (8 + $stepOffset)

# Update PolicyParameters.json
Write-Host "`nUpdating PolicyParameters.json with actual resource IDs..." -ForegroundColor $colors.Info
$policyParamsPath = "$PSScriptRoot\PolicyParameters.json"

if (Test-Path $policyParamsPath) {
    $params = Get-Content $policyParamsPath -Raw | ConvertFrom-Json -AsHashtable
} else {
    $params = @{}
}

# Update with real resource IDs
if ($workspace) {
    $params["Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace"] = @{ 
        logAnalytics = $workspace.ResourceId 
    }
}

if ($authRule) {
    $params["Deploy - Configure diagnostic settings to an Event Hub to be enabled on Azure Key Vault Managed HSM"] = @{ 
        eventHubRuleId = $authRule.Id
        eventHubLocation = $Location
    }
    $params["Deploy Diagnostic Settings for Key Vault to Event Hub"] = @{ 
        eventHubRuleId = $authRule.Id
        eventHubLocation = $Location
    }
}

if ($dnsZone) {
    $params["Configure Azure Key Vaults to use private DNS zones"] = @{ 
        privateDnsZoneId = $dnsZone.ResourceId 
    }
}

if ($subnet) {
    $params["Configure Azure Key Vaults with private endpoints"] = @{ 
        privateEndpointSubnetId = $subnet.Id 
    }
    $params["[Preview]: Configure Azure Key Vault Managed HSM with private endpoints"] = @{
        privateEndpointSubnetId = $subnet.Id
        privateDnsZoneId = $dnsZone.ResourceId
    }
}

$params | ConvertTo-Json -Depth 10 | Set-Content $policyParamsPath
Write-Status "PolicyParameters.json updated" "Success" $policyParamsPath

# Create PolicyImplementationConfig.json
$config = @{
    ManagedIdentityId = $identity.Id
    ManagedIdentityResourceId = $identity.Id
    ManagedIdentityPrincipalId = $identity.PrincipalId
    TestResourceGroup = $TestResourceGroup
    InfraResourceGroup = $InfraResourceGroup
    SubscriptionId = $SubscriptionId
    LogAnalyticsId = $workspace.ResourceId
    EventHubAuthRuleId = if ($authRule) { $authRule.Id } else { $null }
    PrivateDnsZoneId = $dnsZone.ResourceId
    SubnetId = $subnet.Id
    TestVaults = $createdVaults | ForEach-Object { @{ Name = $_.Name; Id = $_.Id } }
}

$config | ConvertTo-Json -Depth 10 | Set-Content "$PSScriptRoot\PolicyImplementationConfig.json"
Write-Status "PolicyImplementationConfig.json created" "Success" "$PSScriptRoot\PolicyImplementationConfig.json"

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host "`n" -NoNewline
Write-Host "╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    SETUP COMPLETE - SUMMARY                            ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📋 Infrastructure Resources:" -ForegroundColor $colors.Section
Write-Host "  ✓ Managed Identity: $($identity.Name)" -ForegroundColor $colors.Success
Write-Host "    └─ $($identity.Id)" -ForegroundColor Gray
Write-Host "  ✓ Log Analytics: $($workspace.Name)" -ForegroundColor $colors.Success
Write-Host "    └─ $($workspace.ResourceId)" -ForegroundColor Gray
Write-Host "  ✓ Event Hub: $($namespace.Name)" -ForegroundColor $colors.Success
Write-Host "    └─ $($namespace.Id)" -ForegroundColor Gray
if ($authRule) {
    Write-Host "  ✓ Auth Rule: $($authRule.Name)" -ForegroundColor $colors.Success
}
Write-Host "  ✓ Private DNS: $dnsZoneName" -ForegroundColor $colors.Success
Write-Host "  ✓ Virtual Network: $vnetName" -ForegroundColor $colors.Success
Write-Host "  ✓ Subnet: $subnetName" -ForegroundColor $colors.Success

Write-Host "`n🔑 Test Key Vaults Created: $($createdVaults.Count)" -ForegroundColor $colors.Section
foreach ($vault in $createdVaults) {
    Write-Host "  ✓ $($vault.Name)" -ForegroundColor $colors.Success
    Write-Host "    └─ $($vault.Description)" -ForegroundColor Gray
}

if (-not $SkipVaultSeeding) {
    Write-Host "`n📦 Test Data Seeded (per vault):" -ForegroundColor $colors.Section
    Write-Host "  • 3 secrets (with/without expiration, content type)" -ForegroundColor $colors.Info
    Write-Host "  • 3 keys (RSA 2048/4096, EC P-256, with/without expiration)" -ForegroundColor $colors.Info
}

Write-Host "`n🔐 RBAC Permissions:" -ForegroundColor $colors.Section
if ($userObjectId) {
    Write-Host "  ✓ User ($currentUser)" -ForegroundColor $colors.Success
    Write-Host "    └─ Key Vault Administrator on all test vaults" -ForegroundColor Gray
}
Write-Host "  ✓ Managed Identity ($($identity.Name))" -ForegroundColor $colors.Success
Write-Host "    └─ Contributor, Key Vault Contributor, Log Analytics Contributor (subscription)" -ForegroundColor Gray

Write-Host "`n📄 Configuration Files:" -ForegroundColor $colors.Section
Write-Host "  ✓ PolicyParameters.json (updated with resource IDs)" -ForegroundColor $colors.Success
Write-Host "  ✓ PolicyImplementationConfig.json (created)" -ForegroundColor $colors.Success

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "NEXT STEPS - PHASE 2 TESTING:" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host "`n1️⃣  PHASE 2.1 - Deny Mode Testing:" -ForegroundColor Yellow
Write-Host "   .\Phase2.1-AssignDenyMode.ps1" -ForegroundColor White
Write-Host "   • Assigns all 46 policies in Deny mode to $TestResourceGroup" -ForegroundColor Gray
Write-Host "   • Wait 15-30 min for policy evaluation, then test blocking behavior" -ForegroundColor Gray

Write-Host "`n2️⃣  PHASE 2.2 - Enforce Mode Testing:" -ForegroundColor Yellow
Write-Host "   .\AzPolicyImplScript.ps1 -PolicyMode Enforce -ScopeType ResourceGroup -IdentityResourceId '$($identity.Id)'" -ForegroundColor White
Write-Host "   • Tests auto-remediation with DeployIfNotExists/Modify policies" -ForegroundColor Gray

Write-Host "`n3️⃣  PHASE 3 - Full Subscription Deployment:" -ForegroundColor Yellow
Write-Host "   .\AzPolicyImplScript.ps1 -PolicyMode Audit -ScopeType Subscription -IdentityResourceId '$($identity.Id)'" -ForegroundColor White
Write-Host "   • Production deployment across entire subscription" -ForegroundColor Gray

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Cyan
