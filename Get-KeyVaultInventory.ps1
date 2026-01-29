<#
.SYNOPSIS
    Inventories all Azure Key Vaults across all subscriptions with detailed metadata.

.DESCRIPTION
    This script discovers all Azure Key Vaults in accessible subscriptions, retrieves
    configuration details, compliance settings, and exports to CSV format.
    Part of Sprint 1, Story 1.1 - Environment Discovery & Baseline Assessment.

.PARAMETER OutputPath
    Path where the CSV inventory file will be saved. Default: .\KeyVaultInventory.csv

.PARAMETER SubscriptionIds
    Optional array of specific subscription IDs to scan. If not provided, scans all subscriptions.

.PARAMETER IncludeNetworkRules
    If specified, includes network ACL rules for each Key Vault.

.PARAMETER IncludeAccessPolicies
    If specified, includes count of access policies configured on each Key Vault.

.EXAMPLE
    .\Get-KeyVaultInventory.ps1
    
    Generates basic Key Vault inventory across all subscriptions.

.EXAMPLE
    .\Get-KeyVaultInventory.ps1 -IncludeNetworkRules -IncludeAccessPolicies -OutputPath "C:\Reports\KeyVaults.csv"
    
    Generates detailed inventory with network rules and access policy counts.

.EXAMPLE
    .\Get-KeyVaultInventory.ps1 -SubscriptionIds @('sub-id-1', 'sub-id-2')
    
    Scans only specified subscriptions.

.NOTES
    Author: Azure Policy Automation Team
    Created: January 29, 2026
    Version: 1.0
    Requires: Az.Accounts, Az.KeyVault PowerShell modules
    Minimum PowerShell Version: 7.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\KeyVaultInventory-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv",
    
    [Parameter(Mandatory = $false)]
    [string[]]$SubscriptionIds,
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeNetworkRules,
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeAccessPolicies
)

#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.KeyVault

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Helper Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'INFO'    { 'Cyan' }
        'WARN'    { 'Yellow' }
        'ERROR'   { 'Red' }
        'SUCCESS' { 'Green' }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-AzureConnection {
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Log "Not connected to Azure. Please run Connect-AzAccount first." -Level 'ERROR'
            return $false
        }
        
        Write-Log "Connected to Azure as: $($context.Account.Id)" -Level 'SUCCESS'
        Write-Log "Tenant: $($context.Tenant.Id)" -Level 'INFO'
        return $true
    }
    catch {
        Write-Log "Failed to verify Azure connection: $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
}

function Get-NetworkRulesSummary {
    param($KeyVault)
    
    try {
        if ($KeyVault.NetworkAcls) {
            $defaultAction = $KeyVault.NetworkAcls.DefaultAction
            $ipRuleCount = if ($KeyVault.NetworkAcls.IpAddressRanges) { $KeyVault.NetworkAcls.IpAddressRanges.Count } else { 0 }
            $vnetRuleCount = if ($KeyVault.NetworkAcls.VirtualNetworkResourceIds) { $KeyVault.NetworkAcls.VirtualNetworkResourceIds.Count } else { 0 }
            $bypass = $KeyVault.NetworkAcls.Bypass
            
            return "DefaultAction=$defaultAction; IPRules=$ipRuleCount; VNetRules=$vnetRuleCount; Bypass=$bypass"
        }
        return 'No network rules configured'
    }
    catch {
        return 'Error retrieving network rules'
    }
}

function Get-AccessPolicyCount {
    param($KeyVault)
    
    try {
        if ($KeyVault.AccessPolicies) {
            return $KeyVault.AccessPolicies.Count
        }
        return 0
    }
    catch {
        return 'Error'
    }
}

function Get-DiagnosticSettingsStatus {
    param(
        [string]$ResourceId
    )
    
    try {
        # Note: Requires Az.Monitor module which may not be loaded
        # Wrap in try-catch to handle module not available
        $diagSettings = Get-AzDiagnosticSetting -ResourceId $ResourceId -ErrorAction SilentlyContinue
        if ($diagSettings) {
            return "Configured ($($diagSettings.Count) setting(s))"
        }
        return 'Not configured'
    }
    catch {
        return 'Unable to check'
    }
}

#endregion

#region Main Script

Write-Log "=== Azure Key Vault Inventory Script ===" -Level 'INFO'
Write-Log "Sprint 1, Story 1.1 - Environment Discovery & Baseline Assessment" -Level 'INFO'
Write-Log "" -Level 'INFO'

# Verify Azure connection
if (-not (Test-AzureConnection)) {
    Write-Log "Please connect to Azure using Connect-AzAccount and try again." -Level 'ERROR'
    exit 1
}

# Get subscriptions to scan
if ($SubscriptionIds) {
    Write-Log "Scanning specified subscriptions: $($SubscriptionIds.Count)" -Level 'INFO'
    $subscriptions = $SubscriptionIds | ForEach-Object { Get-AzSubscription -SubscriptionId $_ }
}
else {
    Write-Log "Retrieving all subscriptions in tenant..." -Level 'INFO'
    try {
        $subscriptions = Get-AzSubscription -ErrorAction Stop
        Write-Log "Found $($subscriptions.Count) subscription(s)" -Level 'SUCCESS'
    }
    catch {
        Write-Log "Failed to retrieve subscriptions: $($_.Exception.Message)" -Level 'ERROR'
        exit 1
    }
}

# Build Key Vault inventory
$inventory = @()
$totalKeyVaults = 0
$currentSubIndex = 0

foreach ($sub in $subscriptions) {
    $currentSubIndex++
    Write-Log "Processing subscription $currentSubIndex of $($subscriptions.Count): $($sub.Name)" -Level 'INFO'
    
    try {
        # Set context to current subscription
        $contextSet = Set-AzContext -SubscriptionId $sub.Id -ErrorAction SilentlyContinue
        
        if (-not $contextSet) {
            Write-Log "  Skipping - subscription in different tenant (MFA required or no access)" -Level 'WARN'
            continue
        }
        
        # Get all Key Vaults in subscription
        $keyVaults = Get-AzKeyVault -ErrorAction SilentlyContinue
        
        if (-not $keyVaults) {
            Write-Log "  No Key Vaults found in this subscription" -Level 'INFO'
            continue
        }
        
        Write-Log "  Found $($keyVaults.Count) Key Vault(s)" -Level 'SUCCESS'
        $totalKeyVaults += $keyVaults.Count
        
        foreach ($kv in $keyVaults) {
            Write-Log "    Processing: $($kv.VaultName)" -Level 'INFO'
            
            try {
                # Get detailed Key Vault information
                $kvDetails = Get-AzKeyVault -VaultName $kv.VaultName -ResourceGroupName $kv.ResourceGroupName -ErrorAction Stop
                
                # Build inventory item
                $inventoryItem = [PSCustomObject]@{
                    KeyVaultName          = $kvDetails.VaultName
                    SubscriptionName      = $sub.Name
                    SubscriptionId        = $sub.Id
                    ResourceGroupName     = $kvDetails.ResourceGroupName
                    Location              = $kvDetails.Location
                    ResourceId            = $kvDetails.ResourceId
                    VaultUri              = $kvDetails.VaultUri
                    Sku                   = $kvDetails.Sku
                    TenantId              = $kvDetails.TenantId
                    EnabledForDeployment  = $kvDetails.EnabledForDeployment
                    EnabledForDiskEncryption = $kvDetails.EnabledForDiskEncryption
                    EnabledForTemplateDeployment = $kvDetails.EnabledForTemplateDeployment
                    EnableSoftDelete      = $kvDetails.EnableSoftDelete
                    SoftDeleteRetentionInDays = $kvDetails.SoftDeleteRetentionInDays
                    EnablePurgeProtection = $kvDetails.EnablePurgeProtection
                    EnableRbacAuthorization = $kvDetails.EnableRbacAuthorization
                    PublicNetworkAccess   = $kvDetails.PublicNetworkAccess
                    PrivateEndpointConnections = if ($kvDetails.PSObject.Properties.Name -contains 'PrivateEndpointConnections' -and $kvDetails.PrivateEndpointConnections) { $kvDetails.PrivateEndpointConnections.Count } else { 'Not configured' }
                    Tags                  = if ($kvDetails.Tags) { ($kvDetails.Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; ' } else { 'None' }
                }
                
                # Add network rules if requested
                if ($IncludeNetworkRules) {
                    $inventoryItem | Add-Member -NotePropertyName 'NetworkRules' -NotePropertyValue (Get-NetworkRulesSummary -KeyVault $kvDetails)
                }
                
                # Add access policy count if requested
                if ($IncludeAccessPolicies) {
                    $inventoryItem | Add-Member -NotePropertyName 'AccessPolicyCount' -NotePropertyValue (Get-AccessPolicyCount -KeyVault $kvDetails)
                }
                
                # Add diagnostic settings status (requires Az.Monitor)
                $inventoryItem | Add-Member -NotePropertyName 'DiagnosticSettings' -NotePropertyValue (Get-DiagnosticSettingsStatus -ResourceId $kvDetails.ResourceId)
                
                $inventory += $inventoryItem
            }
            catch {
                Write-Log "    Error processing Key Vault $($kv.VaultName): $($_.Exception.Message)" -Level 'ERROR'
                
                # Add error record
                $inventoryItem = [PSCustomObject]@{
                    KeyVaultName          = $kv.VaultName
                    SubscriptionName      = $sub.Name
                    SubscriptionId        = $sub.Id
                    ResourceGroupName     = $kv.ResourceGroupName
                    Location              = $kv.Location
                    ResourceId            = "ERROR: $($_.Exception.Message)"
                    VaultUri              = 'N/A'
                    Sku                   = 'N/A'
                    TenantId              = 'N/A'
                    EnabledForDeployment  = 'N/A'
                    EnabledForDiskEncryption = 'N/A'
                    EnabledForTemplateDeployment = 'N/A'
                    EnableSoftDelete      = 'N/A'
                    SoftDeleteRetentionInDays = 'N/A'
                    EnablePurgeProtection = 'N/A'
                    EnableRbacAuthorization = 'N/A'
                    PublicNetworkAccess   = 'N/A'
                    PrivateEndpointConnections = 'N/A'
                    Tags                  = 'N/A'
                }
                
                if ($IncludeNetworkRules) {
                    $inventoryItem | Add-Member -NotePropertyName 'NetworkRules' -NotePropertyValue 'N/A'
                }
                
                if ($IncludeAccessPolicies) {
                    $inventoryItem | Add-Member -NotePropertyName 'AccessPolicyCount' -NotePropertyValue 'N/A'
                }
                
                $inventoryItem | Add-Member -NotePropertyName 'DiagnosticSettings' -NotePropertyValue 'N/A'
                
                $inventory += $inventoryItem
            }
        }
    }
    catch {
        Write-Log "  Error processing subscription: $($_.Exception.Message)" -Level 'ERROR'
    }
}

# Export to CSV
Write-Log "" -Level 'INFO'
Write-Log "Exporting inventory to: $OutputPath" -Level 'INFO'
try {
    if ($inventory.Count -eq 0) {
        Write-Log "No Key Vaults found in scanned subscriptions!" -Level 'WARN'
        Write-Log "Creating empty CSV file with headers..." -Level 'INFO'
        
        # Create empty object with all properties
        $emptyObject = [PSCustomObject]@{
            KeyVaultName          = ''
            SubscriptionName      = ''
            SubscriptionId        = ''
            ResourceGroupName     = ''
            Location              = ''
            ResourceId            = ''
            VaultUri              = ''
            Sku                   = ''
            TenantId              = ''
            EnabledForDeployment  = ''
            EnabledForDiskEncryption = ''
            EnabledForTemplateDeployment = ''
            EnableSoftDelete      = ''
            SoftDeleteRetentionInDays = ''
            EnablePurgeProtection = ''
            EnableRbacAuthorization = ''
            PublicNetworkAccess   = ''
            PrivateEndpointConnections = ''
            Tags                  = ''
            DiagnosticSettings    = ''
        }
        
        if ($IncludeNetworkRules) {
            $emptyObject | Add-Member -NotePropertyName 'NetworkRules' -NotePropertyValue ''
        }
        
        if ($IncludeAccessPolicies) {
            $emptyObject | Add-Member -NotePropertyName 'AccessPolicyCount' -NotePropertyValue ''
        }
        
        @($emptyObject) | Export-Csv -Path $OutputPath -NoTypeInformation -Force
    }
    else {
        $inventory | Export-Csv -Path $OutputPath -NoTypeInformation -Force
        Write-Log "Export completed successfully!" -Level 'SUCCESS'
        Write-Log "Total Key Vaults inventoried: $($inventory.Count)" -Level 'SUCCESS'
        
        # Display summary statistics
        Write-Log "" -Level 'INFO'
        Write-Log "=== Summary Statistics ===" -Level 'INFO'
        Write-Log "Total Subscriptions Scanned: $($subscriptions.Count)" -Level 'INFO'
        Write-Log "Total Key Vaults Found: $totalKeyVaults" -Level 'INFO'
        
        # Compliance-related statistics (with null-safe counting)
        $softDeleteEnabled = @($inventory | Where-Object { $_.EnableSoftDelete -eq $true }).Count
        $purgeProtectionEnabled = @($inventory | Where-Object { $_.EnablePurgeProtection -eq $true }).Count
        $rbacEnabled = @($inventory | Where-Object { $_.EnableRbacAuthorization -eq $true }).Count
        $publicNetworkDisabled = @($inventory | Where-Object { $_.PublicNetworkAccess -eq 'Disabled' }).Count
        $withPrivateEndpoints = @($inventory | Where-Object { $_.PrivateEndpointConnections -ne 'Not configured' -and $_.PrivateEndpointConnections -ne 'N/A' }).Count
        
        Write-Log "" -Level 'INFO'
        Write-Log "=== Compliance Snapshot ===" -Level 'INFO'
        if ($totalKeyVaults -gt 0) {
            Write-Log "Soft Delete Enabled: $softDeleteEnabled / $totalKeyVaults ($([math]::Round($softDeleteEnabled/$totalKeyVaults*100, 2))%)" -Level 'INFO'
            Write-Log "Purge Protection Enabled: $purgeProtectionEnabled / $totalKeyVaults ($([math]::Round($purgeProtectionEnabled/$totalKeyVaults*100, 2))%)" -Level 'INFO'
            Write-Log "RBAC Authorization Enabled: $rbacEnabled / $totalKeyVaults ($([math]::Round($rbacEnabled/$totalKeyVaults*100, 2))%)" -Level 'INFO'
            Write-Log "Public Network Access Disabled: $publicNetworkDisabled / $totalKeyVaults ($([math]::Round($publicNetworkDisabled/$totalKeyVaults*100, 2))%)" -Level 'INFO'
            Write-Log "Private Endpoints Configured: $withPrivateEndpoints / $totalKeyVaults ($([math]::Round($withPrivateEndpoints/$totalKeyVaults*100, 2))%)" -Level 'INFO'
        }
    }
}
catch {
    Write-Log "Failed to export inventory: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

Write-Log "" -Level 'INFO'
Write-Log "Inventory complete! Review the output file for details." -Level 'SUCCESS'

# Exit with success code
exit 0

#endregion
