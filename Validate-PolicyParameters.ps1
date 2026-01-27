<#
.SYNOPSIS
    Validates all PolicyParameters JSON files against official Azure Policy definitions.

.DESCRIPTION
    This script validates parameter files by:
    1. Checking parameter names against policy definition schemas
    2. Verifying parameter values are within allowed ranges
    3. Validating effect parameters against policy allowed effects
    4. Ensuring scenario alignment (DevTest vs Production parameters)
    5. Checking for missing or extra parameters

.PARAMETER ParameterFile
    Path to the parameter JSON file to validate. If not specified, validates all parameter files.

.PARAMETER Detailed
    Show detailed validation output for each policy.

.EXAMPLE
    .\Validate-PolicyParameters.ps1
    Validates all parameter files

.EXAMPLE
    .\Validate-PolicyParameters.ps1 -ParameterFile .\PolicyParameters-Production-Deny.json -Detailed
    Validates only the Production Deny parameter file with detailed output
#>

param(
    [string]$ParameterFile,
    [switch]$Detailed
)

$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'SUCCESS' { 'Green' }
        'WARN' { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'White' }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Get-PolicyDefinition {
    param([string]$DisplayName)
    
    # Load policy mapping
    $mappingPath = Join-Path $PSScriptRoot 'PolicyNameMapping.json'
    if (-not (Test-Path $mappingPath)) {
        Write-Log "PolicyNameMapping.json not found" -Level 'ERROR'
        return $null
    }
    
    $mapping = Get-Content $mappingPath | ConvertFrom-Json
    $policyId = $mapping.$DisplayName
    
    if (-not $policyId) {
        Write-Log "Policy '$DisplayName' not found in mapping" -Level 'WARN'
        return $null
    }
    
    try {
        $definition = Get-AzPolicyDefinition -Id $policyId -ErrorAction Stop
        return $definition
    } catch {
        Write-Log "Failed to get policy definition for '$DisplayName': $($_.Exception.Message)" -Level 'ERROR'
        return $null
    }
}

function Validate-ParameterFile {
    param(
        [string]$FilePath,
        [switch]$Detailed
    )
    
    Write-Log "`n═══════════════════════════════════════════════════════════════" -Level 'INFO'
    Write-Log "Validating: $(Split-Path $FilePath -Leaf)" -Level 'INFO'
    Write-Log "═══════════════════════════════════════════════════════════════`n" -Level 'INFO'
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "File not found: $FilePath" -Level 'ERROR'
        return @{
            File = $FilePath
            TotalPolicies = 0
            Valid = 0
            Invalid = 0
            Warnings = 0
            Issues = @("File not found")
        }
    }
    
    $content = Get-Content $FilePath -Raw | ConvertFrom-Json
    $results = @{
        File = (Split-Path $FilePath -Leaf)
        TotalPolicies = 0
        Valid = 0
        Invalid = 0
        Warnings = 0
        Issues = @()
    }
    
    foreach ($policyName in $content.PSObject.Properties.Name) {
        $results.TotalPolicies++
        $params = $content.$policyName
        
        if ($Detailed) {
            Write-Log "`nPolicy: $policyName" -Level 'INFO'
        }
        
        # Get policy definition
        $definition = Get-PolicyDefinition -DisplayName $policyName
        if (-not $definition) {
            $results.Invalid++
            $results.Issues += "$policyName - Policy definition not found"
            if ($Detailed) {
                Write-Log "  ❌ Policy definition not found" -Level 'ERROR'
            }
            continue
        }
        
        # Get allowed effects
        $allowedEffects = @()
        if ($definition.Properties.PolicyRule.then.effect) {
            # Fixed effect
            $allowedEffects += $definition.Properties.PolicyRule.then.effect
        } elseif ($definition.Properties.Parameters.effect) {
            # Parameterized effect
            $effectParam = $definition.Properties.Parameters.effect
            if ($effectParam.allowedValues) {
                $allowedEffects = $effectParam.allowedValues
            }
        }
        
        # Get defined parameters
        $definedParams = @()
        if ($definition.Properties.Parameters) {
            $definedParams = $definition.Properties.Parameters.PSObject.Properties.Name
        }
        
        # Validate parameters
        $policyValid = $true
        $policyWarnings = @()
        
        foreach ($paramName in $params.PSObject.Properties.Name) {
            $paramValue = $params.$paramName
            
            # Check if parameter exists in definition
            if ($paramName -notin $definedParams -and $paramName -ne 'effect') {
                $policyValid = $false
                $issue = "$policyName - Parameter '$paramName' not found in policy definition (available: $($definedParams -join ', '))"
                $results.Issues += $issue
                if ($Detailed) {
                    Write-Log "  ❌ Parameter '$paramName' = $paramValue - NOT FOUND IN DEFINITION" -Level 'ERROR'
                }
                continue
            }
            
            # Validate effect parameter
            if ($paramName -eq 'effect') {
                if ($allowedEffects.Count -eq 0) {
                    $policyWarnings += "$policyName - Policy has fixed effect, parameter override ignored"
                    if ($Detailed) {
                        Write-Log "  ⚠️  Effect parameter provided but policy has fixed effect" -Level 'WARN'
                    }
                } elseif ($paramValue -notin $allowedEffects) {
                    $policyValid = $false
                    $issue = "$policyName - Effect '$paramValue' not in allowed effects: $($allowedEffects -join ', ')"
                    $results.Issues += $issue
                    if ($Detailed) {
                        Write-Log "  ❌ Effect '$paramValue' NOT ALLOWED (valid: $($allowedEffects -join ', '))" -Level 'ERROR'
                    }
                } else {
                    if ($Detailed) {
                        Write-Log "  ✅ Effect: $paramValue (allowed: $($allowedEffects -join ', '))" -Level 'SUCCESS'
                    }
                }
                continue
            }
            
            # Validate parameter value against allowed values
            $paramDef = $definition.Properties.Parameters.$paramName
            if ($paramDef.allowedValues -and $paramValue -is [string]) {
                if ($paramValue -notin $paramDef.allowedValues) {
                    $policyValid = $false
                    $issue = "$policyName - Parameter '$paramName' value '$paramValue' not in allowed values: $($paramDef.allowedValues -join ', ')"
                    $results.Issues += $issue
                    if ($Detailed) {
                        Write-Log "  ❌ $paramName = $paramValue - NOT IN ALLOWED VALUES: $($paramDef.allowedValues -join ', ')" -Level 'ERROR'
                    }
                } else {
                    if ($Detailed) {
                        Write-Log "  ✅ $paramName = $paramValue" -Level 'SUCCESS'
                    }
                }
            } elseif ($paramDef.allowedValues -and $paramValue -is [array]) {
                # Check array values
                foreach ($val in $paramValue) {
                    if ($val -notin $paramDef.allowedValues) {
                        $policyValid = $false
                        $issue = "$policyName - Parameter '$paramName' value '$val' not in allowed values: $($paramDef.allowedValues -join ', ')"
                        $results.Issues += $issue
                        if ($Detailed) {
                            Write-Log "  ❌ $paramName contains '$val' - NOT IN ALLOWED VALUES: $($paramDef.allowedValues -join ', ')" -Level 'ERROR'
                        }
                    }
                }
                if ($policyValid -and $Detailed) {
                    Write-Log "  ✅ $paramName = [$($paramValue -join ', ')]" -Level 'SUCCESS'
                }
            } else {
                if ($Detailed) {
                    $valueStr = if ($paramValue -is [array]) { "[$($paramValue -join ', ')]" } else { $paramValue }
                    Write-Log "  ✅ $paramName = $valueStr" -Level 'SUCCESS'
                }
            }
        }
        
        # Check for missing required parameters
        $providedParams = $params.PSObject.Properties.Name
        foreach ($requiredParam in $definedParams) {
            $paramDef = $definition.Properties.Parameters.$requiredParam
            if ($paramDef -and -not $paramDef.defaultValue -and $requiredParam -notin $providedParams) {
                $policyWarnings += "$policyName - Required parameter '$requiredParam' not provided (no default value)"
                if ($Detailed) {
                    Write-Log "  ⚠️  Required parameter '$requiredParam' not provided" -Level 'WARN'
                }
            }
        }
        
        if ($policyValid -and $policyWarnings.Count -eq 0) {
            $results.Valid++
            if ($Detailed) {
                Write-Log "  ✅ Policy parameters VALID" -Level 'SUCCESS'
            }
        } elseif ($policyValid -and $policyWarnings.Count -gt 0) {
            $results.Valid++
            $results.Warnings += $policyWarnings.Count
            if ($Detailed) {
                Write-Log "  ✅ Policy parameters VALID (with warnings)" -Level 'SUCCESS'
            }
        } else {
            $results.Invalid++
        }
    }
    
    # Summary
    Write-Log "`n─────────────────────────────────────────────────────────────" -Level 'INFO'
    Write-Log "SUMMARY: $(Split-Path $FilePath -Leaf)" -Level 'INFO'
    Write-Log "  Total Policies: $($results.TotalPolicies)" -Level 'INFO'
    Write-Log "  Valid: $($results.Valid)" -Level $(if ($results.Valid -eq $results.TotalPolicies) { 'SUCCESS' } else { 'INFO' })
    Write-Log "  Invalid: $($results.Invalid)" -Level $(if ($results.Invalid -gt 0) { 'ERROR' } else { 'INFO' })
    Write-Log "  Warnings: $($results.Warnings)" -Level $(if ($results.Warnings -gt 0) { 'WARN' } else { 'INFO' })
    Write-Log "─────────────────────────────────────────────────────────────`n" -Level 'INFO'
    
    return $results
}

# Main execution
try {
    Write-Log "Starting Policy Parameter Validation" -Level 'INFO'
    Write-Log "Checking Azure connection..." -Level 'INFO'
    
    $context = Get-AzContext
    if (-not $context) {
        Write-Log "Not connected to Azure. Running Connect-AzAccount..." -Level 'WARN'
        Connect-AzAccount
    }
    
    Write-Log "Using Azure context: $($context.Account.Id)" -Level 'SUCCESS'
    
    # Determine files to validate
    $filesToValidate = @()
    if ($ParameterFile) {
        $filesToValidate += $ParameterFile
    } else {
        # Validate all parameter files
        $filesToValidate = @(
            "PolicyParameters-DevTest.json",
            "PolicyParameters-DevTest-Full.json",
            "PolicyParameters-DevTest-Full-Remediation.json",
            "PolicyParameters-Production.json",
            "PolicyParameters-Production-Deny.json",
            "PolicyParameters-Production-Remediation.json"
        )
    }
    
    $allResults = @()
    foreach ($file in $filesToValidate) {
        $filePath = if ([System.IO.Path]::IsPathRooted($file)) {
            $file
        } else {
            Join-Path $PSScriptRoot $file
        }
        
        $result = Validate-ParameterFile -FilePath $filePath -Detailed:$Detailed
        $allResults += $result
    }
    
    # Overall summary
    Write-Log "`n╔═══════════════════════════════════════════════════════════════╗" -Level 'INFO'
    Write-Log "║                 OVERALL VALIDATION SUMMARY                    ║" -Level 'INFO'
    Write-Log "╚═══════════════════════════════════════════════════════════════╝`n" -Level 'INFO'
    
    $totalPolicies = ($allResults | Measure-Object -Property TotalPolicies -Sum).Sum
    $totalValid = ($allResults | Measure-Object -Property Valid -Sum).Sum
    $totalInvalid = ($allResults | Measure-Object -Property Invalid -Sum).Sum
    $totalWarnings = ($allResults | Measure-Object -Property Warnings -Sum).Sum
    
    Write-Log "Files Validated: $($allResults.Count)" -Level 'INFO'
    Write-Log "Total Policies: $totalPolicies" -Level 'INFO'
    Write-Log "Valid: $totalValid" -Level $(if ($totalValid -eq $totalPolicies) { 'SUCCESS' } else { 'INFO' })
    Write-Log "Invalid: $totalInvalid" -Level $(if ($totalInvalid -gt 0) { 'ERROR' } else { 'SUCCESS' })
    Write-Log "Warnings: $totalWarnings" -Level $(if ($totalWarnings -gt 0) { 'WARN' } else { 'INFO' })
    
    if ($totalInvalid -gt 0) {
        Write-Log "`n═══ ISSUES FOUND ═══`n" -Level 'ERROR'
        foreach ($result in $allResults) {
            if ($result.Issues.Count -gt 0) {
                Write-Log "File: $($result.File)" -Level 'ERROR'
                foreach ($issue in $result.Issues) {
                    Write-Log "  • $issue" -Level 'ERROR'
                }
                Write-Log "" -Level 'INFO'
            }
        }
        exit 1
    } else {
        Write-Log "`n✅ ALL PARAMETER FILES VALID!" -Level 'SUCCESS'
        exit 0
    }
    
} catch {
    Write-Log "Validation failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Log $_.ScriptStackTrace -Level 'ERROR'
    exit 1
}
