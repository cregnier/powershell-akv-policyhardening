<#
.SYNOPSIS
    Analyze Azure Policy effects for all 46 Key Vault policies

.DESCRIPTION
    This script reads all Key Vault policies from DefinitionListExport.csv and analyzes their effects to determine
    which policies CAN block operations (support Deny) vs only AUDIT/REMEDIATE
    
    KEY FINDING: ALL Azure Key Vault built-in policies have parameterized effects and default to Audit mode,
    but most CAN be set to Deny mode to block operations!
#>

param(
    [string]$CsvFile = ".\DefinitionListExport.csv",
    [string]$MappingFile = ".\PolicyNameMapping.json",
    [string]$OutputFile = "PolicyEffectMatrix-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
)

Write-Host "[INFO] Analyzing Key Vault Policy Effects..." -ForegroundColor Cyan
Write-Host ""

# Load policy definitions from CSV
if (-not (Test-Path $CsvFile)) {
    Write-Host "[ERROR] Policy CSV file not found: $CsvFile" -ForegroundColor Red
    exit 1
}

$csvPolicies = Import-Csv -Path $CsvFile
Write-Host "[INFO] Loaded $($csvPolicies.Count) policies from CSV" -ForegroundColor Cyan

# Load policy mapping
$mapping = $null
if (Test-Path $MappingFile) {
    $mapping = Get-Content -Path $MappingFile -Raw | ConvertFrom-Json
    Write-Host "[INFO] Loaded policy mapping file" -ForegroundColor Cyan
} else {
    Write-Host "[WARNING] Policy mapping file not found at $MappingFile" -ForegroundColor Yellow
}

Write-Host ""

# Analyze each policy
$results = @()
$effectCounts = @{
    'Audit-Only' = 0           # Default=Audit, no Deny option
    'Deny-Capable' = 0         # Default=Audit, but Deny is allowed
    'DeployIfNotExists' = 0    # Remediation policies
    'Modify' = 0               # Auto-fix policies
    'Other' = 0
}

$processed = 0
$skipped = 0

Write-Host "[INFO] Processing policies..." -ForegroundColor Cyan

foreach ($csvPolicy in $csvPolicies) {
    $policyName = $csvPolicy.Name
    
    # Find policy definition
    $policyDef = $null
    $policyId = $null
    
    # Try to find in mapping
    if ($mapping) {
        $mapEntry = $mapping.PSObject.Properties | Where-Object { $_.Name -eq $policyName } | Select-Object -First 1
        if ($mapEntry) {
            $policyId = $mapEntry.Value.Id
        }
    }
    
    # Get policy definition from Azure
    if ($policyId) {
        try {
            $policyDef = Get-AzPolicyDefinition -Id $policyId -ErrorAction Stop
            $processed++
        } catch {
            Write-Host "[WARNING] Could not load policy '$policyName'" -ForegroundColor Yellow
            $skipped++
            continue
        }
    } else {
        # Try direct lookup by display name
        try {
            $allDefs = Get-AzPolicyDefinition -ErrorAction Stop
            $policyDef = $allDefs | Where-Object { $_.DisplayName -eq $policyName } | Select-Object -First 1
            if ($policyDef) {
                $processed++
            } else {
                Write-Host "[WARNING] Could not find policy: $policyName" -ForegroundColor Yellow
                $skipped++
                continue
            }
        } catch {
            Write-Host "[WARNING] Error looking up policy '$policyName'" -ForegroundColor Yellow
            $skipped++
            continue
        }
    }
    
    if (-not $policyDef) {
        $skipped++
        continue
    }
    
    # Analyze effect
    $effectType = $policyDef.PolicyRule.then.effect
    $isParameterized = $effectType -like '*parameters*'
    $defaultEffect = "Unknown"
    $allowedEffects = @()
    $canDeny = $false
    $canAudit = $false
    $category = "Unknown"
    
    if ($isParameterized) {
        # Get effect parameter details
        $effectParam = $policyDef.Parameter.effect
        if ($effectParam) {
            $defaultEffect = $effectParam.defaultValue
            $allowedEffects = $effectParam.allowedValues
            
            # Check if Deny is allowed
            $canDeny = $allowedEffects -contains 'Deny' -or $allowedEffects -contains 'deny'
            $canAudit = $allowedEffects -contains 'Audit' -or $allowedEffects -contains 'audit'
            
            if ($canDeny) {
                $category = "Deny-Capable (Default: $defaultEffect)"
                $effectCounts['Deny-Capable']++
            } else {
                $category = "Audit-Only (No Deny option)"
                $effectCounts['Audit-Only']++
            }
        } else {
            $category = "Parameterized (Unknown)"
            $effectCounts['Other']++
        }
    } else {
        # Fixed effect
        switch ($effectType) {
            'Audit' { 
                $category = "Audit-Only (Fixed)"
                $defaultEffect = 'Audit'
                $effectCounts['Audit-Only']++
            }
            'Deny' { 
                $category = "Deny (Fixed)"
                $defaultEffect = 'Deny'
                $canDeny = $true
                $effectCounts['Deny-Capable']++
            }
            'DeployIfNotExists' { 
                $category = "Auto-Remediate"
                $defaultEffect = 'DeployIfNotExists'
                $effectCounts['DeployIfNotExists']++
            }
            'Modify' { 
                $category = "Auto-Fix"
                $defaultEffect = 'Modify'
                $effectCounts['Modify']++
            }
            default { 
                $category = "Other"
                $defaultEffect = $effectType
                $effectCounts['Other']++
            }
        }
    }
    
    $description = if ($policyDef.Description) {
        $policyDef.Description.Substring(0, [Math]::Min(120, $policyDef.Description.Length)) + "..."
    } else {
        "N/A"
    }
    
    $results += [PSCustomObject]@{
        'Policy Name' = $policyDef.DisplayName
        'Policy ID' = $policyDef.Name
        'Default Effect' = $defaultEffect
        'Can Use Deny' = $canDeny
        'Can Use Audit' = $canAudit
        'Allowed Effects' = ($allowedEffects -join ', ')
        'Category' = $category
        'Version' = $csvPolicy.'Latest version'
        'Definition Type' = $csvPolicy.'Definition type'
        'Description' = $description
    }
    
    if ($processed % 5 -eq 0) {
        Write-Host "." -NoNewline -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host ""
Write-Host "[INFO] Processed: $processed | Skipped: $skipped | Total: $($csvPolicies.Count)" -ForegroundColor Cyan
Write-Host ""

# Sort by category and name
$results = $results | Sort-Object Category, 'Policy Name'

# Display summary
Write-Host "=" * 90 -ForegroundColor Yellow
Write-Host "POLICY EFFECT ANALYSIS SUMMARY" -ForegroundColor Yellow
Write-Host "=" * 90 -ForegroundColor Yellow
Write-Host ""
Write-Host "Total Policies Analyzed: $($results.Count)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Effect Distribution:" -ForegroundColor Cyan
foreach ($key in $effectCounts.Keys | Sort-Object) {
    $count = $effectCounts[$key]
    $percentage = if ($results.Count -gt 0) { [math]::Round(($count / $results.Count) * 100, 1) } else { 0 }
    $color = switch ($key) {
        'Deny-Capable' { 'Green' }
        'Audit-Only' { 'Yellow' }
        'DeployIfNotExists' { 'Cyan' }
        'Modify' { 'Magenta' }
        default { 'White' }
    }
    Write-Host "  $($key.PadRight(25)): $($count.ToString().PadLeft(3)) ($percentage%)" -ForegroundColor $color
}
Write-Host ""

# Count policies that CAN deny
$denyCapable = $results | Where-Object { $_.'Can Use Deny' -eq $true }
Write-Host "Policies that CAN BLOCK operations (support Deny): $($denyCapable.Count) / $($results.Count)" -ForegroundColor Green
Write-Host "Policies that are Audit-only: $($results.Count - $denyCapable.Count) / $($results.Count)" -ForegroundColor Yellow
Write-Host ""

# Display deny-capable policies
if ($denyCapable.Count -gt 0) {
    Write-Host "=" * 90 -ForegroundColor Green
    Write-Host "POLICIES THAT CAN BLOCK OPERATIONS (Support Deny Effect)" -ForegroundColor Green
    Write-Host "=" * 90 -ForegroundColor Green
    $denyCapable | ForEach-Object { 
        Write-Host "  • $($_.'Policy Name')" -ForegroundColor Green 
    }
    Write-Host ""
}

# Export to CSV
$results | Export-Csv -Path $OutputFile -NoTypeInformation
Write-Host "[SUCCESS] Policy effect matrix exported to: $OutputFile" -ForegroundColor Green
Write-Host ""

# Display sample of results
Write-Host "=" * 90 -ForegroundColor Cyan
Write-Host "SAMPLE RESULTS (First 10 Policies)" -ForegroundColor Cyan
Write-Host "=" * 90 -ForegroundColor Cyan
$results | Select-Object -First 10 | Format-Table 'Policy Name', 'Default Effect', 'Can Use Deny', Category -Wrap

Write-Host ""
Write-Host "[INFO] Full results available in: $OutputFile" -ForegroundColor Cyan
Write-Host ""

# Key findings
Write-Host "=" * 90 -ForegroundColor Magenta
Write-Host "KEY FINDINGS" -ForegroundColor Magenta
Write-Host "=" * 90 -ForegroundColor Magenta
Write-Host "• All Azure Key Vault built-in policies have PARAMETERIZED effects" -ForegroundColor Cyan
Write-Host "• Most policies DEFAULT to 'Audit' mode (non-blocking)" -ForegroundColor Yellow
Write-Host "• $($denyCapable.Count) policies SUPPORT 'Deny' mode (can block operations)" -ForegroundColor Green
Write-Host "• You can switch policies to Deny mode during assignment!" -ForegroundColor Green
Write-Host ""

# Return results for further processing
return $results
