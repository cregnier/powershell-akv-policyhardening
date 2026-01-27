<#
.SYNOPSIS
    Interactive menu for Azure Key Vault Policy deployment scenarios with history tracking.

.DESCRIPTION
    Provides guided deployment experience with:
    - Interactive menu of all 9 deployment scenarios
    - Deployment history tracking (which scenarios already deployed)
    - Pre-deployment validation and warnings
    - Parameter collection and validation
    - Preview mode support
    - Deployment history persistence

.PARAMETER SubscriptionId
    Azure subscription ID. If not provided, uses current Azure context.

.PARAMETER ManagedIdentityResourceId
    Managed identity resource ID for auto-remediation scenarios (3 and 6).
    Required for scenarios that use DeployIfNotExists/Modify policies.

.PARAMETER SkipHistory
    Skip loading deployment history (useful for fresh start).

.PARAMETER ClearHistory
    Clear all deployment history and start fresh.

.EXAMPLE
    .\Deploy-PolicyScenarios.ps1
    Interactive menu with history tracking

.EXAMPLE
    .\Deploy-PolicyScenarios.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb"
    Pre-set subscription ID

.EXAMPLE
    .\Deploy-PolicyScenarios.ps1 -ClearHistory
    Clear history and start fresh

.NOTES
    Version: 1.0
    Last Updated: 2026-01-22
    Deployment history stored in: .policy-deployment-history.json
#>

[CmdletBinding()]
param(
    [string]$SubscriptionId,
    [string]$ManagedIdentityResourceId,
    [switch]$SkipHistory,
    [switch]$ClearHistory
)

# Configuration
$HistoryFile = ".policy-deployment-history.json"
$ScriptRoot = $PSScriptRoot
$DeploymentScript = Join-Path $ScriptRoot "AzPolicyImplScript.ps1"

# Scenario definitions
$Scenarios = @(
    @{
        Number = 1
        Name = "DevTest Baseline (30 Policies)"
        Description = "Safe initial deployment with core policies - Audit mode"
        ParameterFile = "PolicyParameters-DevTest.json"
        RequiresIdentity = $false
        RequiresMG = $false
        RequiresRG = $false
        RiskLevel = "Low"
        Duration = "5 minutes"
        Effect = "Audit"
    },
    @{
        Number = 2
        Name = "DevTest Full (46 Policies)"
        Description = "Comprehensive testing of all policies - Audit mode"
        ParameterFile = "PolicyParameters-DevTest-Full.json"
        RequiresIdentity = $false
        RequiresMG = $false
        RequiresRG = $false
        RiskLevel = "Low"
        Duration = "5 minutes"
        Effect = "Audit"
    },
    @{
        Number = 3
        Name = "DevTest Auto-Remediation (46 Policies)"
        Description = "Test automated compliance fixes - Audit + DeployIfNotExists"
        ParameterFile = "PolicyParameters-DevTest-Full-Remediation.json"
        RequiresIdentity = $true
        RequiresMG = $false
        RequiresRG = $false
        RiskLevel = "Medium"
        Duration = "60-90 minutes (Azure evaluation)"
        Effect = "Audit + DINE"
    },
    @{
        Number = 4
        Name = "Production Audit (46 Policies)"
        Description = "Production monitoring without blocking - Audit mode"
        ParameterFile = "PolicyParameters-Production.json"
        RequiresIdentity = $false
        RequiresMG = $false
        RequiresRG = $false
        RiskLevel = "Low"
        Duration = "5 minutes"
        Effect = "Audit"
    },
    @{
        Number = 5
        Name = "Production Deny (35 Policies)"
        Description = "Maximum enforcement - BLOCKS non-compliant resources"
        ParameterFile = "PolicyParameters-Production-Deny.json"
        RequiresIdentity = $false
        RequiresMG = $false
        RequiresRG = $false
        RiskLevel = "HIGH"
        Duration = "5 minutes"
        Effect = "Deny"
    },
    @{
        Number = 6
        Name = "Production Auto-Remediation (46 Policies)"
        Description = "Production automated compliance - Audit + DeployIfNotExists"
        ParameterFile = "PolicyParameters-Production-Remediation.json"
        RequiresIdentity = $true
        RequiresMG = $false
        RequiresRG = $false
        RiskLevel = "Medium"
        Duration = "60-90 minutes (Azure evaluation)"
        Effect = "Audit + DINE"
    },
    @{
        Number = 7
        Name = "Resource Group Scope (30 Policies)"
        Description = "Limited scope testing - Single resource group"
        ParameterFile = "PolicyParameters-DevTest.json"
        RequiresIdentity = $false
        RequiresMG = $false
        RequiresRG = $true
        RiskLevel = "Low"
        Duration = "5 minutes"
        Effect = "Audit"
    },
    @{
        Number = 8
        Name = "Management Group Scope (46 Policies)"
        Description = "Organization-wide governance - Multiple subscriptions"
        ParameterFile = "PolicyParameters-Production.json"
        RequiresIdentity = $false
        RequiresMG = $true
        RequiresRG = $false
        RiskLevel = "Medium"
        Duration = "5 minutes"
        Effect = "Audit"
    },
    @{
        Number = 9
        Name = "Rollback (Remove All Policies)"
        Description = "Remove all KV-* policy assignments"
        ParameterFile = $null
        RequiresIdentity = $false
        RequiresMG = $false
        RequiresRG = $false
        RiskLevel = "Low"
        Duration = "3 minutes"
        Effect = "Removal"
    }
)

# Functions

function Get-TestResourceGroupName {
    <#
    .SYNOPSIS
        Auto-discovers the test resource group created by Setup-AzureKeyVaultPolicyEnvironment.ps1
    #>
    try {
        Write-Host "  🔍 Auto-discovering test resource group..." -ForegroundColor Cyan
        
        # Try to find the test resource group with Key Vaults
        $rgName = "rg-policy-keyvault-test"
        
        $rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
        
        if ($rg) {
            # Verify it has Key Vaults
            $kvCount = (Get-AzKeyVault -ResourceGroupName $rgName -ErrorAction SilentlyContinue).Count
            
            Write-Host "  ✅ Found: $($rg.ResourceGroupName)" -ForegroundColor Green
            Write-Host "     Location: $($rg.Location)" -ForegroundColor Gray
            Write-Host "     Key Vaults: $kvCount" -ForegroundColor Gray
            return $rg.ResourceGroupName
        } else {
            Write-Host "  ⚠️  Test resource group not found: $rgName" -ForegroundColor Yellow
            Write-Host "     Run Setup-AzureKeyVaultPolicyEnvironment.ps1 to create it.`n" -ForegroundColor Yellow
            return $null
        }
    } catch {
        Write-Host "  ⚠️  Error querying resource group: $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

function Get-ManagementGroupId {
    <#
    .SYNOPSIS
        Auto-discovers available management groups in the current Azure tenant
    #>
    try {
        Write-Host "  🔍 Auto-discovering management groups..." -ForegroundColor Cyan
        
        # Get all management groups
        $mgs = Get-AzManagementGroup -ErrorAction SilentlyContinue
        
        if (-not $mgs) {
            Write-Host "  ⚠️  No management groups found" -ForegroundColor Yellow
            Write-Host "     Management groups are optional and not created by default`n" -ForegroundColor Gray
            return $null
        }
        
        # Filter out the Tenant Root Group (too broad for testing)
        $nonRootMgs = $mgs | Where-Object { $_.DisplayName -ne 'Tenant Root Group' }
        
        if ($nonRootMgs.Count -eq 1) {
            # Only one non-root MG, use it
            $mg = $nonRootMgs[0]
            Write-Host "  ✅ Found: $($mg.DisplayName)" -ForegroundColor Green
            Write-Host "     ID: $($mg.Name)" -ForegroundColor Gray
            return $mg.Name
        } elseif ($nonRootMgs.Count -gt 1) {
            # Multiple MGs - show menu
            Write-Host "`n  Available Management Groups:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $nonRootMgs.Count; $i++) {
                Write-Host "    [$($i+1)] $($nonRootMgs[$i].DisplayName) ($($nonRootMgs[$i].Name))" -ForegroundColor White
            }
            
            $choice = Read-Host "`n  Select management group (1-$($nonRootMgs.Count))"
            $index = [int]$choice - 1
            
            if ($index -ge 0 -and $index -lt $nonRootMgs.Count) {
                $mg = $nonRootMgs[$index]
                Write-Host "  ✅ Selected: $($mg.DisplayName)" -ForegroundColor Green
                return $mg.Name
            } else {
                Write-Host "  ⚠️  Invalid selection" -ForegroundColor Yellow
                return $null
            }
        } else {
            # Only Tenant Root Group available
            Write-Host "  ⚠️  Only Tenant Root Group found (too broad for testing)" -ForegroundColor Yellow
            Write-Host "     Create a management group for testing, or skip this scenario`n" -ForegroundColor Gray
            return $null
        }
    } catch {
        Write-Host "  ⚠️  Error querying management groups: $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

function Get-ManagedIdentityResourceId {
    <#
    .SYNOPSIS
        Auto-discovers the managed identity created by Setup-AzureKeyVaultPolicyEnvironment.ps1
    #>
    try {
        Write-Host "  🔍 Auto-discovering managed identity..." -ForegroundColor Cyan
        
        # Try to find the managed identity in the known resource group
        $rgName = "rg-policy-remediation"
        $identityName = "id-policy-remediation"
        
        $identity = Get-AzUserAssignedIdentity -ResourceGroupName $rgName -Name $identityName -ErrorAction SilentlyContinue
        
        if ($identity) {
            Write-Host "  ✅ Found: $($identity.Name)" -ForegroundColor Green
            Write-Host "     Resource ID: $($identity.Id)" -ForegroundColor Gray
            return $identity.Id
        } else {
            Write-Host "  ⚠️  Managed identity not found in resource group: $rgName" -ForegroundColor Yellow
            Write-Host "     Expected name: $identityName" -ForegroundColor Gray
            Write-Host "     Run Setup-AzureKeyVaultPolicyEnvironment.ps1 to create it.`n" -ForegroundColor Yellow
            return $null
        }
    } catch {
        Write-Host "  ⚠️  Error querying managed identity: $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

function Write-Header {
    param([string]$Title)
    
    $width = 80
    Write-Host ""
    Write-Host ("=" * $width) -ForegroundColor Cyan
    Write-Host $Title.PadLeft(($width + $Title.Length) / 2).PadRight($width) -ForegroundColor Cyan
    Write-Host ("=" * $width) -ForegroundColor Cyan
    Write-Host ""
}

function Write-SubHeader {
    param([string]$Title)
    Write-Host "`n$Title" -ForegroundColor Yellow
    Write-Host ("-" * $Title.Length) -ForegroundColor Yellow
}

function Get-DeploymentHistory {
    if ($SkipHistory -or -not (Test-Path $HistoryFile)) {
        return @{}
    }
    
    try {
        $history = Get-Content $HistoryFile -Raw | ConvertFrom-Json
        return $history | ConvertTo-Json | ConvertFrom-Json -AsHashtable
    }
    catch {
        Write-Warning "Could not load deployment history: $($_.Exception.Message)"
        return @{}
    }
}

function Save-DeploymentHistory {
    param([hashtable]$History)
    
    try {
        $History | ConvertTo-Json -Depth 10 | Set-Content $HistoryFile -Force
    }
    catch {
        Write-Warning "Could not save deployment history: $($_.Exception.Message)"
    }
}

function Add-DeploymentRecord {
    param(
        [int]$ScenarioNumber,
        [string]$ScenarioName,
        [bool]$Success,
        [string]$Mode,
        [hashtable]$Parameters
    )
    
    $history = Get-DeploymentHistory
    
    $record = @{
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Success = $Success
        Mode = $Mode
        Parameters = $Parameters
    }
    
    if (-not $history.ContainsKey("Scenario$ScenarioNumber")) {
        $history["Scenario$ScenarioNumber"] = @{
            Name = $ScenarioName
            Deployments = @()
        }
    }
    
    $history["Scenario$ScenarioNumber"].Deployments += $record
    
    Save-DeploymentHistory -History $history
}

function Show-ScenarioMenu {
    param([hashtable]$History)
    
    Write-Header "Azure Key Vault Policy Deployment Scenarios"
    
    Write-Host "Select a deployment scenario:`n" -ForegroundColor White
    
    foreach ($scenario in $Scenarios) {
        $num = $scenario.Number
        $deployed = $false
        $lastDeployment = $null
        
        # Try both key formats (with and without space)
        $historyKey = if ($History.ContainsKey("Scenario$num")) { "Scenario$num" } 
                     elseif ($History.ContainsKey("Scenario $num")) { "Scenario $num" } 
                     else { $null }
        
        if ($historyKey) {
            $deployments = @($History[$historyKey].Deployments)  # Ensure array
            if ($deployments.Count -gt 0) {
                $deployed = $true
                $lastDeployment = $deployments | Select-Object -Last 1
            }
        }
        
        # Color code by risk level
        $color = switch ($scenario.RiskLevel) {
            "Low" { "Green" }
            "Medium" { "Yellow" }
            "HIGH" { "Red" }
            default { "White" }
        }
        
        # Build status indicator
        $status = if ($deployed) {
            # Handle both object and string formats
            if ($lastDeployment -is [string]) {
                # Parse string format
                $success = $lastDeployment -match 'Success=True'
                if ($lastDeployment -match 'Timestamp=([^}]+)') { 
                    $timestamp = $Matches[1].Trim() 
                } else { 
                    $timestamp = 'Unknown' 
                }
                if ($success) {
                    " [\u2713 Deployed: $timestamp]"
                } else {
                    " [\u2717 Failed: $timestamp]"
                }
            } else {
                if ($lastDeployment.Success) {
                    " [\u2713 Deployed: $($lastDeployment.Timestamp)]"
                } else {
                    " [\u2717 Failed: $($lastDeployment.Timestamp)]"
                }
            }
        } else {
            " [Not Deployed]"
        }
        
        Write-Host "  [$num] " -ForegroundColor Cyan -NoNewline
        Write-Host "$($scenario.Name)" -ForegroundColor $color -NoNewline
        Write-Host $status -ForegroundColor Gray
        Write-Host "      $($scenario.Description)" -ForegroundColor DarkGray
        Write-Host "      Risk: " -NoNewline -ForegroundColor DarkGray
        Write-Host $scenario.RiskLevel -ForegroundColor $color -NoNewline
        Write-Host " | Duration: " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($scenario.Duration)" -ForegroundColor DarkGray
        Write-Host ""
    }
    
    Write-Host "  [V] " -ForegroundColor Cyan -NoNewline
    Write-Host "Validate Last Deployment" -ForegroundColor Green
    Write-Host "  [H] " -ForegroundColor Cyan -NoNewline
    Write-Host "View Deployment History" -ForegroundColor White
    Write-Host "  [C] " -ForegroundColor Cyan -NoNewline
    Write-Host "Clear Deployment History" -ForegroundColor White
    Write-Host "  [Q] " -ForegroundColor Cyan -NoNewline
    Write-Host "Quit" -ForegroundColor White
    Write-Host ""
}

function Invoke-ScenarioValidation {
    <#
    .SYNOPSIS
        Validates the last deployment using Validate-Deployment.ps1
    #>
    param([hashtable]$History)
    
    Write-Header "Validate Last Deployment"
    
    # Find the most recent deployment
    $lastScenario = $null
    $lastTimestamp = [DateTime]::MinValue
    
    foreach ($key in $History.Keys) {
        $scenarioData = $History[$key]
        $deployments = @($scenarioData.Deployments)
        
        if ($deployments.Count -gt 0) {
            $lastDeployment = $deployments | Select-Object -Last 1
            
            # Handle both string and object formats
            if ($lastDeployment -is [string]) {
                if ($lastDeployment -match 'Timestamp=([^}]+)') {
                    $timestamp = [DateTime]::Parse($Matches[1].Trim())
                } else {
                    continue
                }
            } else {
                $timestamp = [DateTime]::Parse($lastDeployment.Timestamp)
            }
            
            if ($timestamp -gt $lastTimestamp) {
                $lastTimestamp = $timestamp
                $lastScenario = $key
            }
        }
    }
    
    if (-not $lastScenario) {
        Write-Host "No deployments found in history.`n" -ForegroundColor Yellow
        Write-Host "Deploy a scenario first, then validate it.`n" -ForegroundColor Gray
        return
    }
    
    # Extract scenario number
    $scenarioNum = $lastScenario -replace 'Scenario', ''
    $scenario = $Scenarios | Where-Object { $_.Number -eq [int]$scenarioNum }
    
    if (-not $scenario) {
        Write-Host "Error: Could not find scenario $scenarioNum definition.`n" -ForegroundColor Red
        return
    }
    
    Write-Host "Last deployment: " -NoNewline -ForegroundColor Cyan
    Write-Host "Scenario $scenarioNum - $($scenario.Name)" -ForegroundColor White
    Write-Host "Timestamp: $lastTimestamp`n" -ForegroundColor Gray
    
    # Find the transcript file
    $transcriptPattern = "scenario${scenarioNum}-*.txt"
    $transcriptFiles = Get-ChildItem -Filter $transcriptPattern -ErrorAction SilentlyContinue | 
        Sort-Object LastWriteTime -Descending
    
    if ($transcriptFiles.Count -eq 0) {
        Write-Host "⚠️  No transcript file found for Scenario $scenarioNum" -ForegroundColor Yellow
        Write-Host "   Looking for: $transcriptPattern`n" -ForegroundColor Gray
        return
    }
    
    $transcriptFile = $transcriptFiles[0].Name
    Write-Host "📝 Transcript: $transcriptFile" -ForegroundColor Cyan
    
    # Determine expected values based on scenario
    $expectedSkipped = if ($scenario.RequiresIdentity) { 0 } else { 8 }
    $expectedPolicies = if ($scenario.ParameterFile -match 'DevTest\.json') { 30 } else { 46 }
    
    # Run validation
    Write-Host "`n🔍 Running validation...`n" -ForegroundColor Cyan
    
    $validationScript = Join-Path $ScriptRoot "Validate-Deployment.ps1"
    if (-not (Test-Path $validationScript)) {
        Write-Host "❌ Validation script not found: $validationScript`n" -ForegroundColor Red
        return
    }
    
    & $validationScript `
        -ScenarioNumber $scenarioNum `
        -TranscriptFile $transcriptFile `
        -ExpectedParameterFile (Split-Path $scenario.ParameterFile -Leaf) `
        -ExpectedPolicyCount $expectedPolicies `
        -ExpectedSkippedCount $expectedSkipped
    
    Write-Host ""
}

function Show-DeploymentHistory {
    param([hashtable]$History)
    
    Write-Header "Deployment History"
    
    if ($History.Keys.Count -eq 0) {
        Write-Host "No deployment history found.`n" -ForegroundColor Yellow
        return
    }
    
    foreach ($key in ($History.Keys | Sort-Object)) {
        $scenarioData = $History[$key]
        $scenarioNum = $key -replace 'Scenario', ''
        
        Write-SubHeader "Scenario ${scenarioNum}: $($scenarioData.Name)"
        
        $deployments = @($scenarioData.Deployments)  # Ensure array
        if ($deployments.Count -eq 0) {
            Write-Host "  No deployments recorded" -ForegroundColor Gray
            continue
        }
        
        foreach ($deployment in $deployments) {
            # Handle both object and string formats
            if ($deployment -is [string]) {
                # Parse string format: @{Parameters=; Success=True; Mode=Actual; Timestamp=2026-01-22 17:11:17}
                if ($deployment -match 'Success=([^;]+)') { $success = $Matches[1] -eq 'True' } else { $success = $false }
                if ($deployment -match 'Mode=([^;]+)') { $mode = $Matches[1] } else { $mode = 'Unknown' }
                if ($deployment -match 'Timestamp=([^}]+)') { $timestamp = $Matches[1] } else { $timestamp = 'Unknown' }
            } else {
                # Object format
                $success = $deployment.Success
                $mode = $deployment.Mode
                $timestamp = $deployment.Timestamp
            }
            
            $statusIcon = if ($success) { "✓" } else { "✗" }
            $statusColor = if ($success) { "Green" } else { "Red" }
            
            Write-Host "  [$statusIcon] " -ForegroundColor $statusColor -NoNewline
            Write-Host "$timestamp " -ForegroundColor White -NoNewline
            Write-Host "[$mode mode]" -ForegroundColor Cyan
            
            if ($deployment.Parameters) {
                foreach ($param in $deployment.Parameters.Keys) {
                    Write-Host "      $param : " -NoNewline -ForegroundColor DarkGray
                    Write-Host "$($deployment.Parameters[$param])" -ForegroundColor Gray
                }
            }
        }
        Write-Host ""
    }
    
    Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Get-UserConfirmation {
    param(
        [string]$Message,
        [string]$DefaultChoice = "N"
    )
    
    $choices = "&Yes", "&No"
    $defaultChoice = if ($DefaultChoice -eq "Y") { 0 } else { 1 }
    
    $decision = $Host.UI.PromptForChoice("", $Message, $choices, $defaultChoice)
    return $decision -eq 0
}

function Deploy-Scenario {
    param(
        [hashtable]$Scenario,
        [string]$SubId,
        [string]$IdentityId
    )
    
    Write-Header "Deploying: $($Scenario.Name)"
    
    # Show scenario details
    Write-Host "Description: " -NoNewline -ForegroundColor White
    Write-Host $Scenario.Description -ForegroundColor Gray
    Write-Host "Parameter File: " -NoNewline -ForegroundColor White
    Write-Host $Scenario.ParameterFile -ForegroundColor Gray
    Write-Host "Effect: " -NoNewline -ForegroundColor White
    Write-Host $Scenario.Effect -ForegroundColor Gray
    Write-Host "Risk Level: " -NoNewline -ForegroundColor White
    $riskColor = switch ($Scenario.RiskLevel) {
        "Low" { "Green" }
        "Medium" { "Yellow" }
        "HIGH" { "Red" }
    }
    Write-Host $Scenario.RiskLevel -ForegroundColor $riskColor
    Write-Host "Duration: " -NoNewline -ForegroundColor White
    Write-Host "$($Scenario.Duration)`n" -ForegroundColor Gray
    
    # Check prerequisites
    if ($Scenario.RequiresIdentity -and -not $IdentityId) {
        Write-Host "⚠️  This scenario requires a managed identity for auto-remediation.`n" -ForegroundColor Yellow
        
        # Try to auto-discover the managed identity
        $discoveredId = Get-ManagedIdentityResourceId
        
        if ($discoveredId) {
            Write-Host "  ✅ Using auto-discovered managed identity" -ForegroundColor Green
            $IdentityId = $discoveredId
        } else {
            # Fall back to manual entry
            Write-Host "  Manual entry required:" -ForegroundColor Yellow
            $IdentityId = Read-Host "Enter Managed Identity Resource ID (or 'skip' to cancel)"
            
            if ($IdentityId -eq 'skip' -or [string]::IsNullOrWhiteSpace($IdentityId)) {
                Write-Host "`nDeployment cancelled.`n" -ForegroundColor Yellow
                return $false
            }
        }
        
        Write-Host ""
    }
    
    # Build parameters
    $deployParams = @{}
    
    if ($Scenario.Number -ne 9) {  # Not rollback
        $paramFile = Join-Path $ScriptRoot $Scenario.ParameterFile
        if (-not (Test-Path $paramFile)) {
            Write-Host "❌ Parameter file not found: $paramFile`n" -ForegroundColor Red
            return $false
        }
        $deployParams['ParameterFile'] = $paramFile
    }
    
    if ($Scenario.RequiresIdentity -and $IdentityId) {
        $deployParams['IdentityResourceId'] = $IdentityId
    }
    
    if ($Scenario.RequiresRG) {
        # Try auto-discovery first
        $rgName = Get-TestResourceGroupName
        
        if (-not $rgName) {
            # Fall back to manual input
            Write-Host "`n  Manual input required:" -ForegroundColor Yellow
            $rgName = Read-Host "`nEnter Resource Group name"
        }
        
        if ([string]::IsNullOrWhiteSpace($rgName)) {
            Write-Host "`nDeployment cancelled.`n" -ForegroundColor Yellow
            return $false
        }
        
        $deployParams['ScopeType'] = 'ResourceGroup'
        $deployParams['ResourceGroupName'] = $rgName
    }
    
    if ($Scenario.RequiresMG) {
        # Try auto-discovery first
        $mgId = Get-ManagementGroupId
        
        if (-not $mgId) {
            # Fall back to manual input
            Write-Host "`n  Manual input required:" -ForegroundColor Yellow
            $mgId = Read-Host "`nEnter Management Group ID (or press Enter to skip)"
        }
        
        if ([string]::IsNullOrWhiteSpace($mgId)) {
            Write-Host "`n⏭️  Scenario skipped - No management group available.`n" -ForegroundColor Yellow
            return $false
        }
        
        $deployParams['ScopeType'] = 'ManagementGroup'
        $deployParams['ManagementGroupId'] = $mgId
    }
    
    if ($Scenario.Number -eq 9) {  # Rollback
        $deployParams['Rollback'] = $true
    }
    
    $deployParams['SkipRBACCheck'] = $true
    
    # Ask for Preview or Actual
    Write-Host "`nDeployment Mode:" -ForegroundColor White
    Write-Host "  [P] Preview (safe validation - no changes)" -ForegroundColor Green
    Write-Host "  [A] Actual (deploy policies to Azure)" -ForegroundColor Yellow
    
    $modeChoice = Read-Host "`nSelect mode (P/A)"
    $isPreview = $modeChoice -ne 'A'
    $mode = if ($isPreview) { "Preview" } else { "Actual" }
    
    if ($isPreview) {
        $deployParams['Preview'] = $true
        Write-Host "`n✓ Preview mode selected - no changes will be made`n" -ForegroundColor Green
    }
    else {
        Write-Host "`n⚠️  ACTUAL DEPLOYMENT MODE SELECTED`n" -ForegroundColor Yellow
        
        if ($Scenario.RiskLevel -eq "HIGH") {
            Write-Host "❗ WARNING: This scenario has HIGH RISK LEVEL" -ForegroundColor Red
            Write-Host "   $($Scenario.Description)`n" -ForegroundColor Yellow
        }
        
        if (-not (Get-UserConfirmation -Message "Proceed with actual deployment?" -DefaultChoice "N")) {
            Write-Host "`nDeployment cancelled.`n" -ForegroundColor Yellow
            return $false
        }
    }
    
    # Start transcript for this deployment
    $scenarioSlug = $Scenario.Name -replace '[^\w\s-]', '' -replace '\s+', '-' -replace '-+', '-'
    $scenarioSlug = $scenarioSlug.ToLower()
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $transcriptFile = ".\scenario$($Scenario.Number)-$scenarioSlug-$timestamp.txt"
    Start-Transcript -Path $transcriptFile -Force | Out-Null
    
    # Execute deployment
    Write-Host "`n🚀 Starting deployment...`n" -ForegroundColor Cyan
    Write-Host "Command: .\AzPolicyImplScript.ps1" -ForegroundColor Gray
    
    # Build argument array for custom argument parser in AzPolicyImplScript.ps1
    $argArray = @()
    foreach ($key in $deployParams.Keys) {
        if ($deployParams[$key] -is [bool]) {
            if ($deployParams[$key]) {
                Write-Host "  -$key" -ForegroundColor Gray
                $argArray += "-$key"
            }
        } else {
            Write-Host "  -$key $($deployParams[$key])" -ForegroundColor Gray
            $argArray += "-$key"
            $argArray += $deployParams[$key]
        }
    }
    Write-Host ""
    
    try {
        # Use array splatting (@) to properly expand arguments for custom argument parser
        & $DeploymentScript @argArray
        $success = $LASTEXITCODE -eq 0 -or $?
        
        # Stop transcript
        Stop-Transcript | Out-Null
        
        # Record deployment
        Add-DeploymentRecord -ScenarioNumber $Scenario.Number `
                             -ScenarioName $Scenario.Name `
                             -Success $success `
                             -Mode $mode `
                             -Parameters $deployParams
        
        if ($success) {
            Write-Host "`n✅ Deployment completed successfully!`n" -ForegroundColor Green
            
            # Offer blocking validation tests after Scenario 5 (Production Deny)
            if ($Scenario.Number -eq 5) {
                Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host "  BLOCKING VALIDATION TEST AVAILABLE" -ForegroundColor Yellow
                Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "  Scenario 5 (Production Deny) has been deployed with policies in Deny mode." -ForegroundColor White
                Write-Host "  You can now run blocking validation tests to verify that Deny policies" -ForegroundColor White
                Write-Host "  are actually preventing non-compliant operations." -ForegroundColor White
                Write-Host ""
                Write-Host "  Test Coverage:" -ForegroundColor Yellow
                Write-Host "    • 4 vault-level operations (public network, purge protection, etc.)" -ForegroundColor Gray
                Write-Host "    • 5 resource-level operations (keys, secrets, certificates)" -ForegroundColor Gray
                Write-Host "    • Expected blocking rate: 80%+" -ForegroundColor Gray
                Write-Host ""
                
                $runTests = Get-UserConfirmation -Message "Run blocking validation tests now?" -DefaultChoice "Y"
                
                if ($runTests) {
                    Write-Host ""
                    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                    Write-Host "  EXECUTING BLOCKING VALIDATION TESTS" -ForegroundColor Yellow
                    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                    Write-Host ""
                    
                    try {
                        # Run blocking validation tests
                        & $DeploymentScript -TestProductionEnforcement -SkipRBACCheck
                        
                        Write-Host ""
                        Write-Host "✅ Blocking validation tests completed!" -ForegroundColor Green
                        Write-Host ""
                    }
                    catch {
                        Write-Host ""
                        Write-Host "⚠️  Blocking validation tests encountered errors: $($_.Exception.Message)" -ForegroundColor Yellow
                        Write-Host ""
                    }
                }
                else {
                    Write-Host ""
                    Write-Host "  ⏭️  Skipping blocking validation tests." -ForegroundColor Yellow
                    Write-Host "  You can run them later with:" -ForegroundColor Gray
                    Write-Host "    .\AzPolicyImplScript.ps1 -TestProductionEnforcement -SkipRBACCheck" -ForegroundColor Cyan
                    Write-Host ""
                }
            }
        } else {
            Write-Host "`n⚠️  Deployment completed with warnings or errors`n" -ForegroundColor Yellow
        }
        
        return $success
    }
    catch {
        # Stop transcript on error
        Stop-Transcript | Out-Null
        
        Write-Host "`n❌ Deployment failed: $($_.Exception.Message)`n" -ForegroundColor Red
        
        Add-DeploymentRecord -ScenarioNumber $Scenario.Number `
                             -ScenarioName $Scenario.Name `
                             -Success $false `
                             -Mode $mode `
                             -Parameters $deployParams
        
        return $false
    }
}

# Main script
try {
    # Clear screen
    Clear-Host
    
    # Check if deployment script exists
    if (-not (Test-Path $DeploymentScript)) {
        Write-Host "❌ Deployment script not found: $DeploymentScript`n" -ForegroundColor Red
        exit 1
    }
    
    # Clear history if requested
    if ($ClearHistory -and (Test-Path $HistoryFile)) {
        Remove-Item $HistoryFile -Force
        Write-Host "✓ Deployment history cleared`n" -ForegroundColor Green
    }
    
    # Main loop
    while ($true) {
        $history = Get-DeploymentHistory
        Show-ScenarioMenu -History $history
        
        $choice = Read-Host "Enter your choice"
        
        switch ($choice.ToUpper()) {
            "V" {
                Invoke-ScenarioValidation -History $history
                Read-Host "`nPress Enter to continue"
                continue
            }
            "H" {
                Show-DeploymentHistory -History $history
                continue
            }
            "C" {
                if (Get-UserConfirmation -Message "Clear all deployment history?" -DefaultChoice "N") {
                    if (Test-Path $HistoryFile) {
                        Remove-Item $HistoryFile -Force
                    }
                    Write-Host "`n✓ History cleared`n" -ForegroundColor Green
                    Start-Sleep -Seconds 1
                }
                continue
            }
            "Q" {
                Write-Host "`nExiting...`n" -ForegroundColor Cyan
                exit 0
            }
            default {
                if ($choice -match '^\d+$') {
                    $scenarioNum = [int]$choice
                    $scenario = $Scenarios | Where-Object { $_.Number -eq $scenarioNum }
                    
                    if ($scenario) {
                        Deploy-Scenario -Scenario $scenario `
                                      -SubId $SubscriptionId `
                                      -IdentityId $ManagedIdentityResourceId
                        
                        Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    else {
                        Write-Host "`n⚠️  Invalid scenario number: $choice`n" -ForegroundColor Yellow
                        Start-Sleep -Seconds 1
                    }
                }
                else {
                    Write-Host "`n⚠️  Invalid choice: $choice`n" -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                }
            }
        }
    }
}
catch {
    Write-Host "`n❌ Unexpected error: $($_.Exception.Message)`n" -ForegroundColor Red
    exit 1
}
