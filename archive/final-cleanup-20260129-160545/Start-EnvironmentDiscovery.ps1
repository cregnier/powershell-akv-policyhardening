<#
.SYNOPSIS
    Unified menu-driven environment discovery script for Sprint 1, Story 1.1.

.DESCRIPTION
    Interactive menu system combining subscription, Key Vault, and policy assignment 
    inventories. Outputs to subscriptions-template.csv compatible format.
    
    Supports:
    - Scenario 1: MSDN subscription with guest MSA account (Owner role)
    - Scenario 2: Corporate AAD environment with AAD user (Reader+ role)
    
    Features:
    - Interactive menu for task selection
    - Prerequisites validation
    - Consolidated or individual inventories
    - Export to existing subscriptions-template.csv format
    - Comprehensive error handling for guest and AAD accounts

.PARAMETER AutoRun
    Skip menu and run full discovery automatically.

.PARAMETER OutputDirectory
    Custom output directory. Default: .\Discovery-[timestamp]

.PARAMETER UseExistingTemplate
    Use existing subscriptions-template.csv as input to filter subscriptions.

.EXAMPLE
    .\Start-EnvironmentDiscovery.ps1
    
    Launches interactive menu.

.EXAMPLE
    .\Start-EnvironmentDiscovery.ps1 -AutoRun
    
    Runs full discovery without menu prompts.

.EXAMPLE
    .\Start-EnvironmentDiscovery.ps1 -UseExistingTemplate
    
    Uses subscriptions-template.csv to filter which subscriptions to scan.

.NOTES
    Author: Azure Policy Automation Team
    Created: January 29, 2026
    Version: 1.0
    Requires: Az.Accounts, Az.Resources, Az.KeyVault
    Minimum PowerShell Version: 7.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$AutoRun,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = ".\Discovery-$(Get-Date -Format 'yyyyMMdd-HHmmss')",
    
    [Parameter(Mandatory = $false)]
    [switch]$UseExistingTemplate
)

#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources, Az.KeyVault

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Configuration
$script:SubscriptionsTemplatePath = '.\subscriptions-template.csv'
$script:DetailedMode = $false
#endregion

#region Helper Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'HEADER')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'INFO'    { 'Cyan' }
        'WARN'    { 'Yellow' }
        'ERROR'   { 'Red' }
        'SUCCESS' { 'Green' }
        'HEADER'  { 'Magenta' }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Show-Banner {
    Clear-Host
    Write-Host "=====================================================================" -ForegroundColor Magenta
    Write-Host " Azure Environment Discovery - Unified Discovery Tool" -ForegroundColor Magenta
    Write-Host " Sprint 1, Story 1.1 - Environment Discovery & Baseline Assessment" -ForegroundColor Magenta
    Write-Host "=====================================================================" -ForegroundColor Magenta
    Write-Host ""
    
    # Show current context
    try {
        $context = Get-AzContext
        if ($context) {
            Write-Host "Connected as: " -NoNewline -ForegroundColor Gray
            Write-Host $context.Account.Id -ForegroundColor Cyan
            Write-Host "Tenant:       " -NoNewline -ForegroundColor Gray
            Write-Host $context.Tenant.Id -ForegroundColor Cyan
            
            # Detect account type
            $accountType = if ($context.Account.Id -like '*#EXT#*') {
                'Guest/External (MSA or B2B)'
            } elseif ($context.Account.Type -eq 'User') {
                'Corporate AAD User'
            } else {
                $context.Account.Type
            }
            
            Write-Host "Account Type: " -NoNewline -ForegroundColor Gray
            Write-Host $accountType -ForegroundColor Cyan
        }
        else {
            Write-Host "❌ Not connected to Azure" -ForegroundColor Red
            Write-Host "Please run: Connect-AzAccount" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "❌ Error checking Azure connection" -ForegroundColor Red
    }
    
    Write-Host ""
}

function Show-Menu {
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " MAIN MENU" -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " Prerequisites & Validation" -ForegroundColor Yellow
    Write-Host "   0. Run Prerequisites Check" -ForegroundColor White
    Write-Host ""
    Write-Host " Individual Inventories" -ForegroundColor Yellow
    Write-Host "   1. Subscription Inventory (with subscriptions-template.csv output)" -ForegroundColor White
    Write-Host "   2. Key Vault Inventory" -ForegroundColor White
    Write-Host "   3. Policy Assignment Inventory" -ForegroundColor White
    Write-Host ""
    Write-Host " Combined Operations" -ForegroundColor Yellow
    Write-Host "   4. Run ALL Inventories (Full Discovery)" -ForegroundColor White
    Write-Host "   5. Run ALL Inventories (Quick Discovery - Basic Mode)" -ForegroundColor White
    Write-Host ""
    Write-Host " Advanced Options" -ForegroundColor Yellow
    Write-Host "   6. Filter by Subscriptions Template (use existing subscriptions-template.csv)" -ForegroundColor White
    Write-Host "   7. Toggle Detailed Mode (Currently: $script:DetailedMode)" -ForegroundColor White
    Write-Host ""
    Write-Host " Utilities" -ForegroundColor Yellow
    Write-Host "   8. View Current Configuration" -ForegroundColor White
    Write-Host "   9. Change Output Directory (Current: $OutputDirectory)" -ForegroundColor White
    Write-Host ""
    Write-Host "   Q. Quit" -ForegroundColor White
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-Prerequisites {
    Write-Log "Running prerequisites check..." -Level 'INFO'
    
    $prereqScript = Join-Path $PSScriptRoot "Test-DiscoveryPrerequisites.ps1"
    
    if (Test-Path $prereqScript) {
        & $prereqScript -Detailed
    }
    else {
        Write-Log "Prerequisites script not found: $prereqScript" -Level 'ERROR'
        Write-Log "Manually verify:" -Level 'WARN'
        Write-Log "  - PowerShell 7.0+" -Level 'WARN'
        Write-Log "  - Az.Accounts, Az.Resources, Az.KeyVault modules installed" -Level 'WARN'
        Write-Log "  - Connected to Azure (Connect-AzAccount)" -Level 'WARN'
        Write-Log "  - Reader role on target subscriptions" -Level 'WARN'
    }
    
    Write-Host ""
    Write-Host "Press any key to return to menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Get-FilteredSubscriptions {
    if ($UseExistingTemplate -and (Test-Path $script:SubscriptionsTemplatePath)) {
        Write-Log "Loading subscriptions from template: $script:SubscriptionsTemplatePath" -Level 'INFO'
        
        try {
            $template = Import-Csv $script:SubscriptionsTemplatePath
            $subIds = $template.SubscriptionId | Where-Object { $_ -and $_ -notmatch '12345678' }  # Filter out placeholder IDs
            
            if ($subIds) {
                Write-Log "Found $($subIds.Count) subscription(s) in template" -Level 'SUCCESS'
                return $subIds
            }
            else {
                Write-Log "No valid subscription IDs found in template, using all accessible subscriptions" -Level 'WARN'
                return $null
            }
        }
        catch {
            Write-Log "Error reading template: $($_.Exception.Message)" -Level 'ERROR'
            Write-Log "Using all accessible subscriptions" -Level 'WARN'
            return $null
        }
    }
    
    return $null
}

function Invoke-SubscriptionInventory {
    Write-Log "Starting Subscription Inventory..." -Level 'HEADER'
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }
    
    $outputPath = Join-Path $OutputDirectory "SubscriptionInventory.csv"
    $templateOutputPath = Join-Path $OutputDirectory "subscriptions-template.csv"
    
    try {
        $subscriptions = Get-AzSubscription -ErrorAction Stop
        
        if (-not $subscriptions) {
            Write-Log "No subscriptions found" -Level 'ERROR'
            return
        }
        
        Write-Log "Found $($subscriptions.Count) subscription(s)" -Level 'SUCCESS'
        
        $inventory = @()
        $currentIndex = 0
        
        foreach ($sub in $subscriptions) {
            $currentIndex++
            Write-Log "Processing $currentIndex / $($subscriptions.Count): $($sub.Name)" -Level 'INFO'
            
            try {
                # Attempt to set context - validate it worked before proceeding
                Set-AzContext -SubscriptionId $sub.Id -ErrorAction SilentlyContinue | Out-Null
                $contextSet = $false
                
                try {
                    $testContext = Get-AzContext
                    if ($testContext.Subscription.Id -eq $sub.Id) {
                        $contextSet = $true
                    }
                }
                catch {
                    $contextSet = $false
                }
                
                if (-not $contextSet) {
                    # Subscription in different tenant or requires MFA - skip gracefully
                    Write-Log "  Skipping - subscription in different tenant (MFA required or no access)" -Level 'WARN'
                    continue
                }
                
                $subDetails = Get-AzSubscription -SubscriptionId $sub.Id
                
                $inventoryItem = [PSCustomObject]@{
                    SubscriptionId   = $sub.Id
                    SubscriptionName = $sub.Name
                    TenantId        = $sub.TenantId
                    State           = $sub.State
                    Environment     = '' # To be filled manually or via tags
                    SubscriptionPolicies = $subDetails.SubscriptionPolicies.QuotaId
                    Tags            = if ($sub.Tags) { ($sub.Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; ' } else { 'None' }
                    Notes           = ''
                }
                
                # Try to infer environment from tags or name
                if ($sub.Tags -and $sub.Tags.ContainsKey('Environment')) {
                    $inventoryItem.Environment = $sub.Tags['Environment']
                }
                elseif ($sub.Name -match 'prod|production') {
                    $inventoryItem.Environment = 'Production'
                }
                elseif ($sub.Name -match 'dev|development') {
                    $inventoryItem.Environment = 'Development'
                }
                elseif ($sub.Name -match 'test|testing|qa') {
                    $inventoryItem.Environment = 'Test'
                }
                elseif ($sub.Name -match 'sandbox') {
                    $inventoryItem.Environment = 'Sandbox'
                }
                
                # Add detailed info if requested
                if ($script:DetailedMode) {
                    # Get owners
                    $owners = Get-AzRoleAssignment -Scope "/subscriptions/$($sub.Id)" -RoleDefinitionName "Owner" -ErrorAction SilentlyContinue
                    $inventoryItem | Add-Member -NotePropertyName 'Owners' -NotePropertyValue $(
                        if ($owners) { ($owners | ForEach-Object { $_.SignInName -or $_.DisplayName } | Where-Object { $_ } | Sort-Object -Unique) -join '; ' }
                        else { 'None found' }
                    )
                    
                    # Get resource count
                    $resources = Get-AzResource -ErrorAction SilentlyContinue
                    $inventoryItem | Add-Member -NotePropertyName 'ResourceCount' -NotePropertyValue $resources.Count
                }
                
                $inventory += $inventoryItem
            }
            catch {
                Write-Log "  Error: $($_.Exception.Message)" -Level 'ERROR'
            }
        }
        
        # Export full inventory
        $inventory | Export-Csv -Path $outputPath -NoTypeInformation -Force
        Write-Log "Exported full inventory to: $outputPath" -Level 'SUCCESS'
        
        # Export in subscriptions-template.csv format
        $templateData = $inventory | Select-Object SubscriptionId, SubscriptionName, Environment, Notes
        $templateData | Export-Csv -Path $templateOutputPath -NoTypeInformation -Force
        Write-Log "Exported template format to: $templateOutputPath" -Level 'SUCCESS'
        
        Write-Log "Subscription inventory complete!" -Level 'SUCCESS'
        
        # Show summary
        $enabledCount = ($inventory | Where-Object { $_.State -eq 'Enabled' }).Count
        Write-Log "Summary: $enabledCount enabled / $($inventory.Count) total subscriptions" -Level 'INFO'
    }
    catch {
        Write-Log "Error during subscription inventory: $($_.Exception.Message)" -Level 'ERROR'
    }
    
    Write-Host ""
    Write-Host "Press any key to return to menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Invoke-KeyVaultInventory {
    Write-Log "Starting Key Vault Inventory..." -Level 'HEADER'
    
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }
    
    $outputPath = Join-Path $OutputDirectory "KeyVaultInventory.csv"
    $filterSubs = Get-FilteredSubscriptions
    
    $params = @{
        OutputPath = $outputPath
    }
    
    if ($filterSubs) {
        $params['SubscriptionIds'] = $filterSubs
    }
    
    if ($script:DetailedMode) {
        $params['IncludeNetworkRules'] = $true
        $params['IncludeAccessPolicies'] = $true
    }
    
    try {
        $kvScript = Join-Path $PSScriptRoot "Get-KeyVaultInventory.ps1"
        
        if (Test-Path $kvScript) {
            & $kvScript @params
        }
        else {
            Write-Log "Key Vault inventory script not found: $kvScript" -Level 'ERROR'
        }
    }
    catch {
        Write-Log "Error during Key Vault inventory: $($_.Exception.Message)" -Level 'ERROR'
    }
    
    Write-Host ""
    Write-Host "Press any key to return to menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Invoke-PolicyInventory {
    Write-Log "Starting Policy Assignment Inventory..." -Level 'HEADER'
    
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }
    
    $outputPath = Join-Path $OutputDirectory "PolicyAssignmentInventory.csv"
    $filterSubs = Get-FilteredSubscriptions
    
    $params = @{
        OutputPath = $outputPath
    }
    
    if ($filterSubs) {
        $params['SubscriptionIds'] = $filterSubs
    }
    
    if ($script:DetailedMode) {
        $params['IncludeParameters'] = $true
    }
    
    try {
        $policyScript = Join-Path $PSScriptRoot "Get-PolicyAssignmentInventory.ps1"
        
        if (Test-Path $policyScript) {
            & $policyScript @params
        }
        else {
            Write-Log "Policy inventory script not found: $policyScript" -Level 'ERROR'
        }
    }
    catch {
        Write-Log "Error during policy inventory: $($_.Exception.Message)" -Level 'ERROR'
    }
    
    Write-Host ""
    Write-Host "Press any key to return to menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Invoke-FullDiscovery {
    param([bool]$QuickMode = $false)
    
    $modeText = if ($QuickMode) { "Quick (Basic)" } else { "Full (Detailed)" }
    Write-Log "Starting $modeText Discovery..." -Level 'HEADER'
    
    # Temporarily override detailed mode for quick discovery
    $originalMode = $script:DetailedMode
    if ($QuickMode) {
        $script:DetailedMode = $false
    }
    
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }
    
    # Run all three inventories
    Write-Log "Phase 1/3: Subscription Inventory" -Level 'INFO'
    Invoke-SubscriptionInventory
    
    Write-Log "Phase 2/3: Key Vault Inventory" -Level 'INFO'
    Invoke-KeyVaultInventory
    
    Write-Log "Phase 3/3: Policy Assignment Inventory" -Level 'INFO'
    Invoke-PolicyInventory
    
    # Generate consolidated report
    Write-Log "Generating consolidated report..." -Level 'INFO'
    
    $reportPath = Join-Path $OutputDirectory "DiscoveryReport.txt"
    
    try {
        $orchestrationScript = Join-Path $PSScriptRoot "Invoke-EnvironmentDiscovery.ps1"
        
        # Just generate the report part
        $subCsv = Join-Path $OutputDirectory "SubscriptionInventory.csv"
        $kvCsv = Join-Path $OutputDirectory "KeyVaultInventory.csv"
        $policyCsv = Join-Path $OutputDirectory "PolicyAssignmentInventory.csv"
        
        # Simple report generation
        $report = @"
===================================================================
Azure Environment Discovery - Consolidated Report
Sprint 1, Story 1.1 - Environment Discovery & Baseline Assessment
===================================================================

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Mode: $modeText Discovery

Output Directory: $OutputDirectory

Files Generated:
"@
        
        if (Test-Path $subCsv) { $report += "`n  ✓ SubscriptionInventory.csv" }
        if (Test-Path $kvCsv) { $report += "`n  ✓ KeyVaultInventory.csv" }
        if (Test-Path $policyCsv) { $report += "`n  ✓ PolicyAssignmentInventory.csv" }
        if (Test-Path (Join-Path $OutputDirectory "subscriptions-template.csv")) { 
            $report += "`n  ✓ subscriptions-template.csv (compatible format)" 
        }
        
        $report += @"


===================================================================
Next Steps:
===================================================================

1. Review all CSV files in Excel
2. Update subscriptions-template.csv with Environment tags and Notes
3. Fill out Stakeholder-Contact-Template.csv
4. Update Risk-Register-Template.csv
5. Proceed to Sprint 1, Story 1.2 - Pilot Environment Setup

===================================================================
"@
        
        $report | Out-File -FilePath $reportPath -Encoding utf8
        Write-Log "Consolidated report saved: $reportPath" -Level 'SUCCESS'
        
        # Display summary
        Write-Host ""
        Write-Host $report
    }
    catch {
        Write-Log "Error generating report: $($_.Exception.Message)" -Level 'ERROR'
    }
    
    # Restore original mode
    $script:DetailedMode = $originalMode
    
    Write-Log "Full discovery complete! All files in: $OutputDirectory" -Level 'SUCCESS'
    
    Write-Host ""
    Write-Host "Press any key to return to menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-Configuration {
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " CURRENT CONFIGURATION" -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Output Directory:           " -NoNewline; Write-Host $OutputDirectory -ForegroundColor Yellow
    Write-Host "Detailed Mode:              " -NoNewline; Write-Host $script:DetailedMode -ForegroundColor Yellow
    Write-Host "Use Template Filter:        " -NoNewline; Write-Host $UseExistingTemplate -ForegroundColor Yellow
    Write-Host "Subscriptions Template:     " -NoNewline; Write-Host $script:SubscriptionsTemplatePath -ForegroundColor Yellow
    Write-Host "Template Exists:            " -NoNewline
    if (Test-Path $script:SubscriptionsTemplatePath) {
        Write-Host "Yes" -ForegroundColor Green
    } else {
        Write-Host "No" -ForegroundColor Red
    }
    Write-Host ""
    
    # Show Azure context
    try {
        $context = Get-AzContext
        if ($context) {
            Write-Host "Azure Account:              " -NoNewline; Write-Host $context.Account.Id -ForegroundColor Green
            Write-Host "Tenant:                     " -NoNewline; Write-Host $context.Tenant.Id -ForegroundColor Green
            Write-Host "Subscription (Current):     " -NoNewline; Write-Host $context.Subscription.Name -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Azure Connection:           " -NoNewline; Write-Host "Not Connected" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Press any key to return to menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Set-OutputDirectory {
    Write-Host ""
    Write-Host "Current output directory: " -NoNewline -ForegroundColor Gray
    Write-Host $OutputDirectory -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Enter new output directory path (or press Enter to keep current): " -NoNewline -ForegroundColor Cyan
    
    $newPath = Read-Host
    
    if ($newPath) {
        $script:OutputDirectory = $newPath
        Write-Log "Output directory updated to: $newPath" -Level 'SUCCESS'
    }
    else {
        Write-Log "Output directory unchanged" -Level 'INFO'
    }
    
    Start-Sleep -Seconds 1
}

#endregion

#region Main Script

# Auto-run mode
if ($AutoRun) {
    Write-Log "Auto-run mode enabled - starting full discovery..." -Level 'INFO'
    Invoke-FullDiscovery -QuickMode $false
    exit 0
}

# Interactive menu loop
while ($true) {
    Show-Banner
    Show-Menu
    
    $choice = Read-Host "Select an option"
    
    switch ($choice.ToUpper()) {
        '0' { Test-Prerequisites }
        '1' { Invoke-SubscriptionInventory }
        '2' { Invoke-KeyVaultInventory }
        '3' { Invoke-PolicyInventory }
        '4' { Invoke-FullDiscovery -QuickMode $false }
        '5' { Invoke-FullDiscovery -QuickMode $true }
        '6' { 
            $UseExistingTemplate = -not $UseExistingTemplate
            Write-Log "Template filter toggled to: $UseExistingTemplate" -Level 'SUCCESS'
            Start-Sleep -Seconds 1
        }
        '7' { 
            $script:DetailedMode = -not $script:DetailedMode
            Write-Log "Detailed mode toggled to: $script:DetailedMode" -Level 'SUCCESS'
            Start-Sleep -Seconds 1
        }
        '8' { Show-Configuration }
        '9' { Set-OutputDirectory }
        'Q' { 
            Write-Log "Exiting..." -Level 'INFO'
            exit 0
        }
        default {
            Write-Log "Invalid selection. Please try again." -Level 'WARN'
            Start-Sleep -Seconds 1
        }
    }
}

#endregion
