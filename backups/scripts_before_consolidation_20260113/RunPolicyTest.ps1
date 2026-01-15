#!/usr/bin/env pwsh
# RunPolicyTest.ps1 - Non-interactive wrapper for AzPolicyImplScript.ps1

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = ".\PolicyImplementationConfig.json"
)

# Load configuration
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    Write-Host "Run .\GatherPrerequisites.ps1 first to create this file."
    exit 1
}

$config = Get-Content $ConfigPath | ConvertFrom-Json
$identityId = $config.ManagedIdentityId

if (-not $identityId) {
    Write-Error "ManagedIdentityId not found in configuration file."
    exit 1
}

Write-Host "`n=== Running Azure Policy Implementation ===" -ForegroundColor Cyan
Write-Host "Configuration: $ConfigPath" -ForegroundColor Gray
Write-Host "Identity ID: $identityId" -ForegroundColor Gray
Write-Host "Mode: Audit (non-interactive)" -ForegroundColor Gray
Write-Host ""

# Call main script with answers piped to avoid prompts
$answers = @(
    "",  # Scope type (default: Subscription)
    "",  # Use current subscription? (default: Yes)
    ""   # Mode (default: Audit)
)

$answers | .\AzPolicyImplScript.ps1 -Mode Audit -Scope Subscription -SkipRBACCheck -IdentityResourceId $identityId

Write-Host "`n=== Test Complete ===" -ForegroundColor Green
