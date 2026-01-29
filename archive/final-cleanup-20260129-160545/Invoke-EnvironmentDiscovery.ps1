<#
.SYNOPSIS
    Main orchestration script to run all discovery tasks for Sprint 1, Story 1.1.

.DESCRIPTION
    This script executes all environment discovery scripts, consolidates results,
    and generates a comprehensive baseline assessment report for Azure Key Vault
    policy deployment planning.
    
    Runs:
    - Subscription inventory
    - Key Vault inventory
    - Policy assignment inventory
    - Generates consolidated summary report
    
    Part of Sprint 1, Story 1.1 - Environment Discovery & Baseline Assessment.

.PARAMETER OutputDirectory
    Directory where all output files will be saved. Default: .\Discovery-[timestamp]

.PARAMETER SubscriptionIds
    Optional array of specific subscription IDs to scan. If not provided, scans all subscriptions.

.PARAMETER DetailedInventory
    If specified, includes detailed information (RBAC, network rules, access policies, parameters).
    WARNING: Increases execution time significantly.

.PARAMETER SkipSubscriptionInventory
    Skip subscription inventory (use if already completed).

.PARAMETER SkipKeyVaultInventory
    Skip Key Vault inventory (use if already completed).

.PARAMETER SkipPolicyInventory
    Skip policy assignment inventory (use if already completed).

.EXAMPLE
    .\Invoke-EnvironmentDiscovery.ps1
    
    Runs full discovery with default settings.

.EXAMPLE
    .\Invoke-EnvironmentDiscovery.ps1 -DetailedInventory -OutputDirectory "C:\Reports\Sprint1"
    
    Runs detailed discovery with custom output location.

.EXAMPLE
    .\Invoke-EnvironmentDiscovery.ps1 -SubscriptionIds @('sub-id-1', 'sub-id-2')
    
    Runs discovery on specific subscriptions only.

.NOTES
    Author: Azure Policy Automation Team
    Created: January 29, 2026
    Version: 1.0
    Requires: Az.Accounts, Az.Resources, Az.KeyVault PowerShell modules
    Minimum PowerShell Version: 7.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = ".\Discovery-$(Get-Date -Format 'yyyyMMdd-HHmmss')",
    
    [Parameter(Mandatory = $false)]
    [string[]]$SubscriptionIds,
    
    [Parameter(Mandatory = $false)]
    [switch]$DetailedInventory,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipSubscriptionInventory,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipKeyVaultInventory,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipPolicyInventory
)

#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources, Az.KeyVault

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

function Test-ScriptExists {
    param([string]$ScriptName)
    
    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    if (-not (Test-Path $scriptPath)) {
        Write-Log "Required script not found: $ScriptName" -Level 'ERROR'
        Write-Log "Expected location: $scriptPath" -Level 'ERROR'
        return $false
    }
    return $true
}

function New-ConsolidatedReport {
    param(
        [string]$OutputPath,
        [string]$SubscriptionCsv,
        [string]$KeyVaultCsv,
        [string]$PolicyCsv
    )
    
    Write-Log "Generating consolidated summary report..." -Level 'INFO'
    
    $report = @"
===================================================================
Azure Environment Discovery - Baseline Assessment Report
Sprint 1, Story 1.1 - Environment Discovery & Baseline Assessment
===================================================================

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Tenant: $($(Get-AzContext).Tenant.Id)
Executed By: $($(Get-AzContext).Account.Id)

===================================================================
EXECUTIVE SUMMARY
===================================================================

"@
    
    # Add subscription summary
    if (Test-Path $SubscriptionCsv) {
        $subs = Import-Csv $SubscriptionCsv
        $enabledSubs = ($subs | Where-Object { $_.State -eq 'Enabled' }).Count
        
        $report += @"

SUBSCRIPTIONS:
- Total Subscriptions: $($subs.Count)
- Enabled: $enabledSubs
- Disabled/Other: $($subs.Count - $enabledSubs)

"@
    }
    else {
        $report += "`nSUBSCRIPTIONS: Inventory not available`n"
    }
    
    # Add Key Vault summary
    if (Test-Path $KeyVaultCsv) {
        $kvs = Import-Csv $KeyVaultCsv
        
        if ($kvs.Count -gt 0 -and $kvs[0].KeyVaultName) {
            $softDeleteEnabled = ($kvs | Where-Object { $_.EnableSoftDelete -eq 'True' }).Count
            $purgeProtectionEnabled = ($kvs | Where-Object { $_.EnablePurgeProtection -eq 'True' }).Count
            $rbacEnabled = ($kvs | Where-Object { $_.EnableRbacAuthorization -eq 'True' }).Count
            $publicNetworkDisabled = ($kvs | Where-Object { $_.PublicNetworkAccess -eq 'Disabled' }).Count
            
            $report += @"

KEY VAULTS:
- Total Key Vaults: $($kvs.Count)
- Soft Delete Enabled: $softDeleteEnabled ($([math]::Round($softDeleteEnabled/$kvs.Count*100, 2))%)
- Purge Protection Enabled: $purgeProtectionEnabled ($([math]::Round($purgeProtectionEnabled/$kvs.Count*100, 2))%)
- RBAC Authorization Enabled: $rbacEnabled ($([math]::Round($rbacEnabled/$kvs.Count*100, 2))%)
- Public Network Access Disabled: $publicNetworkDisabled ($([math]::Round($publicNetworkDisabled/$kvs.Count*100, 2))%)

"@
        }
        else {
            $report += "`nKEY VAULTS: No Key Vaults found in scanned subscriptions`n"
        }
    }
    else {
        $report += "`nKEY VAULTS: Inventory not available`n"
    }
    
    # Add policy assignment summary
    if (Test-Path $PolicyCsv) {
        $policies = Import-Csv $PolicyCsv
        
        if ($policies.Count -gt 0 -and $policies[0].AssignmentName) {
            $kvPolicies = $policies | Where-Object { 
                $_.DisplayName -like '*key*vault*' -or 
                $_.DisplayName -like '*keyvault*' -or 
                $_.PolicyCategory -eq 'Key Vault'
            }
            
            $enforced = ($policies | Where-Object { $_.EnforcementMode -eq 'Default' -or $_.EnforcementMode -eq '' }).Count
            
            $report += @"

POLICY ASSIGNMENTS:
- Total Policy Assignments: $($policies.Count)
- Enforced (Default): $enforced
- Key Vault-Related Policies: $($kvPolicies.Count)

"@
            
            if ($kvPolicies.Count -gt 0) {
                $report += "`n⚠️  WARNING: Existing Key Vault policies detected!`n"
                $report += "Review these assignments for potential conflicts before deploying new policies:`n"
                foreach ($kvp in $kvPolicies | Select-Object -First 5) {
                    $report += "  - $($kvp.DisplayName) (Scope: $($kvp.ScopeType))`n"
                }
                if ($kvPolicies.Count -gt 5) {
                    $report += "  ... and $($kvPolicies.Count - 5) more (see PolicyAssignmentInventory.csv)`n"
                }
                $report += "`n"
            }
        }
        else {
            $report += "`nPOLICY ASSIGNMENTS: No policy assignments found`n"
        }
    }
    else {
        $report += "`nPOLICY ASSIGNMENTS: Inventory not available`n"
    }
    
    $report += @"

===================================================================
NEXT STEPS
===================================================================

1. Review detailed CSV files:
   - SubscriptionInventory.csv - Full subscription details
   - KeyVaultInventory.csv - Key Vault configuration details
   - PolicyAssignmentInventory.csv - Existing policy assignments

2. Identify pilot subscriptions (2-3 diverse environments)

3. Engage stakeholders:
   - Cloud Brokers team
   - Cyber Defense team
   - Subscription owners

4. Create stakeholder contact list (use template)

5. Document gaps and risks (use templates)

6. Proceed to Sprint 1, Story 1.2 - Pilot Environment Setup

===================================================================
OUTPUT FILES
===================================================================

All inventory files saved to: $OutputDirectory

$(if (Test-Path $SubscriptionCsv) { "✓ SubscriptionInventory.csv" } else { "✗ SubscriptionInventory.csv (skipped or failed)" })
$(if (Test-Path $KeyVaultCsv) { "✓ KeyVaultInventory.csv" } else { "✗ KeyVaultInventory.csv (skipped or failed)" })
$(if (Test-Path $PolicyCsv) { "✓ PolicyAssignmentInventory.csv" } else { "✗ PolicyAssignmentInventory.csv (skipped or failed)" })

===================================================================
END OF REPORT
===================================================================
"@
    
    # Save report
    $report | Out-File -FilePath $OutputPath -Encoding utf8
    Write-Log "Consolidated report saved to: $OutputPath" -Level 'SUCCESS'
    
    # Display report to console
    Write-Host "`n"
    Write-Host $report
}

#endregion

#region Main Script

Write-Log "=====================================================================" -Level 'INFO'
Write-Log "Azure Environment Discovery - Orchestration Script" -Level 'INFO'
Write-Log "Sprint 1, Story 1.1 - Environment Discovery & Baseline Assessment" -Level 'INFO'
Write-Log "=====================================================================" -Level 'INFO'
Write-Log "" -Level 'INFO'

# Verify Azure connection
if (-not (Test-AzureConnection)) {
    Write-Log "Please connect to Azure using Connect-AzAccount and try again." -Level 'ERROR'
    exit 1
}

# Create output directory
Write-Log "Creating output directory: $OutputDirectory" -Level 'INFO'
try {
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }
    Write-Log "Output directory ready" -Level 'SUCCESS'
}
catch {
    Write-Log "Failed to create output directory: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

# Verify required scripts exist
$requiredScripts = @(
    'Get-AzureSubscriptionInventory.ps1',
    'Get-KeyVaultInventory.ps1',
    'Get-PolicyAssignmentInventory.ps1'
)

foreach ($script in $requiredScripts) {
    if (-not (Test-ScriptExists -ScriptName $script)) {
        Write-Log "Cannot proceed without required scripts." -Level 'ERROR'
        exit 1
    }
}

Write-Log "" -Level 'INFO'
Write-Log "=====================================================================" -Level 'INFO'
Write-Log "PHASE 1: SUBSCRIPTION INVENTORY" -Level 'INFO'
Write-Log "=====================================================================" -Level 'INFO'

$subInventoryPath = Join-Path $OutputDirectory "SubscriptionInventory.csv"

if (-not $SkipSubscriptionInventory) {
    try {
        $subScriptPath = Join-Path $PSScriptRoot "Get-AzureSubscriptionInventory.ps1"
        
        $subParams = @{
            OutputPath = $subInventoryPath
        }
        
        if ($DetailedInventory) {
            $subParams['IncludeRBAC'] = $true
            $subParams['IncludeResourceCounts'] = $true
        }
        
        Write-Log "Executing subscription inventory script..." -Level 'INFO'
        & $subScriptPath @subParams
        
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw "Subscription inventory script failed with exit code $LASTEXITCODE"
        }
        
        Write-Log "Subscription inventory completed" -Level 'SUCCESS'
    }
    catch {
        Write-Log "Subscription inventory failed: $($_.Exception.Message)" -Level 'ERROR'
        Write-Log "Continuing with remaining inventories..." -Level 'WARN'
    }
}
else {
    Write-Log "Skipping subscription inventory (as requested)" -Level 'WARN'
}

Write-Log "" -Level 'INFO'
Write-Log "=====================================================================" -Level 'INFO'
Write-Log "PHASE 2: KEY VAULT INVENTORY" -Level 'INFO'
Write-Log "=====================================================================" -Level 'INFO'

$kvInventoryPath = Join-Path $OutputDirectory "KeyVaultInventory.csv"

if (-not $SkipKeyVaultInventory) {
    try {
        $kvScriptPath = Join-Path $PSScriptRoot "Get-KeyVaultInventory.ps1"
        
        $kvParams = @{
            OutputPath = $kvInventoryPath
        }
        
        if ($SubscriptionIds) {
            $kvParams['SubscriptionIds'] = $SubscriptionIds
        }
        
        if ($DetailedInventory) {
            $kvParams['IncludeNetworkRules'] = $true
            $kvParams['IncludeAccessPolicies'] = $true
        }
        
        Write-Log "Executing Key Vault inventory script..." -Level 'INFO'
        & $kvScriptPath @kvParams
        
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw "Key Vault inventory script failed with exit code $LASTEXITCODE"
        }
        
        Write-Log "Key Vault inventory completed" -Level 'SUCCESS'
    }
    catch {
        Write-Log "Key Vault inventory failed: $($_.Exception.Message)" -Level 'ERROR'
        Write-Log "Continuing with remaining inventories..." -Level 'WARN'
    }
}
else {
    Write-Log "Skipping Key Vault inventory (as requested)" -Level 'WARN'
}

Write-Log "" -Level 'INFO'
Write-Log "=====================================================================" -Level 'INFO'
Write-Log "PHASE 3: POLICY ASSIGNMENT INVENTORY" -Level 'INFO'
Write-Log "=====================================================================" -Level 'INFO'

$policyInventoryPath = Join-Path $OutputDirectory "PolicyAssignmentInventory.csv"

if (-not $SkipPolicyInventory) {
    try {
        $policyScriptPath = Join-Path $PSScriptRoot "Get-PolicyAssignmentInventory.ps1"
        
        $policyParams = @{
            OutputPath = $policyInventoryPath
        }
        
        if ($SubscriptionIds) {
            $policyParams['SubscriptionIds'] = $SubscriptionIds
        }
        
        if ($DetailedInventory) {
            $policyParams['IncludeParameters'] = $true
        }
        
        Write-Log "Executing policy assignment inventory script..." -Level 'INFO'
        & $policyScriptPath @policyParams
        
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw "Policy inventory script failed with exit code $LASTEXITCODE"
        }
        
        Write-Log "Policy assignment inventory completed" -Level 'SUCCESS'
    }
    catch {
        Write-Log "Policy inventory failed: $($_.Exception.Message)" -Level 'ERROR'
        Write-Log "Continuing with report generation..." -Level 'WARN'
    }
}
else {
    Write-Log "Skipping policy assignment inventory (as requested)" -Level 'WARN'
}

Write-Log "" -Level 'INFO'
Write-Log "=====================================================================" -Level 'INFO'
Write-Log "PHASE 4: CONSOLIDATED REPORT GENERATION" -Level 'INFO'
Write-Log "=====================================================================" -Level 'INFO'

$reportPath = Join-Path $OutputDirectory "DiscoveryReport.txt"

try {
    New-ConsolidatedReport -OutputPath $reportPath `
                          -SubscriptionCsv $subInventoryPath `
                          -KeyVaultCsv $kvInventoryPath `
                          -PolicyCsv $policyInventoryPath
}
catch {
    Write-Log "Failed to generate consolidated report: $($_.Exception.Message)" -Level 'ERROR'
}

Write-Log "" -Level 'INFO'
Write-Log "=====================================================================" -Level 'INFO'
Write-Log "DISCOVERY COMPLETE!" -Level 'SUCCESS'
Write-Log "=====================================================================" -Level 'INFO'
Write-Log "" -Level 'INFO'
Write-Log "All output files saved to: $OutputDirectory" -Level 'SUCCESS'
Write-Log "" -Level 'INFO'
Write-Log "Next steps:" -Level 'INFO'
Write-Log "1. Review DiscoveryReport.txt for executive summary" -Level 'INFO'
Write-Log "2. Analyze detailed CSV files" -Level 'INFO'
Write-Log "3. Create stakeholder contact list, gap analysis, and risk register" -Level 'INFO'
Write-Log "4. Identify pilot subscriptions for Story 1.2" -Level 'INFO'
Write-Log "" -Level 'INFO'

#endregion
