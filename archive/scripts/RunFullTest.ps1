#!/usr/bin/env pwsh
# RunFullTest.ps1 - Run complete policy test with managed identity

$config = Get-Content ".\PolicyImplementationConfig.json" | ConvertFrom-Json
$identityId = $config.ManagedIdentityId

if (-not $identityId) {
    Write-Error "ManagedIdentityId not found in PolicyImplementationConfig.json"
    exit 1
}

Write-Host "`n=== Running Full Azure Policy Test ===" -ForegroundColor Cyan
Write-Host "Managed Identity: $identityId" -ForegroundColor Yellow
Write-Host "Mode: Audit" -ForegroundColor Gray
Write-Host "Scope: Subscription" -ForegroundColor Gray
Write-Host ""

.\AzPolicyImplScript.ps1 -PolicyMode Audit -ScopeType Subscription -SkipRBACCheck -IdentityResourceId $identityId

Write-Host "`n=== Test Complete ===" -ForegroundColor Green
