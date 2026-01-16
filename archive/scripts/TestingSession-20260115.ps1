# ============================================================================
# Azure Key Vault Policy Testing Session - January 15, 2026
# ============================================================================
# Purpose: Comprehensive validation of all 46 Azure Key Vault policies
# Environment: MSDN dev/test subscription (can test both dev/test and production workflows)
# Account: Guest MSA with Owner permissions
# ============================================================================

# Session Configuration
$script:SessionConfig = @{
    SessionDate = "2026-01-15"
    SessionStartTime = Get-Date
    SubscriptionId = "ab1336c7-687d-4107-b0f6-9649a0458adb"
    SubscriptionName = "MSDN Platforms Subscription"
    TenantName = "yeshualoves.me"
    TestingMode = "Comprehensive" # Test all 46 policies, all modes (Audit, Deny, Enforce, Disabled)
    
    # Infrastructure Resource Groups
    RemediationRG = "rg-policy-remediation"
    TestVaultRG = "rg-policy-keyvault-test"
    
    # Testing Objectives
    Objectives = @(
        "1. Validate HTML report data accuracy (cross-check 10 policies: Azure vs HTML)",
        "2. Achieve 50%+ test coverage (test 15 more policies → 23/46 total)",
        "3. Verify infrastructure exists (Log Analytics, Event Hub, VNet, DNS)",
        "4. Test 7 key policies (close the 0% coverage gap)",
        "5. Test 3 DeployIfNotExists policies (verify auto-remediation works)",
        "6. Validate managed identity RBAC (verify all required roles assigned)",
        "7. Generate HTML report AFTER 60-minute wait (validate timing)",
        "8. Document actual policy evaluation timing"
    )
    
    # Test Results Tracking
    TestResults = @()
    InfrastructureStatus = @{}
    PolicyCoverage = @{
        TotalPolicies = 46
        TestedPolicies = 0
        TargetCoverage = 23  # 50%
    }
}

# ============================================================================
# PHASE 1: INFRASTRUCTURE VALIDATION
# ============================================================================

function Test-Infrastructure {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "PHASE 1: INFRASTRUCTURE VALIDATION" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $results = @{}
    
    # Test 1: Azure Connection
    Write-Host "`n[TEST 1.1] Azure Connection" -ForegroundColor Yellow
    try {
        $context = Get-AzContext -ErrorAction Stop
        Write-Host "   ✅ Connected as: $($context.Account.Id)" -ForegroundColor Green
        Write-Host "      Subscription: $($context.Subscription.Name)" -ForegroundColor Gray
        Write-Host "      Tenant: $($context.Tenant.Id)" -ForegroundColor Gray
        $results.AzureConnection = "PASSED"
    } catch {
        Write-Host "   ❌ Not connected to Azure" -ForegroundColor Red
        $results.AzureConnection = "FAILED"
        return $results
    }
    
    # Test 2: Resource Groups
    Write-Host "`n[TEST 1.2] Resource Groups" -ForegroundColor Yellow
    $rgRemediation = Get-AzResourceGroup -Name $script:SessionConfig.RemediationRG -ErrorAction SilentlyContinue
    $rgTest = Get-AzResourceGroup -Name $script:SessionConfig.TestVaultRG -ErrorAction SilentlyContinue
    
    if ($rgRemediation -and $rgTest) {
        Write-Host "   ✅ Both resource groups exist" -ForegroundColor Green
        Write-Host "      - $($script:SessionConfig.RemediationRG): $($rgRemediation.Location)" -ForegroundColor Gray
        Write-Host "      - $($script:SessionConfig.TestVaultRG): $($rgTest.Location)" -ForegroundColor Gray
        $results.ResourceGroups = "PASSED"
    } else {
        Write-Host "   ❌ Missing resource groups" -ForegroundColor Red
        if (-not $rgRemediation) { Write-Host "      Missing: $($script:SessionConfig.RemediationRG)" -ForegroundColor Red }
        if (-not $rgTest) { Write-Host "      Missing: $($script:SessionConfig.TestVaultRG)" -ForegroundColor Red }
        $results.ResourceGroups = "FAILED"
    }
    
    # Test 3: Managed Identity
    Write-Host "`n[TEST 1.3] Managed Identity & RBAC" -ForegroundColor Yellow
    $identity = Get-AzUserAssignedIdentity -ResourceGroupName $script:SessionConfig.RemediationRG -Name "id-policy-remediation" -ErrorAction SilentlyContinue
    if ($identity) {
        Write-Host "   ✅ Managed Identity exists" -ForegroundColor Green
        Write-Host "      Name: $($identity.Name)" -ForegroundColor Gray
        Write-Host "      Principal ID: $($identity.PrincipalId)" -ForegroundColor Gray
        
        # Check RBAC roles
        $roles = Get-AzRoleAssignment -ObjectId $identity.PrincipalId
        Write-Host "      RBAC Roles: $($roles.Count)" -ForegroundColor Gray
        foreach ($role in $roles) {
            Write-Host "         ✅ $($role.RoleDefinitionName)" -ForegroundColor Green
        }
        
        # Check for required roles
        $requiredRoles = @("Contributor", "Network Contributor", "Private DNS Zone Contributor", "Key Vault Contributor")
        $missingRoles = @()
        foreach ($required in $requiredRoles) {
            if ($roles.RoleDefinitionName -notcontains $required) {
                $missingRoles += $required
            }
        }
        
        if ($missingRoles.Count -eq 0) {
            Write-Host "      ✅ All required RBAC roles assigned" -ForegroundColor Green
            $results.ManagedIdentity = "PASSED"
        } else {
            Write-Host "      ⚠️ Missing RBAC roles:" -ForegroundColor Yellow
            foreach ($missing in $missingRoles) {
                Write-Host "         - $missing" -ForegroundColor Yellow
            }
            $results.ManagedIdentity = "WARNING - Missing roles"
        }
    } else {
        Write-Host "   ❌ Managed Identity not found" -ForegroundColor Red
        $results.ManagedIdentity = "FAILED"
    }
    
    # Test 4: Log Analytics
    Write-Host "`n[TEST 1.4] Log Analytics Workspace" -ForegroundColor Yellow
    $law = Get-AzOperationalInsightsWorkspace -ResourceGroupName $script:SessionConfig.RemediationRG -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($law) {
        Write-Host "   ✅ Log Analytics exists: $($law.Name)" -ForegroundColor Green
        $results.LogAnalytics = "PASSED"
    } else {
        Write-Host "   ⚠️ Log Analytics not found - Diagnostic policies will show N/A" -ForegroundColor Yellow
        $results.LogAnalytics = "NOT FOUND"
    }
    
    # Test 5: Event Hub
    Write-Host "`n[TEST 1.5] Event Hub Namespace" -ForegroundColor Yellow
    $eh = Get-AzEventHubNamespace -ResourceGroupName $script:SessionConfig.RemediationRG -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($eh) {
        Write-Host "   ✅ Event Hub exists: $($eh.Name)" -ForegroundColor Green
        $results.EventHub = "PASSED"
    } else {
        Write-Host "   ⚠️ Event Hub not found - Event hub policies will show N/A" -ForegroundColor Yellow
        $results.EventHub = "NOT FOUND"
    }
    
    # Test 6: Virtual Network
    Write-Host "`n[TEST 1.6] Virtual Network & Subnets" -ForegroundColor Yellow
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $script:SessionConfig.RemediationRG -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($vnet) {
        Write-Host "   ✅ VNet exists: $($vnet.Name)" -ForegroundColor Green
        Write-Host "      Subnets: $($vnet.Subnets.Count)" -ForegroundColor Gray
        foreach ($subnet in $vnet.Subnets) {
            Write-Host "         - $($subnet.Name)" -ForegroundColor Gray
        }
        $results.VirtualNetwork = "PASSED"
    } else {
        Write-Host "   ⚠️ VNet not found - Private endpoint policies will fail" -ForegroundColor Yellow
        $results.VirtualNetwork = "NOT FOUND"
    }
    
    # Test 7: Private DNS Zone
    Write-Host "`n[TEST 1.7] Private DNS Zone" -ForegroundColor Yellow
    $dns = Get-AzPrivateDnsZone -ResourceGroupName $script:SessionConfig.RemediationRG -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($dns) {
        Write-Host "   ✅ Private DNS Zone exists: $($dns.Name)" -ForegroundColor Green
        $results.PrivateDNS = "PASSED"
    } else {
        Write-Host "   ⚠️ Private DNS not found - Private endpoint policies will fail" -ForegroundColor Yellow
        $results.PrivateDNS = "NOT FOUND"
    }
    
    # Test 8: Test Key Vaults
    Write-Host "`n[TEST 1.8] Test Key Vaults" -ForegroundColor Yellow
    $vaults = Get-AzKeyVault -ResourceGroupName $script:SessionConfig.TestVaultRG -ErrorAction SilentlyContinue
    if ($vaults -and $vaults.Count -gt 0) {
        Write-Host "   ✅ Test vaults found: $($vaults.Count)" -ForegroundColor Green
        foreach ($vault in $vaults) {
            Write-Host "      📦 $($vault.VaultName)" -ForegroundColor Gray
            Write-Host "         Purge Protection: $($vault.EnablePurgeProtection)" -ForegroundColor Gray
            Write-Host "         Soft Delete: $($vault.EnableSoftDelete)" -ForegroundColor Gray
        }
        $results.TestVaults = "PASSED - $($vaults.Count) vaults"
    } else {
        Write-Host "   ❌ No test vaults found - Cannot test policies" -ForegroundColor Red
        $results.TestVaults = "FAILED"
    }
    
    # Summary
    Write-Host "`n========================================" -ForegroundColor Gray
    Write-Host "INFRASTRUCTURE VALIDATION SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Gray
    
    $passCount = ($results.Values | Where-Object { $_ -match "PASSED" }).Count
    $failCount = ($results.Values | Where-Object { $_ -match "FAILED" }).Count
    $warnCount = ($results.Values | Where-Object { $_ -match "NOT FOUND|WARNING" }).Count
    
    foreach ($test in $results.GetEnumerator()) {
        $status = if ($test.Value -match "PASSED") { "✅" } elseif ($test.Value -match "FAILED") { "❌" } else { "⚠️" }
        $color = if ($status -eq "✅") { "Green" } elseif ($status -eq "❌") { "Red" } else { "Yellow" }
        Write-Host "$status $($test.Key): $($test.Value)" -ForegroundColor $color
    }
    
    Write-Host "`nResults: $passCount Passed | $failCount Failed | $warnCount Warnings" -ForegroundColor Cyan
    
    # Store results
    $script:SessionConfig.InfrastructureStatus = $results
    
    # GO/NO-GO Decision
    if ($failCount -eq 0) {
        Write-Host "`n✅ GO: Infrastructure validation PASSED - Ready to deploy policies" -ForegroundColor Green
        return $true
    } elseif ($failCount -le 2 -and $results.TestVaults -match "PASSED") {
        Write-Host "`n⚠️ CAUTION: Some infrastructure missing but can proceed with limited testing" -ForegroundColor Yellow
        return $true
    } else {
        Write-Host "`n❌ NO-GO: Critical infrastructure missing - Run Setup-AzureKeyVaultPolicyEnvironment.ps1" -ForegroundColor Red
        return $false
    }
}

# ============================================================================
# PHASE 2: PARAMETER FILE VALIDATION
# ============================================================================

function Test-ParameterFiles {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "PHASE 2: PARAMETER FILE VALIDATION" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # Test DevTest parameter file
    Write-Host "`n[TEST 2.1] DevTest Parameter File" -ForegroundColor Yellow
    if (Test-Path "PolicyParameters-DevTest.json") {
        $devtest = Get-Content "PolicyParameters-DevTest.json" | ConvertFrom-Json
        $policyCount = $devtest.policies.Count
        $disabledCount = ($devtest.policies | Where-Object { $_.effect -eq "Disabled" }).Count
        
        Write-Host "   ✅ File exists" -ForegroundColor Green
        Write-Host "      Policies: $policyCount (Expected: 30)" -ForegroundColor $(if ($policyCount -eq 30) { "Green" } else { "Yellow" })
        Write-Host "      Disabled effects: $disabledCount (Expected: 0)" -ForegroundColor $(if ($disabledCount -eq 0) { "Green" } else { "Yellow" })
        
        # Check for common issues
        $issues = @()
        if ($policyCount -ne 30) { $issues += "Unexpected policy count" }
        if ($disabledCount -gt 0) { $issues += "$disabledCount policies are Disabled" }
        
        if ($issues.Count -eq 0) {
            Write-Host "      ✅ Validation PASSED" -ForegroundColor Green
        } else {
            Write-Host "      ⚠️ Issues found:" -ForegroundColor Yellow
            $issues | ForEach-Object { Write-Host "         - $_" -ForegroundColor Yellow }
        }
    } else {
        Write-Host "   ❌ File not found" -ForegroundColor Red
    }
    
    # Test Production parameter file
    Write-Host "`n[TEST 2.2] Production Parameter File" -ForegroundColor Yellow
    if (Test-Path "PolicyParameters-Production.json") {
        $prod = Get-Content "PolicyParameters-Production.json" | ConvertFrom-Json
        $policyCount = $prod.policies.Count
        $disabledCount = ($prod.policies | Where-Object { $_.effect -eq "Disabled" }).Count
        
        Write-Host "   ✅ File exists" -ForegroundColor Green
        Write-Host "      Policies: $policyCount (Expected: 32 or 46)" -ForegroundColor $(if ($policyCount -in @(32, 46)) { "Green" } else { "Yellow" })
        Write-Host "      Disabled effects: $disabledCount (Expected: 0)" -ForegroundColor $(if ($disabledCount -eq 0) { "Green" } else { "Yellow" })
        
        # Check for common issues
        $issues = @()
        if ($policyCount -notin @(32, 46)) { $issues += "Unexpected policy count" }
        if ($disabledCount -gt 0) { $issues += "$disabledCount policies are Disabled" }
        
        if ($issues.Count -eq 0) {
            Write-Host "      ✅ Validation PASSED" -ForegroundColor Green
        } else {
            Write-Host "      ⚠️ Issues found:" -ForegroundColor Yellow
            $issues | ForEach-Object { Write-Host "         - $_" -ForegroundColor Yellow }
        }
    } else {
        Write-Host "   ❌ File not found" -ForegroundColor Red
    }
    
    # Test Policy Name Mapping
    Write-Host "`n[TEST 2.3] Policy Name Mapping File" -ForegroundColor Yellow
    if (Test-Path "PolicyNameMapping.json") {
        $mapping = Get-Content "PolicyNameMapping.json" | ConvertFrom-Json
        $mappingCount = ($mapping.PSObject.Properties).Count
        Write-Host "   ✅ File exists with $mappingCount policy mappings" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ File not found - May cause policy name lookup issues" -ForegroundColor Yellow
    }
}

# ============================================================================
# PHASE 3: 46-POLICY COVERAGE TRACKER
# ============================================================================

function Initialize-PolicyCoverageTracker {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "PHASE 3: 46-POLICY COVERAGE TRACKER" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # Define all 46 policies by category
    $script:AllPolicies = @{
        "Vault Protection" = @(
            @{ ID = "KV-001"; Name = "Purge protection enabled"; Tested = $false }
            @{ ID = "KV-002"; Name = "Soft delete enabled"; Tested = $true }  # Tested yesterday
            @{ ID = "KV-003"; Name = "ARM template deployment blocked"; Tested = $false }
        )
        "Network Security" = @(
            @{ ID = "KV-004"; Name = "Private endpoints required"; Tested = $false }
            @{ ID = "KV-005"; Name = "Private link configuration"; Tested = $false }
            @{ ID = "KV-006"; Name = "Firewall enabled"; Tested = $true }  # Tested yesterday
            @{ ID = "KV-007"; Name = "Public network access disabled"; Tested = $false }
            @{ ID = "KV-008"; Name = "Service endpoints enabled"; Tested = $false }
            @{ ID = "KV-009"; Name = "IP firewall rules configured"; Tested = $false }
            @{ ID = "KV-010"; Name = "VNet integration required"; Tested = $false }
            @{ ID = "KV-011"; Name = "Private DNS zone configured"; Tested = $false }
            @{ ID = "KV-012"; Name = "Trusted services bypass enabled"; Tested = $false }
        )
        "Deployment/Configuration" = @(
            @{ ID = "KV-013"; Name = "Deploy private endpoint (DeployIfNotExists)"; Tested = $false }
            @{ ID = "KV-014"; Name = "Deploy diagnostic settings (DeployIfNotExists)"; Tested = $false }
            @{ ID = "KV-015"; Name = "Deploy private DNS (DeployIfNotExists)"; Tested = $false }
            @{ ID = "KV-016"; Name = "Configure firewall (Modify)"; Tested = $true }  # Tested yesterday
            @{ ID = "KV-017"; Name = "Configure public access (Modify)"; Tested = $false }
            @{ ID = "KV-018"; Name = "Deploy event hub diagnostics (DeployIfNotExists)"; Tested = $false }
        )
        "Access Control" = @(
            @{ ID = "KV-019"; Name = "RBAC permission model (Modify)"; Tested = $true }  # Tested yesterday
        )
        "Diagnostic Logging" = @(
            @{ ID = "KV-020"; Name = "Resource logs enabled (Key Vault)"; Tested = $false }
            @{ ID = "KV-021"; Name = "Resource logs enabled (HSM)"; Tested = $false }
        )
        "Certificates" = @(
            @{ ID = "KV-022"; Name = "Certificate validity period ≤12 months"; Tested = $true }  # Tested yesterday
            @{ ID = "KV-023"; Name = "Certificate expiration set"; Tested = $true }  # Tested yesterday
            @{ ID = "KV-024"; Name = "Certificate renewal configured"; Tested = $true }  # Tested yesterday
            @{ ID = "KV-025"; Name = "Certificate lifetime action set"; Tested = $false }
            @{ ID = "KV-026"; Name = "Certificate type restrictions"; Tested = $false }
            @{ ID = "KV-027"; Name = "Certificate key type restrictions"; Tested = $false }
            @{ ID = "KV-028"; Name = "Integrated CA required"; Tested = $false }
            @{ ID = "KV-029"; Name = "Non-integrated CA restrictions"; Tested = $false }
        )
        "Keys" = @(
            @{ ID = "KV-030"; Name = "Key expiration date set"; Tested = $false }
            @{ ID = "KV-031"; Name = "Key validity period ≤X days"; Tested = $false }
            @{ ID = "KV-032"; Name = "Key rotation enabled"; Tested = $false }
            @{ ID = "KV-033"; Name = "Key type (RSA/EC)"; Tested = $false }
            @{ ID = "KV-034"; Name = "RSA key size ≥2048"; Tested = $false }
            @{ ID = "KV-035"; Name = "EC curve restrictions"; Tested = $false }
            @{ ID = "KV-036"; Name = "Key not active >X days"; Tested = $false }
            @{ ID = "KV-037"; Name = "HSM-backed keys required"; Tested = $false }
            @{ ID = "KV-038"; Name = "Key rotation policy (Audit only)"; Tested = $false }
            @{ ID = "KV-039"; Name = "HSM key expiration (Managed HSM)"; Tested = $false }
            @{ ID = "KV-040"; Name = "HSM key size ≥2048 (Managed HSM)"; Tested = $false }
            @{ ID = "KV-041"; Name = "HSM EC curves (Managed HSM)"; Tested = $false }
            @{ ID = "KV-042"; Name = "HSM purge protection (Managed HSM)"; Tested = $false }
            @{ ID = "KV-043"; Name = "HSM public access disabled (Managed HSM)"; Tested = $false }
        )
        "Secrets" = @(
            @{ ID = "KV-044"; Name = "Secret expiration date set"; Tested = $true }  # Tested yesterday
            @{ ID = "KV-045"; Name = "Secret validity period ≤X days"; Tested = $false }
            @{ ID = "KV-046"; Name = "Secret content type specified"; Tested = $false }
            @{ ID = "KV-047"; Name = "Secret activation date valid"; Tested = $false }
            @{ ID = "KV-048"; Name = "Secret not expired"; Tested = $false }
        )
    }
    
    # Calculate current coverage
    $totalPolicies = 0
    $testedPolicies = 0
    
    foreach ($category in $script:AllPolicies.Keys) {
        $policies = $script:AllPolicies[$category]
        $totalPolicies += $policies.Count
        $testedPolicies += ($policies | Where-Object { $_.Tested }).Count
    }
    
    $coveragePercent = [math]::Round(($testedPolicies / $totalPolicies) * 100, 1)
    
    Write-Host "`n📊 Current Test Coverage:" -ForegroundColor Cyan
    Write-Host "   Total Policies: $totalPolicies" -ForegroundColor Gray
    Write-Host "   Tested: $testedPolicies ($coveragePercent%)" -ForegroundColor $(if ($coveragePercent -ge 50) { "Green" } else { "Yellow" })
    Write-Host "   Target: 23 (50%)" -ForegroundColor Gray
    Write-Host "   Remaining: $($totalPolicies - $testedPolicies)" -ForegroundColor Yellow
    
    # Show coverage by category
    Write-Host "`n📋 Coverage by Category:" -ForegroundColor Cyan
    foreach ($category in $script:AllPolicies.Keys | Sort-Object) {
        $policies = $script:AllPolicies[$category]
        $tested = ($policies | Where-Object { $_.Tested }).Count
        $total = $policies.Count
        $percent = if ($total -gt 0) { [math]::Round(($tested / $total) * 100, 0) } else { 0 }
        
        $status = if ($percent -eq 0) { "❌" } elseif ($percent -lt 50) { "⚠️" } elseif ($percent -lt 100) { "🔶" } else { "✅" }
        Write-Host "   $status $category : $tested/$total ($percent%)" -ForegroundColor $(
            if ($percent -eq 0) { "Red" } 
            elseif ($percent -lt 50) { "Yellow" } 
            elseif ($percent -lt 100) { "Cyan" } 
            else { "Green" }
        )
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Start-TestingSession {
    Write-Host "`n" -NoNewline
    Write-Host "============================================================================" -ForegroundColor Magenta
    Write-Host "  AZURE KEY VAULT POLICY TESTING SESSION" -ForegroundColor Magenta
    Write-Host "  Date: $($script:SessionConfig.SessionDate)" -ForegroundColor Magenta
    Write-Host "  Subscription: $($script:SessionConfig.SubscriptionName)" -ForegroundColor Magenta
    Write-Host "  Tenant: $($script:SessionConfig.TenantName)" -ForegroundColor Magenta
    Write-Host "============================================================================" -ForegroundColor Magenta
    Write-Host "`n📋 Session Objectives:" -ForegroundColor Cyan
    $script:SessionConfig.Objectives | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    
    # Run validations
    Write-Host "`n🚀 Starting validation phases..." -ForegroundColor Green
    Start-Sleep -Seconds 2
    
    # Phase 1: Infrastructure
    $infraReady = Test-Infrastructure
    if (-not $infraReady) {
        Write-Host "`n❌ Infrastructure validation failed - Cannot proceed" -ForegroundColor Red
        return
    }
    
    # Phase 2: Parameter Files
    Test-ParameterFiles
    
    # Phase 3: Policy Coverage
    Initialize-PolicyCoverageTracker
    
    Write-Host "`n============================================================================" -ForegroundColor Magenta
    Write-Host "  VALIDATION COMPLETE - READY TO BEGIN TESTING" -ForegroundColor Magenta
    Write-Host "============================================================================" -ForegroundColor Magenta
    
    Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Review validation results above" -ForegroundColor Gray
    Write-Host "   2. Deploy policies: .\AzPolicyImplScript.ps1 -Environment DevTest -Phase Test" -ForegroundColor Gray
    Write-Host "   3. Wait 60 minutes for policy evaluation" -ForegroundColor Gray
    Write-Host "   4. Generate HTML report: .\AzPolicyImplScript.ps1 -CheckCompliance" -ForegroundColor Gray
    Write-Host "   5. Cross-validate data accuracy" -ForegroundColor Gray
    Write-Host "   6. Test individual policies to achieve 50% coverage" -ForegroundColor Gray
}

# Export functions
Export-ModuleMember -Function Start-TestingSession, Test-Infrastructure, Test-ParameterFiles, Initialize-PolicyCoverageTracker

Write-Host "Testing session script loaded. Run Start-TestingSession to begin." -ForegroundColor Green
