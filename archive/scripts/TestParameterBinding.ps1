#!/usr/bin/env pwsh
# Minimal test case for parameter binding

[CmdletBinding()]
param(
    [string]$ScopeType,
    [string]$PolicyMode,
    [switch]$TestSwitch
)

Write-Host "PSBoundParameters keys: $($PSBoundParameters.Keys -join ', ')"
Write-Host "ScopeType value: '$ScopeType'"
Write-Host "PolicyMode value: '$PolicyMode'"
Write-Host "TestSwitch value: $TestSwitch"
Write-Host "ScopeType in PSBoundParameters: $($PSBoundParameters.ContainsKey('ScopeType'))"
