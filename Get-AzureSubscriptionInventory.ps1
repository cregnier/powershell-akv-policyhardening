<#
.SYNOPSIS
    Enumerates all Azure subscriptions in the current tenant and exports detailed inventory.

.DESCRIPTION
    This script discovers all Azure subscriptions accessible to the current user/identity,
    retrieves metadata (name, ID, state, tags, owners), and exports to CSV format.
    Part of Sprint 1, Story 1.1 - Environment Discovery & Baseline Assessment.

.PARAMETER OutputPath
    Path where the CSV inventory file will be saved. Default: .\SubscriptionInventory.csv

.PARAMETER IncludeRBAC
    If specified, includes RBAC role assignments (Owners, Contributors) for each subscription.
    WARNING: This can significantly increase execution time for large tenants.

.PARAMETER IncludeResourceCounts
    If specified, includes resource counts per subscription. May take longer to execute.

.EXAMPLE
    .\Get-AzureSubscriptionInventory.ps1
    
    Generates basic subscription inventory with default output.

.EXAMPLE
    .\Get-AzureSubscriptionInventory.ps1 -OutputPath "C:\Reports\Subscriptions.csv" -IncludeRBAC
    
    Generates detailed inventory with RBAC information.

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
    [string]$OutputPath = ".\SubscriptionInventory-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv",
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeRBAC,
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeResourceCounts
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

function Get-SubscriptionOwners {
    param([string]$SubscriptionId)
    
    try {
        $owners = Get-AzRoleAssignment -Scope "/subscriptions/$SubscriptionId" -RoleDefinitionName "Owner" -ErrorAction SilentlyContinue
        if ($owners) {
            return ($owners | ForEach-Object { $_.SignInName -or $_.DisplayName } | Where-Object { $_ } | Sort-Object -Unique) -join '; '
        }
        return 'None found'
    }
    catch {
        Write-Log "Failed to get owners for subscription $SubscriptionId : $($_.Exception.Message)" -Level 'WARN'
        return 'Error retrieving owners'
    }
}

function Get-SubscriptionContributors {
    param([string]$SubscriptionId)
    
    try {
        $contributors = Get-AzRoleAssignment -Scope "/subscriptions/$SubscriptionId" -RoleDefinitionName "Contributor" -ErrorAction SilentlyContinue
        if ($contributors) {
            return ($contributors | ForEach-Object { $_.SignInName -or $_.DisplayName } | Where-Object { $_ } | Sort-Object -Unique) -join '; '
        }
        return 'None found'
    }
    catch {
        Write-Log "Failed to get contributors for subscription $SubscriptionId : $($_.Exception.Message)" -Level 'WARN'
        return 'Error retrieving contributors'
    }
}

function Get-SubscriptionResourceCount {
    param([string]$SubscriptionId)
    
    try {
        Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue | Out-Null
        $resources = Get-AzResource -ErrorAction SilentlyContinue
        return $resources.Count
    }
    catch {
        Write-Log "Failed to get resource count for subscription $SubscriptionId : $($_.Exception.Message)" -Level 'WARN'
        return 'Error'
    }
}

#endregion

#region Main Script

Write-Log "=== Azure Subscription Inventory Script ===" -Level 'INFO'
Write-Log "Sprint 1, Story 1.1 - Environment Discovery & Baseline Assessment" -Level 'INFO'
Write-Log "" -Level 'INFO'

# Verify Azure connection
if (-not (Test-AzureConnection)) {
    Write-Log "Please connect to Azure using Connect-AzAccount and try again." -Level 'ERROR'
    exit 1
}

# Get all subscriptions
Write-Log "Retrieving all subscriptions in tenant..." -Level 'INFO'
try {
    $subscriptions = Get-AzSubscription -ErrorAction Stop
    Write-Log "Found $($subscriptions.Count) subscription(s)" -Level 'SUCCESS'
}
catch {
    Write-Log "Failed to retrieve subscriptions: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

# Build inventory
$inventory = @()
$currentIndex = 0

foreach ($sub in $subscriptions) {
    $currentIndex++
    Write-Log "Processing subscription $currentIndex of $($subscriptions.Count): $($sub.Name)" -Level 'INFO'
    
    try {
        # Set context to current subscription
        $contextSet = Set-AzContext -SubscriptionId $sub.Id -ErrorAction SilentlyContinue
        
        if (-not $contextSet) {
            Write-Log "  Skipping - subscription in different tenant (MFA required or no access)" -Level 'WARN'
            continue
        }
        
        # Get subscription details
        $subDetails = Get-AzSubscription -SubscriptionId $sub.Id -ErrorAction Stop
        
        # Build base inventory object
        $inventoryItem = [PSCustomObject]@{
            SubscriptionName = $sub.Name
            SubscriptionId   = $sub.Id
            TenantId        = $sub.TenantId
            State           = $sub.State
            SubscriptionPolicies = $subDetails.SubscriptionPolicies.QuotaId
            Tags            = if ($sub.Tags) { ($sub.Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; ' } else { 'None' }
        }
        
        # Add RBAC information if requested
        if ($IncludeRBAC) {
            Write-Log "  Retrieving RBAC assignments..." -Level 'INFO'
            $inventoryItem | Add-Member -NotePropertyName 'Owners' -NotePropertyValue (Get-SubscriptionOwners -SubscriptionId $sub.Id)
            $inventoryItem | Add-Member -NotePropertyName 'Contributors' -NotePropertyValue (Get-SubscriptionContributors -SubscriptionId $sub.Id)
        }
        
        # Add resource count if requested
        if ($IncludeResourceCounts) {
            Write-Log "  Counting resources..." -Level 'INFO'
            $inventoryItem | Add-Member -NotePropertyName 'ResourceCount' -NotePropertyValue (Get-SubscriptionResourceCount -SubscriptionId $sub.Id)
        }
        
        $inventory += $inventoryItem
        Write-Log "  Completed" -Level 'SUCCESS'
    }
    catch {
        Write-Log "  Error processing subscription: $($_.Exception.Message)" -Level 'ERROR'
        
        # Add error record
        $inventoryItem = [PSCustomObject]@{
            SubscriptionName = $sub.Name
            SubscriptionId   = $sub.Id
            TenantId        = $sub.TenantId
            State           = "ERROR: $($_.Exception.Message)"
            SubscriptionPolicies = 'N/A'
            Tags            = 'N/A'
        }
        
        if ($IncludeRBAC) {
            $inventoryItem | Add-Member -NotePropertyName 'Owners' -NotePropertyValue 'N/A'
            $inventoryItem | Add-Member -NotePropertyName 'Contributors' -NotePropertyValue 'N/A'
        }
        
        if ($IncludeResourceCounts) {
            $inventoryItem | Add-Member -NotePropertyName 'ResourceCount' -NotePropertyValue 'N/A'
        }
        
        $inventory += $inventoryItem
    }
}

# Export to CSV
Write-Log "" -Level 'INFO'
Write-Log "Exporting inventory to: $OutputPath" -Level 'INFO'
try {
    $inventory | Export-Csv -Path $OutputPath -NoTypeInformation -Force
    Write-Log "Export completed successfully!" -Level 'SUCCESS'
    
    # Calculate total with null-safe array wrapping
    $inventoryArray = @($inventory)
    $totalSubscriptions = $inventoryArray.Count
    Write-Log "Total subscriptions inventoried: $totalSubscriptions" -Level 'SUCCESS'
    
    # Display summary statistics with null-safe counting
    $enabledSubs = @($inventory | Where-Object { $_.State -eq 'Enabled' }).Count
    $disabledSubs = @($inventory | Where-Object { $_.State -ne 'Enabled' -and $_.State -notlike 'ERROR:*' }).Count
    $errorSubs = @($inventory | Where-Object { $_.State -like 'ERROR:*' }).Count
    
    Write-Log "" -Level 'INFO'
    Write-Log "=== Summary Statistics ===" -Level 'INFO'
    Write-Log "Enabled Subscriptions: $enabledSubs" -Level 'INFO'
    Write-Log "Disabled Subscriptions: $disabledSubs" -Level 'INFO'
    Write-Log "Errors: $errorSubs" -Level 'WARN'
    
    if ($IncludeResourceCounts) {
        $totalResources = ($inventory | Where-Object { $_.ResourceCount -match '^\d+$' } | ForEach-Object { [int]$_.ResourceCount } | Measure-Object -Sum).Sum
        Write-Log "Total Resources Across All Subscriptions: $totalResources" -Level 'INFO'
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
