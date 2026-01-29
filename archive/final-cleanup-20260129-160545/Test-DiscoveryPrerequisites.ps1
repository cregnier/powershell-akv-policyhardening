<#
.SYNOPSIS
    Validates prerequisites for running Azure environment discovery scripts.

.DESCRIPTION
    This script checks all prerequisites for both MSDN guest account and corporate AAD scenarios:
    - PowerShell version
    - Required Azure PowerShell modules
    - Azure connectivity
    - RBAC permissions on subscriptions
    - Access to required Azure Resource Providers
    
    Supports:
    - Scenario 1: MSDN subscription with guest MSA account (Owner role)
    - Scenario 2: Corporate AAD environment with varying permissions

.PARAMETER Detailed
    Show detailed information about each check including remediation steps.

.PARAMETER FixIssues
    Attempt to automatically fix issues (install missing modules, etc.).

.EXAMPLE
    .\Test-DiscoveryPrerequisites.ps1
    
    Runs basic prerequisite checks.

.EXAMPLE
    .\Test-DiscoveryPrerequisites.ps1 -Detailed -FixIssues
    
    Runs detailed checks and attempts to fix issues automatically.

.NOTES
    Author: Azure Policy Automation Team
    Created: January 29, 2026
    Version: 1.0
    Minimum PowerShell Version: 7.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Detailed,
    
    [Parameter(Mandatory = $false)]
    [switch]$FixIssues
)

#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'  # Don't stop on errors during validation

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

function Write-CheckResult {
    param(
        [string]$CheckName,
        [bool]$Passed,
        [string]$Details = "",
        [string]$Remediation = ""
    )
    
    $status = if ($Passed) { "✓ PASS" } else { "✗ FAIL" }
    $color = if ($Passed) { 'Green' } else { 'Red' }
    
    Write-Host "`n$status - $CheckName" -ForegroundColor $color
    
    if ($Details) {
        Write-Host "  Details: $Details" -ForegroundColor Gray
    }
    
    if (-not $Passed -and $Remediation) {
        Write-Host "  Remediation: $Remediation" -ForegroundColor Yellow
    }
    
    return $Passed
}

#endregion

#region Validation Functions

function Test-PowerShellVersion {
    Write-Log "Checking PowerShell version..." -Level 'INFO'
    
    $currentVersion = $PSVersionTable.PSVersion
    $requiredVersion = [Version]"7.0"
    
    $passed = $currentVersion -ge $requiredVersion
    
    Write-CheckResult -CheckName "PowerShell Version" `
                      -Passed $passed `
                      -Details "Current: $currentVersion, Required: $requiredVersion or higher" `
                      -Remediation "Install PowerShell 7 from: https://aka.ms/powershell-release"
    
    return $passed
}

function Test-AzureModules {
    Write-Log "Checking Azure PowerShell modules..." -Level 'INFO'
    
    $requiredModules = @(
        @{ Name = 'Az.Accounts'; MinVersion = '2.0.0'; Purpose = 'Azure authentication and context management' },
        @{ Name = 'Az.Resources'; MinVersion = '6.0.0'; Purpose = 'Resource and policy management' },
        @{ Name = 'Az.KeyVault'; MinVersion = '4.0.0'; Purpose = 'Key Vault inventory' }
    )
    
    $optionalModules = @(
        @{ Name = 'Az.Monitor'; MinVersion = '4.0.0'; Purpose = 'Diagnostic settings check (optional)' }
    )
    
    $allPassed = $true
    $missingModules = @()
    
    foreach ($module in $requiredModules) {
        $installed = Get-Module -ListAvailable -Name $module.Name | 
                     Where-Object { $_.Version -ge [Version]$module.MinVersion } | 
                     Select-Object -First 1
        
        if ($installed) {
            Write-CheckResult -CheckName "Module: $($module.Name)" `
                              -Passed $true `
                              -Details "Version: $($installed.Version), Purpose: $($module.Purpose)"
        }
        else {
            $allPassed = $false
            $missingModules += $module.Name
            
            Write-CheckResult -CheckName "Module: $($module.Name)" `
                              -Passed $false `
                              -Details "Not installed or version < $($module.MinVersion)" `
                              -Remediation "Install-Module -Name $($module.Name) -MinimumVersion $($module.MinVersion) -Scope CurrentUser -Force"
        }
    }
    
    # Check optional modules
    Write-Log "`nChecking optional modules..." -Level 'INFO'
    foreach ($module in $optionalModules) {
        $installed = Get-Module -ListAvailable -Name $module.Name | 
                     Where-Object { $_.Version -ge [Version]$module.MinVersion } | 
                     Select-Object -First 1
        
        if ($installed) {
            Write-Host "  ✓ Optional: $($module.Name) v$($installed.Version) - $($module.Purpose)" -ForegroundColor Green
        }
        else {
            Write-Host "  ℹ Optional: $($module.Name) not installed - $($module.Purpose)" -ForegroundColor Yellow
        }
    }
    
    # Auto-fix if requested
    if (-not $allPassed -and $FixIssues) {
        Write-Log "`nAttempting to install missing modules..." -Level 'WARN'
        foreach ($moduleName in $missingModules) {
            try {
                Write-Log "Installing $moduleName..." -Level 'INFO'
                Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber
                Write-Log "Successfully installed $moduleName" -Level 'SUCCESS'
            }
            catch {
                Write-Log "Failed to install $moduleName : $($_.Exception.Message)" -Level 'ERROR'
            }
        }
        
        # Re-check after installation
        Write-Log "`nRe-checking modules after installation..." -Level 'INFO'
        return Test-AzureModules
    }
    
    return $allPassed
}

function Test-AzureConnection {
    Write-Log "Checking Azure connectivity..." -Level 'INFO'
    
    try {
        $context = Get-AzContext -ErrorAction Stop
        
        if (-not $context) {
            Write-CheckResult -CheckName "Azure Connection" `
                              -Passed $false `
                              -Details "Not connected to Azure" `
                              -Remediation "Run: Connect-AzAccount"
            return $false
        }
        
        # Determine account type
        $accountType = if ($context.Account.Type -eq 'User') {
            if ($context.Account.Id -like '*#EXT#*') {
                'Guest/External User (MSA or B2B)'
            }
            else {
                'Corporate AAD User'
            }
        }
        else {
            $context.Account.Type
        }
        
        Write-CheckResult -CheckName "Azure Connection" `
                          -Passed $true `
                          -Details "Connected as: $($context.Account.Id) | Type: $accountType | Tenant: $($context.Tenant.Id)"
        
        return $true
    }
    catch {
        Write-CheckResult -CheckName "Azure Connection" `
                          -Passed $false `
                          -Details "Error checking connection: $($_.Exception.Message)" `
                          -Remediation "Run: Connect-AzAccount"
        return $false
    }
}

function Test-SubscriptionAccess {
    Write-Log "Checking subscription access..." -Level 'INFO'
    
    try {
        $subscriptions = Get-AzSubscription -ErrorAction Stop
        
        if (-not $subscriptions -or $subscriptions.Count -eq 0) {
            Write-CheckResult -CheckName "Subscription Access" `
                              -Passed $false `
                              -Details "No subscriptions accessible to current account" `
                              -Remediation "Verify account has access to at least one subscription. Contact subscription owner."
            return $false
        }
        
        Write-CheckResult -CheckName "Subscription Access" `
                          -Passed $true `
                          -Details "Accessible subscriptions: $($subscriptions.Count)"
        
        # Show first 5 subscriptions
        if ($Detailed) {
            Write-Host "`n  Subscription Details:" -ForegroundColor Gray
            foreach ($sub in ($subscriptions | Select-Object -First 5)) {
                Write-Host "    - $($sub.Name) ($($sub.Id)) - State: $($sub.State)" -ForegroundColor Gray
            }
            if ($subscriptions.Count -gt 5) {
                Write-Host "    ... and $($subscriptions.Count - 5) more" -ForegroundColor Gray
            }
        }
        
        return $true
    }
    catch {
        Write-CheckResult -CheckName "Subscription Access" `
                          -Passed $false `
                          -Details "Error enumerating subscriptions: $($_.Exception.Message)" `
                          -Remediation "Verify network connectivity and authentication token validity"
        return $false
    }
}

function Test-RBACPermissions {
    Write-Log "Checking RBAC permissions on subscriptions..." -Level 'INFO'
    
    try {
        $subscriptions = Get-AzSubscription -ErrorAction Stop
        
        if (-not $subscriptions) {
            Write-Log "  Skipping RBAC check (no subscriptions accessible)" -Level 'WARN'
            return $false
        }
        
        # Check first subscription as sample
        $sampleSub = $subscriptions | Select-Object -First 1
        Set-AzContext -SubscriptionId $sampleSub.Id -ErrorAction Stop | Out-Null
        
        $context = Get-AzContext
        $currentUserId = $context.Account.Id
        
        # Required permissions for discovery
        $requiredRoles = @('Reader', 'Contributor', 'Owner')
        $roleAssignments = Get-AzRoleAssignment -SignInName $currentUserId -Scope "/subscriptions/$($sampleSub.Id)" -ErrorAction SilentlyContinue
        
        if (-not $roleAssignments) {
            # Try checking without -SignInName (for service principals or guests)
            $roleAssignments = Get-AzRoleAssignment -Scope "/subscriptions/$($sampleSub.Id)" -ErrorAction SilentlyContinue |
                               Where-Object { $_.SignInName -eq $currentUserId -or $_.DisplayName -eq $currentUserId }
        }
        
        $hasRequiredRole = $false
        $assignedRoles = @()
        
        foreach ($assignment in $roleAssignments) {
            $assignedRoles += $assignment.RoleDefinitionName
            if ($assignment.RoleDefinitionName -in $requiredRoles) {
                $hasRequiredRole = $true
            }
        }
        
        if ($hasRequiredRole) {
            Write-CheckResult -CheckName "RBAC Permissions (Sample: $($sampleSub.Name))" `
                              -Passed $true `
                              -Details "Assigned roles: $($assignedRoles -join ', ')"
        }
        else {
            Write-CheckResult -CheckName "RBAC Permissions (Sample: $($sampleSub.Name))" `
                              -Passed $false `
                              -Details "Current roles: $($assignedRoles -join ', ' | Out-String). Required: Reader, Contributor, or Owner" `
                              -Remediation "Contact subscription owner to grant Reader role: New-AzRoleAssignment -SignInName '$currentUserId' -RoleDefinitionName 'Reader' -Scope '/subscriptions/$($sampleSub.Id)'"
            
            if ($Detailed) {
                Write-Host "`n  Minimum Required Permissions for Discovery:" -ForegroundColor Yellow
                Write-Host "    - Reader role at subscription scope (for inventory)" -ForegroundColor Yellow
                Write-Host "    - Optional: User Access Administrator (for RBAC owner/contributor enumeration)" -ForegroundColor Yellow
                Write-Host "`n  Minimum Required Permissions for Policy Deployment (Story 1.2):" -ForegroundColor Yellow
                Write-Host "    - Contributor role at subscription scope" -ForegroundColor Yellow
                Write-Host "    - Resource Policy Contributor role (or Owner)" -ForegroundColor Yellow
            }
        }
        
        return $hasRequiredRole
    }
    catch {
        Write-CheckResult -CheckName "RBAC Permissions" `
                          -Passed $false `
                          -Details "Error checking permissions: $($_.Exception.Message)" `
                          -Remediation "Verify you have Reader role on at least one subscription"
        return $false
    }
}

function Test-ResourceProviderAccess {
    Write-Log "Checking access to required Resource Providers..." -Level 'INFO'
    
    try {
        $subscriptions = Get-AzSubscription -ErrorAction Stop
        
        if (-not $subscriptions) {
            Write-Log "  Skipping Resource Provider check (no subscriptions accessible)" -Level 'WARN'
            return $false
        }
        
        # Check first subscription as sample
        $sampleSub = $subscriptions | Select-Object -First 1
        Set-AzContext -SubscriptionId $sampleSub.Id -ErrorAction Stop | Out-Null
        
        $requiredProviders = @('Microsoft.KeyVault', 'Microsoft.PolicyInsights', 'Microsoft.Authorization')
        
        $allRegistered = $true
        
        foreach ($provider in $requiredProviders) {
            try {
                $providerStatus = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue
                
                if ($providerStatus -and $providerStatus.RegistrationState -eq 'Registered') {
                    Write-Host "  ✓ $provider - Registered" -ForegroundColor Green
                }
                else {
                    $allRegistered = $false
                    Write-Host "  ✗ $provider - Not Registered or Not Accessible" -ForegroundColor Red
                }
            }
            catch {
                $allRegistered = $false
                Write-Host "  ✗ $provider - Error checking status" -ForegroundColor Red
            }
        }
        
        Write-CheckResult -CheckName "Resource Provider Access" `
                          -Passed $allRegistered `
                          -Details "Checked sample subscription: $($sampleSub.Name)" `
                          -Remediation "If providers not registered, contact subscription owner to run: Register-AzResourceProvider -ProviderNamespace 'Microsoft.KeyVault'"
        
        return $allRegistered
    }
    catch {
        Write-CheckResult -CheckName "Resource Provider Access" `
                          -Passed $false `
                          -Details "Error checking Resource Providers: $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Main Script

Write-Log "=====================================================================" -Level 'HEADER'
Write-Log "Azure Environment Discovery - Prerequisites Validation" -Level 'HEADER'
Write-Log "Sprint 1, Story 1.1 - Environment Discovery & Baseline Assessment" -Level 'HEADER'
Write-Log "=====================================================================" -Level 'HEADER'
Write-Log "" -Level 'INFO'

Write-Log "Supported Scenarios:" -Level 'INFO'
Write-Log "  1. MSDN subscription with guest MSA account (Owner role)" -Level 'INFO'
Write-Log "  2. Corporate AAD environment with AAD user (Reader+ role)" -Level 'INFO'
Write-Log "" -Level 'INFO'

# Track overall results
$results = @{
    PowerShellVersion = $false
    AzureModules = $false
    AzureConnection = $false
    SubscriptionAccess = $false
    RBACPermissions = $false
    ResourceProviderAccess = $false
}

# Run checks
Write-Log "=====================================================================" -Level 'HEADER'
Write-Log "PHASE 1: Local Environment Checks" -Level 'HEADER'
Write-Log "=====================================================================" -Level 'HEADER'

$results.PowerShellVersion = Test-PowerShellVersion
$results.AzureModules = Test-AzureModules

Write-Log "" -Level 'INFO'
Write-Log "=====================================================================" -Level 'HEADER'
Write-Log "PHASE 2: Azure Connectivity Checks" -Level 'HEADER'
Write-Log "=====================================================================" -Level 'HEADER'

$results.AzureConnection = Test-AzureConnection

if ($results.AzureConnection) {
    $results.SubscriptionAccess = Test-SubscriptionAccess
    
    if ($results.SubscriptionAccess) {
        $results.RBACPermissions = Test-RBACPermissions
        $results.ResourceProviderAccess = Test-ResourceProviderAccess
    }
}
else {
    Write-Log "Skipping remaining checks (not connected to Azure)" -Level 'WARN'
}

# Summary
Write-Log "" -Level 'INFO'
Write-Log "=====================================================================" -Level 'HEADER'
Write-Log "VALIDATION SUMMARY" -Level 'HEADER'
Write-Log "=====================================================================" -Level 'HEADER'

$passedCount = ($results.Values | Where-Object { $_ -eq $true }).Count
$totalCount = $results.Count

Write-Log "" -Level 'INFO'
Write-Log "Checks Passed: $passedCount / $totalCount" -Level $(if ($passedCount -eq $totalCount) { 'SUCCESS' } else { 'WARN' })

foreach ($check in $results.GetEnumerator()) {
    $status = if ($check.Value) { "✓ PASS" } else { "✗ FAIL" }
    $color = if ($check.Value) { 'Green' } else { 'Red' }
    Write-Host "  $status - $($check.Key)" -ForegroundColor $color
}

Write-Log "" -Level 'INFO'

if ($passedCount -eq $totalCount) {
    Write-Log "✓ All prerequisites met! Ready to run discovery scripts." -Level 'SUCCESS'
    Write-Log "" -Level 'INFO'
    Write-Log "Next Steps:" -Level 'INFO'
    Write-Log "  1. Run: .\Start-EnvironmentDiscovery.ps1 (unified menu-driven script)" -Level 'INFO'
    Write-Log "  2. Or run: .\Invoke-EnvironmentDiscovery.ps1 (orchestration script)" -Level 'INFO'
    exit 0
}
else {
    Write-Log "✗ Some prerequisites not met. Review failures above." -Level 'ERROR'
    Write-Log "" -Level 'INFO'
    Write-Log "Common Resolutions:" -Level 'WARN'
    
    if (-not $results.PowerShellVersion) {
        Write-Log "  - Install PowerShell 7: https://aka.ms/powershell-release" -Level 'WARN'
    }
    
    if (-not $results.AzureModules) {
        Write-Log "  - Install Azure modules: Install-Module Az -Scope CurrentUser -Force" -Level 'WARN'
        Write-Log "  - Or run this script with -FixIssues to auto-install" -Level 'WARN'
    }
    
    if (-not $results.AzureConnection) {
        Write-Log "  - Connect to Azure: Connect-AzAccount" -Level 'WARN'
        Write-Log "  - For guest accounts: Connect-AzAccount -TenantId '<tenant-id>'" -Level 'WARN'
    }
    
    if (-not $results.RBACPermissions) {
        Write-Log "  - Request Reader role on target subscriptions" -Level 'WARN'
        Write-Log "  - For MSDN: Verify you're the subscription Owner" -Level 'WARN'
        Write-Log "  - For Corporate: Contact Cloud Brokers or subscription owner" -Level 'WARN'
    }
    
    exit 1
}

#endregion
