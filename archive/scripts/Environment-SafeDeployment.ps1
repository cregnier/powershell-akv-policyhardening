# Environment-SafeDeployment.ps1
# Helper script demonstrating safe deployment workflow from dev/test to production
# This script provides safeguards and step-by-step guidance for policy deployments

<#
.SYNOPSIS
    Safe deployment helper for Azure Key Vault policies across environments

.DESCRIPTION
    This script provides a guided workflow for deploying policies safely:
    1. Test in dev/test environment first
    2. Deploy to production in Audit mode
    3. Review compliance and remediate
    4. Enable enforcement (Deny mode) in production

.PARAMETER Environment
    Target environment: DevTest or Production

.PARAMETER Phase
    Deployment phase: Test, Audit, or Enforce

.PARAMETER Scope
    Deployment scope: ResourceGroup or Subscription

.PARAMETER WhatIf
    Preview changes without deploying

.EXAMPLE
    # Phase 1: Test in dev/test
    .\Environment-SafeDeployment.ps1 -Environment DevTest -Phase Test -Scope ResourceGroup

.EXAMPLE
    # Phase 2: Production audit mode
    .\Environment-SafeDeployment.ps1 -Environment Production -Phase Audit -Scope Subscription

.EXAMPLE
    # Phase 3: Production enforcement (after validation)
    .\Environment-SafeDeployment.ps1 -Environment Production -Phase Enforce -Scope Subscription
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('DevTest', 'Production')]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet('Test', 'Audit', 'Enforce')]
    [string]$Phase,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('ResourceGroup', 'Subscription')]
    [string]$Scope = 'ResourceGroup',
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

# Configuration
$script:Config = @{
    DevTest = @{
        SubscriptionId = "ab1336c7-687d-4107-b0f6-9649a0458adb"
        ResourceGroup = "rg-policy-keyvault-test"
        ParameterFile = "./PolicyParameters-DevTest.json"
    }
    Production = @{
        SubscriptionId = "ab1336c7-687d-4107-b0f6-9649a0458adb"
        ResourceGroup = $null  # Not used for subscription scope
        ParameterFile = "./PolicyParameters-Production.json"
    }
    ManagedIdentity = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
}

function Show-DeploymentBanner {
    param([string]$Env, [string]$Ph, [string]$Sc)
    
    $color = if ($Env -eq 'Production') { 'Red' } else { 'Cyan' }
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor $color
    Write-Host "║  Azure Key Vault Policy Safe Deployment                      ║" -ForegroundColor $color
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor $color
    Write-Host ""
    Write-Host "  Environment: " -NoNewline -ForegroundColor Yellow
    Write-Host "$Env" -ForegroundColor White
    Write-Host "  Phase: " -NoNewline -ForegroundColor Yellow
    Write-Host "$Ph" -ForegroundColor White
    Write-Host "  Scope: " -NoNewline -ForegroundColor Yellow
    Write-Host "$Sc" -ForegroundColor White
    Write-Host ""
}

function Test-Prerequisites {
    Write-Host "  Checking prerequisites..." -ForegroundColor Cyan
    
    # Check parameter file exists
    $paramFile = $script:Config[$Environment].ParameterFile
    if (-not (Test-Path $paramFile)) {
        Write-Host "    ❌ Parameter file not found: $paramFile" -ForegroundColor Red
        return $false
    }
    Write-Host "    ✓ Parameter file found" -ForegroundColor Green
    
    # Check main script exists
    if (-not (Test-Path "./AzPolicyImplScript.ps1")) {
        Write-Host "    ❌ Main script not found: AzPolicyImplScript.ps1" -ForegroundColor Red
        return $false
    }
    Write-Host "    ✓ Main script found" -ForegroundColor Green
    
    # Check Azure connection
    try {
        $context = Get-AzContext -ErrorAction Stop
        if (-not $context) { throw "Not connected" }
        Write-Host "    ✓ Azure connection active" -ForegroundColor Green
        Write-Host "      Subscription: $($context.Subscription.Name)" -ForegroundColor Gray
    }
    catch {
        Write-Host "    ❌ Not connected to Azure. Run Connect-AzAccount first." -ForegroundColor Red
        return $false
    }
    
    return $true
}

function Show-PhaseGuidance {
    param([string]$Ph)
    
    Write-Host ""
    Write-Host "  📋 Phase Guidance:" -ForegroundColor Cyan
    Write-Host ""
    
    switch ($Ph) {
        'Test' {
            Write-Host "    This phase will:" -ForegroundColor Yellow
            Write-Host "      • Deploy policies to test resource group only" -ForegroundColor White
            Write-Host "      • Use relaxed dev/test parameters" -ForegroundColor White
            Write-Host "      • Run in Audit mode (no blocking)" -ForegroundColor White
            Write-Host "      • Validate policy deployment process" -ForegroundColor White
            Write-Host ""
            Write-Host "    ✓ Safe to run - no production impact" -ForegroundColor Green
        }
        'Audit' {
            if ($Environment -eq 'Production') {
                Write-Host "    This phase will:" -ForegroundColor Yellow
                Write-Host "      • Deploy production parameters in Audit mode" -ForegroundColor White
                Write-Host "      • Identify non-compliant resources" -ForegroundColor White
                Write-Host "      • NOT block any operations" -ForegroundColor Green
                Write-Host "      • Generate compliance reports" -ForegroundColor White
                Write-Host ""
                Write-Host "    ⚠️  Wait 24-48 hours after deployment to:" -ForegroundColor Yellow
                Write-Host "        1. Review compliance reports" -ForegroundColor White
                Write-Host "        2. Remediate non-compliant resources" -ForegroundColor White
                Write-Host "        3. Process exemption requests" -ForegroundColor White
                Write-Host "        4. Notify stakeholders" -ForegroundColor White
            } else {
                Write-Host "    This phase will:" -ForegroundColor Yellow
                Write-Host "      • Deploy dev/test parameters in Audit mode" -ForegroundColor White
                Write-Host "      • Practice compliance checking workflow" -ForegroundColor White
            }
        }
        'Enforce' {
            Write-Host "    ⚠️  THIS PHASE WILL ENFORCE POLICIES ⚠️" -ForegroundColor Red
            Write-Host ""
            Write-Host "    This phase will:" -ForegroundColor Yellow
            Write-Host "      • Enable Deny mode for critical policies" -ForegroundColor Red
            Write-Host "      • BLOCK non-compliant operations" -ForegroundColor Red
            Write-Host "      • Prevent vault creation without soft delete" -ForegroundColor Red
            Write-Host "      • Require firewall configuration" -ForegroundColor Red
            Write-Host "      • Enforce strict security parameters" -ForegroundColor Red
            Write-Host ""
            Write-Host "    ✅ Prerequisites before proceeding:" -ForegroundColor Yellow
            Write-Host "        □ Audit mode has run for 24+ hours" -ForegroundColor White
            Write-Host "        □ Compliance reports reviewed" -ForegroundColor White
            Write-Host "        □ Non-compliant resources remediated" -ForegroundColor White
            Write-Host "        □ Exemptions created where needed" -ForegroundColor White
            Write-Host "        □ Stakeholders notified" -ForegroundColor White
            Write-Host "        □ Rollback plan ready" -ForegroundColor White
            Write-Host ""
            Write-Host "    Type 'YES' to confirm you've completed all prerequisites: " -NoNewline -ForegroundColor Red
            $confirmation = Read-Host
            if ($confirmation -ne 'YES') {
                Write-Host ""
                Write-Host "    ❌ Deployment cancelled - prerequisites not confirmed" -ForegroundColor Red
                Write-Host ""
                return $false
            }
        }
    }
    
    Write-Host ""
    return $true
}

function Get-DeploymentCommand {
    param([string]$Env, [string]$Ph, [string]$Sc)
    
    $config = $script:Config[$Env]
    $paramFile = $config.ParameterFile
    $identity = $script:Config.ManagedIdentity
    
    # Determine policy mode based on phase
    $mode = switch ($Ph) {
        'Test' { 'Audit' }
        'Audit' { 'Audit' }
        'Enforce' { 'Deny' }
    }
    
    # Build command arguments
    $args = @(
        "-PolicyMode $mode"
        "-ScopeType $Sc"
        "-ParameterOverridesPath `"$paramFile`""
        "-IdentityResourceId `"$identity`""
    )
    
    # Add resource group for ResourceGroup scope
    if ($Sc -eq 'ResourceGroup' -and $config.ResourceGroup) {
        $args += "-ResourceGroupName `"$($config.ResourceGroup)`""
    }
    
    return ".\AzPolicyImplScript.ps1 $($args -join ' ')"
}

# =============================================================================
# Main Execution
# =============================================================================

Show-DeploymentBanner -Env $Environment -Ph $Phase -Sc $Scope

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-Host ""
    Write-Host "❌ Prerequisites check failed. Please resolve issues and try again." -ForegroundColor Red
    Write-Host ""
    exit 1
}

# Show phase-specific guidance
if (-not (Show-PhaseGuidance -Ph $Phase)) {
    exit 1
}

# Build deployment command
$command = Get-DeploymentCommand -Env $Environment -Ph $Phase -Sc $Scope

Write-Host "  📋 Deployment Command:" -ForegroundColor Cyan
Write-Host ""
Write-Host "    $command" -ForegroundColor Yellow
Write-Host ""

if ($WhatIf) {
    Write-Host "  ℹ️  WhatIf mode enabled - showing command only" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  To execute this deployment, run:" -ForegroundColor White
    Write-Host "    .\Environment-SafeDeployment.ps1 -Environment $Environment -Phase $Phase -Scope $Scope" -ForegroundColor Gray
    Write-Host ""
    exit 0
}

# Confirm execution
Write-Host "  Ready to execute deployment?" -ForegroundColor Yellow
Write-Host "    Type 'RUN' to proceed: " -NoNewline -ForegroundColor White
$runConfirm = Read-Host

if ($runConfirm -ne 'RUN') {
    Write-Host ""
    Write-Host "  ❌ Deployment cancelled" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  Starting Deployment...                                       ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# Execute deployment
$startTime = Get-Date
try {
    Invoke-Expression $command
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  Deployment Completed Successfully                            ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor White
    Write-Host ""
    
    # Post-deployment guidance
    Write-Host "  📋 Next Steps:" -ForegroundColor Cyan
    Write-Host ""
    
    switch ($Phase) {
        'Test' {
            Write-Host "    1. Review deployment logs above" -ForegroundColor White
            Write-Host "    2. Check Azure Portal for policy assignments" -ForegroundColor White
            Write-Host "    3. Validate test Key Vault compliance" -ForegroundColor White
            Write-Host "    4. If successful, proceed to Production Audit phase:" -ForegroundColor White
            Write-Host "       .\Environment-SafeDeployment.ps1 -Environment Production -Phase Audit -Scope Subscription" -ForegroundColor Gray
        }
        'Audit' {
            if ($Environment -eq 'Production') {
                Write-Host "    1. Wait 24-48 hours for compliance data" -ForegroundColor White
                Write-Host "    2. Run compliance check:" -ForegroundColor White
                Write-Host "       .\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan" -ForegroundColor Gray
                Write-Host "    3. Review HTML compliance report" -ForegroundColor White
                Write-Host "    4. Remediate non-compliant resources" -ForegroundColor White
                Write-Host "    5. Process exemption requests (see EXEMPTION_PROCESS.md)" -ForegroundColor White
                Write-Host "    6. When ready, proceed to Enforce phase:" -ForegroundColor White
                Write-Host "       .\Environment-SafeDeployment.ps1 -Environment Production -Phase Enforce -Scope Subscription" -ForegroundColor Gray
            } else {
                Write-Host "    1. Review compliance in test environment" -ForegroundColor White
                Write-Host "    2. Practice remediation workflow" -ForegroundColor White
            }
        }
        'Enforce' {
            Write-Host "    1. Monitor Azure Activity Log for policy denials" -ForegroundColor White
            Write-Host "    2. Watch for user reports of blocked operations" -ForegroundColor White
            Write-Host "    3. Process urgent exemption requests" -ForegroundColor White
            Write-Host "    4. If issues occur, rollback with:" -ForegroundColor White
            Write-Host "       .\AzPolicyImplScript.ps1 -Rollback" -ForegroundColor Gray
            Write-Host "    5. Generate monthly compliance reports" -ForegroundColor White
        }
    }
    
    Write-Host ""
}
catch {
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║  Deployment Failed                                            ║" -ForegroundColor Red
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor White
    Write-Host ""
    Write-Host "  📋 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "    • Review error message above" -ForegroundColor White
    Write-Host "    • Check RBAC permissions" -ForegroundColor White
    Write-Host "    • Verify parameter file exists and is valid JSON" -ForegroundColor White
    Write-Host "    • Ensure Azure connection is active" -ForegroundColor White
    Write-Host ""
    exit 1
}
