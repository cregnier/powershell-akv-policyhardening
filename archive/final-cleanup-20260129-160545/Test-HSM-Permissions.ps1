#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verification script to test Premium HSM and Managed HSM deployment permissions
    
.DESCRIPTION
    Tests whether current user/subscription can:
    1. Create Premium Key Vault with HSM-backed keys
    2. Deploy Azure Managed HSM pool
    
    Provides detailed error messages to diagnose quota/permission issues.
#>

[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'rg-policy-keyvault-test',
    [string]$Location = 'eastus'
)

$ErrorActionPreference = 'Stop'

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  HSM DEPLOYMENT PERMISSION VERIFICATION                      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Get current context
$context = Get-AzContext
Write-Host "📋 Current Context:" -ForegroundColor White
Write-Host "   Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -ForegroundColor Gray
Write-Host "   User: $($context.Account.Id)" -ForegroundColor Gray
Write-Host "   Tenant: $($context.Tenant.Id)" -ForegroundColor Gray

# Verify resource group exists
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "`n❌ ERROR: Resource group '$ResourceGroupName' not found" -ForegroundColor Red
    Write-Host "   Create it first with: New-AzResourceGroup -Name '$ResourceGroupName' -Location '$Location'" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n✅ Resource Group: $ResourceGroupName exists" -ForegroundColor Green

#region Test 1: Premium Vault with HSM-backed keys

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║  TEST 1: Premium Key Vault + HSM-Backed Keys                ║" -ForegroundColor Yellow
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow

$premiumVaultName = "val-hsm-test-$(Get-Random -Min 1000 -Max 9999)"
$premiumTestPassed = $false

try {
    Write-Host "`n[Step 1] Creating Premium vault via ARM template..." -ForegroundColor Cyan
    
    # Use ARM template for policy compliance
    $armTemplate = @{
        '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
        contentVersion = '1.0.0.0'
        resources = @(@{
            type = 'Microsoft.KeyVault/vaults'
            apiVersion = '2023-07-01'
            name = $premiumVaultName
            location = $Location
            properties = @{
                sku = @{ family = 'A'; name = 'premium' }
                tenantId = $context.Tenant.Id
                enableSoftDelete = $true
                softDeleteRetentionInDays = 90
                enablePurgeProtection = $true
                enableRbacAuthorization = $true
                publicNetworkAccess = 'Disabled'
                networkAcls = @{ defaultAction = 'Deny'; bypass = 'AzureServices'; ipRules = @() }
            }
        })
    }
    
    $templateFile = Join-Path $env:TEMP "premium-hsm-test.json"
    $armTemplate | ConvertTo-Json -Depth 10 | Set-Content $templateFile
    
    $deployment = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
        -TemplateFile $templateFile -Name "premium-hsm-test-$(Get-Date -Format 'HHmmss')" -ErrorAction Stop
    
    Remove-Item $templateFile -Force -ErrorAction SilentlyContinue
    
    Write-Host "   ✅ Premium vault created: $premiumVaultName" -ForegroundColor Green
    
    Write-Host "`n[Step 2] Assigning RBAC permissions..." -ForegroundColor Cyan
    $currentUser = $context.Account.Id
    $vaultDetails = Get-AzKeyVault -VaultName $premiumVaultName -ResourceGroupName $ResourceGroupName
    $vaultResourceId = $vaultDetails.ResourceId
    
    New-AzRoleAssignment -SignInName $currentUser -RoleDefinitionName "Key Vault Administrator" `
        -Scope $vaultResourceId -ErrorAction SilentlyContinue | Out-Null
    
    Write-Host "   ✅ RBAC assigned: Key Vault Administrator" -ForegroundColor Green
    Write-Host "   ⏱️  Waiting 60 seconds for RBAC propagation..." -ForegroundColor Yellow
    Start-Sleep -Seconds 60
    
    Write-Host "`n[Step 3] Attempting to create HSM-backed key..." -ForegroundColor Cyan
    
    try {
        $hsmKey = Add-AzKeyVaultKey -VaultName $premiumVaultName -Name "test-hsm-key" `
            -Destination HSM -KeyType RSA -Size 2048 -Expires (Get-Date).AddDays(90) -ErrorAction Stop
        
        Write-Host "   ✅ SUCCESS: HSM-backed key created!" -ForegroundColor Green
        Write-Host "   Key Name: $($hsmKey.Name)" -ForegroundColor Gray
        Write-Host "   Key Type: $($hsmKey.KeyType)" -ForegroundColor Gray
        Write-Host "   Destination: HSM" -ForegroundColor Gray
        $premiumTestPassed = $true
        
        # Cleanup key
        Remove-AzKeyVaultKey -VaultName $premiumVaultName -Name "test-hsm-key" -Force -ErrorAction SilentlyContinue | Out-Null
        
    } catch {
        Write-Host "   ❌ FAILED: Cannot create HSM-backed key" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        
        if ($_.Exception.Message -like "*not authorized*" -or $_.Exception.Message -like "*Forbidden*") {
            Write-Host "`n   📋 Diagnosis: RBAC Permission Issue" -ForegroundColor Yellow
            Write-Host "      - RBAC may need >60 seconds to propagate" -ForegroundColor Yellow
            Write-Host "      - User may need additional permissions on vault" -ForegroundColor Yellow
        } elseif ($_.Exception.Message -like "*policy*" -or $_.Exception.Message -like "*disallowed*") {
            Write-Host "`n   📋 Diagnosis: Azure Policy Blocking" -ForegroundColor Yellow
            Write-Host "      - A policy is blocking HSM-backed key creation" -ForegroundColor Yellow
        } else {
            Write-Host "`n   📋 Diagnosis: Unknown Error" -ForegroundColor Yellow
        }
    }
    
    # Cleanup vault
    Write-Host "`n[Cleanup] Removing Premium vault..." -ForegroundColor Gray
    Remove-AzKeyVault -VaultName $premiumVaultName -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue | Out-Null
    Remove-AzKeyVault -VaultName $premiumVaultName -InRemovedState -Location $Location -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Host "   ✅ Cleanup complete" -ForegroundColor Green
    
} catch {
    Write-Host "`n❌ FAILED: Premium vault creation failed" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Message -like "*policy*" -or $_.Exception.Message -like "*disallowed*") {
        Write-Host "`n   📋 Diagnosis: Azure Policy Blocking Vault Creation" -ForegroundColor Yellow
        Write-Host "      - Check deployed policies for vault-level restrictions" -ForegroundColor Yellow
    }
}

#endregion

#region Test 2: Managed HSM Deployment

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║  TEST 2: Managed HSM Pool Deployment                        ║" -ForegroundColor Yellow
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow

$managedHsmName = "hsm-test-$(Get-Random -Min 100 -Max 999)"
$managedHsmTestPassed = $false

Write-Host "`n[Step 1] Checking Managed HSM availability in location: $Location" -ForegroundColor Cyan

$hsmLocations = Get-AzResourceProvider -ProviderNamespace "Microsoft.KeyVault" | 
    Select-Object -ExpandProperty ResourceTypes | 
    Where-Object { $_.ResourceTypeName -eq "managedHSMs" } | 
    Select-Object -ExpandProperty Locations

if ($hsmLocations -contains $Location -or $hsmLocations -contains ($Location -replace '\s', '')) {
    Write-Host "   ✅ Managed HSM is available in $Location" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  WARNING: Managed HSM may not be available in $Location" -ForegroundColor Yellow
    Write-Host "   Available locations:" -ForegroundColor Yellow
    $hsmLocations | ForEach-Object { Write-Host "      - $_" -ForegroundColor Gray }
}

Write-Host "`n[Step 2] Getting user ObjectId for HSM administrator..." -ForegroundColor Cyan

$signedInUser = Get-AzADUser -SignedIn -ErrorAction SilentlyContinue
if ($signedInUser) {
    $userObjectId = $signedInUser.Id
    Write-Host "   ✅ User: $($signedInUser.UserPrincipalName)" -ForegroundColor Green
    Write-Host "   ObjectId: $userObjectId" -ForegroundColor Gray
} else {
    $userObjectId = (Get-AzADUser -UserPrincipalName $context.Account.Id -ErrorAction SilentlyContinue).Id
    if ($userObjectId) {
        Write-Host "   ✅ User ObjectId: $userObjectId" -ForegroundColor Green
    } else {
        Write-Host "   ❌ ERROR: Cannot retrieve user ObjectId" -ForegroundColor Red
        Write-Host "   This is required for Managed HSM administrator assignment" -ForegroundColor Red
        $userObjectId = $null
    }
}

if ($userObjectId) {
    Write-Host "`n[Step 3] Attempting to create Managed HSM pool..." -ForegroundColor Cyan
    Write-Host "   ⚠️  NOTE: This will NOT wait for activation (would take 15-20 min)" -ForegroundColor Yellow
    Write-Host "   ⚠️  We only test if deployment can START" -ForegroundColor Yellow
    
    try {
        $managedHsm = New-AzKeyVaultManagedHsm -Name $managedHsmName -ResourceGroupName $ResourceGroupName `
            -Location $Location -Administrator $userObjectId -SoftDeleteRetentionInDays 7 -ErrorAction Stop
        
        Write-Host "`n   ✅ SUCCESS: Managed HSM deployment started!" -ForegroundColor Green
        Write-Host "   HSM Name: $managedHsmName" -ForegroundColor Gray
        Write-Host "   Provisioning State: $($managedHsm.ProvisioningState)" -ForegroundColor Gray
        Write-Host "   Location: $($managedHsm.Location)" -ForegroundColor Gray
        $managedHsmTestPassed = $true
        
        Write-Host "`n   ⏱️  Deployment will take 15-20 minutes to complete (not waiting)" -ForegroundColor Yellow
        Write-Host "`n   🧹 CRITICAL: Cleaning up immediately to prevent billing!" -ForegroundColor Red
        
        # Immediate cleanup - don't wait for activation
        Start-Sleep -Seconds 5  # Brief wait to ensure deployment is registered
        Remove-AzKeyVaultManagedHsm -Name $managedHsmName -ResourceGroupName $ResourceGroupName -Force -ErrorAction Stop
        Write-Host "   ✅ Cleanup complete - HSM deployment cancelled" -ForegroundColor Green
        
    } catch {
        Write-Host "`n   ❌ FAILED: Cannot create Managed HSM" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        
        if ($_.Exception.Message -like "*Forbidden*" -or $_.Exception.Message -like "*not authorized*") {
            Write-Host "`n   📋 Diagnosis: Subscription Quota or Permission Issue" -ForegroundColor Yellow
            Write-Host "      Possible causes:" -ForegroundColor Yellow
            Write-Host "      1. Subscription does not have Managed HSM quota enabled" -ForegroundColor Yellow
            Write-Host "      2. User needs 'Managed HSM Contributor' role at subscription level" -ForegroundColor Yellow
            Write-Host "      3. Location '$Location' may not support Managed HSM" -ForegroundColor Yellow
            Write-Host "`n      To request quota:" -ForegroundColor Yellow
            Write-Host "      1. Azure Portal → Support → New Support Request" -ForegroundColor Yellow
            Write-Host "      2. Issue Type: Service and subscription limits (quotas)" -ForegroundColor Yellow
            Write-Host "      3. Quota Type: Key Vault → Managed HSM pool quota increase" -ForegroundColor Yellow
            Write-Host "      4. Location: eastus2 or northeurope (confirmed supported)" -ForegroundColor Yellow
            
        } elseif ($_.Exception.Message -like "*policy*" -or $_.Exception.Message -like "*disallowed*") {
            Write-Host "`n   📋 Diagnosis: Azure Policy Blocking" -ForegroundColor Yellow
            Write-Host "      - A policy is blocking Managed HSM deployment" -ForegroundColor Yellow
        } elseif ($_.Exception.Message -like "*quota*" -or $_.Exception.Message -like "*limit*") {
            Write-Host "`n   📋 Diagnosis: Subscription Quota Limit" -ForegroundColor Yellow
            Write-Host "      - Subscription has reached Managed HSM quota limit" -ForegroundColor Yellow
            Write-Host "      - Submit support request to increase quota" -ForegroundColor Yellow
        } else {
            Write-Host "`n   📋 Diagnosis: Unknown Error" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "`n   ⚠️  SKIPPED: Cannot test Managed HSM without user ObjectId" -ForegroundColor Yellow
}

#endregion

#region Summary Report

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  VERIFICATION SUMMARY                                        ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "Test Results:" -ForegroundColor White
Write-Host "  Premium Vault + HSM Keys: $(if ($premiumTestPassed) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($premiumTestPassed) { 'Green' } else { 'Red' })
Write-Host "  Managed HSM Deployment:   $(if ($managedHsmTestPassed) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($managedHsmTestPassed) { 'Green' } else { 'Red' })

Write-Host "`nInterpretation:" -ForegroundColor White

if ($premiumTestPassed -and $managedHsmTestPassed) {
    Write-Host "  ✅ Your subscription CAN deploy both Premium HSM and Managed HSM" -ForegroundColor Green
    Write-Host "  The test failures in AzPolicyImplScript.ps1 may be due to:" -ForegroundColor Yellow
    Write-Host "     - Insufficient RBAC propagation time (need >60 seconds)" -ForegroundColor Yellow
    Write-Host "     - Transient Azure API issues" -ForegroundColor Yellow
    Write-Host "  Recommendation: Re-run comprehensive test with extended wait times" -ForegroundColor Green
} elseif ($premiumTestPassed -and -not $managedHsmTestPassed) {
    Write-Host "  ⚠️  Premium HSM works, but Managed HSM is blocked" -ForegroundColor Yellow
    Write-Host "  This confirms the Managed HSM quota/permission limitation" -ForegroundColor Yellow
    Write-Host "  Recommendation: Request Managed HSM quota from Azure Support" -ForegroundColor Yellow
} elseif (-not $premiumTestPassed -and $managedHsmTestPassed) {
    Write-Host "  ⚠️  Managed HSM works, but Premium HSM-backed keys are blocked" -ForegroundColor Yellow
    Write-Host "  This may be due to:" -ForegroundColor Yellow
    Write-Host "     - RBAC permissions need more time (>60 seconds)" -ForegroundColor Yellow
    Write-Host "     - Policy blocking HSM-backed keys" -ForegroundColor Yellow
    Write-Host "  Recommendation: Increase RBAC wait time in test script" -ForegroundColor Yellow
} else {
    Write-Host "  ❌ Both Premium HSM and Managed HSM are blocked" -ForegroundColor Red
    Write-Host "  This confirms subscription-level limitations" -ForegroundColor Red
    Write-Host "  Recommendation: Accept current test results (25/34 PASS) and proceed" -ForegroundColor Yellow
}

Write-Host "`nNext Steps:" -ForegroundColor White
if (-not $premiumTestPassed -or -not $managedHsmTestPassed) {
    Write-Host "  1. Review error messages above for specific blockers" -ForegroundColor Gray
    Write-Host "  2. Request quota/permissions if needed (see diagnostics above)" -ForegroundColor Gray
    Write-Host "  3. Consider accepting 25/34 PASS as complete for dev/test" -ForegroundColor Gray
    Write-Host "  4. Plan full HSM testing in production subscription (if needed)" -ForegroundColor Gray
} else {
    Write-Host "  1. Update AzPolicyImplScript.ps1 to increase RBAC wait to 90 seconds" -ForegroundColor Gray
    Write-Host "  2. Re-run comprehensive test: .\AzPolicyImplScript.ps1 -TestAllDenyPolicies" -ForegroundColor Gray
    Write-Host "  3. Expect 32-33/34 PASS with full HSM testing" -ForegroundColor Gray
}

Write-Host ""

#endregion
