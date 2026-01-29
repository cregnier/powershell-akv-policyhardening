<#
.SYNOPSIS
    Discovers and inventories all Azure Policy assignments across subscriptions.

.DESCRIPTION
    This script enumerates Azure Policy assignments to identify existing governance controls,
    potential conflicts with Key Vault policies, and compliance requirements.
    Part of Sprint 1, Story 1.1 - Environment Discovery & Baseline Assessment.

.PARAMETER OutputPath
    Path where the CSV inventory file will be saved. Default: .\PolicyAssignmentInventory.csv

.PARAMETER SubscriptionIds
    Optional array of specific subscription IDs to scan. If not provided, scans all subscriptions.

.PARAMETER FilterByKeyVault
    If specified, only includes policy assignments related to Key Vault (name contains 'key', 'vault', 'kv').

.PARAMETER IncludeParameters
    If specified, includes policy parameter values in the export (can be lengthy).

.EXAMPLE
    .\Get-PolicyAssignmentInventory.ps1
    
    Generates inventory of all policy assignments across all subscriptions.

.EXAMPLE
    .\Get-PolicyAssignmentInventory.ps1 -FilterByKeyVault -OutputPath "C:\Reports\KeyVaultPolicies.csv"
    
    Generates inventory of only Key Vault-related policy assignments.

.EXAMPLE
    .\Get-PolicyAssignmentInventory.ps1 -SubscriptionIds @('sub-id-1') -IncludeParameters
    
    Scans specific subscription with detailed parameter information.

.NOTES
    Author: Azure Policy Automation Team
    Created: January 29, 2026
    Version: 1.0
    Requires: Az.Accounts, Az.Resources PowerShell modules
    Minimum PowerShell Version: 7.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\PolicyAssignmentInventory-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv",
    
    [Parameter(Mandatory = $false)]
    [string[]]$SubscriptionIds,
    
    [Parameter(Mandatory = $false)]
    [switch]$FilterByKeyVault,
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeParameters
)

#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources

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

function Test-KeyVaultRelated {
    param([string]$Name, [string]$DisplayName, [string]$Description)
    
    $keyVaultTerms = @('key vault', 'keyvault', 'key-vault', 'kv-', ' kv ', 'vault')
    
    $searchText = "$Name $DisplayName $Description".ToLower()
    
    foreach ($term in $keyVaultTerms) {
        if ($searchText -like "*$term*") {
            return $true
        }
    }
    
    return $false
}

function Get-PolicyDefinitionDetails {
    param([string]$PolicyDefinitionId)
    
    try {
        $definition = Get-AzPolicyDefinition -Id $PolicyDefinitionId -ErrorAction SilentlyContinue
        if ($definition) {
            return @{
                DisplayName = $definition.Properties.DisplayName
                Description = $definition.Properties.Description
                PolicyType  = $definition.Properties.PolicyType
                Mode        = $definition.Properties.Mode
                Category    = $definition.Properties.Metadata.category
            }
        }
    }
    catch {
        # Silently handle errors - may not have access to definition
    }
    
    return @{
        DisplayName = 'Unable to retrieve'
        Description = 'Unable to retrieve'
        PolicyType  = 'Unknown'
        Mode        = 'Unknown'
        Category    = 'Unknown'
    }
}

function Get-ParametersSummary {
    param($Parameters)
    
    if (-not $Parameters) {
        return 'No parameters'
    }
    
    try {
        $paramCount = ($Parameters.PSObject.Properties | Measure-Object).Count
        $paramNames = ($Parameters.PSObject.Properties | ForEach-Object { $_.Name }) -join ', '
        
        if ($paramNames.Length -gt 100) {
            $paramNames = $paramNames.Substring(0, 97) + '...'
        }
        
        return "Count=$paramCount; Names=$paramNames"
    }
    catch {
        return 'Error parsing parameters'
    }
}

function Get-ParametersDetailed {
    param($Parameters)
    
    if (-not $Parameters) {
        return 'No parameters'
    }
    
    try {
        $paramDetails = @()
        foreach ($param in $Parameters.PSObject.Properties) {
            $value = if ($param.Value.value) { $param.Value.value } else { $param.Value }
            $paramDetails += "$($param.Name)=$value"
        }
        
        return $paramDetails -join '; '
    }
    catch {
        return 'Error parsing parameters'
    }
}

#endregion

#region Main Script

Write-Log "=== Azure Policy Assignment Inventory Script ===" -Level 'INFO'
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

# Build policy assignment inventory
$inventory = @()
$totalAssignments = 0
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
        
        # Get all policy assignments at subscription scope
        $assignments = Get-AzPolicyAssignment -Scope "/subscriptions/$($sub.Id)" -ErrorAction SilentlyContinue
        
        if (-not $assignments) {
            Write-Log "  No policy assignments found in this subscription" -Level 'INFO'
            continue
        }
        
        Write-Log "  Found $($assignments.Count) policy assignment(s)" -Level 'SUCCESS'
        
        foreach ($assignment in $assignments) {
            # Filter by Key Vault if requested
            if ($FilterByKeyVault) {
                # Handle both Property and direct property access patterns
                $displayName = if ($assignment.PSObject.Properties.Name -contains 'Properties') { $assignment.Properties.DisplayName } else { $assignment.DisplayName }
                $description = if ($assignment.PSObject.Properties.Name -contains 'Properties') { $assignment.Properties.Description } else { $assignment.Description }
                $isKvRelated = Test-KeyVaultRelated -Name $assignment.Name -DisplayName $displayName -Description $description
                if (-not $isKvRelated) {
                    continue
                }
            }
            
            $totalAssignments++
            
            # Handle both Property and direct property access patterns
            $displayName = if ($assignment.PSObject.Properties.Name -contains 'Properties') { $assignment.Properties.DisplayName } else { $assignment.DisplayName }
            Write-Log "    Processing: $displayName" -Level 'INFO'
            
            try {
                # Handle both Property and direct property access patterns
                $scope = if ($assignment.PSObject.Properties.Name -contains 'Properties') { $assignment.Properties.Scope } else { $assignment.Scope }
                $policyDefId = if ($assignment.PSObject.Properties.Name -contains 'Properties') { $assignment.Properties.PolicyDefinitionId } else { $assignment.PolicyDefinitionId }
                $enforcementMode = if ($assignment.PSObject.Properties.Name -contains 'Properties') { $assignment.Properties.EnforcementMode } else { $assignment.EnforcementMode }
                $description = if ($assignment.PSObject.Properties.Name -contains 'Properties') { $assignment.Properties.Description } else { $assignment.Description }
                $notScopes = if ($assignment.PSObject.Properties.Name -contains 'Properties') { $assignment.Properties.NotScopes } else { $assignment.NotScope }
                $parameters = if ($assignment.PSObject.Properties.Name -contains 'Properties') { $assignment.Properties.Parameters } else { $assignment.Parameter }
                $metadata = if ($assignment.PSObject.Properties.Name -contains 'Properties') { $assignment.Properties.Metadata } else { $assignment.Metadata }
                
                # Determine scope type
                $scopeType = 'Unknown'
                if ($scope -match '/subscriptions/[^/]+$') {
                    $scopeType = 'Subscription'
                }
                elseif ($scope -match '/resourceGroups/') {
                    $scopeType = 'ResourceGroup'
                }
                elseif ($scope -match '/providers/Microsoft.Management/managementGroups/') {
                    $scopeType = 'ManagementGroup'
                }
                
                # Get policy definition details
                $defDetails = Get-PolicyDefinitionDetails -PolicyDefinitionId $policyDefId
                
                # Build inventory item
                $inventoryItem = [PSCustomObject]@{
                    AssignmentName        = $assignment.Name
                    DisplayName           = $displayName
                    Description           = $description
                    SubscriptionName      = $sub.Name
                    SubscriptionId        = $sub.Id
                    Scope                 = $scope
                    ScopeType             = $scopeType
                    PolicyDefinitionId    = $policyDefId
                    PolicyDefinitionName  = $defDetails.DisplayName
                    PolicyType            = $defDetails.PolicyType
                    PolicyMode            = $defDetails.Mode
                    PolicyCategory        = $defDetails.Category
                    EnforcementMode       = $enforcementMode
                    Identity              = if ($assignment.IdentityType) { "$($assignment.IdentityType); PrincipalId=$($assignment.IdentityPrincipalId)" } else { 'None' }
                    Location              = $assignment.Location
                    NotScopes             = if ($notScopes) { $notScopes -join '; ' } else { 'None' }
                    Parameters            = if ($IncludeParameters) { Get-ParametersDetailed -Parameters $parameters } else { Get-ParametersSummary -Parameters $parameters }
                    Metadata              = if ($metadata) { 
                        $meta = @()
                        if ($metadata.PSObject.Properties.Name -contains 'assignedBy' -and $metadata.assignedBy) { $meta += "AssignedBy=$($metadata.assignedBy)" }
                        if ($metadata.PSObject.Properties.Name -contains 'createdBy' -and $metadata.createdBy) { $meta += "CreatedBy=$($metadata.createdBy)" }
                        if ($metadata.PSObject.Properties.Name -contains 'createdOn' -and $metadata.createdOn) { $meta += "CreatedOn=$($metadata.createdOn)" }
                        if ($metadata.PSObject.Properties.Name -contains 'updatedOn' -and $metadata.updatedOn) { $meta += "UpdatedOn=$($metadata.updatedOn)" }
                        if ($meta.Count -gt 0) { $meta -join '; ' } else { 'No metadata' }
                    } else { 'No metadata' }
                    ResourceId            = if ($assignment.PSObject.Properties.Name -contains 'ResourceId') { $assignment.ResourceId } else { $assignment.Id }
                }
                
                $inventory += $inventoryItem
            }
            catch {
                Write-Log "    Error processing assignment $($assignment.Name): $($_.Exception.Message)" -Level 'ERROR'
                
                # Add error record with direct property access
                $inventoryItem = [PSCustomObject]@{
                    AssignmentName        = $assignment.Name
                    DisplayName           = $assignment.DisplayName
                    Description           = "ERROR: $($_.Exception.Message)"
                    SubscriptionName      = $sub.Name
                    SubscriptionId        = $sub.Id
                    Scope                 = $assignment.Scope
                    ScopeType             = 'Error'
                    PolicyDefinitionId    = $assignment.PolicyDefinitionId
                    PolicyDefinitionName  = 'N/A'
                    PolicyType            = 'N/A'
                    PolicyMode            = 'N/A'
                    PolicyCategory        = 'N/A'
                    EnforcementMode       = 'N/A'
                    Identity              = 'N/A'
                    Location              = 'N/A'
                    NotScopes             = 'N/A'
                    Parameters            = 'N/A'
                    Metadata              = 'N/A'
                    ResourceId            = 'N/A'
                }
                
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
        Write-Log "No policy assignments found in scanned subscriptions!" -Level 'WARN'
        if ($FilterByKeyVault) {
            Write-Log "Note: FilterByKeyVault was enabled - try without filter to see all policies." -Level 'INFO'
        }
        Write-Log "Creating empty CSV file with headers..." -Level 'INFO'
        
        # Create empty object with all properties
        $emptyObject = [PSCustomObject]@{
            AssignmentName        = ''
            DisplayName           = ''
            Description           = ''
            SubscriptionName      = ''
            SubscriptionId        = ''
            Scope                 = ''
            ScopeType             = ''
            PolicyDefinitionId    = ''
            PolicyDefinitionName  = ''
            PolicyType            = ''
            PolicyMode            = ''
            PolicyCategory        = ''
            EnforcementMode       = ''
            Identity              = ''
            Location              = ''
            NotScopes             = ''
            Parameters            = ''
            Metadata              = ''
            ResourceId            = ''
        }
        
        @($emptyObject) | Export-Csv -Path $OutputPath -NoTypeInformation -Force
    }
    else {
        $inventory | Export-Csv -Path $OutputPath -NoTypeInformation -Force
        Write-Log "Export completed successfully!" -Level 'SUCCESS'
        Write-Log "Total policy assignments inventoried: $($inventory.Count)" -Level 'SUCCESS'
        
        # Display summary statistics
        Write-Log "" -Level 'INFO'
        Write-Log "=== Summary Statistics ===" -Level 'INFO'
        Write-Log "Total Subscriptions Scanned: $(@($subscriptions).Count)" -Level 'INFO'
        Write-Log "Total Policy Assignments Found: $totalAssignments" -Level 'INFO'
        
        if ($FilterByKeyVault) {
            Write-Log "Key Vault-Related Assignments: $(@($inventory).Count)" -Level 'INFO'
        }
        
        # Breakdown by scope type with null-safe counting
        $subScope = @($inventory | Where-Object { $_.ScopeType -eq 'Subscription' }).Count
        $rgScope = @($inventory | Where-Object { $_.ScopeType -eq 'ResourceGroup' }).Count
        $mgScope = @($inventory | Where-Object { $_.ScopeType -eq 'ManagementGroup' }).Count
        
        Write-Log "" -Level 'INFO'
        Write-Log "=== Scope Breakdown ===" -Level 'INFO'
        Write-Log "Subscription Scope: $subScope" -Level 'INFO'
        Write-Log "Resource Group Scope: $rgScope" -Level 'INFO'
        Write-Log "Management Group Scope: $mgScope" -Level 'INFO'
        
        # Breakdown by enforcement mode with null-safe counting
        $enforced = @($inventory | Where-Object { $_.EnforcementMode -eq 'Default' -or $_.EnforcementMode -eq $null }).Count
        $notEnforced = @($inventory | Where-Object { $_.EnforcementMode -eq 'DoNotEnforce' }).Count
        
        Write-Log "" -Level 'INFO'
        Write-Log "=== Enforcement Mode ===" -Level 'INFO'
        Write-Log "Enforced (Default): $enforced" -Level 'INFO'
        Write-Log "Not Enforced (DoNotEnforce): $notEnforced" -Level 'INFO'
        
        # Breakdown by category (if available)
        $categories = $inventory | Group-Object -Property PolicyCategory | Sort-Object Count -Descending | Select-Object -First 10
        if ($categories) {
            Write-Log "" -Level 'INFO'
            Write-Log "=== Top 10 Policy Categories ===" -Level 'INFO'
            foreach ($cat in $categories) {
                Write-Log "$($cat.Name): $($cat.Count)" -Level 'INFO'
            }
        }
        
        # Check for Key Vault policies (even if not filtered)
        if (-not $FilterByKeyVault) {
            $kvPolicies = @($inventory | Where-Object { 
                $_.DisplayName -like '*key*vault*' -or 
                $_.DisplayName -like '*keyvault*' -or 
                $_.PolicyCategory -eq 'Key Vault'
            })
            
            if ($kvPolicies -and $kvPolicies.Count -gt 0) {
                Write-Log "" -Level 'INFO'
                Write-Log "=== Key Vault-Related Policies Detected ===" -Level 'WARN'
                Write-Log "Found $($kvPolicies.Count) existing Key Vault policy assignment(s)" -Level 'WARN'
                Write-Log "Review these for potential conflicts before deploying new policies!" -Level 'WARN'
                
                foreach ($kvPolicy in $kvPolicies | Select-Object -First 5) {
                    Write-Log "  - $($kvPolicy.DisplayName) (Scope: $($kvPolicy.ScopeType))" -Level 'INFO'
                }
                
                if ($kvPolicies.Count -gt 5) {
                    Write-Log "  ... and $($kvPolicies.Count - 5) more. See CSV for full list." -Level 'INFO'
                }
            }
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
