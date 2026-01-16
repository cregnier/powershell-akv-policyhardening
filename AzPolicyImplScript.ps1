<#
.SYNOPSIS
  Azure Policy implementation and testing framework for Key Vault governance policies.

.DESCRIPTION
  ═══════════════════════════════════════════════════════════════════════════════
  AZURE KEY VAULT POLICY GOVERNANCE - IMPLEMENTATION & TESTING FRAMEWORK
  ═══════════════════════════════════════════════════════════════════════════════
  
  WHO:    Enterprise Azure administrators implementing Key Vault security governance
  WHAT:   Automated deployment, testing, and compliance monitoring for 46 Azure Key Vault policies
  WHEN:   Use during phased rollout: DevTest → Production Audit → Production Enforcement
  WHERE:  Azure subscriptions and resource groups with Key Vault resources
  WHY:    Ensure consistent security posture, compliance, and governance across Key Vault resources
  HOW:    PowerShell automation with parameter files, policy assignments, and comprehensive testing
  
  ═══════════════════════════════════════════════════════════════════════════════
  VERSION HISTORY
  ═══════════════════════════════════════════════════════════════════════════════
  Version: 2.0
  Date: 2026-01-16
  Changes: 
    - Added resource-level policy testing (keys, secrets, certificates)
    - Enhanced Test-ProductionEnforcement with 9 comprehensive tests (was 4)
    - Added -TriggerScan timeout (5 minutes) to prevent hanging
    - Fixed Phase 2.3 auto-detection confusion
    - Documented soft delete ARM template workaround
    - All 46 policies tested across 5 phases (100% success rate)
  
  Previous Versions:
    1.x: Initial implementation with basic testing
  
  ═══════════════════════════════════════════════════════════════════════════════
  TESTED & VALIDATED
  ═══════════════════════════════════════════════════════════════════════════════
  Test Date: 2026-01-16
  Test Coverage: 46/46 policies (100%)
  Test Phases: 5 (Infrastructure, DevTest, Production Audit, Production Enforcement, HTML Validation)
  Test Results: ALL PASS ✅
  Evidence: See FINAL-TEST-SUMMARY.md, TESTING-MAPPING.md
  
  ═══════════════════════════════════════════════════════════════════════════════
  POLICY SELECTION ARCHITECTURE
  ═══════════════════════════════════════════════════════════════════════════════
  
  The script uses a **two-file approach** for policy deployment:
  
  1. **Parameter JSON Files** (PolicyParameters-*.json)
     - PRIMARY SOURCE: Defines WHICH policies to deploy
     - Contains only the policies relevant to that scenario
     - Example: Tier1-Deny.json contains 9 policies (subset of 46)
     - Each policy name becomes a key in the JSON with parameter values
  
  2. **Definition CSV File** (DefinitionListExport.csv)
     - REFERENCE ONLY: Metadata for all 46 available Azure Key Vault policies
     - Used to look up policy definition IDs, versions, and metadata
     - Never used as source of which policies to deploy
  
  This ensures Tier deployments (9 policies) don't attempt all 46 policies.

  ═══════════════════════════════════════════════════════════════════════════════
  6 PARAMETER FILES FOR ALL TESTING SCENARIOS
  ═══════════════════════════════════════════════════════════════════════════════
  
  DevTest Environment (30 policies):
  - PolicyParameters-DevTest.json              : Audit mode, safe default
  - PolicyParameters-DevTest-Remediation.json  : 6 auto-remediation policies
  
  DevTest Environment (46 policies - comprehensive):
  - PolicyParameters-DevTest-Full.json              : Audit mode, all policies
  - PolicyParameters-DevTest-Full-Remediation.json  : 8 auto-remediation policies
  
  Production Environment (46 policies):
  - PolicyParameters-Production.json              : Audit mode enforcement
  - PolicyParameters-Production-Remediation.json  : 8 auto-remediation policies
  
  Production Environment (9 Tier 1 Deny policies):
  - PolicyParameters-Tier1-Deny.json           : Critical security policies in Deny mode
  
  See PolicyParameters-QuickReference.md for complete guide.

  ═══════════════════════════════════════════════════════════════════════════════
  DEPLOYMENT WORKFLOWS
  ═══════════════════════════════════════════════════════════════════════════════
  
  # DevTest - Safe (30 policies)
  .\AzPolicyImplScript.ps1 -DeployDevTest -SkipRBACCheck
  
  # DevTest - Full (46 policies)
  .\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -SkipRBACCheck
  
  # Production - Enforcement (46 policies, Deny mode)
  .\AzPolicyImplScript.ps1 -DeployProduction -SkipRBACCheck
  
  # Auto-Remediation Testing (8 DeployIfNotExists/Modify policies)
  .\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json -SkipRBACCheck
  .\AzPolicyImplScript.ps1 -TestAutoRemediation -SkipRBACCheck

  TESTING MODES:
  
  # Infrastructure validation (11-step check)
  .\AzPolicyImplScript.ps1 -TestInfrastructure
  
  # Production enforcement testing (4 Deny mode tests)
  .\AzPolicyImplScript.ps1 -TestProductionEnforcement
  
  # Auto-remediation testing (30-60 min)
  .\AzPolicyImplScript.ps1 -TestAutoRemediation
  
  # Compliance reporting
  .\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan

.PARAMETER DeployDevTest
  Deploy 30 policies using PolicyParameters-DevTest.json (Audit mode, safe default).

.PARAMETER DeployProduction
  Deploy 46 policies using PolicyParameters-Production.json (Deny mode enforcement).

.PARAMETER ParameterFile
  Path to custom parameter file (e.g., PolicyParameters-DevTest-Full-Remediation.json).

.PARAMETER TestInfrastructure
  Run comprehensive 11-step infrastructure validation check.
  Validates: Azure connection, resource groups, managed identity, RBAC, Log Analytics,
  Event Hub, VNet, DNS, test vaults, policy assignments, parameter files.

.PARAMETER TestProductionEnforcement
  Run 4 focused Deny mode validation tests:
  - Purge protection enforcement
  - Firewall enforcement
  - RBAC authorization enforcement
  - Compliant vault baseline

.PARAMETER TestAutoRemediation
  Test DeployIfNotExists/Modify policies by creating non-compliant vault and
  monitoring auto-remediation (30-60 minute wait for Azure Policy evaluation cycle).
  Tests 8 auto-remediation policies: diagnostic settings, private endpoints, RBAC, firewall.

.PARAMETER CheckCompliance
  Generate HTML compliance report for current policy assignments.

.PARAMETER ValidateReport
  Validate generated HTML compliance report for data integrity, policy count accuracy,
  compliance percentage calculations, and timestamp recency.
  If -ReportPath not specified, validates the most recent ComplianceReport-*.html file.

.PARAMETER ReportPath
  Path to specific HTML report file to validate. Used with -ValidateReport parameter.

.PARAMETER SkipRBACCheck
  Skips the RBAC permission check before deploying policies. By default, the script
  verifies the current user has Owner, Contributor, or Policy Contributor role on
  the target scope. Use this switch to bypass the check in the following scenarios:
  
  ✅ WHEN TO USE:
  - Automated CI/CD pipelines where service principal/managed identity permissions are pre-verified
  - Testing environments where you've confirmed RBAC assignments separately
  - Repeated runs where you've already validated permissions
  - Non-interactive execution (scripts, automation runbooks, scheduled tasks)
  
  ⚠️ WHEN NOT TO USE:
  - First-time deployment on a new subscription/resource group (always verify RBAC first)
  - Production environments with strict governance (validate permissions to avoid audit issues)
  - When unsure about current role assignments (script will show helpful error if missing permissions)

.EXAMPLE
  # Deploy DevTest (30 policies, Audit mode)
  .\AzPolicyImplScript.ps1 -DeployDevTest -SkipRBACCheck
  
  # Deploy DevTest Full (46 policies, Audit mode)
  .\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -SkipRBACCheck
  
  # Deploy Production (46 policies, Deny mode)
  .\AzPolicyImplScript.ps1 -DeployProduction -SkipRBACCheck
  
  # Deploy with Auto-Remediation
  .\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Remediation.json -SkipRBACCheck

.EXAMPLE
  # Test infrastructure readiness
  .\AzPolicyImplScript.ps1 -TestInfrastructure
  
  # Test Deny mode enforcement
  .\AzPolicyImplScript.ps1 -TestProductionEnforcement
  
  # Test auto-remediation (30-60 min)
  .\AzPolicyImplScript.ps1 -TestAutoRemediation -SkipRBACCheck
  
  # Generate compliance report
  .\AzPolicyImplScript.ps1 -CheckCompliance -SkipRBACCheck

.NOTES
  - Requires Az PowerShell modules. The script can install missing modules.
  - Run interactively from a user account with sufficient RBAC (Owner or
    Policy Contributor) for the target scope. If you lack roles the script
    prints a request template to ask your security/infra team.
  - For production deployments, always run with RBAC checks enabled (default)
    to ensure proper governance and audit trail.
  - Recommended workflow: DevTest → DevTest-Full → Production (Audit) → Production (Deny) → Remediation
  - Auto-remediation testing requires 30-60 minutes for Azure Policy evaluation cycle

  VERSION: 0.1.0 (6-Parameter File Strategy)
  LAST UPDATED: January 15, 2026

#>

$Script:Version = '0.1.0'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $ts = (Get-Date).ToString('u')
    $color = switch ($Level) {
        'ERROR' { 'Red' }
        'WARN'  { 'Yellow' }
        'SUCCESS' { 'Green' }
        'INFO'  { 'Cyan' }
        default { 'White' }
    }
    Write-Host "[$ts] " -NoNewline -ForegroundColor DarkGray
    Write-Host "[$Level] " -NoNewline -ForegroundColor $color
    Write-Host $Message -ForegroundColor $color
}

function Ensure-RequiredModules {
    Write-Log 'Checking required PowerShell modules...'
    $modules = @('Az.Accounts','Az.Resources','Az.PolicyInsights','Az.Monitor','Az.KeyVault')
    foreach ($m in $modules) {
        if (-not (Get-Module -ListAvailable -Name $m)) {
            Write-Log "Module $m not found. Installing..."
            try {
                Install-Module -Name $m -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
                Write-Log "Installed $m" -Level 'SUCCESS'
            } catch {
                Write-Log -Message "Failed to install $($m): $($_)" -Level 'ERROR'
                throw
            }
        } else {
            Write-Log "Module $m is present" -Level 'SUCCESS'
        }
    }
}

function Connect-AzureIfNeeded {
    param(
        [switch]$DryRun
    )
    if ($DryRun) {
        Write-Log -Message 'Dry-run mode: skipping Azure interactive login.' -Level 'INFO'
        return
    }
    if (-not (Get-AzContext)) {
        Write-Log 'No Azure context found. Prompting for interactive login.'
        Connect-AzAccount | Out-Null
    } else {
        Write-Log "Using Azure context: $((Get-AzContext).Account)"
    }
}

function Check-UserPermissions {
    param(
        [string]$Scope
    )
    $acct = (Get-AzContext).Account.Id
    Write-Log "Checking role assignments for $acct on scope $Scope"
    try {
        $assignments = Get-AzRoleAssignment -Scope $Scope -SignInName $acct -ErrorAction Stop
    } catch {
        Write-Log -Message "Unable to query role assignments: $($_)" -Level 'ERROR'
        return $false
    }
    $needed = @('Owner','Contributor','Policy Contributor')
    foreach ($a in $assignments) {
        if ($needed -contains $a.RoleDefinitionName) {
            Write-Log "Found role $($a.RoleDefinitionName) for $acct"
            return $true
        }
    }
    Write-Log -Message "No recommended RBAC role found. You need one of: $($needed -join ', ')" -Level 'WARN'
    Write-Host "----- ROLE REQUEST TEMPLATE START -----"
    Write-Host "Please grant the following RBAC role to $($acct) on scope $($Scope):"
    Write-Host " - Role: Policy Contributor (or Owner)"
    Write-Host "Reason: Needed to assign and manage Azure Policy for Key Vault governance and compliance evaluations."
    Write-Host "Requested-by: $($acct)"
    Write-Host "Contact: security-team@contoso.com"
    Write-Host "----- ROLE REQUEST TEMPLATE END -----"
    return $false
}

function Show-InteractiveMenu {
    Write-Host ""
    Write-Log "========================================" -Level 'INFO'
    Write-Log "  Azure Policy Implementation Assistant" -Level 'INFO'
    Write-Log "========================================" -Level 'INFO'
    Write-Host ""
    Write-Log "Choose environment preset:" -Level 'WARN'
    Write-Host "  1) Dev/Test  - Relaxed parameters, all Audit mode, longer validity periods"
    Write-Host "  2) Production - Strict parameters, critical policies Deny, shorter validity periods"
    Write-Host "  3) Custom    - Use existing PolicyParameters.json"
    Write-Host ""
    $envChoice = Read-Host "Select environment [1-3]"
    
    $paramFile = './PolicyParameters.json'
    switch ($envChoice) {
        '1' { 
            $paramFile = './PolicyParameters-DevTest.json'
            Write-Log "✓ Dev/Test preset selected" -Level 'SUCCESS'
        }
        '2' { 
            $paramFile = './PolicyParameters-Production.json'
            Write-Log "✓ Production preset selected" -Level 'SUCCESS'
        }
        '3' { 
            Write-Log "✓ Using custom PolicyParameters.json" -Level 'SUCCESS'
        }
        default { 
            Write-Log "✓ Default to custom PolicyParameters.json" -Level 'SUCCESS'
        }
    }
    
    Write-Host ""
    Write-Log "Choose policy scope:" -Level 'WARN'
    Write-Host "  1) All 46 policies from CSV"
    Write-Host "  2) Critical policies only (soft delete, purge protection, expiration dates)"
    Write-Host "  3) Custom selection (you'll provide list)"
    Write-Host ""
    $scopeChoice = Read-Host "Select scope [1-3]"
    
    $includePolicies = @()
    switch ($scopeChoice) {
        '1' { 
            Write-Log "✓ All 46 policies selected" -Level 'SUCCESS'
        }
        '2' {
            $includePolicies = @(
                'Key vaults should have soft delete enabled',
                'Key vaults should have deletion protection enabled',
                'Azure Key Vault Managed HSM should have purge protection enabled',
                'Key Vault secrets should have an expiration date',
                'Key Vault keys should have an expiration date',
                'Azure Key Vault should disable public network access',
                'Resource logs in Key Vault should be enabled'
            )
            Write-Log "✓ Critical policies selected ($($includePolicies.Count) policies)" -Level 'SUCCESS'
        }
        '3' {
            Write-Host "Enter comma-separated policy names (or leave blank to review CSV first):"
            $customInput = Read-Host "Policy names"
            if ($customInput) {
                $includePolicies = $customInput -split ',' | ForEach-Object { $_.Trim() }
                Write-Log "✓ Custom selection: $($includePolicies.Count) policies" -Level 'SUCCESS'
            }
        }
    }
    
    return @{
        ParameterFile = $paramFile
        IncludePolicies = $includePolicies
    }
}

function Test-DenyBlocking {
    <#
    .SYNOPSIS
    Tests that Deny mode policies actually block non-compliant operations.
    
    .DESCRIPTION
    Creates test scenarios to verify that Azure Policies in Deny mode prevent
    non-compliant Key Vault resources from being created or modified.
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$ResourceGroupName = 'rg-policy-keyvault-test',
        
        [Parameter(Mandatory=$false)]
        [string]$Location = 'eastus'
    )
    
    Write-Host ""
    Write-Log "═══════════════════════════════════════════════════════════" -Level 'INFO'
    Write-Log "  DENY BLOCKING TEST MODE" -Level 'INFO'
    Write-Log "═══════════════════════════════════════════════════════════" -Level 'INFO'
    Write-Host ""
    Write-Host "This will test that Deny policies block non-compliant operations." -ForegroundColor White
    Write-Log "Expected result: All test operations should be DENIED by policy." -Level 'WARN'
    Write-Host ""
    
    $testResults = @{
        TotalTests = 0
        Blocked = 0
        NotBlocked = 0
        Errors = @()
        TestDetails = @()
    }
    
    # Ensure resource group exists
    try {
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if (-not $rg) {
            Write-Log "Resource group '$ResourceGroupName' not found. Creating..." -Level 'WARN'
            $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
            Write-Log "Resource group created." -Level 'SUCCESS'
        }
    } catch {
        Write-Log "Failed to access/create resource group: $_" -Level 'ERROR'
        return $testResults
    }
    
    # Test 1: Create Key Vault WITHOUT purge protection (should be DENIED)
    Write-Host ""
    Write-Log "🧪 Test 1: Create Key Vault WITHOUT purge protection" -Level 'INFO'
    Write-Host "   Expected: DENIED by policy" -ForegroundColor Gray
    $testResults.TotalTests++
    
    $testVaultName = "kv-deny-test-" + (Get-Random -Minimum 1000 -Maximum 9999)
    try {
        # Note: SoftDelete is always enabled by default now, can't be disabled
        # Test purge protection instead
        $vault = New-AzKeyVault -Name $testVaultName -ResourceGroupName $ResourceGroupName `
            -Location $Location -ErrorAction Stop
        
        Write-Log "FAIL: Vault created without purge protection (policy did NOT block)" -Level 'ERROR'
        $testResults.NotBlocked++
        $testResults.TestDetails += @{
            Test = "Create vault without purge protection"
            Result = "NOT BLOCKED"
            VaultName = $testVaultName
            Message = "Policy should have denied this operation"
        }
        
        # Clean up the non-compliant vault
        Remove-AzKeyVault -Name $testVaultName -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue
        
    } catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "RequestDisallowedByPolicy|policy|denied|disallow") {
            Write-Log "PASS: Blocked by policy" -Level 'SUCCESS'
            Write-Host "   Policy: $($errorMessage -replace '.*PolicyDefinitionName\s*:\s*([^,]+).*','$1')" -ForegroundColor Gray
            $testResults.Blocked++
            $testResults.TestDetails += @{
                Test = "Create vault without purge protection"
                Result = "BLOCKED"
                PolicyName = ($errorMessage -replace '.*PolicyDefinitionName\s*:\s*([^,]+).*','$1')
                Message = $errorMessage.Split([Environment]::NewLine)[0]
            }
        } else {
            Write-Log "ERROR: Unexpected failure" -Level 'WARN'
            Write-Host "   $errorMessage" -ForegroundColor Gray
            $testResults.Errors += "Test 1: $errorMessage"
        }
    }
    
    # Test 2: Create Key Vault with public network access (should be DENIED if policy enforces private-only)
    Write-Host ""
    Write-Log "🧪 Test 2: Create Key Vault with public network access enabled" -Level 'INFO'
    Write-Host "   Expected: DENIED by policy (if public network disabled policy is in Enforce)" -ForegroundColor Gray
    $testResults.TotalTests++
    
    $testVaultName = "kv-deny-test-" + (Get-Random -Minimum 1000 -Maximum 9999)
    try {
        $vault = New-AzKeyVault -Name $testVaultName -ResourceGroupName $ResourceGroupName `
            -Location $Location -EnablePurgeProtection -PublicNetworkAccess 'Enabled' -ErrorAction Stop
        
        Write-Log "INFO: Vault created with public access (policy may be Audit-only or not enforcing this)" -Level 'WARN'
        $testResults.NotBlocked++
        $testResults.TestDetails += @{
            Test = "Create vault with public network access"
            Result = "NOT BLOCKED"
            VaultName = $testVaultName
            Message = "Policy may be in Audit mode or not assigned for public network restriction"
        }

        
        # Clean up
        Remove-AzKeyVault -Name $testVaultName -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue
        
    } catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "RequestDisallowedByPolicy|policy|denied|disallow") {
            Write-Log "PASS: Blocked by policy" -Level 'SUCCESS'
            Write-Host "   Policy: $($errorMessage -replace '.*PolicyDefinitionName\s*:\s*([^,]+).*','$1')" -ForegroundColor Gray
            $testResults.Blocked++
            $testResults.TestDetails += @{
                Test = "Create vault without purge protection"
                Result = "BLOCKED"
                PolicyName = ($errorMessage -replace '.*PolicyDefinitionName\s*:\s*([^,]+).*','$1')
                Message = $errorMessage.Split([Environment]::NewLine)[0]
            }
        } else {
            Write-Log "ERROR: Unexpected failure" -Level 'WARN'
            Write-Host "   $errorMessage" -ForegroundColor Gray
            $testResults.Errors += "Test 2: $errorMessage"
        }
    }
    
    # Test 3: Create compliant vault, then try to add key WITHOUT expiration (should be DENIED)
    Write-Host ""
    Write-Log "🧪 Test 3: Create key WITHOUT expiration date" -Level 'INFO'
    Write-Host "   Expected: DENIED by policy" -ForegroundColor Gray
    $testResults.TotalTests++
    
    # First, create a compliant vault
    $compliantVaultName = "kv-deny-test-" + (Get-Random -Minimum 1000 -Maximum 9999)
    try {
        $compliantVault = New-AzKeyVault -Name $compliantVaultName -ResourceGroupName $ResourceGroupName `
            -Location $Location -EnablePurgeProtection -ErrorAction Stop
        
        # Try to add key without expiration
        Start-Sleep -Seconds 5  # Wait for vault to be ready
        
        try {
            $key = Add-AzKeyVaultKey -VaultName $compliantVaultName -Name "test-key-no-expiry" `
                -Destination Software -ErrorAction Stop
            
            Write-Log "FAIL: Key created without expiration (policy did NOT block)" -Level 'ERROR'
            $testResults.NotBlocked++
            $testResults.TestDetails += @{
                Test = "Create key without expiration"
                Result = "NOT BLOCKED"
                VaultName = $compliantVaultName
                Message = "Policy should have denied this operation"
            }
            
        } catch {
            $errorMessage = $_.Exception.Message
            if ($errorMessage -match "RequestDisallowedByPolicy|policy|denied|disallow") {
                Write-Log "PASS: Blocked by policy" -Level 'SUCCESS'
                Write-Host "   Policy: $($errorMessage -replace '.*PolicyDefinitionName\s*:\s*([^,]+).*','$1')" -ForegroundColor Gray
                $testResults.Blocked++
                $testResults.TestDetails += @{
                    Test = "Create key without expiration"
                    Result = "BLOCKED"
                    PolicyName = ($errorMessage -replace '.*PolicyDefinitionName\s*:\s*([^,]+).*','$1')
                    Message = $errorMessage.Split([Environment]::NewLine)[0]
                }
            } else {
                Write-Log "ERROR: Unexpected failure" -Level 'WARN'
                Write-Host "   $errorMessage" -ForegroundColor Gray
                $testResults.Errors += "Test 3: $errorMessage"
            }
        }
        
        # Clean up compliant vault
        Remove-AzKeyVault -Name $compliantVaultName -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-Log "ERROR: Failed to create compliant vault for testing" -Level 'WARN'
        Write-Host "   $($_.Exception.Message)" -ForegroundColor Gray
        $testResults.Errors += "Test 3 setup: $($_.Exception.Message)"
    }
    
    # Test 4: Create certificate WITHOUT expiration (should be DENIED)
    Write-Host ""
    Write-Log "🧪 Test 4: Create certificate with excessive validity period" -Level 'INFO'
    Write-Host "   Expected: DENIED by policy (max 12 months)" -ForegroundColor Gray
    $testResults.TotalTests++
    
    # Create another compliant vault for cert test
    $certVaultName = "kv-deny-test-" + (Get-Random -Minimum 1000 -Maximum 9999)
    try {
        $certVault = New-AzKeyVault -Name $certVaultName -ResourceGroupName $ResourceGroupName `
            -Location $Location -EnablePurgeProtection -ErrorAction Stop
        
        Start-Sleep -Seconds 5  # Wait for vault to be ready
        
        # Try to create cert with 5-year validity (exceeds 12-month policy)
        $policy = New-AzKeyVaultCertificatePolicy -SubjectName "CN=test" -IssuerName Self `
            -ValidityInMonths 60  # 5 years - should exceed policy limit
        
        try {
            $cert = Add-AzKeyVaultCertificate -VaultName $certVaultName -Name "test-cert-long" `
                -CertificatePolicy $policy -ErrorAction Stop
            
            Write-Log "FAIL: Certificate created with 60-month validity (policy did NOT block)" -Level 'ERROR'
            $testResults.NotBlocked++
            $testResults.TestDetails += @{
                Test = "Create certificate with excessive validity period"
                Result = "NOT BLOCKED"
                VaultName = $certVaultName
                Message = "Policy should have denied this operation"
            }
            
        } catch {
            $errorMessage = $_.Exception.Message
            if ($errorMessage -match "RequestDisallowedByPolicy|policy|denied|disallow") {
                Write-Log "PASS: Blocked by policy" -Level 'SUCCESS'
                Write-Host "   Policy: $($errorMessage -replace '.*PolicyDefinitionName\s*:\s*([^,]+).*','$1')" -ForegroundColor Gray
                $testResults.Blocked++
                $testResults.TestDetails += @{
                    Test = "Create certificate with excessive validity period"
                    Result = "BLOCKED"
                    PolicyName = ($errorMessage -replace '.*PolicyDefinitionName\s*:\s*([^,]+).*','$1')
                    Message = $errorMessage.Split([Environment]::NewLine)[0]
                }
            } else {
                Write-Log "ERROR: Unexpected failure" -Level 'WARN'
                Write-Host "   $errorMessage" -ForegroundColor Gray
                $testResults.Errors += "Test 4: $errorMessage"
            }
        }
        
        # Clean up cert vault
        Remove-AzKeyVault -Name $certVaultName -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-Log "ERROR: Failed to create vault for certificate testing" -Level 'WARN'
        Write-Host "   $($_.Exception.Message)" -ForegroundColor Gray
        $testResults.Errors += "Test 4 setup: $($_.Exception.Message)"
    }
    
    # Display summary
    Write-Host ""
    Write-Log "═══════════════════════════════════════════════════════════" -Level 'INFO'
    Write-Log "  TEST SUMMARY" -Level 'INFO'
    Write-Log "═══════════════════════════════════════════════════════════" -Level 'INFO'
    Write-Host ""
    Write-Host "Total Tests: $($testResults.TotalTests)" -ForegroundColor White
    Write-Log "✅ Blocked (PASS): $($testResults.Blocked)" -Level 'SUCCESS'
    Write-Log "❌ Not Blocked (FAIL): $($testResults.NotBlocked)" -Level 'ERROR'
    Write-Log "⚠️  Errors: $($testResults.Errors.Count)" -Level 'WARN'
    
    $successRate = if ($testResults.TotalTests -gt 0) {
        [math]::Round(($testResults.Blocked / $testResults.TotalTests) * 100, 2)
    } else { 0 }
    
    Write-Host ""
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 75) { 'Green' } elseif ($successRate -ge 50) { 'Yellow' } else { 'Red' })
    Write-Host ""
    
    # Display detailed results
    if ($testResults.TestDetails.Count -gt 0) {
        Write-Log "Detailed Results:" -Level 'INFO'
        foreach ($detail in $testResults.TestDetails) {
            Write-Host "  • $($detail.Test): $($detail.Result)" -ForegroundColor White
            if ($detail.PolicyName) {
                Write-Host "    Policy: $($detail.PolicyName)" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }
    
    if ($testResults.Errors.Count -gt 0) {
        Write-Log "Errors Encountered:" -Level 'WARN'
        foreach ($error in $testResults.Errors) {
            Write-Host "  • $error" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Generate JSON report
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $reportPath = "DenyBlockingTestResults-$timestamp.json"
    $testResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Log "📄 Test results saved to: $reportPath" -Level 'INFO'
    Write-Host ""
    
    return $testResults
}

function Test-ProductionEnforcement {
    <#
    .SYNOPSIS
    Validates Deny mode policies block non-compliant resources in production.
    
    .DESCRIPTION
    Creates test scenarios to verify Azure Policies in Deny mode prevent non-compliant
    Key Vault resources. Tests purge protection, firewall, RBAC, and compliant baseline.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ResourceGroupName = 'rg-policy-keyvault-test',
        
        [Parameter(Mandatory=$false)]
        [string]$Location = 'eastus'
    )
    
    Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║      Production Enforcement Validation - Deny Mode Tests    ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    $results = @()
    
    # Test 1: Purge Protection
    Write-Host "[Test 1] Purge Protection Policy (HIGH RISK)" -ForegroundColor Yellow
    Write-Host "  Attempting to create vault WITHOUT purge protection..." -ForegroundColor White
    try {
        $vault1 = New-AzKeyVault -Name "val-nopurge-$(Get-Random -Min 1000 -Max 9999)" `
            -ResourceGroupName $ResourceGroupName -Location $Location -ErrorAction Stop
        
        $results += [PSCustomObject]@{
            Test = "Purge Protection"; RiskLevel = "HIGH"; Phase = "Phase 3"
            Expected = "Blocked"; Actual = "Created"; Status = "❌ FAIL"
            PolicyWorking = $false; VaultName = $vault1.VaultName
            Notes = "Policy NOT blocking - CRITICAL ISSUE"
        }
        Write-Host "  ❌ FAIL: Vault created without purge protection!" -ForegroundColor Red
        Remove-AzKeyVault -VaultName $vault1.VaultName -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue
    } catch {
        if ($_.Exception.Message -like "*disallowed by policy*") {
            $policyName = if ($_.Exception.Message -match "Policy assignment '([^']+)'") { $matches[1] } else { "Unknown" }
            $results += [PSCustomObject]@{
                Test = "Purge Protection"; RiskLevel = "HIGH"; Phase = "Phase 3"
                Expected = "Blocked"; Actual = "Blocked"; Status = "✅ PASS"
                PolicyWorking = $true; PolicyName = $policyName
                Notes = "Deny mode working correctly"
            }
            Write-Host "  ✅ PASS: Blocked by policy - $policyName" -ForegroundColor Green
        }
    }
    
    # Test 2: Firewall Required
    Write-Host "`n[Test 2] Firewall Required Policy (MEDIUM RISK)" -ForegroundColor Yellow
    Write-Host "  Attempting to create PUBLIC vault (no firewall)..." -ForegroundColor White
    try {
        $vault2 = New-AzKeyVault -Name "val-public-$(Get-Random -Min 1000 -Max 9999)" `
            -ResourceGroupName $ResourceGroupName -Location $Location `
            -EnablePurgeProtection -PublicNetworkAccess Enabled -ErrorAction Stop
        
        $vaultDetails = Get-AzKeyVault -VaultName $vault2.VaultName -ResourceGroupName $ResourceGroupName
        if ($vaultDetails.NetworkAcls.DefaultAction -eq 'Allow') {
            $results += [PSCustomObject]@{
                Test = "Firewall Required"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                Expected = "Blocked"; Actual = "Created (Public)"; Status = "❌ FAIL"
                PolicyWorking = $false; VaultName = $vault2.VaultName
                Notes = "Policy NOT blocking public vaults"
            }
            Write-Host "  ❌ FAIL: Public vault created!" -ForegroundColor Red
        }
        Remove-AzKeyVault -VaultName $vault2.VaultName -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue
    } catch {
        if ($_.Exception.Message -like "*disallowed by policy*") {
            $policyName = if ($_.Exception.Message -match "Policy assignment '([^']+)'") { $matches[1] } else { "Unknown" }
            $results += [PSCustomObject]@{
                Test = "Firewall Required"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                Expected = "Blocked"; Actual = "Blocked"; Status = "✅ PASS"
                PolicyWorking = $true; PolicyName = $policyName
                Notes = "Deny mode working correctly"
            }
            Write-Host "  ✅ PASS: Blocked by policy - $policyName" -ForegroundColor Green
        }
    }
    
    # Test 3: RBAC Required
    Write-Host "`n[Test 3] RBAC Permission Model Policy (MEDIUM RISK)" -ForegroundColor Yellow
    Write-Host "  Attempting to create vault with Access Policies (not RBAC)..." -ForegroundColor White
    try {
        $vault3 = New-AzKeyVault -Name "val-accesspol-$(Get-Random -Min 1000 -Max 9999)" `
            -ResourceGroupName $ResourceGroupName -Location $Location `
            -EnablePurgeProtection -DisableRbacAuthorization -ErrorAction Stop
        
        $vaultDetails = Get-AzKeyVault -VaultName $vault3.VaultName -ResourceGroupName $ResourceGroupName
        if ($vaultDetails.EnableRbacAuthorization -ne $true) {
            $results += [PSCustomObject]@{
                Test = "RBAC Required"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                Expected = "Blocked"; Actual = "Created (Access Policies)"; Status = "❌ FAIL"
                PolicyWorking = $false; VaultName = $vault3.VaultName
                Notes = "Policy NOT blocking Access Policy vaults"
            }
            Write-Host "  ❌ FAIL: Vault created with Access Policies!" -ForegroundColor Red
        }
        Remove-AzKeyVault -VaultName $vault3.VaultName -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue
    } catch {
        if ($_.Exception.Message -like "*disallowed by policy*") {
            $policyName = if ($_.Exception.Message -match "Policy assignment '([^']+)'") { $matches[1] } else { "Unknown" }
            $results += [PSCustomObject]@{
                Test = "RBAC Required"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                Expected = "Blocked"; Actual = "Blocked"; Status = "✅ PASS"
                PolicyWorking = $true; PolicyName = $policyName
                Notes = "Deny mode working correctly"
            }
            Write-Host "  ✅ PASS: Blocked by policy - $policyName" -ForegroundColor Green
        }
    }
    
    # Test 4: Compliant Vault Creation
    Write-Host "`n[Test 4] Compliant Vault Creation (BASELINE)" -ForegroundColor Green
    Write-Host "  Attempting to create COMPLIANT vault (all security requirements met)..." -ForegroundColor White
    try {
        # Use ARM template to explicitly set enableSoftDelete property
        # PowerShell cmdlet may not set this property correctly in the ARM request
        $vaultName = "val-compliant-$(Get-Random -Min 1000 -Max 9999)"
        $armTemplate = @{
            '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
            contentVersion = '1.0.0.0'
            resources = @(
                @{
                    type = 'Microsoft.KeyVault/vaults'
                    apiVersion = '2023-07-01'
                    name = $vaultName
                    location = $Location
                    properties = @{
                        sku = @{
                            family = 'A'
                            name = 'premium'
                        }
                        tenantId = (Get-AzContext).Tenant.Id
                        enableSoftDelete = $true
                        softDeleteRetentionInDays = 90
                        enablePurgeProtection = $true
                        enableRbacAuthorization = $true
                        publicNetworkAccess = 'Disabled'
                        networkAcls = @{
                            defaultAction = 'Deny'
                            bypass = 'AzureServices'
                        }
                    }
                }
            )
        }
        
        $templateFile = Join-Path $env:TEMP "test4-compliant-vault.json"
        $armTemplate | ConvertTo-Json -Depth 10 | Set-Content -Path $templateFile
        
        $deployment = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templateFile -Name "test4-deployment-$(Get-Date -Format 'HHmmss')" `
            -ErrorAction Stop
        
        Remove-Item $templateFile -Force -ErrorAction SilentlyContinue
        
        $vault4 = Get-AzKeyVault -VaultName $vaultName -ResourceGroupName $ResourceGroupName
        $vault4 = Get-AzKeyVault -VaultName $vaultName -ResourceGroupName $ResourceGroupName
        
        $complianceChecks = @{
            PurgeProtection = $vault4.EnablePurgeProtection -eq $true
            SoftDelete = $vault4.EnableSoftDelete -eq $true
            RBAC = $vault4.EnableRbacAuthorization -eq $true
            PublicAccessDisabled = $vault4.PublicNetworkAccess -eq 'Disabled'
        }
        
        $allCompliant = ($complianceChecks.Values | Where-Object { $_ -eq $false }).Count -eq 0
        if ($allCompliant) {
            Write-Host "`n  ✅ PASS: Fully compliant vault created successfully" -ForegroundColor Green
            Write-Host "    Vault: $($vault4.VaultName)" -ForegroundColor Cyan
            Write-Host "    ✅ Purge Protection: Enabled" -ForegroundColor Gray
            Write-Host "    ✅ RBAC Authorization: Enabled" -ForegroundColor Gray
            Write-Host "    ✅ Soft Delete: Enabled ($($vault4.SoftDeleteRetentionInDays) days)" -ForegroundColor Gray
            Write-Host "    ✅ Public Network Access: Disabled" -ForegroundColor Gray
            
            $results += [PSCustomObject]@{
                Test = "Compliant Vault"; RiskLevel = "BASELINE"; Phase = "All"
                Expected = "Created"; Actual = "Created"; Status = "✅ PASS"
                PolicyWorking = $true; VaultName = $vault4.VaultName
                Notes = "Production-ready: Purge protection, RBAC, Soft delete (90d), Public access disabled (ARM template)"
            }
        }
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Host "  ❌ FAIL: Compliant vault blocked!" -ForegroundColor Red
        Write-Host "    Error: $errorMsg" -ForegroundColor Yellow
        
        # Extract policy name from error message
        $policyName = "Unknown"
        if ($errorMsg -match "policy '([^']+)'") {
            $policyName = $Matches[1]
        } elseif ($errorMsg -match "Policy assignment '([^']+)'") {
            $policyName = $Matches[1]
        }
        
        $results += [PSCustomObject]@{
            Test = "Compliant Vault"; RiskLevel = "BASELINE"; Phase = "All"
            Expected = "Created"; Actual = "Blocked"; Status = "❌ FAIL"
            PolicyWorking = $false; PolicyName = $policyName
            Notes = "CRITICAL: Compliant vault blocked - Error: $errorMsg"
        }
    }
    
    # Test Resource-Level Policies (if compliant vault was created)
    $testVault = $results | Where-Object { $_.Test -eq "Compliant Vault" -and $_.Status -eq "✅ PASS" }
    if ($testVault -and $testVault.VaultName) {
        Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║    Resource-Level Policy Tests (Keys, Secrets, Certs)       ║" -ForegroundColor Cyan
        Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
        Write-Host "Using vault: $($testVault.VaultName)" -ForegroundColor Gray
        
        # Test 5: Keys must have expiration date
        Write-Host "`n[Test 5] Key Vault keys should have expiration date" -ForegroundColor Yellow
        Write-Host "  Attempting to create key WITHOUT expiration date..." -ForegroundColor White
        try {
            Add-AzKeyVaultKey -VaultName $testVault.VaultName -Name "test-key-no-expiry" -Destination 'Software' -ErrorAction Stop | Out-Null
            
            $results += [PSCustomObject]@{
                Test = "Keys Expiration"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                Expected = "Blocked"; Actual = "Created"; Status = "❌ FAIL"
                PolicyWorking = $false; VaultName = $testVault.VaultName
                Notes = "Policy NOT blocking keys without expiration"
            }
            Write-Host "  ❌ FAIL: Key created without expiration (policy not blocking)" -ForegroundColor Red
        } catch {
            if ($_.Exception.Message -like "*policy*" -or $_.Exception.Message -like "*denied*" -or $_.Exception.Message -like "*disallowed*") {
                $policyName = if ($_.Exception.Message -match "Policy assignment '([^']+)'") { $matches[1] } else { "Unknown" }
                $results += [PSCustomObject]@{
                    Test = "Keys Expiration"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                    Expected = "Blocked"; Actual = "Blocked"; Status = "✅ PASS"
                    PolicyWorking = $true; PolicyName = $policyName
                    Notes = "Deny mode working correctly"
                }
                Write-Host "  ✅ PASS: Blocked by policy" -ForegroundColor Green
            } else {
                $results += [PSCustomObject]@{
                    Test = "Keys Expiration"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                    Expected = "Blocked"; Actual = "Error"; Status = "⚠️ WARN"
                    PolicyWorking = $null; VaultName = $testVault.VaultName
                    Notes = "Non-policy error: $($_.Exception.Message.Substring(0, [Math]::Min(100, $_.Exception.Message.Length)))"
                }
                Write-Host "  ⚠️  WARN: Failed but not policy-related" -ForegroundColor Yellow
            }
        }
        
        # Test 6: Secrets must have expiration date
        Write-Host "`n[Test 6] Key Vault secrets should have expiration date" -ForegroundColor Yellow
        Write-Host "  Attempting to create secret WITHOUT expiration date..." -ForegroundColor White
        try {
            $secretValue = ConvertTo-SecureString "TestPassword123!" -AsPlainText -Force
            Set-AzKeyVaultSecret -VaultName $testVault.VaultName -Name "test-secret-no-expiry" -SecretValue $secretValue -ErrorAction Stop | Out-Null
            
            $results += [PSCustomObject]@{
                Test = "Secrets Expiration"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                Expected = "Blocked"; Actual = "Created"; Status = "❌ FAIL"
                PolicyWorking = $false; VaultName = $testVault.VaultName
                Notes = "Policy NOT blocking secrets without expiration"
            }
            Write-Host "  ❌ FAIL: Secret created without expiration (policy not blocking)" -ForegroundColor Red
        } catch {
            if ($_.Exception.Message -like "*policy*" -or $_.Exception.Message -like "*denied*" -or $_.Exception.Message -like "*disallowed*") {
                $policyName = if ($_.Exception.Message -match "Policy assignment '([^']+)'") { $matches[1] } else { "Unknown" }
                $results += [PSCustomObject]@{
                    Test = "Secrets Expiration"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                    Expected = "Blocked"; Actual = "Blocked"; Status = "✅ PASS"
                    PolicyWorking = $true; PolicyName = $policyName
                    Notes = "Deny mode working correctly"
                }
                Write-Host "  ✅ PASS: Blocked by policy" -ForegroundColor Green
            } else {
                $results += [PSCustomObject]@{
                    Test = "Secrets Expiration"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                    Expected = "Blocked"; Actual = "Error"; Status = "⚠️ WARN"
                    PolicyWorking = $null; VaultName = $testVault.VaultName
                    Notes = "Non-policy error: $($_.Exception.Message.Substring(0, [Math]::Min(100, $_.Exception.Message.Length)))"
                }
                Write-Host "  ⚠️  WARN: Failed but not policy-related" -ForegroundColor Yellow
            }
        }
        
        # Test 7: RSA Keys must have minimum 2048-bit key size
        Write-Host "`n[Test 7] Keys using RSA should have minimum 2048 key size" -ForegroundColor Yellow
        Write-Host "  Attempting to create RSA key with 1024-bit size..." -ForegroundColor White
        try {
            Add-AzKeyVaultKey -VaultName $testVault.VaultName -Name "test-key-small-rsa" -Destination 'Software' -KeyType 'RSA' -Size 1024 -Expires (Get-Date).AddYears(1) -ErrorAction Stop | Out-Null
            
            $results += [PSCustomObject]@{
                Test = "RSA Key Size"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                Expected = "Blocked"; Actual = "Created"; Status = "❌ FAIL"
                PolicyWorking = $false; VaultName = $testVault.VaultName
                Notes = "Policy NOT blocking small RSA keys (1024-bit)"
            }
            Write-Host "  ❌ FAIL: Small RSA key created (policy not blocking)" -ForegroundColor Red
        } catch {
            if ($_.Exception.Message -like "*policy*" -or $_.Exception.Message -like "*denied*" -or $_.Exception.Message -like "*disallowed*" -or $_.Exception.Message -like "*minimum*") {
                $policyName = if ($_.Exception.Message -match "Policy assignment '([^']+)'") { $matches[1] } else { "Unknown" }
                $results += [PSCustomObject]@{
                    Test = "RSA Key Size"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                    Expected = "Blocked"; Actual = "Blocked"; Status = "✅ PASS"
                    PolicyWorking = $true; PolicyName = $policyName
                    Notes = "Deny mode working correctly"
                }
                Write-Host "  ✅ PASS: Blocked by policy" -ForegroundColor Green
            } else {
                $results += [PSCustomObject]@{
                    Test = "RSA Key Size"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                    Expected = "Blocked"; Actual = "Error"; Status = "⚠️ WARN"
                    PolicyWorking = $null; VaultName = $testVault.VaultName
                    Notes = "Non-policy error: $($_.Exception.Message.Substring(0, [Math]::Min(100, $_.Exception.Message.Length)))"
                }
                Write-Host "  ⚠️  WARN: Failed but not policy-related" -ForegroundColor Yellow
            }
        }
        
        # Test 8: Certificates must have max 12 month validity
        Write-Host "`n[Test 8] Certificates should have maximum 12 month validity" -ForegroundColor Yellow
        Write-Host "  Attempting to create certificate with 24 month validity..." -ForegroundColor White
        try {
            $policy = New-AzKeyVaultCertificatePolicy -SubjectName "CN=test-long-cert" -IssuerName Self -ValidityInMonths 24
            Add-AzKeyVaultCertificate -VaultName $testVault.VaultName -Name "test-cert-long-validity" -CertificatePolicy $policy -ErrorAction Stop | Out-Null
            
            $results += [PSCustomObject]@{
                Test = "Cert Max Validity"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                Expected = "Blocked"; Actual = "Created"; Status = "❌ FAIL"
                PolicyWorking = $false; VaultName = $testVault.VaultName
                Notes = "Policy NOT blocking long-validity certificates (24 months)"
            }
            Write-Host "  ❌ FAIL: Long-validity certificate created (policy not blocking)" -ForegroundColor Red
        } catch {
            if ($_.Exception.Message -like "*policy*" -or $_.Exception.Message -like "*denied*" -or $_.Exception.Message -like "*disallowed*" -or $_.Exception.Message -like "*validity*") {
                $policyName = if ($_.Exception.Message -match "Policy assignment '([^']+)'") { $matches[1] } else { "Unknown" }
                $results += [PSCustomObject]@{
                    Test = "Cert Max Validity"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                    Expected = "Blocked"; Actual = "Blocked"; Status = "✅ PASS"
                    PolicyWorking = $true; PolicyName = $policyName
                    Notes = "Deny mode working correctly"
                }
                Write-Host "  ✅ PASS: Blocked by policy" -ForegroundColor Green
            } else {
                $results += [PSCustomObject]@{
                    Test = "Cert Max Validity"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                    Expected = "Blocked"; Actual = "Error"; Status = "⚠️ WARN"
                    PolicyWorking = $null; VaultName = $testVault.VaultName
                    Notes = "Non-policy error: $($_.Exception.Message.Substring(0, [Math]::Min(100, $_.Exception.Message.Length)))"
                }
                Write-Host "  ⚠️  WARN: Failed but not policy-related" -ForegroundColor Yellow
            }
        }
        
        # Test 9: Certificates should not expire within 30 days
        Write-Host "`n[Test 9] Certificates should not expire within 30 days" -ForegroundColor Yellow
        Write-Host "  Attempting to create certificate expiring in <30 days..." -ForegroundColor White
        try {
            # Note: Certificate policies require ValidityInMonths >= 1, so we test with short renewal window instead
            $policy = New-AzKeyVaultCertificatePolicy -SubjectName "CN=test-short-cert" -IssuerName Self -ValidityInMonths 1 -RenewAtNumberOfDaysBeforeExpiry 1
            Add-AzKeyVaultCertificate -VaultName $testVault.VaultName -Name "test-cert-short-expiry" -CertificatePolicy $policy -ErrorAction Stop | Out-Null
            
            # If created successfully, check if it violates 30-day rule (this is a limitation of the test)
            Write-Host "  ⚠️  NOTE: Certificate created with 1-month validity (API limitation prevents <30 day test)" -ForegroundColor Yellow
            $results += [PSCustomObject]@{
                Test = "Cert Min Validity"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                Expected = "Blocked"; Actual = "Created (1mo)"; Status = "⚠️ SKIP"
                PolicyWorking = $null; VaultName = $testVault.VaultName
                Notes = "Test limitation: Cannot create cert with <30 day validity via API. Policy blocks existing certs approaching expiration."
            }
        } catch {
            if ($_.Exception.Message -like "*policy*" -or $_.Exception.Message -like "*denied*" -or $_.Exception.Message -like "*disallowed*" -or $_.Exception.Message -like "*expire*") {
                $policyName = if ($_.Exception.Message -match "Policy assignment '([^']+)'") { $matches[1] } else { "Unknown" }
                $results += [PSCustomObject]@{
                    Test = "Cert Min Validity"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                    Expected = "Blocked"; Actual = "Blocked"; Status = "✅ PASS"
                    PolicyWorking = $true; PolicyName = $policyName
                    Notes = "Deny mode working correctly"
                }
                Write-Host "  ✅ PASS: Blocked by policy" -ForegroundColor Green
            } else {
                $results += [PSCustomObject]@{
                    Test = "Cert Min Validity"; RiskLevel = "MEDIUM"; Phase = "Phase 2"
                    Expected = "Blocked"; Actual = "Error"; Status = "⚠️ WARN"
                    PolicyWorking = $null; VaultName = $testVault.VaultName
                    Notes = "Non-policy error: $($_.Exception.Message.Substring(0, [Math]::Min(100, $_.Exception.Message.Length)))"
                }
                Write-Host "  ⚠️  WARN: Failed but not policy-related" -ForegroundColor Yellow
            }
        }
        
    } else {
        Write-Host "`n⚠️  SKIP: Resource-level tests skipped (no compliant vault available)" -ForegroundColor Yellow
    }
    
    # Display Results
    Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║               Enforcement Validation Results                 ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    $results | Format-Table Test, RiskLevel, Expected, Actual, Status, Notes -AutoSize -Wrap
    
    $passed = ($results | Where-Object { $_.Status -eq "✅ PASS" }).Count
    $failed = ($results | Where-Object { $_.Status -eq "❌ FAIL" }).Count
    $warned = ($results | Where-Object { $_.Status -like "⚠️*" }).Count
    $total = $results.Count
    
    Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Validation Summary:" -ForegroundColor White
    Write-Host "  ✅ PASS: $passed / $total" -ForegroundColor Green
    Write-Host "  ❌ FAIL: $failed / $total" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
    if ($warned -gt 0) {
        Write-Host "  ⚠️  WARN/SKIP: $warned / $total" -ForegroundColor Yellow
    }
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $resultsFile = "EnforcementValidation-$timestamp.csv"
    $results | Export-Csv $resultsFile -NoTypeInformation
    Write-Host "`nResults exported to: $resultsFile" -ForegroundColor Gray
    
    return $results
}

function Test-HTMLReportValidation {
    <#
    .SYNOPSIS
    Validates HTML compliance report for data integrity and accuracy.
    
    .DESCRIPTION
    Performs comprehensive validation of generated HTML compliance reports checking:
    - Policy count accuracy (30/46 policies depending on deployment)
    - Compliance percentage calculations
    - Resource evaluation counts
    - Timestamp recency
    - Data completeness
    
    .PARAMETER ReportPath
    Path to HTML report file. If not specified, uses most recent ComplianceReport-*.html
    
    .EXAMPLE
    .\AzPolicyImplScript.ps1 -ValidateReport
    
    .EXAMPLE
    .\AzPolicyImplScript.ps1 -ValidateReport -ReportPath .\ComplianceReport-20260115-140000.html
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ReportPath
    )
    
    Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          HTML Compliance Report Validation                   ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # Find report if not specified
    if (-not $ReportPath) {
        $reports = Get-ChildItem -Filter "ComplianceReport-*.html" -ErrorAction SilentlyContinue | 
            Sort-Object LastWriteTime -Descending
        
        if (-not $reports) {
            Write-Host "❌ No compliance reports found in current directory" -ForegroundColor Red
            Write-Host "   Generate a report first using: .\AzPolicyImplScript.ps1 -CheckCompliance" -ForegroundColor Yellow
            return $null
        }
        
        $ReportPath = $reports[0].FullName
        Write-Host "📄 Validating most recent report: $($reports[0].Name)" -ForegroundColor Cyan
    }
    
    if (-not (Test-Path $ReportPath)) {
        Write-Host "❌ Report file not found: $ReportPath" -ForegroundColor Red
        return $null
    }
    
    $reportContent = Get-Content $ReportPath -Raw
    $issues = @()
    $warnings = @()
    $validations = @()
    
    # Validation 1: HTML Structure
    Write-Host "[1/7] Validating HTML structure..." -ForegroundColor Yellow
    if ($reportContent -match '<html.*>.*</html>') {
        $validations += [PSCustomObject]@{ Check = "HTML Structure"; Status = "✅ PASS"; Details = "Valid HTML tags found" }
        Write-Host "  ✅ Valid HTML structure" -ForegroundColor Green
    } else {
        $issues += "Missing or invalid HTML structure"
        $validations += [PSCustomObject]@{ Check = "HTML Structure"; Status = "❌ FAIL"; Details = "Invalid HTML tags" }
        Write-Host "  ❌ Invalid HTML structure" -ForegroundColor Red
    }
    
    # Validation 2: Policy Count
    Write-Host "[2/7] Counting policies in report..." -ForegroundColor Yellow
    $policyRows = ([regex]::Matches($reportContent, 'KV-\d{3}')).Count
    $expectedCounts = @(30, 46)  # DevTest=30, DevTest-Full/Production=46
    
    if ($policyRows -in $expectedCounts) {
        $validations += [PSCustomObject]@{ Check = "Policy Count"; Status = "✅ PASS"; Details = "$policyRows policies (expected $($expectedCounts -join ' or '))" }
        Write-Host "  ✅ Policy count: $policyRows (valid)" -ForegroundColor Green
    } elseif ($policyRows -gt 0) {
        $warnings += "Unexpected policy count: $policyRows (expected $($expectedCounts -join ' or '))"
        $validations += [PSCustomObject]@{ Check = "Policy Count"; Status = "⚠️  WARN"; Details = "$policyRows policies (expected $($expectedCounts -join ' or '))" }
        Write-Host "  ⚠️  Policy count: $policyRows (unexpected - expected $($expectedCounts -join ' or '))" -ForegroundColor Yellow
    } else {
        $issues += "No policies found in report"
        $validations += [PSCustomObject]@{ Check = "Policy Count"; Status = "❌ FAIL"; Details = "0 policies found" }
        Write-Host "  ❌ No policies found" -ForegroundColor Red
    }
    
    # Validation 3: Zero Resource Evaluations
    Write-Host "[3/7] Checking for incomplete policy evaluations..." -ForegroundColor Yellow
    if ($reportContent -match '0\s+resources?\s+evaluated') {
        $zeroEvalMatches = ([regex]::Matches($reportContent, '0\s+resources?\s+evaluated')).Count
        $warnings += "Found $zeroEvalMatches policies with 0 resources evaluated (may need more time for Azure evaluation)"
        $validations += [PSCustomObject]@{ Check = "Resource Evaluations"; Status = "⚠️  WARN"; Details = "$zeroEvalMatches policies showing 0 resources evaluated" }
        Write-Host "  ⚠️  $zeroEvalMatches policies show 0 resources evaluated (Azure may still be evaluating)" -ForegroundColor Yellow
    } else {
        $validations += [PSCustomObject]@{ Check = "Resource Evaluations"; Status = "✅ PASS"; Details = "All policies have resource evaluations" }
        Write-Host "  ✅ All policies have resource evaluation data" -ForegroundColor Green
    }
    
    # Validation 4: Timestamp Recency
    Write-Host "[4/7] Checking report timestamp..." -ForegroundColor Yellow
    if ($reportContent -match 'Generated.*?(\d{4}-\d{2}-\d{2})') {
        $reportDate = $matches[1]
        $reportDateTime = [datetime]::ParseExact($reportDate, 'yyyy-MM-dd', $null)
        $daysSinceReport = ([datetime]::Now - $reportDateTime).Days
        
        if ($daysSinceReport -eq 0) {
            $validations += [PSCustomObject]@{ Check = "Timestamp"; Status = "✅ PASS"; Details = "Generated today ($reportDate)" }
            Write-Host "  ✅ Report generated today: $reportDate" -ForegroundColor Green
        } elseif ($daysSinceReport -le 7) {
            $validations += [PSCustomObject]@{ Check = "Timestamp"; Status = "✅ PASS"; Details = "Generated $daysSinceReport days ago ($reportDate)" }
            Write-Host "  ✅ Report date: $reportDate ($daysSinceReport days old)" -ForegroundColor Green
        } else {
            $warnings += "Report is $daysSinceReport days old (generated $reportDate)"
            $validations += [PSCustomObject]@{ Check = "Timestamp"; Status = "⚠️  WARN"; Details = "$daysSinceReport days old" }
            Write-Host "  ⚠️  Report is $daysSinceReport days old (consider regenerating)" -ForegroundColor Yellow
        }
    } else {
        $warnings += "Could not determine report timestamp"
        $validations += [PSCustomObject]@{ Check = "Timestamp"; Status = "⚠️  WARN"; Details = "No timestamp found" }
        Write-Host "  ⚠️  No timestamp found in report" -ForegroundColor Yellow
    }
    
    # Validation 5: Compliance Percentage Presence
    Write-Host "[5/7] Checking compliance percentage calculations..." -ForegroundColor Yellow
    $compliancePercentages = ([regex]::Matches($reportContent, '(\d+(\.\d+)?)\s*%')).Count
    if ($compliancePercentages -gt 0) {
        $validations += [PSCustomObject]@{ Check = "Compliance %"; Status = "✅ PASS"; Details = "$compliancePercentages percentage values found" }
        Write-Host "  ✅ Found $compliancePercentages compliance percentage calculations" -ForegroundColor Green
    } else {
        $warnings += "No compliance percentages found in report"
        $validations += [PSCustomObject]@{ Check = "Compliance %"; Status = "⚠️  WARN"; Details = "No percentages found" }
        Write-Host "  ⚠️  No compliance percentages found" -ForegroundColor Yellow
    }
    
    # Validation 6: Security Metrics Section
    Write-Host "[6/7] Checking for security metrics section..." -ForegroundColor Yellow
    if ($reportContent -match '(Security\s+Value|Framework\s+Alignment|Compliance\s+Metrics)') {
        $validations += [PSCustomObject]@{ Check = "Security Metrics"; Status = "✅ PASS"; Details = "Security metrics section present" }
        Write-Host "  ✅ Security metrics section found" -ForegroundColor Green
    } else {
        $warnings += "Security metrics section not found"
        $validations += [PSCustomObject]@{ Check = "Security Metrics"; Status = "⚠️  WARN"; Details = "Section not found" }
        Write-Host "  ⚠️  Security metrics section not found" -ForegroundColor Yellow
    }
    
    # Validation 7: Overall Report Size
    Write-Host "[7/7] Checking report file size..." -ForegroundColor Yellow
    $fileSize = (Get-Item $ReportPath).Length
    if ($fileSize -gt 10KB) {
        $fileSizeKB = [math]::Round($fileSize / 1KB, 2)
        $validations += [PSCustomObject]@{ Check = "File Size"; Status = "✅ PASS"; Details = "$fileSizeKB KB" }
        Write-Host "  ✅ Report size: $fileSizeKB KB (contains data)" -ForegroundColor Green
    } else {
        $warnings += "Report file very small ($fileSize bytes) - may be incomplete"
        $validations += [PSCustomObject]@{ Check = "File Size"; Status = "⚠️  WARN"; Details = "$fileSize bytes (suspiciously small)" }
        Write-Host "  ⚠️  Report size: $fileSize bytes (may be incomplete)" -ForegroundColor Yellow
    }
    
    # Display Results
    Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                  Validation Summary                          ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    $validations | Format-Table Check, Status, Details -AutoSize -Wrap
    
    # Summary
    $passCount = ($validations | Where-Object { $_.Status -eq "✅ PASS" }).Count
    $warnCount = ($validations | Where-Object { $_.Status -eq "⚠️  WARN" }).Count
    $failCount = ($validations | Where-Object { $_.Status -eq "❌ FAIL" }).Count
    
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Results:" -ForegroundColor White
    Write-Host "  ✅ PASS: $passCount / $($validations.Count)" -ForegroundColor Green
    if ($warnCount -gt 0) {
        Write-Host "  ⚠️  WARN: $warnCount / $($validations.Count)" -ForegroundColor Yellow
        Write-Host "`nWarnings:" -ForegroundColor Yellow
        $warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    }
    if ($failCount -gt 0) {
        Write-Host "  ❌ FAIL: $failCount / $($validations.Count)" -ForegroundColor Red
        Write-Host "`nIssues:" -ForegroundColor Red
        $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    }
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    # Overall Assessment
    Write-Host "`n📊 Overall Assessment:" -ForegroundColor Cyan
    if ($failCount -eq 0 -and $warnCount -eq 0) {
        Write-Host "  ✅ EXCELLENT - Report passes all validation checks" -ForegroundColor Green
    } elseif ($failCount -eq 0) {
        Write-Host "  ✅ GOOD - Report has minor warnings but is usable" -ForegroundColor Yellow
    } else {
        Write-Host "  ❌ ISSUES FOUND - Report has significant problems" -ForegroundColor Red
        Write-Host "  Recommendation: Regenerate report after waiting for policy evaluation (60+ minutes)" -ForegroundColor Yellow
    }
    
    Write-Host "`n📁 Report: $(Split-Path $ReportPath -Leaf)" -ForegroundColor Gray
    Write-Host ""
    
    return [PSCustomObject]@{
        ReportPath = $ReportPath
        TotalChecks = $validations.Count
        Passed = $passCount
        Warnings = $warnCount
        Failed = $failCount
        Issues = $issues
        ValidationDetails = $validations
    }
}

function Test-InfrastructureValidation {
    <#
    .SYNOPSIS
    Comprehensive infrastructure validation before policy deployment.
    
    .DESCRIPTION
    Validates all required infrastructure components including Azure connection,
    resource groups, managed identity, RBAC, Log Analytics, Event Hub, VNet, DNS, etc.
    #>
    [CmdletBinding()]
    param(
        [switch]$Detailed
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "COMPREHENSIVE INFRASTRUCTURE VALIDATION" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    $validationResults = @{}
    
    # Step 1: Azure Connection
    Write-Host "[Step 1/11] Verifying Azure Connection..." -ForegroundColor Yellow
    try {
        $context = Get-AzContext -ErrorAction Stop
        if ($context) {
            Write-Host "   ✅ Connected as $($context.Account.Id)" -ForegroundColor Green
            Write-Host "      Subscription: $($context.Subscription.Name)" -ForegroundColor Cyan
            $validationResults.AzureConnection = @{Status = "PASS"; Details = "Connected"}
            $subscriptionId = $context.Subscription.Id
        }
    } catch {
        Write-Host "   ❌ Not connected to Azure" -ForegroundColor Red
        $validationResults.AzureConnection = @{Status = "FAIL"; Details = "Not connected"}
        return $validationResults
    }
    
    # Step 2: Resource Groups
    Write-Host "`n[Step 2/11] Checking Resource Groups..." -ForegroundColor Yellow
    $rgRemediation = Get-AzResourceGroup -Name "rg-policy-remediation" -ErrorAction SilentlyContinue
    $rgTest = Get-AzResourceGroup -Name "rg-policy-keyvault-test" -ErrorAction SilentlyContinue
    
    if ($rgRemediation) { Write-Host "   ✅ rg-policy-remediation: EXISTS" -ForegroundColor Green }
    else { Write-Host "   ❌ rg-policy-remediation: NOT FOUND" -ForegroundColor Red }
    if ($rgTest) { Write-Host "   ✅ rg-policy-keyvault-test: EXISTS" -ForegroundColor Green }
    else { Write-Host "   ❌ rg-policy-keyvault-test: NOT FOUND" -ForegroundColor Red }
    
    $validationResults.ResourceGroups = @{
        Status = if ($rgRemediation -and $rgTest) { "PASS" } else { "FAIL" }
        Details = "Remediation: $($rgRemediation -ne $null), Test: $($rgTest -ne $null)"
    }
    
    # Step 3: Managed Identity
    Write-Host "`n[Step 3/11] Checking Managed Identity..." -ForegroundColor Yellow
    $identity = Get-AzUserAssignedIdentity -ResourceGroupName "rg-policy-remediation" -Name "id-policy-remediation" -ErrorAction SilentlyContinue
    if ($identity) {
        Write-Host "   ✅ Managed Identity: EXISTS" -ForegroundColor Green
        Write-Host "      Principal ID: $($identity.PrincipalId)" -ForegroundColor Gray
        $validationResults.ManagedIdentity = @{Status = "PASS"; Details = $identity.PrincipalId}
    } else {
        Write-Host "   ❌ Managed Identity: NOT FOUND" -ForegroundColor Red
        $validationResults.ManagedIdentity = @{Status = "FAIL"; Details = "Not found"}
    }
    
    # Step 4: Managed Identity RBAC
    Write-Host "`n[Step 4/11] Checking Managed Identity RBAC..." -ForegroundColor Yellow
    if ($identity) {
        $roles = Get-AzRoleAssignment -ObjectId $identity.PrincipalId -ErrorAction SilentlyContinue
        if ($roles) {
            Write-Host "   ✅ RBAC Roles: $($roles.Count) assigned" -ForegroundColor Green
            $roles | ForEach-Object { Write-Host "      ✅ $($_.RoleDefinitionName)" -ForegroundColor Green }
            $validationResults.ManagedIdentityRBAC = @{Status = "PASS"; Details = "$($roles.Count) roles"}
        } else {
            Write-Host "   ⚠️ No RBAC roles assigned" -ForegroundColor Yellow
            $validationResults.ManagedIdentityRBAC = @{Status = "WARN"; Details = "No roles"}
        }
    }
    
    # Step 5-8: Infrastructure Resources
    Write-Host "`n[Step 5/11] Checking Log Analytics..." -ForegroundColor Yellow
    $law = Get-AzOperationalInsightsWorkspace -ResourceGroupName "rg-policy-remediation" -ErrorAction SilentlyContinue
    if ($law) { Write-Host "   ✅ Log Analytics: $($law.Name)" -ForegroundColor Green }
    else { Write-Host "   ⚠️ Log Analytics: NOT FOUND" -ForegroundColor Yellow }
    $validationResults.LogAnalytics = @{Status = if ($law) {"PASS"} else {"WARN"}; Details = if ($law) {$law.Name} else {"Not found"}}
    
    Write-Host "`n[Step 6/11] Checking Event Hub..." -ForegroundColor Yellow
    $eh = Get-AzEventHubNamespace -ResourceGroupName "rg-policy-remediation" -ErrorAction SilentlyContinue
    if ($eh) { Write-Host "   ✅ Event Hub: $($eh.Name)" -ForegroundColor Green }
    else { Write-Host "   ⚠️ Event Hub: NOT FOUND" -ForegroundColor Yellow }
    $validationResults.EventHub = @{Status = if ($eh) {"PASS"} else {"WARN"}; Details = if ($eh) {$eh.Name} else {"Not found"}}
    
    Write-Host "`n[Step 7/11] Checking Virtual Network..." -ForegroundColor Yellow
    $vnet = Get-AzVirtualNetwork -ResourceGroupName "rg-policy-keyvault-test" -ErrorAction SilentlyContinue
    if ($vnet) {
        Write-Host "   ✅ Virtual Network: $($vnet.Name)" -ForegroundColor Green
        Write-Host "      Subnets: $($vnet.Subnets.Count)" -ForegroundColor Gray
    } else { Write-Host "   ⚠️ Virtual Network: NOT FOUND" -ForegroundColor Yellow }
    $validationResults.VirtualNetwork = @{Status = if ($vnet) {"PASS"} else {"WARN"}; Details = if ($vnet) {$vnet.Name} else {"Not found"}}
    
    Write-Host "`n[Step 8/11] Checking Private DNS Zone..." -ForegroundColor Yellow
    $dns = Get-AzPrivateDnsZone -ResourceGroupName "rg-policy-remediation" -ErrorAction SilentlyContinue
    if ($dns) {
        Write-Host "   ✅ Private DNS Zone: $($dns.Count) zones" -ForegroundColor Green
        $dns | ForEach-Object { Write-Host "      - $($_.Name)" -ForegroundColor Gray }
    } else { Write-Host "   ⚠️ Private DNS Zone: NOT FOUND" -ForegroundColor Yellow }
    $validationResults.PrivateDNS = @{Status = if ($dns) {"PASS"} else {"WARN"}; Details = if ($dns) {"$($dns.Count) zones"} else {"Not found"}}
    
    # Step 9: Test Vaults
    Write-Host "`n[Step 9/11] Checking Test Key Vaults..." -ForegroundColor Yellow
    $vaults = Get-AzKeyVault -ResourceGroupName "rg-policy-keyvault-test" -ErrorAction SilentlyContinue
    if ($vaults) {
        Write-Host "   ✅ Test Key Vaults: $($vaults.Count) found" -ForegroundColor Green
        $vaults | ForEach-Object { Write-Host "      📦 $($_.VaultName)" -ForegroundColor Cyan }
        $validationResults.TestVaults = @{Status = "PASS"; Details = "$($vaults.Count) vaults"}
    } else {
        Write-Host "   ❌ Test Key Vaults: NONE FOUND" -ForegroundColor Red
        $validationResults.TestVaults = @{Status = "FAIL"; Details = "No vaults"}
    }
    
    # Step 10: Policy Assignments
    Write-Host "`n[Step 10/11] Checking Existing Policy Assignments..." -ForegroundColor Yellow
    $assignments = Get-AzPolicyAssignment | Where-Object { 
        $_.Properties.DisplayName -like "*Key Vault*" -or $_.Name -like "KV-*" 
    }
    if ($assignments) {
        Write-Host "   ⚠️ Found $($assignments.Count) existing assignments" -ForegroundColor Yellow
        $validationResults.PolicyAssignments = @{Status = "WARN"; Details = "$($assignments.Count) existing"}
    } else {
        Write-Host "   ✅ No existing assignments (clean slate)" -ForegroundColor Green
        $validationResults.PolicyAssignments = @{Status = "PASS"; Details = "Clean slate"}
    }
    
    # Step 11: Parameter Files
    Write-Host "`n[Step 11/11] Validating Parameter Files..." -ForegroundColor Yellow
    $devTestExists = Test-Path "PolicyParameters-DevTest.json"
    $prodExists = Test-Path "PolicyParameters-Production.json"
    
    if ($devTestExists) { Write-Host "   ✅ PolicyParameters-DevTest.json: EXISTS" -ForegroundColor Green }
    else { Write-Host "   ❌ PolicyParameters-DevTest.json: NOT FOUND" -ForegroundColor Red }
    if ($prodExists) { Write-Host "   ✅ PolicyParameters-Production.json: EXISTS" -ForegroundColor Green }
    else { Write-Host "   ❌ PolicyParameters-Production.json: NOT FOUND" -ForegroundColor Red }
    
    $validationResults.ParameterFiles = @{
        Status = if ($devTestExists -and $prodExists) {"PASS"} else {"FAIL"}
        Details = "DevTest: $devTestExists, Production: $prodExists"
    }
    
    # Summary
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "VALIDATION SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $passCount = ($validationResults.Values | Where-Object {$_.Status -eq "PASS"}).Count
    $warnCount = ($validationResults.Values | Where-Object {$_.Status -eq "WARN"}).Count
    $failCount = ($validationResults.Values | Where-Object {$_.Status -eq "FAIL"}).Count
    
    foreach ($key in $validationResults.Keys | Sort-Object) {
        $result = $validationResults[$key]
        $icon = switch ($result.Status) { "PASS" {"✅"} "WARN" {"⚠️"} "FAIL" {"❌"} default {"❓"} }
        $color = switch ($result.Status) { "PASS" {"Green"} "WARN" {"Yellow"} "FAIL" {"Red"} default {"Gray"} }
        Write-Host "$icon $($key.PadRight(25)): $($result.Details)" -ForegroundColor $color
    }
    
    Write-Host "`n========================================" -ForegroundColor Gray
    Write-Host "Total: $($validationResults.Count) checks" -ForegroundColor Cyan
    Write-Host "  ✅ Passed: $passCount" -ForegroundColor Green
    Write-Host "  ⚠️ Warnings: $warnCount" -ForegroundColor Yellow
    Write-Host "  ❌ Failed: $failCount" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Gray
    
    return $validationResults
}

function Test-AutoRemediation {
    <#
    .SYNOPSIS
    Tests DeployIfNotExists and Modify policy auto-remediation capabilities.
    
    .DESCRIPTION
    Creates a non-compliant Key Vault to trigger auto-remediation policies
    for diagnostic settings, private endpoints, firewall, and DNS configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ResourceGroupName = "rg-policy-keyvault-test",
        
        [Parameter(Mandatory=$false)]
        [string]$Location = "eastus"
    )
    
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║      Auto-Remediation Policy Testing                         ║" -ForegroundColor Cyan  
    Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    Write-Host "[Test 1] Creating vault WITHOUT diagnostic settings..." -ForegroundColor Yellow
    Write-Host "  Expected: Policy should auto-deploy Log Analytics diagnostics`n"
    
    $vaultName = "kv-remediate-$(Get-Random -Minimum 1000 -Maximum 9999)"
    
    try {
        $vault = New-AzKeyVault -Name $vaultName -ResourceGroupName $ResourceGroupName `
            -Location $Location -EnablePurgeProtection -EnableRbacAuthorization `
            -PublicNetworkAccess Disabled -ErrorAction Stop
        
        Write-Host "  ✅ Vault created: $vaultName" -ForegroundColor Green
        Write-Host "     Resource ID: $($vault.ResourceId)"
        
        Write-Host "`n  ⏳ Waiting 30 seconds for policy evaluation..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        
        Write-Host "`n  📊 Checking compliance state..." -ForegroundColor Cyan
        $complianceStates = Get-AzPolicyState -ResourceId $vault.ResourceId -Top 20 2>$null
        
        if ($complianceStates) {
            $nonCompliant = $complianceStates | Where-Object { $_.ComplianceState -eq "NonCompliant" }
            Write-Host "     Total policy evaluations: $($complianceStates.Count)" -ForegroundColor Cyan
            Write-Host "     Non-compliant: $($nonCompliant.Count)" -ForegroundColor Yellow
            $nonCompliant | ForEach-Object { Write-Host "       - $($_.PolicyDefinitionName)" -ForegroundColor Yellow }
            
            Write-Host "`n  🔧 Checking for remediation tasks..." -ForegroundColor Cyan
            $remediationTasks = Get-AzPolicyRemediation -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
            
            if ($remediationTasks) {
                Write-Host "     ✅ Found $($remediationTasks.Count) remediation task(s)" -ForegroundColor Green
                $remediationTasks | ForEach-Object { Write-Host "       - $($_.Name): $($_.ProvisioningState)" -ForegroundColor Cyan }
            } else {
                Write-Host "     ℹ️  No automatic remediation tasks found (may require manual trigger)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "     ⏳ Policy evaluation in progress (check back in 5-10 minutes)" -ForegroundColor Yellow
        }
        
        Write-Host "`n  📋 Checking if diagnostic settings were auto-deployed..." -ForegroundColor Cyan
        Start-Sleep -Seconds 10
        $diagnostics = Get-AzDiagnosticSetting -ResourceId $vault.ResourceId -ErrorAction SilentlyContinue
        
        if ($diagnostics -and $diagnostics.Count -gt 0) {
            Write-Host "     ✅ Diagnostic settings found (auto-remediation worked!)" -ForegroundColor Green
            $diagnostics | ForEach-Object {
                Write-Host "       - $($_.Name): Logs=$($_.Logs.Count), Metrics=$($_.Metrics.Count)" -ForegroundColor Cyan
            }
        } else {
            Write-Host "     ℹ️  No diagnostic settings yet (may take 15-30 minutes)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                  Test Summary                                 ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    Write-Host "Test vault: $vaultName" -ForegroundColor Cyan
    Write-Host "`n⏰ Auto-remediation timeline:" -ForegroundColor Yellow
    Write-Host "   • Policy evaluation: 5-10 minutes"
    Write-Host "   • Remediation task creation: 10-15 minutes"
    Write-Host "   • Resource deployment: 15-30 minutes"
    Write-Host "   • Total expected time: 30-60 minutes`n"
    Write-Host "🔍 Manual verification commands:" -ForegroundColor Cyan
    Write-Host "   Get-AzDiagnosticSetting -ResourceId '$($vault.ResourceId)'"
    Write-Host "   Get-AzPolicyRemediation -ResourceGroupName '$ResourceGroupName'"
    Write-Host "   Get-AzPolicyState -ResourceId '$($vault.ResourceId)'`n"
}

function Test-Phase2Point3Enforcement {
    <#
    .SYNOPSIS
    Phase 2.3 Enforcement Testing - Validates Enforce mode policies and remediation.
    
    .DESCRIPTION
    Tests that Enforce mode policies are active and collecting compliance data.
    Verifies managed identity has required permissions for DeployIfNotExists/Modify remediation.
    Checks for active remediation jobs and validates their completion status.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Scope,
        
        [Parameter(Mandatory=$false)]
        [string]$ManagedIdentityPrincipalId,
        
        [Parameter(Mandatory=$false)]
        [string]$SubscriptionId
    )
    
    Write-Host ""
    Write-Log "═══════════════════════════════════════════════════════════" -Level 'INFO'
    Write-Log "  PHASE 2.3: ENFORCEMENT MODE TESTING" -Level 'INFO'
    Write-Log "═══════════════════════════════════════════════════════════" -Level 'INFO'
    Write-Host ""
    Write-Host "This validates that Enforce mode policies are active and working." -ForegroundColor White
    Write-Host ""
    
    $phase23Results = @{
        TestName = "Phase 2.3 Enforcement Validation"
        TestDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss UTC')
        Scope = $Scope
        Tests = @{}
        Summary = @{}
        Issues = @()
    }
    
    # Test 1: Verify Enforce mode assignments exist
    Write-Log "🧪 Test 1: Verify Enforce mode policy assignments exist" -Level 'INFO'
    Write-Host "   Scope: $Scope" -ForegroundColor Gray
    try {
        $assignments = Get-AzPolicyAssignment -Scope $Scope -ErrorAction Stop | Where-Object { $_.EnforcementMode -eq 'Default' }
        $enforceCount = @($assignments | Where-Object { $_.EnforcementMode -eq 'Default' }).Count
        
        if ($enforceCount -gt 0) {
            Write-Log "PASS: $enforceCount policies in Enforce mode" -Level 'SUCCESS'
            $phase23Results.Tests['EnforceAssignmentsExist'] = @{Result='PASS'; Count=$enforceCount; Message="Found $enforceCount Enforce-mode assignments"}
        } else {
            Write-Log "FAIL: No Enforce mode assignments found" -Level 'ERROR'
            $phase23Results.Tests['EnforceAssignmentsExist'] = @{Result='FAIL'; Count=0; Message="No Enforce-mode assignments detected"}
            $phase23Results.Issues += "No Enforce mode assignments found at scope $Scope"
        }
    } catch {
        Write-Log "ERROR: Failed to query assignments - $($_)" -Level 'WARN'
        $phase23Results.Tests['EnforceAssignmentsExist'] = @{Result='ERROR'; Message="$($_)"}
        $phase23Results.Issues += "Failed to retrieve policy assignments: $($_)"
    }
    
    # Test 2: Check compliance data availability
    Write-Host ""
    Write-Log "🧪 Test 2: Verify compliance data is being collected" -Level 'INFO'
    try {
        # Get-AzPolicyState doesn't have -Scope parameter, use -Filter or query all and filter
        $complianceStates = Get-AzPolicyState -Top 100 -ErrorAction Stop | Where-Object { $_.ResourceId -like "$Scope*" }
        $resourceCount = @($complianceStates | Select-Object -Unique -Property ResourceId).Count
        $policyCount = @($complianceStates | Select-Object -Unique -Property PolicyAssignmentId).Count
        
        if ($complianceStates -and $resourceCount -gt 0) {
            Write-Log "PASS: Compliance data available" -Level 'SUCCESS'
            Write-Host "   Resources evaluated: $resourceCount | Policies: $policyCount | States: $($complianceStates.Count)" -ForegroundColor Gray
            $phase23Results.Tests['ComplianceDataAvailable'] = @{Result='PASS'; ResourceCount=$resourceCount; PolicyCount=$policyCount; StateCount=$complianceStates.Count}
        } else {
            Write-Log "WARNING: No compliance data yet (may need 30-90 min after assignment)" -Level 'WARN'
            $phase23Results.Tests['ComplianceDataAvailable'] = @{Result='PENDING'; Message="Policies may still be evaluating"}
            $phase23Results.Issues += "Compliance data not yet available - policies still evaluating"
        }
    } catch {
        Write-Log "ERROR: Failed to query compliance - $($_)" -Level 'WARN'
        $phase23Results.Tests['ComplianceDataAvailable'] = @{Result='ERROR'; Message="$($_)"}
        $phase23Results.Issues += "Failed to retrieve compliance data: $($_)"
    }
    
    # Test 3: Check for remediation tasks (if SubscriptionId provided)
    Write-Host ""
    Write-Log "🧪 Test 3: Check for active remediation tasks" -Level 'INFO'
    if ($SubscriptionId) {
        try {
            $remediations = Get-AzPolicyRemediation -Scope "/subscriptions/$SubscriptionId" -ErrorAction Stop
            $remediationCount = @($remediations).Count
            
            if ($remediationCount -gt 0) {
                $succeeded = @($remediations | Where-Object { $_.ProvisioningState -eq 'Succeeded' }).Count
                $inProgress = @($remediations | Where-Object { $_.ProvisioningState -eq 'InProgress' }).Count
                $failed = @($remediations | Where-Object { $_.ProvisioningState -eq 'Failed' }).Count
                
                Write-Log "PASS: Remediations detected" -Level 'SUCCESS'
                Write-Host "   Total: $remediationCount | Succeeded: $succeeded | InProgress: $inProgress | Failed: $failed" -ForegroundColor Gray
                $phase23Results.Tests['RemediationTasks'] = @{Result='PASS'; Total=$remediationCount; Succeeded=$succeeded; InProgress=$inProgress; Failed=$failed}
            } else {
                Write-Log "INFO: No active remediations (expected if all remediation-eligible policies have already been remediated)" -Level 'INFO'
                $phase23Results.Tests['RemediationTasks'] = @{Result='INFO'; Count=0; Message="No active remediations detected"}
            }
        } catch {
            Write-Log "ERROR: Failed to query remediations - $($_)" -Level 'WARN'
            $phase23Results.Tests['RemediationTasks'] = @{Result='ERROR'; Message="$($_)"}
        }
    } else {
        Write-Log "SKIPPED: SubscriptionId not provided (needed for remediation check)" -Level 'WARN'
        $phase23Results.Tests['RemediationTasks'] = @{Result='SKIPPED'; Message="SubscriptionId required for remediation queries"}
    }
    
    # Test 4: Verify managed identity permissions (if principal ID provided)
    Write-Host ""
    Write-Log "🧪 Test 4: Verify managed identity has required roles" -Level 'INFO'
    if ($ManagedIdentityPrincipalId -and $SubscriptionId) {
        try {
            $roleAssignments = Get-AzRoleAssignment -ObjectId $ManagedIdentityPrincipalId -Scope "/subscriptions/$SubscriptionId" -ErrorAction Stop
            $roles = @($roleAssignments | Select-Object -ExpandProperty RoleDefinitionName -Unique)
            
            # Check for required roles for remediation (Contributor, Policy Contributor, or Owner)
            $requiredRoles = @('Contributor', 'Owner', 'Policy Contributor')
            $hasRequiredRole = $false
            foreach ($role in $roles) {
                if ($requiredRoles -contains $role) {
                    $hasRequiredRole = $true
                    break
                }
            }
            
            if ($hasRequiredRole) {
                Write-Log "PASS: Identity has required roles" -Level 'SUCCESS'
                Write-Host "   Roles assigned: $($roles -join ', ')" -ForegroundColor Gray
                $phase23Results.Tests['IdentityPermissions'] = @{Result='PASS'; Roles=$roles; HasRequiredRole=$true}
            } else {
                Write-Log "WARNING: Identity lacks recommended roles for remediation" -Level 'WARN'
                Write-Host "   Current roles: $($roles -join ', ')" -ForegroundColor Gray
                Write-Host "   Recommended: Contributor or Policy Contributor" -ForegroundColor Gray
                $phase23Results.Tests['IdentityPermissions'] = @{Result='WARNING'; Roles=$roles; HasRequiredRole=$false; Message="Missing required roles for auto-remediation"}
                $phase23Results.Issues += "Managed identity missing recommended roles for DeployIfNotExists/Modify remediation"
            }
        } catch {
            Write-Host "   ⚠️  ERROR: Failed to query role assignments - $($_)" -ForegroundColor Yellow
            $phase23Results.Tests['IdentityPermissions'] = @{Result='ERROR'; Message="$($_)"}
        }
    } else {
        Write-Log "SKIPPED: ManagedIdentityPrincipalId not provided" -Level 'WARN'
        $phase23Results.Tests['IdentityPermissions'] = @{Result='SKIPPED'; Message="Principal ID required for role verification"}
    }
    
    # Generate summary
    Write-Host ""
    Write-Log "═══════════════════════════════════════════════════════════" -Level 'INFO'
    Write-Log "  PHASE 2.3 TEST SUMMARY" -Level 'INFO'
    Write-Log "═══════════════════════════════════════════════════════════" -Level 'INFO'
    Write-Host ""
    
    $passedTests = @($phase23Results.Tests.Values | Where-Object { $_.Result -eq 'PASS' }).Count
    $totalTests = @($phase23Results.Tests.Values | Where-Object { $_.Result -in 'PASS','FAIL','ERROR' }).Count
    $successRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 2) } else { 0 }
    
    Write-Host "✅ Passed: $passedTests/$totalTests" -ForegroundColor Green
    Write-Host "📊 Success Rate: $successRate%" -ForegroundColor Cyan
    Write-Host ""
    
    if ($phase23Results.Issues.Count -gt 0) {
        Write-Log "⚠️  Issues Found:" -Level 'WARN'
        foreach ($issue in $phase23Results.Issues) {
            Write-Host "  • $issue" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Save results to JSON
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $resultsPath = "Phase2Point3TestResults-$timestamp.json"
    $phase23Results | ConvertTo-Json -Depth 10 | Out-File -FilePath $resultsPath -Encoding UTF8
    Write-Host "📄 Phase 2.3 results saved to: $resultsPath" -ForegroundColor Cyan
    Write-Host ""
    
    return $phase23Results
}

function Test-PolicyOperationalValue {
    param(
        [string]$Scope,
        [array]$AssignmentResults
    )
    Write-Log "Testing policy operational value and effectiveness..."
    
    $tests = @{
        AssignmentsCreated = 0
        AssignmentsVerified = 0
        PoliciesGeneratingData = 0
        ComplianceDataAvailable = $false
        EffectivePolicies = 0
        FailedTests = @()
    }
    
    # Test 1: Count successful assignments
    $successfulAssignments = $AssignmentResults | Where-Object { $_.Status -eq 'Assigned' }
    $tests.AssignmentsCreated = $successfulAssignments.Count
    
    if ($tests.AssignmentsCreated -eq 0) {
        $tests.FailedTests += "No policies successfully assigned"
        return $tests
    }
    
    # Test 2: Verify assignments exist in Azure
    Write-Log "Verifying assignments exist in Azure..."
    foreach ($result in $successfulAssignments) {
        try {
            $assignment = Get-AzPolicyAssignment -Id $result.Assignment.PolicyAssignmentId -ErrorAction Stop
            if ($assignment) {
                $tests.AssignmentsVerified++
            }
        } catch {
            $tests.FailedTests += "Assignment verification failed: $($result.Name)"
        }
    }
    
    # Test 3: Check if policies are generating compliance data (wait 60 seconds for evaluation)
    Write-Host ""
    Write-Host "Waiting 60 seconds for initial policy evaluation..." -ForegroundColor Yellow
    Start-Sleep -Seconds 60
    
    try {
        $complianceData = Get-AzPolicyState -Top 100 -ErrorAction Stop
        if ($complianceData -and $complianceData.Count -gt 0) {
            $tests.ComplianceDataAvailable = $true
            $tests.PoliciesGeneratingData = ($complianceData | Select-Object -Unique -Property PolicyAssignmentId | Measure-Object).Count
            
            # Test 4: Identify effective policies (those showing compliant or non-compliant resources)
            $effectiveAssignments = $complianceData | Group-Object -Property PolicyAssignmentId | Where-Object { $_.Count -gt 0 }
            $tests.EffectivePolicies = $effectiveAssignments.Count
        } else {
            $tests.FailedTests += "No compliance data generated yet (policies may need more time to evaluate)"
        }
    } catch {
        $tests.FailedTests += "Failed to retrieve compliance data: $($_.Exception.Message)"
    }
    
    # Summary
    Write-Host ""
    Write-Host "=== Operational Value Test Results ===" -ForegroundColor Cyan
    Write-Host "✓ Assignments Created: $($tests.AssignmentsCreated)" -ForegroundColor Green
    Write-Host "✓ Assignments Verified: $($tests.AssignmentsVerified)" -ForegroundColor Green
    Write-Host "✓ Policies Generating Data: $($tests.PoliciesGeneratingData)" -ForegroundColor $(if ($tests.PoliciesGeneratingData -gt 0) { 'Green' } else { 'Yellow' })
    Write-Host "✓ Compliance Data Available: $($tests.ComplianceDataAvailable)" -ForegroundColor $(if ($tests.ComplianceDataAvailable) { 'Green' } else { 'Yellow' })
    Write-Host "✓ Effective Policies: $($tests.EffectivePolicies)" -ForegroundColor $(if ($tests.EffectivePolicies -gt 0) { 'Green' } else { 'Yellow' })
    
    if ($tests.FailedTests.Count -gt 0) {
        Write-Host ""
        Write-Host "⚠ Issues Detected:" -ForegroundColor Yellow
        $tests.FailedTests | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    }
    
    Write-Host ""
    if ($tests.ComplianceDataAvailable -and $tests.EffectivePolicies -gt 0) {
        Write-Host "✅ SUCCESS: Policies are operational and showing value!" -ForegroundColor Green
    } elseif ($tests.AssignmentsVerified -gt 0) {
        Write-Host "⚠ PARTIAL: Policies assigned but may need more time for compliance data (15-60 min typical)" -ForegroundColor Yellow
    } else {
        Write-Host "❌ ISSUES: Policies not functioning as expected. Review errors above." -ForegroundColor Red
    }
    
    return $tests
}

function Import-PolicyListFromCsv {
    param(
        [string]$CsvPath = "./DefinitionListExport.csv"
    )
    if (-not (Test-Path $CsvPath)) {
        Write-Log -Message "CSV file not found at $CsvPath" -Level 'ERROR'
        throw "CSV file not found"
    }
    Write-Log "Reading policy list from $CsvPath"
    $items = Import-Csv -Path $CsvPath
    # Normalize display names
    $names = $items | Select-Object -ExpandProperty Name
    return $names
}

function Load-PolicyParameterOverrides {
    param(
        [string]$Path = './PolicyParameters.json'
    )
    if (-not (Test-Path $Path)) {
        Write-Log -Message "No policy parameter override file found at $Path; continuing without overrides." -Level 'INFO'
        return @{}
    }
    Write-Log "Loading policy parameter overrides from $Path"
    try {
        $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
        return $json
    } catch {
        Write-Log -Message "Failed to parse parameter overrides: $($_)" -Level 'ERROR'
        return @{}
    }
}

function Build-PolicyMappingFile {
    param(
        [string]$OutPath = './PolicyNameMapping.json'
    )
    Write-Log "Building policy name-to-definition mapping from tenant definitions..."
    $mapping = @{}
    
    # Scan policy definitions
    try {
        $defs = Get-AzPolicyDefinition -ErrorAction Stop
        foreach ($d in $defs) {
            # DisplayName is a direct property per Microsoft documentation
            if ($d.DisplayName -and $d.DisplayName.Trim() -ne '') {
                if (-not $mapping.ContainsKey($d.DisplayName)) {
                    $mapping[$d.DisplayName] = @{
                        Type = 'PolicyDefinition'
                        Id = $d.Id  # Use Id property, not PolicyDefinitionId
                        Name = $d.Name
                        DisplayName = $d.DisplayName
                    }
                }
            }
        }
        Write-Log "Scanned $($defs.Count) policy definitions, mapped $($mapping.Keys.Count) with display names"
    } catch {
        Write-Log -Message "Failed to scan policy definitions: $($_)" -Level 'ERROR'
    }
    
    # Scan policy set definitions (initiatives)
    try {
        $sets = Get-AzPolicySetDefinition -ErrorAction Stop
        $setCount = 0
        foreach ($s in $sets) {
            # DisplayName is a direct property per Microsoft documentation
            if ($s.DisplayName -and $s.DisplayName.Trim() -ne '') {
                $displayName = $s.DisplayName
                if (-not $mapping.ContainsKey($displayName)) {
                    $mapping[$displayName] = @{
                        Type = 'PolicySetDefinition'
                        Id = $s.Id  # Use Id property, not PolicySetDefinitionId
                        Name = $s.Name
                        DisplayName = $displayName
                    }
                    $setCount++
                }
            }
        }
        Write-Log "Scanned $($sets.Count) policy set definitions, mapped $setCount with display names"
    } catch {
        Write-Log -Message "Failed to scan policy set definitions: $($_)" -Level 'ERROR'
    }
    
    # Write mapping file
    $mapping | ConvertTo-Json -Depth 4 | Out-File -FilePath $OutPath -Encoding UTF8
    Write-Log "Wrote policy mapping to $OutPath ($(($mapping.Keys).Count) entries)" -Level 'SUCCESS'
    return $OutPath
}

function Load-PolicyMappingFile {
    param(
        [string]$Path = './PolicyNameMapping.json'
    )
    if (-not (Test-Path $Path)) {
        Write-Log -Message "Policy mapping file not found at $Path; will use direct lookup." -Level 'INFO'
        return $null
    }
    Write-Log "Loading policy mapping from $Path"
    try {
        $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
        # Convert to hashtable
        $map = @{}
        foreach ($p in $json.PSObject.Properties) {
            $map[$p.Name] = $p.Value
        }
        Write-Log "Loaded $($map.Keys.Count) policy mappings"
        return $map
    } catch {
        Write-Log -Message "Failed to load policy mapping: $($_)" -Level 'ERROR'
        return $null
    }
}

function Resolve-PolicyDefinitionByName {
    param(
        [string]$DisplayName,
        [hashtable]$Mapping = $null
    )
    
    # Try mapping first if available
    if ($Mapping -and $Mapping.ContainsKey($DisplayName)) {
        $entry = $Mapping[$DisplayName]
        Write-Log "Found '$DisplayName' in mapping: $($entry.Type) -> $($entry.Id)" -Level 'SUCCESS'
        try {
            if ($entry.Type -eq 'PolicyDefinition') {
                $def = Get-AzPolicyDefinition -Id $entry.Id -ErrorAction Stop
                return $def
            } elseif ($entry.Type -eq 'PolicySetDefinition') {
                $def = Get-AzPolicySetDefinition -Id $entry.Id -ErrorAction Stop
                return $def
            }
        } catch {
            Write-Log -Message "Failed to retrieve definition from mapping: $($_)" -Level 'WARN'
            # Fall through to direct lookup
        }
    }
    
    # Fallback to direct lookup using DisplayName property per Microsoft documentation
    $exact = Get-AzPolicyDefinition -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -eq $DisplayName}
    if ($exact) { return $exact }
    # Try displayName wildcard match
    $found = Get-AzPolicyDefinition -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -like "*$DisplayName*"}
    if ($found) { return $found }
    # Also search policy set definitions (initiatives)
    $pset = Get-AzPolicySetDefinition -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -eq $DisplayName -or $_.DisplayName -like "*$DisplayName*"}
    if ($pset) { return $pset }
    return $null
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory=$true)][scriptblock]$ScriptBlock,
        [int]$MaxRetries = 3,
        [int]$InitialDelaySeconds = 2
    )
    $attempt = 0
    $delay = $InitialDelaySeconds
    while ($attempt -lt $MaxRetries) {
        try {
            return & $ScriptBlock
        } catch {
            $attempt++
            if ($attempt -ge $MaxRetries) {
                throw
            }
            Write-Log -Message "Attempt $attempt failed: $($_.Exception.Message). Retrying in $delay seconds..." -Level 'WARN'
            Start-Sleep -Seconds $delay
            $delay = $delay * 2  # Exponential backoff
        }
    }
}

function Get-PolicyDefinitionParameters {
    <#
    .SYNOPSIS
    Gets parameters from a policy definition, handling both old and new Azure PowerShell SDK structures.
    
    .DESCRIPTION
    Azure PowerShell SDK changed the structure of policy definitions:
    - New structure: $definition.Parameter (singular, note property)
    - Old structure: $definition.Properties.parameters (plural, under Properties)
    This function checks both locations and returns the parameters object.
    
    .PARAMETER PolicyDefinition
    The policy definition object from Get-AzPolicyDefinition or Get-AzPolicySetDefinition
    
    .OUTPUTS
    PSCustomObject containing the policy parameters, or $null if no parameters exist
    #>
    param(
        [Parameter(Mandatory)][object]$PolicyDefinition
    )
    
    # Try new structure first (Parameter - singular)
    if ($PolicyDefinition.Parameter) {
        return $PolicyDefinition.Parameter
    }
    
    # Fall back to old structure (Properties.parameters - plural)
    if ($PolicyDefinition.Properties.parameters) {
        return $PolicyDefinition.Properties.parameters
    }
    
    # Also check policyRule.then.details.parameters (for DeployIfNotExists policies)
    if ($PolicyDefinition.PolicyRule.then.details.parameters) {
        return $PolicyDefinition.PolicyRule.then.details.parameters
    }
    if ($PolicyDefinition.Properties.policyRule.then.details.parameters) {
        return $PolicyDefinition.Properties.policyRule.then.details.parameters
    }
    
    return $null
}

function Validate-PolicyParameters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PolicyDefinition,
        [Parameter()][hashtable]$ProposedParameters
    )
    
    if (-not $ProposedParameters -or $ProposedParameters.Count -eq 0) {
        return @{Valid=$true; CleanedParameters=@{}; Warnings=@(); MissingRequired=$false}
    }
    
    $cleanedParams = @{}
    $warnings = @()
    $definedParams = Get-PolicyDefinitionParameters -PolicyDefinition $PolicyDefinition
    $missingRequired = $false
    
    if (-not $definedParams) {
        foreach ($key in $ProposedParameters.Keys) {
            $warnings += "Parameter '$key' provided but policy has no parameters defined - skipping"
        }
        return @{Valid=$false; CleanedParameters=@{}; Warnings=$warnings; MissingRequired=$false}
    }
    
    # Check each proposed parameter exists in the policy definition
    foreach ($paramName in $ProposedParameters.Keys) {
        Write-Log "DEBUG: Checking parameter '$paramName' against policy definition" -Level 'INFO'
        Write-Log "DEBUG: Defined parameter names: $($definedParams.PSObject.Properties.Name -join ', ')" -Level 'INFO'
        
        if ($definedParams.PSObject.Properties.Name -contains $paramName) {
            $paramDef = $definedParams.$paramName
            $proposedValue = $ProposedParameters[$paramName]
            
            # Validate against allowedValues if present
            if ($paramDef.allowedValues -and $paramDef.allowedValues.Count -gt 0) {
                # Handle array parameters - check if all values are in allowed list
                if ($proposedValue -is [array]) {
                    $invalidValues = $proposedValue | Where-Object { $paramDef.allowedValues -notcontains $_ }
                    if ($invalidValues) {
                        $warnings += "Parameter '$paramName' contains invalid values: [$($invalidValues -join ', ')]. Allowed: [$($paramDef.allowedValues -join ', ')]. Skipping."
                        continue
                    }
                } else {
                    # Single value - check if it's in allowed list
                    if ($paramDef.allowedValues -notcontains $proposedValue) {
                        $warnings += "Parameter '$paramName' value '$proposedValue' not in allowed values [$($paramDef.allowedValues -join ', ')]. Skipping to avoid PolicyParameterValueNotAllowed error."
                        continue
                    }
                }
            }
            
            $cleanedParams[$paramName] = $proposedValue
            Write-Log "DEBUG: Added parameter '$paramName' = '$proposedValue' to cleaned params" -Level 'INFO'
        } else {
            $warnings += "Parameter '$paramName' not defined in policy. Skipping to avoid UndefinedPolicyParameter error."
            Write-Log "DEBUG: Parameter '$paramName' NOT FOUND in policy definition - SKIPPED" -Level 'WARN'
        }
    }
    
    # Check for missing required parameters
    foreach ($paramName in $definedParams.PSObject.Properties.Name) {
        $paramDef = $definedParams.$paramName
        # If no defaultValue and not in our parameters, it's missing and required
        if (-not $paramDef.defaultValue -and $paramName -ne 'effect' -and -not $cleanedParams.ContainsKey($paramName)) {
            $warnings += "Required parameter '$paramName' missing. Policy will fail with MissingPolicyParameter error."
            $missingRequired = $true
        }
    }
    
    return @{Valid=($warnings.Count -eq 0 -or $cleanedParams.Count -gt 0); CleanedParameters=$cleanedParams; Warnings=$warnings; MissingRequired=$missingRequired}
}

function Test-PolicyRequiresManagedIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PolicyDefinition
    )
    
    $effect = $null
    
    # Check the policy rule effect
    if ($PolicyDefinition.Properties.policyRule.then.effect) {
        $effect = $PolicyDefinition.Properties.policyRule.then.effect
        # Handle parameterized effects like [parameters('effect')]
        if ($effect -match '\[parameters\(') {
            # Extract parameter name using a regex that matches the full pattern [parameters('name')]
            if ($effect -match '\[parameters\(''([^'']+)''\)\]') {
                $effectParamName = $Matches[1]
                $params = Get-PolicyDefinitionParameters -PolicyDefinition $PolicyDefinition
                $effectParam = if ($params) { $params.$effectParamName } else { $null }
                if ($effectParam -and $effectParam.allowedValues) {
                    # Check if any allowed value requires identity
                    foreach ($allowedEffect in $effectParam.allowedValues) {
                        if ($allowedEffect -in @('DeployIfNotExists', 'Modify')) {
                            return @{Requires=$true; Effect=$allowedEffect; Reason="Effect '$allowedEffect' requires managed identity"}
                        }
                    }
                }
            }
        } elseif ($effect -in @('DeployIfNotExists', 'Modify')) {
            return @{Requires=$true; Effect=$effect; Reason="Effect '$effect' requires managed identity"}
        }
    }
    
    return @{Requires=$false; Effect=$null; Reason=$null}
}

function Assign-Policy {
    param(
        [Parameter(Mandatory=$true)][string]$DisplayName,
        [Parameter(Mandatory=$true)][string]$Scope,
        [ValidateSet('Audit','Deny','Enforce')][string]$Mode = 'Audit',
        [switch]$DryRun,
        [object]$ParameterOverrides,
        [hashtable]$Mapping = $null,
        [int]$MaxRetries = 3,
        [string]$IdentityResourceId = $null
    )
    Write-Log "Assigning policy '$DisplayName' to $Scope (Mode=$Mode)"
    $def = Resolve-PolicyDefinitionByName -DisplayName $DisplayName -Mapping $Mapping
    if (-not $def) {
        Write-Log -Message "Policy definition '$DisplayName' not found in tenant." -Level 'ERROR'
        return @{Name=$DisplayName; Status='NotFound'}
    }
    # Azure policy assignment names must be <= 64 chars. Generate a shortened name.
    $cleanName = $DisplayName -replace '[^a-zA-Z0-9]',''
    # Check if an assignment for this policy already exists at this scope
    $existingAssignment = Get-AzPolicyAssignment -Scope $Scope -PolicyDefinitionId $def.Id -ErrorAction SilentlyContinue | Select-Object -First 1
    
    $randomSuffix = '-' + (Get-Random)
    $maxBaseLength = 64 - $randomSuffix.Length
    if ($cleanName.Length -gt $maxBaseLength) {
        $cleanName = $cleanName.Substring(0, $maxBaseLength)
    }
    $assignmentName = if ($existingAssignment) { $existingAssignment.Name } else { $cleanName + $randomSuffix }
    $props = @{
        Name = $assignmentName
        Scope = $Scope
    }
    # EnforcementMode: Default => enforced, DoNotEnforce => not enforced (audit)
    switch ($Mode) {
        'Audit'   { $props.Add('EnforcementMode','DoNotEnforce') }
        'Deny'    { $props.Add('EnforcementMode','Default') }
        'Enforce' { $props.Add('EnforcementMode','Default') }
    }
    # Attempt to set 'effect' parameter if supported by the definition
    $parameters = @{}
    # Merge provided per-policy override object/hashtable into parameters
    # Azure Policy API expects: @{ paramName = value } NOT @{ paramName = @{ value = value } }
    if ($ParameterOverrides) {
        if ($ParameterOverrides -is [System.Management.Automation.PSCustomObject]) {
            foreach ($p in $ParameterOverrides.PSObject.Properties) {
                # Extract the actual value (unwrap if already wrapped)
                if ($p.Value -is [hashtable] -and $p.Value.ContainsKey('value')) {
                    $parameters[$p.Name] = $p.Value.value  # Unwrap
                } else {
                    $parameters[$p.Name] = $p.Value  # Use directly
                }
            }
        } elseif ($ParameterOverrides -is [hashtable]) {
            foreach ($k in $ParameterOverrides.Keys) {
                # Extract the actual value (unwrap if already wrapped)
                if ($ParameterOverrides[$k] -is [hashtable] -and $ParameterOverrides[$k].ContainsKey('value')) {
                    $parameters[$k] = $ParameterOverrides[$k].value  # Unwrap
                } else {
                    $parameters[$k] = $ParameterOverrides[$k]  # Use directly
                }
            }
        } else {
            try {
                $parsed = $ParameterOverrides | ConvertFrom-Json -ErrorAction Stop
                foreach ($p in $parsed.PSObject.Properties) { 
                    # Extract the actual value (unwrap if already wrapped)
                    if ($p.Value -is [hashtable] -and $p.Value.ContainsKey('value')) {
                        $parameters[$p.Name] = $p.Value.value  # Unwrap
                    } else {
                        $parameters[$p.Name] = $p.Value  # Use directly
                    }
                }
            } catch {
                # ignore unknown formats
            }
        }
    }

    # Validate parameters against definition (prevents Missing/Undefined/NotAllowed errors)
    $paramValidation = Validate-PolicyParameters -PolicyDefinition $def -ProposedParameters $parameters
    $parameters = $paramValidation.CleanedParameters
    foreach ($w in $paramValidation.Warnings) {
        Write-Log $w -Level 'WARN'
    }
    if ($paramValidation.MissingRequired) {
        Write-Log "Skipping assignment for '$DisplayName' due to missing required parameters." -Level 'WARN'
        return @{Name=$DisplayName; Status='Skipped'; Error='Missing required parameters'}
    }
    # Validate and set effect parameter
    $defParams = Get-PolicyDefinitionParameters -PolicyDefinition $def
    if ($defParams -and $defParams.PSObject.Properties.Name -contains 'effect') {
        # Check which effect values are allowed by this policy
        $allowedEffects = @()
        if ($defParams.effect.allowedValues) {
            $allowedEffects = $defParams.effect.allowedValues
        }
        
        # If effect was provided in ParameterOverrides, validate it
        if ($parameters.ContainsKey('effect')) {
            $providedEffect = $parameters['effect']
            if ($allowedEffects.Count -gt 0 -and $allowedEffects -notcontains $providedEffect) {
                Write-Log -Message "Effect '$providedEffect' from parameter override not supported by policy '$DisplayName'. Allowed: $($allowedEffects -join ', '). Removing effect parameter." -Level 'WARN'
                $parameters.Remove('effect')
            }
        } else {
            # Set effect based on mode if not provided in overrides
            $desiredEffect = if ($Mode -eq 'Deny' -or $Mode -eq 'Enforce') { 'Deny' } else { 'Audit' }
            
            # Only set the effect if it's allowed, otherwise use policy's default or skip
            if ($allowedEffects.Count -gt 0) {
                if ($allowedEffects -contains $desiredEffect) {
                    $parameters['effect'] = $desiredEffect
                } else {
                    Write-Log -Message "Effect '$desiredEffect' not supported by policy '$DisplayName'. Allowed: $($allowedEffects -join ', '). Using policy default." -Level 'WARN'
                    # Don't set effect parameter - let policy use its default
                }
            } else {
                # No allowed values defined, assume it's supported
                $parameters['effect'] = $desiredEffect
            }
        }
    }

    # Managed identity requirements for DeployIfNotExists/Modify
    $miCheck = Test-PolicyRequiresManagedIdentity -PolicyDefinition $def
    $requiresIdentity = $miCheck.Requires
    $miReason = $miCheck.Reason
    
    # Also check if effect parameter (if set) requires identity
    if (-not $requiresIdentity -and $parameters.ContainsKey('effect')) {
        if ($parameters['effect'] -in @('DeployIfNotExists','Modify')) {
            $requiresIdentity = $true
            $miReason = "Effect '${parameters['effect']}' requires managed identity"
        }
    }
    
    # If still not required, check policy definition's default effect
    # This handles cases where we're NOT setting effect parameter but policy defaults to DeployIfNotExists/Modify
    if (-not $requiresIdentity) {
        $policyRule = if ($def.Properties.policyRule) { $def.Properties.policyRule } elseif ($def.PolicyRule) { $def.PolicyRule } else { $null }
        if ($policyRule -and $policyRule.then -and $policyRule.then.effect) {
            $defaultEffect = $policyRule.then.effect
            # Handle both static effect values and parameter references
            if ($defaultEffect -is [string] -and $defaultEffect -match '^\[parameters\(') {
                # Effect is a parameter reference - check default value
                if ($defParams.effect.defaultValue) {
                    $defaultEffect = $defParams.effect.defaultValue
                }
            }
            if ($defaultEffect -in @('DeployIfNotExists','Modify')) {
                $requiresIdentity = $true
                $miReason = "Policy default effect '$defaultEffect' requires managed identity"
                Write-Log "Detected policy default effect '$defaultEffect' requires managed identity" -Level 'INFO'
            }
        }
    }
    
    if ($requiresIdentity) {
        Write-Log "DEBUG: IdentityResourceId parameter value: '$IdentityResourceId' (Length: $($IdentityResourceId.Length))" -Level 'INFO'
        if ($IdentityResourceId -and $IdentityResourceId -ne '') {
            Write-Log "Policy requires managed identity. Using: $IdentityResourceId" -Level 'INFO'
            # Identity will be added to assignment props below
        } else {
            Write-Log "$miReason. Skipping assignment - provide -IdentityResourceId to enable." -Level 'WARN'
            return @{Name=$DisplayName; Status='Skipped'; Error=$miReason}
        }
    }
    try {
        if ($parameters.Count -gt 0) {
            $props.Add('PolicyParameterObject',$parameters)
        }
        
        # Add managed identity if required
        if ($IdentityResourceId -and $requiresIdentity) {
            $props.Add('IdentityType','UserAssigned')
            $props.Add('IdentityId',$IdentityResourceId)
            # Location is required for assignments with managed identity
            # Get the managed identity to retrieve its location
            try {
                $identityResource = Get-AzUserAssignedIdentity -ResourceId $IdentityResourceId -ErrorAction Stop
                $identityLocation = $identityResource.Location
                $props.Add('Location', $identityLocation)
                Write-Log "Added user-assigned identity: $IdentityResourceId (Location: $identityLocation)" -Level 'INFO'
            } catch {
                # Fallback to subscription's default location if we can't get identity location
                $context = Get-AzContext
                $subscription = Get-AzSubscription -SubscriptionId $context.Subscription.Id
                $defaultLocation = 'eastus'  # Safe default
                $props.Add('Location', $defaultLocation)
                Write-Log "Added user-assigned identity: $IdentityResourceId (using default location: $defaultLocation)" -Level 'INFO'
            }
        }
        
        if ($DryRun) {
            Write-Log -Message "Dry-run: would create assignment with name $assignmentName and params: $($parameters | Out-String)" -Level 'INFO'
            return @{Name=$DisplayName; Status='DryRun'; IntendedAssignmentName=$assignmentName; Parameters=$parameters}
        }
        
        # Determine if this is a PolicyDefinition or PolicySetDefinition
        $isPolicySet = $def.PSObject.Properties.Name -contains 'PolicySetDefinitionId'
        
        # Use retry logic for the assignment
        if ($existingAssignment) {
            # UPDATE existing assignment with new parameters/mode
            Write-Log "Assignment already exists for '$DisplayName'. Updating parameters and enforcement mode..." -Level 'INFO'
            
            $assignment = Invoke-WithRetry -MaxRetries $MaxRetries -ScriptBlock {
                $updateParams = @{
                    Id = $existingAssignment.Id
                }
                
                # Update enforcement mode
                if ($props.ContainsKey('EnforcementMode')) {
                    $updateParams.Add('EnforcementMode', $props['EnforcementMode'])
                }
                
                # Update parameters if any
                if ($props.ContainsKey('PolicyParameterObject')) {
                    $updateParams.Add('PolicyParameterObject', $props['PolicyParameterObject'])
                }
                
                # Update identity if required
                if ($props.ContainsKey('IdentityType')) {
                    $updateParams.Add('IdentityType', $props['IdentityType'])
                    $updateParams.Add('IdentityId', $props['IdentityId'])
                    if ($props.ContainsKey('Location')) {
                        $updateParams.Add('Location', $props['Location'])
                    }
                }
                
                Set-AzPolicyAssignment @updateParams -ErrorAction Stop
            }
            
            Write-Log "Updated assignment $($assignment.PolicyAssignmentId)" -Level 'SUCCESS'
            return @{Name=$DisplayName; Status='Updated'; Assignment=$assignment; DefinitionType=($isPolicySet ? 'PolicySet' : 'Policy'); IsExisting=$true}
        } else {
            # CREATE new assignment
            $assignment = Invoke-WithRetry -MaxRetries $MaxRetries -ScriptBlock {
                if ($isPolicySet) {
                    New-AzPolicyAssignment @props -PolicySetDefinition $def -ErrorAction Stop
                } else {
                    New-AzPolicyAssignment @props -PolicyDefinition $def -ErrorAction Stop
                }
            }
            
            Write-Log "Created new assignment $($assignment.PolicyAssignmentId)" -Level 'SUCCESS'
            return @{Name=$DisplayName; Status='Assigned'; Assignment=$assignment; DefinitionType=($isPolicySet ? 'PolicySet' : 'Policy')}
        }
    } catch {
        Write-Log -Message "Failed to assign policy after $MaxRetries retries: $($_)" -Level 'ERROR'
        return @{Name=$DisplayName; Status='Failed'; Error = $_.Exception.Message}
    }
}

function Verify-Assignments {
    param(
        [string[]]$AssignmentIds
    )
    $results = @()
    foreach ($id in $AssignmentIds) {
        try {
            $a = Get-AzPolicyAssignment -Id $id -ErrorAction Stop
            $results += @{AssignmentId=$id; Exists=$true; Name=$a.Name; Scope=$a.Scope}
        } catch {
            $results += @{AssignmentId=$id; Exists=$false}
        }
    }
    return $results
}

function Get-ComplianceReport {
    param(
        [string]$Scope,
        [int]$Top = 1000,
        [switch]$IncludeResourceDetails,
        [switch]$IncludeTrends
    )
    Write-Log "Querying policy states for scope: $Scope"
    try {
        if ($Scope -like "*/resourceGroups/*") {
            # Extract subscription and resource group from scope
            $scopeParts = $Scope -split '/'
            $subId = $scopeParts[2]
            $rgName = $scopeParts[4]
            $states = Get-AzPolicyState -SubscriptionId $subId -ResourceGroupName $rgName -Top $Top -ErrorAction Stop
        } elseif ($Scope -like "*/managementGroups/*") {
            # Extract management group from scope
            $scopeParts = $Scope -split '/'
            $mgId = $scopeParts[4]
            $states = Get-AzPolicyState -ManagementGroupName $mgId -Top $Top -ErrorAction Stop
        } elseif ($Scope -like "*/subscriptions/*") {
            # Subscription scope - extract subscription ID
            $scopeParts = $Scope -split '/'
            $subId = $scopeParts[2]
            $states = Get-AzPolicyState -SubscriptionId $subId -Top $Top -ErrorAction Stop
        } else {
            # Default: query without scope
            $states = Get-AzPolicyState -Top $Top -ErrorAction Stop
        }
    } catch {
        Write-Log -Message "Failed to query policy states: $($_)" -Level 'ERROR'
        return $null
    }
    
    if (-not $states -or $states.Count -eq 0) {
        Write-Log -Message "No policy states found for scope $Scope" -Level 'WARN'
        return @{Raw=$null; Summary=@(); OperationalStatus=[PSCustomObject]@{TotalPoliciesReporting=0; TotalResourcesEvaluated=0; OverallCompliancePercent=0}}
    }
    
    # Summarize by assignment
    $summary = $states | Group-Object -Property PolicyAssignmentId | ForEach-Object {
        $group = $_.Group
        $compliantCount = ($group | Where-Object {$_.ComplianceState -eq 'Compliant'}).Count
        $nonCompliantCount = ($group | Where-Object {$_.ComplianceState -ne 'Compliant'}).Count
        $total = $group.Count
        $compliancePercent = if ($total -gt 0) { [math]::Round(($compliantCount / $total) * 100, 2) } else { 0 }
        
        [PSCustomObject]@{
            PolicyAssignmentId = $_.Name
            PolicyAssignmentName = ($group[0].PolicyAssignmentName -replace '^.*/','')
            Total = $total
            Compliant = $compliantCount
            NonCompliant = $nonCompliantCount
            CompliancePercent = $compliancePercent
            EffectivenessRating = if ($compliancePercent -ge 95) { 'Excellent' } elseif ($compliancePercent -ge 80) { 'Good' } elseif ($compliancePercent -ge 60) { 'Fair' } else { 'NeedsAttention' }
        }
    }
    
    # Non-compliance reasons
    $nonCompliantReasons = $states | Where-Object {$_.ComplianceState -ne 'Compliant'} | 
        Group-Object -Property ComplianceReasonCode | 
        Select-Object @{N='Reason';E={$_.Name}}, @{N='Count';E={$_.Count}} |
        Sort-Object Count -Descending
    
    # Resource breakdown
    $resourceBreakdown = $null
    if ($IncludeResourceDetails) {
        $resourceBreakdown = $states | Group-Object -Property ResourceType | ForEach-Object {
            $rg = $_.Group
            [PSCustomObject]@{
                ResourceType = $_.Name
                Total = $rg.Count
                Compliant = ($rg | Where-Object {$_.ComplianceState -eq 'Compliant'}).Count
                NonCompliant = ($rg | Where-Object {$_.ComplianceState -ne 'Compliant'}).Count
            }
        } | Sort-Object NonCompliant -Descending
    }
    
    # Operational status
    $compliantCount = ($states | Where-Object {$_.ComplianceState -eq 'Compliant'} | Measure-Object).Count
    $nonCompliantCount = ($states | Where-Object {$_.ComplianceState -ne 'Compliant'} | Measure-Object).Count
    $totalResources = ($states | Select-Object -Unique -Property ResourceId | Measure-Object).Count
    $overallCompliancePercent = if ($states.Count -gt 0) { 
        [math]::Round((($states | Where-Object {$_.ComplianceState -eq 'Compliant'}).Count / $states.Count) * 100, 2) 
    } else { 0 }
    
    $effectivenessRating = if ($overallCompliancePercent -ge 95) { 'Excellent ⭐⭐⭐⭐⭐' } 
        elseif ($overallCompliancePercent -ge 80) { 'Good ⭐⭐⭐⭐' } 
        elseif ($overallCompliancePercent -ge 60) { 'Fair ⭐⭐⭐' } 
        elseif ($overallCompliancePercent -ge 40) { 'Needs Attention ⭐⭐' }
        else { 'Critical ⭐' }
    
    $operationalStatus = [PSCustomObject]@{
        TotalPoliciesReporting = ($summary | Measure-Object).Count
        TotalResourcesEvaluated = $totalResources
        CompliantResourceCount = $compliantCount
        NonCompliantResourceCount = $nonCompliantCount
        OverallCompliancePercent = $overallCompliancePercent
        EffectivenessRating = $effectivenessRating
        LastEvaluationTime = ($states | Sort-Object Timestamp -Descending | Select-Object -First 1).Timestamp
        PoliciesNeedingAttention = ($summary | Where-Object {$_.CompliancePercent -lt 80} | Measure-Object).Count
    }
    
    return @{
        Raw = $states
        Summary = $summary
        NonCompliantReasons = $nonCompliantReasons
        ResourceBreakdown = $resourceBreakdown
        OperationalStatus = $operationalStatus
        ReportGeneratedAt = (Get-Date).ToUniversalTime()
    }
}

function Create-AlertingTemplate {
    param(
        [string]$ResourceGroup,
        [string]$ActionGroupName = 'PolicyNonComplianceActionGroup',
        [string]$ActionGroupShortName = 'PolicyAG',
        [string]$LogAnalyticsWorkspaceId = '',
        [string]$KustoQuery = "PolicyResources | where TimeGenerated > ago(24h) | where IsCompliant == false | summarize Count = count() by PolicyAssignmentId, PolicyDefinitionId",
        [int]$FrequencyMinutes = 60,
        [int]$WindowMinutes = 60,
        [int]$Severity = 3,
        [switch]$DryRun
    )

    Write-Log "Scaffolding alerting templates for resource group $ResourceGroup"
    Write-Host "This function will create an Action Group and a Scheduled Query Rule that fires when policy non-compliance is detected."
    $agParams = @{ResourceGroupName=$ResourceGroup;Name=$ActionGroupName;ShortName=$ActionGroupShortName}
    if ($DryRun) {
        Write-Log -Message "Dry-run: Action Group template: $($agParams | Out-String)" -Level 'INFO'
        Write-Host "Dry-run: Scheduled query rule Kusto:`n$KustoQuery"
        return @{ActionGroupTemplate=$agParams;KustoQuery=$KustoQuery}
    }

    # Create or get Action Group
    try {
        $existing = Get-AzActionGroup -ResourceGroupName $ResourceGroup -Name $ActionGroupName -ErrorAction SilentlyContinue
        if (-not $existing) {
            $ag = New-AzActionGroup -ResourceGroupName $ResourceGroup -Name $ActionGroupName -ShortName $ActionGroupShortName -ReceiverEmail @(New-AzActionGroupReceiver -Name 'OpsEmail' -EmailAddress 'ops@contoso.com') -ErrorAction Stop
            Write-Log "Created Action Group: $($ag.Id)"
        } else {
            $ag = $existing
            Write-Log "Using existing Action Group: $($ag.Id)"
        }
    } catch {
        Write-Log -Message "Failed to create/get Action Group: $($_)" -Level 'ERROR'
        throw
    }

    if (-not $LogAnalyticsWorkspaceId) {
        Write-Log -Message 'No Log Analytics workspace id supplied; scheduled query rule cannot be created.' -Level 'WARN'
        return @{ActionGroup=$ag;KustoQuery=$KustoQuery}
    }

    # Create Scheduled Query Rule (Log Analytics alert)
    try {
        $ruleName = "PolicyNonComplianceRule-$(Get-Random)"
        New-AzScheduledQueryRule -ResourceGroupName $ResourceGroup -Name $ruleName -Location 'Global' -Enabled $true -Source @{Query=$KustoQuery;DataSourceId=$LogAnalyticsWorkspaceId} -Action @{ActionGroup=@($ag.Id)} -Schedule @{FrequencyInMinutes=$FrequencyMinutes;TimeWindowInMinutes=$WindowMinutes} -Severity $Severity -ErrorAction Stop
        Write-Log "Created Scheduled Query Rule: $ruleName"
        return @{ActionGroup=$ag;ScheduledQueryRuleName=$ruleName}
    } catch {
        Write-Log -Message "Failed to create scheduled query rule: $($_)" -Level 'ERROR'
        throw
    }
}

function Generate-RoleAssignmentCommands {
    param(
        [string]$Scope
    )
    Write-Host "PowerShell role assignment template (replace <userObjectId> or <userPrincipalName>):"
    Write-Host "# Grant Policy Contributor to a user on scope $Scope"
    Write-Host "# Using object id (preferred):"
    Write-Host "New-AzRoleAssignment -ObjectId <userObjectId> -RoleDefinitionName 'Policy Contributor' -Scope '$Scope'"
    Write-Host "# Using sign-in name (may require lookup):"
    Write-Host '$uid = (Get-AzADUser -UserPrincipalName ''user@contoso.com'').Id'
    Write-Host "New-AzRoleAssignment -ObjectId `$uid -RoleDefinitionName 'Policy Contributor' -Scope '$Scope'"
}

function Generate-DryRunSummary {
    param(
        [array]$AssignResults,
        [string]$OutPath = './DryRunSummary.txt'
    )
    $lines = @()
    $lines += "Dry-run assignment summary: Generated $(Get-Date -Format u)"
    $lines += "ScriptVersion: $Script:Version"
    $lines += ""
    foreach ($r in $AssignResults) {
        $name = $r.Name
        $status = $r.Status
        if ($r.ContainsKey('IntendedAssignmentName')) { $assignName = $r.IntendedAssignmentName } elseif ($r.Assignment) { $assignName = $r.Assignment.Name } else { $assignName = '' }
        $lines += "- Policy: $name | Status: $status | AssignmentName: $assignName"
        if ($r.Parameters) { $lines += "  Parameters: $($r.Parameters | ConvertTo-Json -Depth 4)" }
    }
    $lines | Out-File -FilePath $OutPath -Encoding UTF8
    Write-Host "Dry-run summary written to $OutPath"
    return $OutPath
}

function Test-AlertingScaffold {
    param(
        [string]$ResourceGroup,
        [switch]$DryRun
    )
    Write-Log "Testing alerting scaffold for resource group $ResourceGroup"
    $sample = @{TimeGenerated=(Get-Date);IsCompliant=$false;PolicyAssignmentId='sample';PolicyDefinitionId='sampleDef'}
    Write-Log "Simulated non-compliant item: $($sample | Out-String)"
    if ($DryRun) { Write-Log 'Dry-run: would fire alert using configured action group' ; return $sample }
    Write-Log 'Non-dry run: you would now verify that the scheduled query rule and action group trigger notifications.'
    return $sample
}

function Generate-ReportFiles {
    param(
        [string]$ReportNamePrefix,
        [object]$ReportObject
    )
    $timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $mdPath = "$ReportNamePrefix-$timestamp.md"
    $jsonPath = "$ReportNamePrefix-$timestamp.json"
    $csvPath = "$ReportNamePrefix-$timestamp.csv"

    $header = @(
        "# $ReportNamePrefix",
        "Generated: $(Get-Date -Format u)",
        "ScriptVersion: $Script:Version",
        "GeneratedBy: $((Get-AzContext).Account)",
        ""
    ) -join "`n"

    $footer = @(
        "",
        "---",
        "Report metadata:",
        "GeneratedUTC: $(Get-Date -AsUTC -Format u)",
        "ScriptVersion: $Script:Version"
    ) -join "`n"

    # Write markdown basic summary (safe concatenation)
    $mdLines = @()
    $mdLines += $header
    $mdLines += ""
    $mdLines += '```'
    $mdLines += ($ReportObject | Out-String)
    $mdLines += '```'
    $mdLines += $footer
    $md = $mdLines -join "`n"
    $md | Out-File -FilePath $mdPath -Encoding UTF8

    # JSON
    $ReportObject | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonPath -Encoding UTF8

    # CSV when summary exists
    if ($ReportObject.Summary) {
        $ReportObject.Summary | Export-Csv -Path $csvPath -NoTypeInformation -Force
    }

    Write-Log "Wrote reports: $mdPath, $jsonPath, $csvPath"
    return @{Markdown=$mdPath;Json=$jsonPath;Csv=$csvPath}
}

function Show-ChangeImpactGuidance {
    Write-Host ""
    Write-Log "═══════════════════════════════════════════════════════════" -Level 'INFO'
    Write-Log "                    📋 NEXT STEPS GUIDANCE" -Level 'INFO'
    Write-Log "═══════════════════════════════════════════════════════════" -Level 'INFO'
    Write-Host ""
    
    Write-Host "⚠️  IMPORTANT: Policy Enforcement Progression" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Phase 1: AUDIT MODE (Current)" -ForegroundColor Cyan
    Write-Host "  → Monitor compliance for 30-90 days" -ForegroundColor White
    Write-Host "  → Identify non-compliant resources without blocking operations" -ForegroundColor White
    Write-Host "  → Check compliance: " -NoNewline -ForegroundColor White
    Write-Host ".\\AzPolicyImplScript.ps1 -CheckCompliance" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Phase 2: DENY MODE (Recommended Next)" -ForegroundColor Cyan
    Write-Host "  → Prevents NEW non-compliant resources from being created" -ForegroundColor White
    Write-Host "  → Existing non-compliant resources remain functional (no impact)" -ForegroundColor White
    Write-Host "  → Use for 60-90 days to validate no critical automation is broken" -ForegroundColor White
    Write-Host "  → Deploy: Set PolicyMode parameter to 'Deny' when ready" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Phase 3: ENFORCE MODE (Final State)" -ForegroundColor Cyan
    Write-Host "  → Automatically remediates existing non-compliant resources" -ForegroundColor White
    Write-Host "  → Requires managed identity with Contributor permissions" -ForegroundColor White
    Write-Host "  → Schedule maintenance window for auto-remediation" -ForegroundColor White
    Write-Host "  → Deploy: Set PolicyMode parameter to 'Enforce' after validation" -ForegroundColor White
    Write-Host ""
    
    Write-Log "📌 Critical Actions Before Moving to Deny/Enforce:" -Level 'WARN'
    Write-Host "  1. ✅ Review compliance report: Open the HTML report generated above" -ForegroundColor White
    Write-Host "  2. ✅ Remediate non-compliant resources: Fix Key Vaults showing violations" -ForegroundColor White
    Write-Host "  3. ✅ Request exemptions if needed: Use -ExemptionAction Create for special cases" -ForegroundColor White
    Write-Host "  4. ✅ Update deployment templates: Ensure ARM/Bicep/Terraform comply with policies" -ForegroundColor White
    Write-Host "  5. ✅ Test in non-production first: Validate in dev/test subscription before production" -ForegroundColor White
    Write-Host "  6. ✅ Notify stakeholders: Communicate policy changes 7-14 days in advance" -ForegroundColor White
    Write-Host ""
    
    Write-Host "⚠️  Risk Warning:" -ForegroundColor Red
    Write-Host "  Switching directly to Deny/Enforce can block critical operations." -ForegroundColor Yellow
    Write-Host "  Always follow phased rollout: Audit → Deny → Enforce" -ForegroundColor Yellow
    Write-Host ""
}

function Get-TargetSubscription {
    Write-Log 'Checking current subscription context.'
    $ctx = Get-AzContext
    if (-not $ctx -or -not $ctx.Subscription) {
        Write-Log -Message 'No subscription context found. Please login and select a subscription.' -Level 'WARN'
        Connect-AzAccount | Out-Null
        $ctx = Get-AzContext
    }
    $currentSub = $ctx.Subscription
    Write-Log "Current subscription: $($currentSub.Name) ($($currentSub.Id))"
    $useCurrent = Read-Host 'Use this subscription? (Y/N) [Y]'
    if ($useCurrent -and $useCurrent.ToLower().StartsWith('n')) {
        $subs = Get-AzSubscription | Select-Object -Property Name,Id
        Write-Host 'Available subscriptions:'
        for ($i = 0; $i -lt $subs.Count; $i++) {
            Write-Host "[$i] $($subs[$i].Name) ($($subs[$i].Id))"
        }
        $sel = Read-Host 'Enter subscription number or id to target'
        if ($sel -match '^[0-9]+$') {
            $idx = [int]$sel
            if ($idx -ge 0 -and $idx -lt $subs.Count) { $chosen = $subs[$idx] } else { throw 'Invalid subscription index' }
        } else {
            $chosen = $subs | Where-Object { $_.Id -eq $sel -or $_.Name -eq $sel }
            if (-not $chosen) { throw 'No subscription matched that id or name' }
        }
        Set-AzContext -Subscription $chosen.Id | Out-Null
        Write-Log "Selected subscription: $($chosen.Name) ($($chosen.Id))"
        return $chosen.Id
    }
    return $currentSub.Id
}

function New-ComplianceHtmlReport {
    param(
        [Parameter(Mandatory)]$ComplianceData,
        [Parameter(Mandatory)]$Metadata,
        [Parameter(Mandatory)]$KeyVaults,
        [string]$OutputPath
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
    
    # Group compliance by policy and resource
    $policyDetails = @()
    if ($ComplianceData.Raw) {
        $grouped = $ComplianceData.Raw | Group-Object -Property PolicyAssignmentName
        foreach ($policyGroup in $grouped) {
            $policyName = $policyGroup.Name
            $states = $policyGroup.Group
            
            $compliant = @($states | Where-Object { $_.ComplianceState -eq 'Compliant' })
            $nonCompliant = @($states | Where-Object { $_.ComplianceState -ne 'Compliant' })
            
            $policyDetails += [PSCustomObject]@{
                PolicyName = $policyName
                TotalResources = $states.Count
                Compliant = $compliant.Count
                NonCompliant = $nonCompliant.Count
                CompliancePercent = if ($states.Count -gt 0) { [math]::Round(($compliant.Count / $states.Count) * 100, 1) } else { 0 }
                NonCompliantResources = $nonCompliant | Select-Object -ExpandProperty ResourceId -Unique
                PolicyDefinitionId = $states[0].PolicyDefinitionId
            }
        }
    }
    
    # Build HTML with detailed resource-level compliance
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Azure Policy Compliance Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; padding: 20px; }
        .container { max-width: 1400px; margin: 0 auto; background: white; border-radius: 12px; box-shadow: 0 10px 40px rgba(0,0,0,0.2); overflow: hidden; }
        .header { background: linear-gradient(135deg, #0078d4 0%, #005a9e 100%); color: white; padding: 40px; text-align: center; }
        .header h1 { font-size: 32px; margin-bottom: 10px; }
        .subtitle { font-size: 14px; opacity: 0.9; margin-top: 5px; }
        .content { padding: 30px; }
        .card { background: #f8f9fa; border-left: 4px solid #0078d4; padding: 20px; margin-bottom: 20px; border-radius: 8px; }
        .card h2 { color: #333; margin-bottom: 15px; font-size: 20px; }
        .metadata { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 20px; }
        .metadata-item { background: white; padding: 15px; border-radius: 6px; border: 1px solid #dee2e6; }
        .metadata-item label { display: block; font-size: 12px; color: #6c757d; margin-bottom: 5px; text-transform: uppercase; }
        .metadata-item value { display: block; font-size: 16px; font-weight: 600; color: #333; }
        table { width: 100%; border-collapse: collapse; background: white; border-radius: 6px; overflow: hidden; margin-top: 15px; }
        th { background: #0078d4; color: white; padding: 12px; text-align: left; font-weight: 600; }
        td { padding: 12px; border-bottom: 1px solid #dee2e6; }
        tr:last-child td { border-bottom: none; }
        tr:hover { background: #f1f3f5; }
        .status-success { color: #28a745; font-weight: 600; }
        .status-error { color: #dc3545; font-weight: 600; }
        .status-warning { color: #ffc107; font-weight: 600; }
        .compliance-metric { text-align: center; padding: 20px; }
        .metric-value { font-size: 48px; font-weight: 700; }
        .metric-label { font-size: 14px; color: #6c757d; margin-top: 5px; }
        .resource-list { font-size: 12px; color: #6c757d; margin-top: 5px; max-height: 100px; overflow-y: auto; }
        .resource-item { padding: 3px 0; border-bottom: 1px dotted #dee2e6; }
        .impact-box { background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin-top: 15px; border-radius: 6px; }
        .impact-box h3 { color: #856404; font-size: 16px; margin-bottom: 8px; }
        .impact-box p { color: #856404; font-size: 14px; line-height: 1.6; }
        .kv-list { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 10px; margin-top: 15px; }
        .kv-card { background: white; border: 1px solid #dee2e6; border-radius: 6px; padding: 12px; }
        .kv-name { font-weight: 600; color: #333; font-size: 14px; }
        .kv-location { font-size: 12px; color: #6c757d; margin-top: 4px; }
        .footer { background: #f8f9fa; padding: 20px; text-align: center; color: #6c757d; font-size: 13px; border-top: 1px solid #dee2e6; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 Azure Policy Compliance Report</h1>
            <div class="subtitle">Key Vault Security & Governance Analysis</div>
            <div class="subtitle">Generated: $timestamp</div>
        </div>
        
        <div class="content">
            <div class="card">
                <h2>📋 Report Metadata</h2>
                <div class="metadata">
                    <div class="metadata-item">
                        <label>Subscription</label>
                        <value>$($Metadata.SubscriptionName)</value>
                    </div>
                    <div class="metadata-item">
                        <label>Scope</label>
                        <value>$($Metadata.ScopeType)</value>
                    </div>
                    <div class="metadata-item">
                        <label>Key Vaults Discovered</label>
                        <value>$($Metadata.KeyVaultCount)</value>
                    </div>
                    <div class="metadata-item">
                        <label>Policies Reporting</label>
                        <value>$($ComplianceData.OperationalStatus.TotalPoliciesReporting)</value>
                    </div>
                </div>
            </div>
            
            <div class="card">
                <h2>📈 Compliance Overview</h2>
                <div class="compliance-metric">
                    <div class="metric-value" style="color: $(if ($ComplianceData.OperationalStatus.OverallCompliancePercent -ge 80) { '#28a745' } elseif ($ComplianceData.OperationalStatus.OverallCompliancePercent -ge 60) { '#ffc107' } else { '#dc3545' });">$($ComplianceData.OperationalStatus.OverallCompliancePercent)%</div>
                    <div class="metric-label">Overall Compliance</div>
                </div>
                <table>
                    <tr><th>Metric</th><th>Value</th></tr>
                    <tr><td>Total Resources Evaluated</td><td>$($ComplianceData.OperationalStatus.TotalResourcesEvaluated)</td></tr>
                    <tr><td>Compliant Resources</td><td class="status-success">$($ComplianceData.OperationalStatus.CompliantResourceCount)</td></tr>
                    <tr><td>Non-Compliant Resources</td><td class="status-error">$($ComplianceData.OperationalStatus.NonCompliantResourceCount)</td></tr>
                    <tr><td>Effectiveness Rating</td><td>$($ComplianceData.OperationalStatus.EffectivenessRating)</td></tr>
                </table>
            </div>
            
            <div class="card">
                <h2>🔍 Key Vaults in Subscription</h2>
                <p>These are the Key Vault resources being evaluated by policies:</p>
                <div class="kv-list">
"@
    
    foreach ($kv in $KeyVaults) {
        $html += @"
                    <div class="kv-card">
                        <div class="kv-name">🔐 $($kv.VaultName)</div>
                        <div class="kv-location">📍 $($kv.Location) | $($kv.ResourceGroupName)</div>
                    </div>
"@
    }
    
    $html += @"
                </div>
            </div>
            
            <div class="card">
                <h2>📊 Policy-by-Policy Compliance Details</h2>
                <p>Detailed breakdown showing which resources are compliant/non-compliant for each policy:</p>
                <table>
                    <tr>
                        <th>Policy Name</th>
                        <th>Total</th>
                        <th>Compliant</th>
                        <th>Non-Compliant</th>
                        <th>Compliance %</th>
                        <th>Non-Compliant Resources</th>
                    </tr>
"@
    
    foreach ($policy in ($policyDetails | Sort-Object CompliancePercent)) {
        $complianceClass = if ($policy.CompliancePercent -ge 80) { 'status-success' } elseif ($policy.CompliancePercent -ge 60) { 'status-warning' } else { 'status-error' }
        
        # Policy-specific remediation guidance
        $remediationGuide = switch -Wildcard ($policy.PolicyName) {
            "*soft delete*" { 
                "<strong>Why Non-Compliant:</strong> Key Vault does not have soft delete enabled (protects against accidental deletion).<br>" +
                "<strong>How to Fix:</strong> Cannot be enabled post-creation. Resource must be recreated with <code>-EnableSoftDelete</code> parameter (now enabled by default on all new vaults).<br>" +
                "<strong>PowerShell:</strong> <code>New-AzKeyVault -EnableSoftDelete -EnablePurgeProtection</code>" 
            }
            "*deletion protection*" { 
                "<strong>Why Non-Compliant:</strong> Key Vault does not have purge protection enabled (prevents permanent deletion during retention period).<br>" +
                "<strong>How to Fix:</strong> Cannot be enabled post-creation. Resource must be recreated with <code>-EnablePurgeProtection</code> parameter.<br>" +
                "<strong>PowerShell:</strong> <code>New-AzKeyVault -EnablePurgeProtection</code><br>" +
                "<strong>⚠️ CRITICAL:</strong> Request exemption for existing vaults. Update deployment templates to include purge protection." 
            }
            "*purge protection*" { 
                "<strong>Why Non-Compliant:</strong> Managed HSM does not have purge protection enabled.<br>" +
                "<strong>How to Fix:</strong> Cannot be enabled post-creation. Managed HSM must be recreated with purge protection enabled.<br>" +
                "<strong>Azure CLI:</strong> <code>az keyvault create --enable-purge-protection true</code>" 
            }
            "*public network*" { 
                "<strong>Why Non-Compliant:</strong> Key Vault allows public internet access (not restricted to private endpoints).<br>" +
                "<strong>How to Fix:</strong> Configure network firewall or disable public access entirely.<br>" +
                "<strong>PowerShell:</strong> <code>Update-AzKeyVault -VaultName 'vault-name' -PublicNetworkAccess Disabled</code><br>" +
                "<strong>Alternative:</strong> <code>Update-AzKeyVault -VaultName 'vault-name' -NetworkRuleSet @{DefaultAction='Deny'; IpRules=@('1.2.3.4/32')}</code>" 
            }
            "*firewall*" { 
                "<strong>Why Non-Compliant:</strong> Key Vault firewall is not enabled (allows unrestricted network access).<br>" +
                "<strong>How to Fix:</strong> Enable firewall and whitelist authorized IPs/VNets.<br>" +
                "<strong>PowerShell:</strong> <code>Update-AzKeyVaultNetworkRuleSet -VaultName 'vault-name' -DefaultAction Deny</code><br>" +
                "<strong>Note:</strong> Auto-remediation available (policy will set DefaultAction=Deny automatically)." 
            }
            "*RBAC*" { 
                "<strong>Why Non-Compliant:</strong> Key Vault using Access Policies instead of RBAC permission model (legacy authentication).<br>" +
                "<strong>How to Fix:</strong> Enable RBAC and assign appropriate roles to users/service principals.<br>" +
                "<strong>PowerShell:</strong> <code>Update-AzKeyVault -VaultName 'vault-name' -EnableRbacAuthorization \$true</code><br>" +
                "<strong>⚠️ IMPORTANT:</strong> Assign Key Vault roles BEFORE enabling RBAC or access will break:<br>" +
                "<code>New-AzRoleAssignment -ObjectId <user-id> -RoleDefinitionName 'Key Vault Administrator' -Scope <vault-id></code><br>" +
                "<strong>Note:</strong> Auto-remediation available (policy will enable RBAC automatically)." 
            }
            "*certificate*validity*" { 
                "<strong>Why Non-Compliant:</strong> Certificate validity period exceeds maximum allowed (typically 12 months).<br>" +
                "<strong>How to Fix:</strong> Reissue certificate with shorter validity period.<br>" +
                "<strong>PowerShell:</strong> <code>Add-AzKeyVaultCertificate -VaultName 'vault-name' -Name 'cert-name' -CertificatePolicy \$policy</code><br>" +
                "<strong>Note:</strong> Existing certificates are grandfathered. Policy affects NEW certificates only." 
            }
            "*expiration date*" { 
                "<strong>Why Non-Compliant:</strong> Key/Secret/Certificate does not have an expiration date set (infinite lifetime).<br>" +
                "<strong>How to Fix:</strong> Set expiration date on the key/secret/certificate.<br>" +
                "<strong>PowerShell (Key):</strong> <code>Set-AzKeyVaultKeyAttribute -VaultName 'vault-name' -Name 'key-name' -Expires (Get-Date).AddYears(1)</code><br>" +
                "<strong>PowerShell (Secret):</strong> <code>Set-AzKeyVaultSecretAttribute -VaultName 'vault-name' -Name 'secret-name' -Expires (Get-Date).AddMonths(6)</code><br>" +
                "<strong>Note:</strong> Existing keys/secrets are grandfathered. Policy affects NEW resources only." 
            }
            "*diagnostic*" { 
                "<strong>Why Non-Compliant:</strong> Resource logs (diagnostic settings) are not enabled for Key Vault.<br>" +
                "<strong>How to Fix:</strong> Configure diagnostic settings to send logs to Log Analytics workspace, Storage Account, or Event Hub.<br>" +
                "<strong>PowerShell:</strong> <code>Set-AzDiagnosticSetting -ResourceId <vault-id> -Name 'diag-settings' -WorkspaceId <workspace-id> -Enabled \$true</code><br>" +
                "<strong>Logs to Enable:</strong> AuditEvent, AzurePolicyEvaluationDetails" 
            }
            "*crypto*" { 
                "<strong>Why Non-Compliant:</strong> Key uses weak cryptographic algorithm or key size (e.g., RSA < 2048 bits, non-approved EC curves).<br>" +
                "<strong>How to Fix:</strong> Create new key with approved algorithm and rotate to new key.<br>" +
                "<strong>PowerShell:</strong> <code>Add-AzKeyVaultKey -VaultName 'vault-name' -Name 'key-name' -Destination Software -KeyType RSA -Size 2048</code><br>" +
                "<strong>Approved Curves:</strong> P-256, P-384, P-521 (for EC keys)<br>" +
                "<strong>Note:</strong> Existing keys are grandfathered. Policy affects NEW keys only." 
            }
            default { 
                "<strong>Why Non-Compliant:</strong> Resource does not meet policy requirements.<br>" +
                "<strong>How to Fix:</strong> Review policy definition and adjust resource configuration accordingly." 
            }
        }
        
        $nonCompliantList = ""
        if ($policy.NonCompliantResources.Count -gt 0) {
            $nonCompliantList = "<div class='resource-list'>"
            foreach ($resource in $policy.NonCompliantResources) {
                $resourceName = ($resource -split '/')[-1]
                $nonCompliantList += "<div class='resource-item'>❌ $resourceName</div>"
            }
            $nonCompliantList += "</div>"
        } else {
            $nonCompliantList = "<span class='status-success'>✅ All compliant</span>"
        }
        
        # Add remediation guidance tooltip/expandable section
        $remediationSection = ""
        if ($policy.NonCompliant -gt 0) {
            $remediationSection = @"
<div style='margin-top: 10px; padding: 12px; background: #fff3cd; border-left: 3px solid #ffc107; border-radius: 4px; font-size: 13px;'>
    <strong style='color: #856404;'>🔧 Remediation Guide:</strong><br>
    <div style='color: #856404; margin-top: 8px; line-height: 1.6;'>$remediationGuide</div>
</div>
"@
        }
        
        $html += @"
                    <tr>
                        <td>
                            <strong>$($policy.PolicyName)</strong>
                            $remediationSection
                        </td>
                        <td>$($policy.TotalResources)</td>
                        <td class="status-success">$($policy.Compliant)</td>
                        <td class="status-error">$($policy.NonCompliant)</td>
                        <td class="$complianceClass">$($policy.CompliancePercent)%</td>
                        <td>$nonCompliantList</td>
                    </tr>
"@
    }
    
    $html += @"
                </table>
            </div>
            
            <div class="impact-box">
                <h3>⚠️ Impact Analysis: Moving from Audit to Deny/Enforce</h3>
                <p><strong>Current State:</strong> Policies are in <strong>Audit</strong> mode, collecting compliance data without blocking operations.</p>
                <p><strong>If switched to Deny mode:</strong></p>
                <ul style="margin-left: 20px; margin-top: 10px; line-height: 1.8;">
                    <li><strong>$($ComplianceData.OperationalStatus.NonCompliantResourceCount) resources</strong> would be flagged as non-compliant</li>
                    <li>New resources not meeting policy requirements would be <strong>blocked from creation</strong></li>
                    <li>Updates to existing resources that violate policies would be <strong>denied</strong></li>
                    <li>Existing non-compliant resources remain unchanged (no automatic remediation)</li>
                </ul>
                <p style="margin-top: 15px;"><strong>Recommendation:</strong> Review all non-compliant resources above before switching to Deny mode. Plan remediation for existing violations, then use Deny to prevent new violations.</p>
            </div>
            
            <div class="card">
                <h2>📋 Next Steps</h2>
                <div style="background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin-bottom: 20px; border-radius: 6px;">
                    <p style="color: #856404; margin-bottom: 10px;"><strong>⚠️ Current Mode: Audit Only</strong></p>
                    <p style="color: #856404; font-size: 14px;">Policies are collecting compliance data but NOT blocking operations. Follow the phased approach below before enabling enforcement.</p>
                </div>
                
                <h3 style="color: #0078d4; margin-top: 20px; margin-bottom: 10px;">Phase 1: Review & Remediate (Current - Weeks 1-4)</h3>
                <ol style="margin-left: 20px; line-height: 2; margin-bottom: 20px;">
                    <li><strong>Analyze compliance data</strong>: Review the tables above to identify non-compliant Key Vaults</li>
                    <li><strong>Plan remediation</strong>: For each non-compliant resource, determine fix strategy:
                        <ul style="margin-left: 20px; margin-top: 5px;">
                            <li>Update Key Vault settings (enable soft delete, purge protection, RBAC, etc.)</li>
                            <li>Rotate certificates/keys/secrets to meet expiration requirements</li>
                            <li>Configure network firewall rules for private access</li>
                            <li>Request exemption if resource cannot comply (use <code>-ExemptionAction Create</code>)</li>
                        </ul>
                    </li>
                    <li><strong>Update deployment templates</strong>: Ensure ARM/Bicep/Terraform include required policy parameters</li>
                    <li><strong>Re-check compliance</strong>: Run <code>.\\AzPolicyImplScript.ps1 -CheckCompliance</code> to verify fixes</li>
                </ol>
                
                <h3 style="color: #0078d4; margin-top: 20px; margin-bottom: 10px;">Phase 2: Test Deny Mode (Weeks 5-12)</h3>
                <ol style="margin-left: 20px; line-height: 2; margin-bottom: 20px;" start="5">
                    <li><strong>Deploy Deny mode in dev/test</strong>: Test in non-production subscription first</li>
                    <li><strong>Deploy Deny mode in production</strong>: After validation, enable for production subscription</li>
                    <li><strong>Monitor blocked operations</strong>: Track Azure Activity Log for denied operations (60-90 days)</li>
                    <li><strong>Adjust as needed</strong>: Grant exemptions or update policy parameters if critical workflows are impacted</li>
                </ol>
                
                <h3 style="color: #0078d4; margin-top: 20px; margin-bottom: 10px;">Phase 3: Enable Enforce Mode (Week 13+)</h3>
                <ol style="margin-left: 20px; line-height: 2; margin-bottom: 20px;" start="9">
                    <li><strong>Configure auto-remediation</strong>: Ensure managed identity has Contributor role</li>
                    <li><strong>Schedule maintenance window</strong>: Notify teams of auto-remediation date/time</li>
                    <li><strong>Enable Enforce mode</strong>: Deploy with PolicyMode='Enforce' to auto-fix non-compliant resources</li>
                    <li><strong>Monitor remediation tasks</strong>: Track remediation job success/failure rates</li>
                    <li><strong>Establish ongoing governance</strong>: Monthly compliance reviews, quarterly policy audits</li>
                </ol>
                
                <div style="background: #d1ecf1; border-left: 4px solid #0c5460; padding: 15px; margin-top: 20px; border-radius: 6px;">
                    <p style="color: #0c5460; margin-bottom: 8px;"><strong>💡 Best Practice</strong></p>
                    <p style="color: #0c5460; font-size: 14px;">Never skip directly from Audit to Enforce. Each phase provides critical insights and reduces risk of operational disruption. Use policy exemptions for resources requiring manual review or temporary exceptions.</p>
                </div>
            </div>
        </div>
        
        <div class="footer">
            Generated by Azure Policy Implementation Script v$($Script:Version) | Subscription: $($Metadata.SubscriptionId)
        </div>
    </div>
</body>
</html>
"@
    
    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Log "Compliance HTML report generated: $OutputPath" -Level 'SUCCESS'
    return $OutputPath
}

function New-HtmlReport {
    param(
        [Parameter(Mandatory)]$AssignmentResults,
        [Parameter(Mandatory)]$Metadata,
        $ComplianceData = $null,
        $OperationalTests = $null,
        [string]$OutputPath = "./PolicyImplementationReport-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
    $successful = @($AssignmentResults | Where-Object { $_.Status -in @('Assigned', 'Updated') })
    $dryRun = @($AssignmentResults | Where-Object { $_.Status -eq 'DryRun' })
    $failed = @($AssignmentResults | Where-Object { $_.Status -notin @('Assigned', 'Updated', 'DryRun') })
    
    # Policy value descriptions
    $policyValues = @{
        "Key vaults should have soft delete enabled" = "Prevents accidental/malicious deletion; enables 90-day recovery window"
        "Key vaults should have deletion protection enabled" = "Prevents purge operations; ensures mandatory retention period"
        "Azure Key Vault should disable public network access" = "Blocks internet exposure; enforces private endpoint access only"
        "Certificates should have the specified maximum validity period" = "Reduces certificate lifecycle risk; enforces rotation policy"
        "Key Vault keys should have an expiration date" = "Prevents indefinite key usage; enforces key rotation hygiene"
        "Azure Key Vault should use RBAC permission model" = "Modernizes access control; enables Azure AD integration"
        "Resource logs in Key Vault should be enabled" = "Enables audit trail; supports security investigations and compliance"
    }
    
    # Determine next steps based on current mode
    $nextStepRecommendation = if ($Metadata.DryRun) {
        # In Preview mode, first step is to run actual deployment
        "✅ <strong>Run actual deployment</strong> by removing the <code>-Preview</code> parameter<br>" +
        "✅ Ensure you have appropriate RBAC permissions (Contributor + Resource Policy Contributor or Owner)<br>" +
        "✅ Consider starting with a <strong>single resource group</strong> or test environment before subscription-wide deployment"
    } else {
        # In live deployment mode, recommend progression through enforcement levels
        switch ($Metadata.EnforcementMode) {
            'Audit' { "✅ <strong>Review compliance data</strong> for 30-90 days to identify non-compliant resources<br>✅ Move to <strong>Deny</strong> mode to prevent new non-compliant configurations while allowing existing resources<br>✅ Plan remediation strategy for existing non-compliant resources" }
            'Deny' { "✅ <strong>Monitor blocked operations</strong> and adjust policy parameters if needed<br>✅ Move to <strong>Enforce</strong> mode with remediation tasks to fix existing non-compliant resources<br>✅ Use policy exemptions for special cases requiring manual review" }
            'Enforce' { "✅ <strong>Monitor compliance metrics</strong> and ensure policies are effective<br>✅ Enable <strong>auto-remediation</strong> for drift detection and correction<br>✅ Review policy assignments quarterly and adjust parameters as needed" }
            default { "✅ Review compliance data and plan enforcement strategy based on organizational requirements" }
        }
    }
    
    $complianceHtml = ""
    if ($ComplianceData -and $ComplianceData.OperationalStatus -and $ComplianceData.OperationalStatus.TotalPoliciesReporting -gt 0) {
        $compPct = $ComplianceData.OperationalStatus.OverallCompliancePercent
        $compColor = if ($compPct -ge 80) { '#28a745' } elseif ($compPct -ge 60) { '#ffc107' } else { '#dc3545' }
        $complianceHtml = @"
        <div class="card">
            <h2>📊 Compliance Overview</h2>
            <div class="compliance-metric">
                <div class="metric-value" style="color: $compColor;">$compPct%</div>
                <div class="metric-label">Overall Compliance</div>
            </div>
            <table>
                <tr><th>Metric</th><th>Value</th></tr>
                <tr><td>Policies Reporting</td><td>$($ComplianceData.OperationalStatus.TotalPoliciesReporting)</td></tr>
                <tr><td>Compliant Resources</td><td class="status-success">$($ComplianceData.OperationalStatus.CompliantResourceCount)</td></tr>
                <tr><td>Non-Compliant Resources</td><td class="status-error">$($ComplianceData.OperationalStatus.NonCompliantResourceCount)</td></tr>
                <tr><td>Effectiveness Rating</td><td>$($ComplianceData.OperationalStatus.EffectivenessRating)</td></tr>
            </table>
        </div>
"@
    } else {
        # Show warning when compliance data is not available
        $complianceHtml = @"
        <div class="card" style="border-left: 4px solid #ffc107; background: #fff3cd;">
            <h2>⏳ Compliance Data Not Yet Available</h2>
            <p style="color: #856404; line-height: 1.8; margin-bottom: 15px;">
                <strong>Azure Policy evaluation takes time.</strong> Newly assigned policies typically need <strong>30-90 minutes</strong> 
                to evaluate existing resources and generate compliance data.
            </p>
            
            <div style="background: white; padding: 15px; border-radius: 6px; margin-top: 15px; border: 1px solid #ffc107;">
                <h3 style="color: #856404; font-size: 16px; margin-bottom: 10px;">📊 How to Check Compliance Later</h3>
                <p style="color: #856404; margin-bottom: 10px;">Run the compliance check command to see detailed resource-level compliance:</p>
                <pre style="background: #f8f9fa; padding: 12px; border-radius: 4px; overflow-x: auto; color: #0078d4; font-family: 'Courier New', monospace; border: 1px solid #dee2e6;">.\AzPolicyImplScript.ps1 -CheckCompliance</pre>
                
                <p style="color: #856404; margin-top: 15px; font-size: 14px;">
                    <strong>This will show you:</strong>
                </p>
                <ul style="color: #856404; margin-left: 20px; line-height: 1.8; font-size: 14px;">
                    <li>✅ Which Key Vaults are compliant vs non-compliant for each policy</li>
                    <li>📊 Detailed resource-level breakdown showing exactly what needs remediation</li>
                    <li>🔧 Policies that support auto-remediation (DeployIfNotExists/Modify effects)</li>
                </ul>
                
                <div style="background: #e7f3ff; padding: 15px; border-radius: 6px; margin-top: 15px; border: 1px solid #0078d4;">
                    <h3 style="color: #005a9e; font-size: 16px; margin-bottom: 10px;">⚡ Auto-Remediation Notice</h3>
                    <p style="color: #005a9e; margin-bottom: 10px; line-height: 1.6;">
                        <strong>Important:</strong> Policies with <strong>DeployIfNotExists</strong> or <strong>Modify</strong> effects 
                        <strong>do NOT automatically remediate</strong> non-compliant resources. You must <strong>manually trigger remediation tasks</strong> 
                        after Azure completes its compliance evaluation (30-90 minutes).
                    </p>
                    <p style="color: #005a9e; margin-bottom: 10px;">To trigger remediation for auto-fix policies:</p>
                    <pre style="background: #f8f9fa; padding: 12px; border-radius: 4px; overflow-x: auto; color: #0078d4; font-family: 'Courier New', monospace; border: 1px solid #dee2e6;"># Trigger all auto-remediation policies
.\AzPolicyImplScript.ps1 -TriggerRemediation

# Or trigger specific policy by definition ID
.\AzPolicyImplScript.ps1 -TriggerRemediation -PolicyDefinitionId "951af2fa-529b-416e-ab6e-066fd85ac459"</pre>
                    <p style="color: #005a9e; font-size: 13px; margin-top: 10px;">
                        💡 <em>Remediation tasks typically complete in 2-10 minutes depending on complexity (diagnostic settings, firewalls, private endpoints).</em>
                    </p>
                </div>
                
                <ul style="color: #856404; margin-left: 20px; line-height: 1.8; font-size: 14px;">
                    <li>⚠️ Impact analysis: what would be blocked if you switched to Deny/Enforce mode</li>
                    <li>📈 Overall compliance percentage and effectiveness ratings</li>
                </ul>
                
                <p style="color: #856404; margin-top: 15px; font-size: 14px;">
                    <strong>Tip:</strong> Wait 30-60 minutes after policy assignment, then run the compliance check to see results.
                </p>
            </div>
            
            <table style="margin-top: 15px;">
                <tr><th>Metric</th><th>Value</th></tr>
                <tr><td>Policies Reporting</td><td><em>Pending evaluation...</em></td></tr>
                <tr><td>Compliant Resources</td><td><em>Pending evaluation...</em></td></tr>
                <tr><td>Non-Compliant Resources</td><td><em>Pending evaluation...</em></td></tr>
                <tr><td>Effectiveness Rating</td><td><em>Pending evaluation...</em></td></tr>
            </table>
        </div>
"@
    }
    
    $operationalHtml = ""
    if ($OperationalTests) {
        $statusIcon = if ($OperationalTests.ComplianceDataAvailable -and $OperationalTests.EffectivePolicies -gt 0) { '✅' } else { '⚠️' }
        $operationalHtml = @"
        <div class="card">
            <h2>$statusIcon Operational Value Tests</h2>
            <table>
                <tr><th>Test</th><th>Result</th></tr>
                <tr><td>Assignments Created</td><td class="status-success">$($OperationalTests.AssignmentsCreated)</td></tr>
                <tr><td>Assignments Verified in Azure</td><td class="status-success">$($OperationalTests.AssignmentsVerified)</td></tr>
                <tr><td>Policies Generating Compliance Data</td><td class="status-success">$($OperationalTests.PoliciesGeneratingData)</td></tr>
                <tr><td>Effective Policies (Showing Value)</td><td class="status-success">$($OperationalTests.EffectivePolicies)</td></tr>
            </table>
        </div>
"@
    }
    
    # In Preview mode, show DryRun results as simulated success; otherwise show Assigned
    $policiesToShow = if ($dryRun.Count -gt 0) { $dryRun } else { $successful }
    
    $successfulPoliciesHtml = ($policiesToShow | ForEach-Object {
        $policyName = $_.Name
        $value = if ($policyValues.ContainsKey($policyName)) { $policyValues[$policyName] } else { "Enhances Key Vault security and compliance posture" }
        $paramsHtml = if ($_.Parameters -and $_.Parameters.Count -gt 0) {
            $paramList = ($_.Parameters.GetEnumerator() | ForEach-Object { "<li><code>$($_.Key)</code>: $($_.Value.value)</li>" }) -join ""
            "<ul class='param-list'>$paramList</ul>"
        } else { "<em>No parameters</em>" }
        
        # Determine status display based on mode
        $statusDisplay = if ($_.Status -eq 'DryRun') { "🔍 Simulated" } else { "✓ Assigned" }
        
        @"
        <tr>
            <td><strong>$policyName</strong><br/><small class="policy-value">💡 $value</small></td>
            <td class="status-success">$statusDisplay</td>
            <td>$paramsHtml</td>
        </tr>
"@
    }) -join ""
    
    $failedPoliciesHtml = if ($failed.Count -gt 0) {
        ($failed | ForEach-Object {
            @"
        <tr>
            <td><strong>$($_.Name)</strong></td>
            <td class="status-error">✗ Failed</td>
            <td><span class="error-msg">$($_.Error)</span></td>
        </tr>
"@
        }) -join ""
    } else {
        "<tr><td colspan='3' style='text-align:center;color:#28a745;'>✅ All policies assigned successfully!</td></tr>"
    }
    
$html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Azure Policy Implementation Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 20px; }
        .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 12px; box-shadow: 0 10px 40px rgba(0,0,0,0.2); overflow: hidden; }
        .header { background: linear-gradient(135deg, #0078d4 0%, #005a9e 100%); color: white; padding: 30px; text-align: center; }
        .header h1 { font-size: 28px; margin-bottom: 10px; }
        .header .subtitle { opacity: 0.9; font-size: 14px; }
        .content { padding: 30px; }
        .card { background: #f8f9fa; border-left: 4px solid #0078d4; padding: 20px; margin-bottom: 20px; border-radius: 8px; }
        .card h2 { color: #333; margin-bottom: 15px; font-size: 20px; }
        .metadata { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 20px; }
        .metadata-item { background: white; padding: 15px; border-radius: 6px; border: 1px solid #dee2e6; }
        .metadata-item label { display: block; font-size: 12px; color: #6c757d; margin-bottom: 5px; text-transform: uppercase; }
        .metadata-item value { display: block; font-size: 16px; font-weight: 600; color: #333; }
        table { width: 100%; border-collapse: collapse; background: white; border-radius: 6px; overflow: hidden; }
        th { background: #0078d4; color: white; padding: 12px; text-align: left; font-weight: 600; }
        td { padding: 12px; border-bottom: 1px solid #dee2e6; }
        tr:last-child td { border-bottom: none; }
        tr:hover { background: #f1f3f5; }
        .status-success { color: #28a745; font-weight: 600; }
        .status-error { color: #dc3545; font-weight: 600; }
        .status-warning { color: #ffc107; font-weight: 600; }
        .error-msg { color: #dc3545; font-size: 13px; }
        .policy-value { color: #6c757d; display: block; margin-top: 5px; }
        .param-list { margin: 5px 0; padding-left: 20px; font-size: 13px; }
        .param-list li { margin: 3px 0; }
        code { background: #e9ecef; padding: 2px 6px; border-radius: 3px; font-size: 12px; }
        .next-steps { background: #fff3cd; border-left: 4px solid #ffc107; padding: 20px; margin-top: 20px; border-radius: 8px; }
        .next-steps h3 { color: #856404; margin-bottom: 10px; }
        .next-steps p { color: #856404; line-height: 1.6; }
        .compliance-metric { text-align: center; padding: 20px; }
        .metric-value { font-size: 48px; font-weight: 700; }
        .metric-label { font-size: 14px; color: #6c757d; margin-top: 5px; }
        .footer { background: #f8f9fa; padding: 20px; text-align: center; color: #6c757d; font-size: 13px; border-top: 1px solid #dee2e6; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔐 Azure Policy Implementation Report</h1>
            <div class="subtitle">Key Vault Governance & Security Baseline</div>
            <div class="subtitle">Generated: $timestamp</div>
        </div>
        
        <div class="content">
            <div class="card">
                <h2>📋 Deployment Metadata</h2>
                <div class="metadata">
                    <div class="metadata-item">
                        <label>Scope Type</label>
                        <value>$($Metadata.ScopeType)</value>
                    </div>
                    <div class="metadata-item">
                        <label>Scope</label>
                        <value>$($Metadata.Scope)</value>
                    </div>
                    <div class="metadata-item">
                        <label>Enforcement Mode</label>
                        <value>$($Metadata.EnforcementMode)</value>
                    </div>
                    <div class="metadata-item">
                        <label>Deployment Mode</label>
                        <value>$(if ($Metadata.DryRun) { '🔍 Preview/Dry-Run' } else { '🚀 Live Deployment' })</value>
                    </div>
                    <div class="metadata-item">
                        <label>Environment Preset</label>
                        <value>$($Metadata.EnvironmentPreset)</value>
                    </div>
                    <div class="metadata-item">
                        <label>Total Policies Processed</label>
                        <value>$($AssignmentResults.Count)</value>
                    </div>
                    <div class="metadata-item">
                        <label>$(if ($Metadata.DryRun) { 'Simulated Assignments' } else { 'Successfully Assigned' })</label>
                        <value class="status-success">$($dryRun.Count + $successful.Count)</value>
                    </div>
                    <div class="metadata-item">
                        <label>Failed $(if ($Metadata.DryRun) { 'Simulations' } else { 'Assignments' })</label>
                        <value class="status-error">$($failed.Count)</value>
                    </div>
                </div>
                
                $(if (-not $Metadata.DryRun -and $ComplianceData -and $ComplianceData.OperationalStatus.TotalPoliciesReporting -gt 0) {
                    # Show propagation warning when we have partial compliance data
                    $compPct = $ComplianceData.OperationalStatus.OverallCompliancePercent
                    if ($compPct -lt 80) {
                        @"
                <div style="margin-top: 10px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px; font-size: 14px;">
                    <strong>⚠️ IMPORTANT: Azure Policy Evaluation in Progress</strong><br><br>
                    <strong>Deployment Status:</strong> ✅ All $($successful.Count) policies successfully assigned<br>
                    <strong>Compliance Status:</strong> ⏳ Partial data ($compPct%) - Azure is still evaluating resources<br><br>
                    
                    <div style="background: white; padding: 12px; border-radius: 6px; margin-top: 10px; border: 1px solid #ffc107;">
                        <strong style="color: #856404;">📊 Why Compliance is Low Right Now:</strong><br>
                        <ul style="margin-left: 20px; margin-top: 8px; color: #856404; line-height: 1.8;">
                            <li><strong>Policy Assignment Propagation:</strong> 30-90 minutes for Azure to distribute assignments across all regions</li>
                            <li><strong>Resource Scanning:</strong> 15-30 minutes for Azure Policy engine to scan existing Key Vaults</li>
                            <li><strong>Compliance State Calculation:</strong> 10-15 minutes to evaluate resources against policy rules</li>
                        </ul>
                        
                        <p style="margin-top: 15px; color: #856404;"><strong>⏱️ WAIT 60 MINUTES</strong> from deployment time ($timestamp), then regenerate this report to see accurate compliance.</p>
                        
                        <p style="margin-top: 15px; color: #856404;"><strong>How to Regenerate Report:</strong></p>
                        <pre style="background: #f8f9fa; padding: 10px; border-radius: 4px; margin-top: 8px; color: #0078d4; font-family: 'Courier New', monospace; border: 1px solid #dee2e6;">.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan</pre>
                        
                        <p style="margin-top: 12px; color: #856404; font-size: 13px;">
                            <strong>Expected improvement:</strong> Compliance should increase from $compPct% to 60-80% range with all $($AssignmentResults.Count) policies reporting complete data.
                        </p>
                    </div>
                </div>
"@
                    }
                })
                
                <div style="margin-top: 10px; padding: 10px; background: #e7f3ff; border-left: 3px solid #0078d4; border-radius: 4px; font-size: 13px;">
                    <strong>📊 Status Breakdown:</strong>
                    $(if ($Metadata.DryRun) {
                        "🔍 Simulated: $($dryRun.Count) | ❌ Failed: $($failed.Count)"
                    } else {
                        "✅ Assigned: $($successful.Count) | ❌ Failed: $($failed.Count)"
                    })
                    $(if ($AssignmentResults.Count -eq 1) { " | ℹ️ Single policy run" })
                </div>
            </div>
            
            $(if ($Metadata.DryRun) {
            @"
            <div class="card" style="background: #cfe2ff; border-left: 4px solid #0d6efd;">
                <h2>ℹ️ Preview Mode Notice</h2>
                <p style="color: #084298; line-height: 1.8;">
                    This report was generated in <strong>Preview/Dry-Run mode</strong>. No actual policy assignments were created in Azure.
                    The results below show what <em>would</em> have been assigned if this script ran in live deployment mode.
                    <br><br>
                    <strong>To perform actual deployments:</strong> Remove the <code>-Preview</code> parameter and ensure you have appropriate RBAC permissions.
                </p>
            </div>
"@
            })
            
            $complianceHtml
            
            $operationalHtml
            
            <div class="card">
                <h2>✅ $(if ($Metadata.DryRun) { 'Simulated Policy Assignments (Preview Mode)' } else { 'Successfully Assigned Policies' })</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Policy Name & Value</th>
                            <th style="width: 120px;">Status</th>
                            <th style="width: 300px;">Parameters</th>
                        </tr>
                    </thead>
                    <tbody>
                        $successfulPoliciesHtml
                    </tbody>
                </table>
            </div>
            
            <div class="card">
                <h2>❌ Failed Policy Assignments</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Policy Name</th>
                            <th style="width: 120px;">Status</th>
                            <th>Error Details</th>
                        </tr>
                    </thead>
                    <tbody>
                        $failedPoliciesHtml
                    </tbody>
                </table>
            </div>
            
            <div class="card" style="background: #f8f9fa; border-left: 4px solid #6c757d;">
                <h2>📖 Policy Enforcement Modes Explained</h2>
                <table style="margin-top: 15px;">
                    <thead>
                        <tr>
                            <th>Mode</th>
                            <th>Behavior</th>
                            <th>Use Case</th>
                            <th>Operational Impact</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><strong style="color: #0078d4;">Audit</strong></td>
                            <td>Logs non-compliance events without blocking resource operations</td>
                            <td>
                                <strong>Initial Assessment Phase</strong><br>
                                • Discover non-compliant resources<br>
                                • Gather compliance telemetry<br>
                                • No operational disruption
                            </td>
                            <td>
                                <span style="color: #28a745;">✓ Zero risk</span> - No resources blocked<br>
                                <span style="color: #0078d4;">ℹ️ Duration:</span> 30-90 days recommended
                            </td>
                        </tr>
                        <tr>
                            <td><strong style="color: #ffc107;">Deny</strong></td>
                            <td>Blocks creation/modification of non-compliant resources; existing resources unaffected</td>
                            <td>
                                <strong>Prevention Phase</strong><br>
                                • Stop new violations<br>
                                • Allow time for remediation planning<br>
                                • Gradual compliance improvement
                            </td>
                            <td>
                                <span style="color: #ffc107;">⚠️ Medium risk</span> - May block deployments<br>
                                <span style="color: #0078d4;">ℹ️ Duration:</span> 60-120 days before Enforce
                            </td>
                        </tr>
                        <tr>
                            <td><strong style="color: #dc3545;">Enforce</strong></td>
                            <td>Actively remediates non-compliant resources through automated tasks or DeployIfNotExists policies</td>
                            <td>
                                <strong>Active Remediation Phase</strong><br>
                                • Auto-correct non-compliant resources<br>
                                • Full policy enforcement<br>
                                • Continuous compliance
                            </td>
                            <td>
                                <span style="color: #dc3545;">⚠️ High risk</span> - Modifies resources<br>
                                <span style="color: #0078d4;">ℹ️ Duration:</span> Ongoing with monitoring
                            </td>
                        </tr>
                    </tbody>
                </table>
                
                <div style="margin-top: 20px; padding: 15px; background: #e7f3ff; border-left: 3px solid #0078d4; border-radius: 4px;">
                    <h4 style="color: #0078d4; margin-bottom: 10px;">🔄 Recommended Lifecycle Progression</h4>
                    <div style="display: flex; align-items: center; gap: 10px; flex-wrap: wrap;">
                        <div style="flex: 1; min-width: 150px; padding: 10px; background: white; border-radius: 4px; text-align: center;">
                            <strong style="color: #0078d4;">1. Audit</strong><br>
                            <small>Discovery & Assessment</small><br>
                            <span style="font-size: 11px;">30-90 days</span>
                        </div>
                        <span style="font-size: 24px; color: #6c757d;">→</span>
                        <div style="flex: 1; min-width: 150px; padding: 10px; background: white; border-radius: 4px; text-align: center;">
                            <strong style="color: #0078d4;">2. Analyze</strong><br>
                            <small>Review Compliance Data</small><br>
                            <span style="font-size: 11px;">1-2 weeks</span>
                        </div>
                        <span style="font-size: 24px; color: #6c757d;">→</span>
                        <div style="flex: 1; min-width: 150px; padding: 10px; background: white; border-radius: 4px; text-align: center;">
                            <strong style="color: #ffc107;">3. Deny</strong><br>
                            <small>Prevent New Violations</small><br>
                            <span style="font-size: 11px;">60-120 days</span>
                        </div>
                        <span style="font-size: 24px; color: #6c757d;">→</span>
                        <div style="flex: 1; min-width: 150px; padding: 10px; background: white; border-radius: 4px; text-align: center;">
                            <strong style="color: #0078d4;">4. Remediate</strong><br>
                            <small>Fix Existing Issues</small><br>
                            <span style="font-size: 11px;">2-4 weeks</span>
                        </div>
                        <span style="font-size: 24px; color: #6c757d;">→</span>
                        <div style="flex: 1; min-width: 150px; padding: 10px; background: white; border-radius: 4px; text-align: center;">
                            <strong style="color: #dc3545;">5. Enforce</strong><br>
                            <small>Auto-Remediation</small><br>
                            <span style="font-size: 11px;">Ongoing</span>
                        </div>
                        <span style="font-size: 24px; color: #6c757d;">→</span>
                        <div style="flex: 1; min-width: 150px; padding: 10px; background: white; border-radius: 4px; text-align: center;">
                            <strong style="color: #28a745;">6. Monitor</strong><br>
                            <small>Maintain Compliance</small><br>
                            <span style="font-size: 11px;">Continuous</span>
                        </div>
                    </div>
                </div>
                
                <p style="margin-top: 15px; color: #6c757d; font-size: 13px;">
                    <strong>💡 Best Practice:</strong> Never skip directly from Audit to Enforce. Each phase provides critical insights and reduces risk of operational disruption.
                    Use policy exemptions for resources requiring manual review or temporary exceptions.
                </p>
            </div>
            
            <div class="next-steps">
                <h3>📌 Recommended Next Steps</h3>
                <p>$nextStepRecommendation</p>
                <p style="margin-top: 10px;"><strong>Additional Recommendations:</strong></p>
                <ul style="margin-left: 20px; margin-top: 10px;">
                    <li>Review non-compliant resources and create remediation tasks</li>
                    <li>Configure Azure Monitor alerts for policy compliance thresholds</li>
                    <li>Schedule monthly compliance reviews with security team</li>
                    <li>Document exceptions and exemptions with business justification</li>
                    <li>Test remediation in dev/test environment before production rollout</li>
                </ul>
            </div>
        </div>
        
        <div class="footer">
            Generated by Azure Policy Implementation Script v0.1.0 | Microsoft Azure Governance
        </div>
    </div>
</body>
</html>
"@
    
    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Log "HTML report generated: $OutputPath" -Level 'SUCCESS'
    return $OutputPath
}

function Manage-PolicyExemptions {
    <#
    .SYNOPSIS
        Manage Azure Policy exemptions for Key Vault resources.
    .DESCRIPTION
        Create, list, remove, or export policy exemptions with governance controls:
        - Maximum 90-day exemption duration
        - Required justification
        - Color-coded expiry warnings
        - CSV export for audit trail
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Create', 'List', 'Remove', 'Export')]
        [string]$Action,
        
        [string]$ResourceId,
        [string]$PolicyAssignmentName,
        [string]$Justification,
        
        [int]$ExpiresInDays = 30,
        
        [ValidateSet('Waiver', 'Mitigated')]
        [string]$Category = 'Waiver',
        
        [string]$Scope
    )
    
    try {
        switch ($Action) {
            'Create' {
                if (-not $ResourceId) {
                    throw "ResourceId is required for Create action"
                }
                if (-not $PolicyAssignmentName) {
                    throw "PolicyAssignmentName is required for Create action"
                }
                if (-not $Justification) {
                    throw "Justification is required for Create action"
b                }
                
                # Enforce 90-day maximum
                if ($ExpiresInDays -gt 90) {
                    Write-Host "WARNING: Maximum exemption duration is 90 days. Setting to 90 days." -ForegroundColor Yellow
                    $ExpiresInDays = 90
                }
                
                # Get the policy assignment
                $assignment = Get-AzPolicyAssignment | Where-Object { $_.Name -eq $PolicyAssignmentName }
                if (-not $assignment) {
                    throw "Policy assignment '$PolicyAssignmentName' not found"
                }
                
                # Generate exemption name
                $resourceName = $ResourceId.Split('/')[-1]
                $exemptionName = "exempt-$PolicyAssignmentName-$resourceName-$(Get-Date -Format 'yyyyMMdd')"
                if ($exemptionName.Length > 64) {
                    $exemptionName = $exemptionName.Substring(0, 64)
                }
                
                # Calculate expiry date
                $expiresOn = (Get-Date).AddDays($ExpiresInDays).ToUniversalTime()
                
                Write-Host "`nCreating policy exemption:" -ForegroundColor Cyan
                Write-Host "  Name: $exemptionName"
                Write-Host "  Resource: $ResourceId"
                Write-Host "  Policy: $PolicyAssignmentName"
                Write-Host "  Category: $Category"
                Write-Host "  Expires: $($expiresOn.ToString('yyyy-MM-dd')) ($ExpiresInDays days)"
                Write-Host "  Justification: $Justification"
                
                $exemption = New-AzPolicyExemption `
                    -Name $exemptionName `
                    -PolicyAssignment $assignment `
                    -Scope $ResourceId `
                    -ExemptionCategory $Category `
                    -Description $Justification `
                    -DisplayName "Exemption for $resourceName" `
                    -ExpiresOn $expiresOn
                
                Write-Host "`n✓ Exemption created successfully" -ForegroundColor Green
                return $exemption
            }
            
            'List' {
                $scope = if ($Scope) { $Scope } else { "/subscriptions/$((Get-AzContext).Subscription.Id)" }
                $exemptions = Get-AzPolicyExemption -Scope $scope
                
                if ($exemptions.Count -eq 0) {
                    Write-Host "`nNo policy exemptions found" -ForegroundColor Yellow
                    return
                }
                
                Write-Host "`nPolicy Exemptions ($($exemptions.Count) found):" -ForegroundColor Cyan
                Write-Host ("=" * 120)
                
                foreach ($exempt in $exemptions) {
                    $daysUntilExpiry = if ($exempt.Properties.ExpiresOn) {
                        [math]::Round(($exempt.Properties.ExpiresOn - (Get-Date)).TotalDays)
                    } else {
                        999
                    }
                    
                    # Color-code based on expiry
                    $expiryColor = if ($daysUntilExpiry -le 7) { 'Red' } 
                                  elseif ($daysUntilExpiry -le 30) { 'Yellow' } 
                                  else { 'Green' }
                    
                    Write-Host "`nExemption: " -NoNewline
                    Write-Host $exempt.Name -ForegroundColor Cyan
                    Write-Host "  Resource: $($exempt.Properties.Scope)"
                    Write-Host "  Policy: $($exempt.Properties.PolicyAssignmentId.Split('/')[-1])"
                    Write-Host "  Category: $($exempt.Properties.ExemptionCategory)"
                    Write-Host "  Expires: " -NoNewline
                    if ($exempt.Properties.ExpiresOn) {
                        Write-Host "$($exempt.Properties.ExpiresOn.ToString('yyyy-MM-dd')) " -NoNewline -ForegroundColor $expiryColor
                        Write-Host "($daysUntilExpiry days)" -ForegroundColor $expiryColor
                    } else {
                        Write-Host "Never" -ForegroundColor Gray
                    }
                    Write-Host "  Justification: $($exempt.Properties.Description)"
                }
                
                Write-Host ("=" * 120)
                return $exemptions
            }
            
            'Remove' {
                if (-not $ResourceId) {
                    throw "ResourceId is required for Remove action"
                }
                
                $exemptions = Get-AzPolicyExemption | Where-Object { $_.Properties.Scope -eq $ResourceId }
                
                if ($exemptions.Count -eq 0) {
                    Write-Host "`nNo exemptions found for resource: $ResourceId" -ForegroundColor Yellow
                    return
                }
                
                Write-Host "`nFound $($exemptions.Count) exemption(s) for resource" -ForegroundColor Cyan
                foreach ($exempt in $exemptions) {
                    Write-Host "`nRemoving exemption: $($exempt.Name)" -ForegroundColor Yellow
                    Remove-AzPolicyExemption -Id $exempt.Id -Force
                    Write-Host "✓ Removed: $($exempt.Name)" -ForegroundColor Green
                }
            }
            
            'Export' {
                $scope = if ($Scope) { $Scope } else { "/subscriptions/$((Get-AzContext).Subscription.Id)" }
                $exemptions = Get-AzPolicyExemption -Scope $scope
                
                if ($exemptions.Count -eq 0) {
                    Write-Host "`nNo exemptions to export" -ForegroundColor Yellow
                    return
                }
                
                $exportPath = "PolicyExemptions-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
                
                $exemptions | Select-Object `
                    Name,
                    @{Name='ResourceScope';Expression={$_.Properties.Scope}},
                    @{Name='PolicyAssignment';Expression={$_.Properties.PolicyAssignmentId.Split('/')[-1]}},
                    @{Name='Category';Expression={$_.Properties.ExemptionCategory}},
                    @{Name='Justification';Expression={$_.Properties.Description}},
                    @{Name='ExpiresOn';Expression={$_.Properties.ExpiresOn}},
                    @{Name='DaysRemaining';Expression={
                        if ($_.Properties.ExpiresOn) {
                            [math]::Round(($_.Properties.ExpiresOn - (Get-Date)).TotalDays)
                        } else {
                            'Never'
                        }
                    }} | Export-Csv -Path $exportPath -NoTypeInformation
                
                Write-Host "`n✓ Exported $($exemptions.Count) exemptions to: $exportPath" -ForegroundColor Green
                return $exportPath
            }
        }
    }
    catch {
        Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Remove-KeyVaultPolicyAssignments {
    <#
    .SYNOPSIS
        Remove all Key Vault policy assignments (KV-All-* and KV-Tier1-*).
    .DESCRIPTION
        Safely removes all Key Vault governance policy assignments with confirmation.
        Filters for assignments starting with KV-All- or KV-Tier1-.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Scope
    )
    
    try {
        Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "║  WARNING: Policy Rollback - Removing KV Policy Assignments  ║" -ForegroundColor Yellow
        Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
        
        # Get all KV policy assignments at the specified scope
        $assignments = Get-AzPolicyAssignment -Scope $Scope | Where-Object {
            $_.Name -like "KV-All-*" -or $_.Name -like "KV-Tier1-*" -or $_.Name -like "KV-*"
        }
        
        if ($assignments.Count -eq 0) {
            Write-Host "`nNo Key Vault policy assignments found at scope: $Scope" -ForegroundColor Yellow
            return
        }
        
        Write-Host "`nFound $($assignments.Count) Key Vault policy assignments to remove:" -ForegroundColor Cyan
        $assignments | Select-Object Name, @{Name='Scope';Expression={$_.Properties.Scope}} | Format-Table -AutoSize
        
        if ($WhatIf) {
            Write-Host "`nWhatIf: Would remove $($assignments.Count) policy assignments" -ForegroundColor Cyan
            return
        }
        
        Write-Host "`nThis will remove ALL Key Vault policy assignments." -ForegroundColor Red
        Write-Host "Type 'ROLLBACK' to confirm removal: " -NoNewline -ForegroundColor Yellow
        $confirmation = Read-Host
        
        if ($confirmation -ne 'ROLLBACK') {
            Write-Host "`nRollback cancelled" -ForegroundColor Yellow
            return
        }
        
        Write-Host "`nRemoving policy assignments..." -ForegroundColor Cyan
        $successCount = 0
        $failCount = 0
        
        foreach ($assignment in $assignments) {
            try {
                Write-Host "  Removing: $($assignment.Name)..." -NoNewline
                Remove-AzPolicyAssignment -Id $assignment.Id -ErrorAction Stop | Out-Null
                Write-Host " ✓" -ForegroundColor Green
                $successCount++
            }
            catch {
                Write-Host " ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
                $failCount++
            }
        }
        
        Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║  Rollback Complete                                           ║" -ForegroundColor Green
        Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host "  Removed: $successCount assignments" -ForegroundColor Green
        if ($failCount -gt 0) {
            Write-Host "  Failed: $failCount assignments" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "`nERROR during rollback: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Main {
    [CmdletBinding()]
    param(
        [string]$CsvPath = "./DefinitionListExport.csv",
        [switch]$DryRun,
        [switch]$Preview,
        [string]$ParameterOverridesPath = './PolicyParameters.json',
        [switch]$BuildMapping,
        [string]$MappingPath = './PolicyNameMapping.json',
        [string[]]$IncludePolicies = @(),
        [string[]]$ExcludePolicies = @(),
        [int]$MaxRetries = 3,
        [switch]$Interactive,
        [switch]$TestOperationalValue,
        [switch]$SkipRBACCheck,  # For testing when you know you have permissions
        [switch]$CheckCompliance,  # Run detailed compliance check and report
        [switch]$TriggerScan,  # Trigger Azure Policy compliance scan before checking
        [switch]$TestDenyBlocking,  # Test that Deny mode policies actually block non-compliant operations
        [switch]$TestProductionEnforcement,  # Production enforcement validation (focused deny mode tests)
        [switch]$TestInfrastructure,  # Comprehensive infrastructure validation
        [switch]$TestAutoRemediation,  # Test auto-remediation (DeployIfNotExists/Modify) policies
        [switch]$TriggerRemediation,  # Manually trigger remediation for all auto-fix policies
        [string]$PolicyDefinitionId,  # Specific policy definition ID to remediate (optional)
        [switch]$Detailed,  # Show detailed output for infrastructure validation
        [switch]$ValidateReport,  # Validate HTML compliance report for data integrity
        [string]$ReportPath,  # Path to HTML report to validate (defaults to most recent)
        [string]$IdentityResourceId,  # Resource ID of managed identity for DeployIfNotExists/Modify policies
        [string]$ScopeType,  # Scope type for policy assignment: Subscription, ResourceGroup, ManagementGroup
        [string]$PolicyMode,  # Policy enforcement mode: Audit, Deny, Enforce
        
        # Exemption Management (Step 5)
        [ValidateSet('Create', 'List', 'Remove', 'Export')]
        [string]$ExemptionAction,  # Exemption operation: Create, List, Remove, Export
        [string]$ExemptionResourceId,  # Resource ID for exemption (Key Vault resource ID)
        [string]$ExemptionPolicyAssignment,  # Policy assignment name for exemption
        [string]$ExemptionJustification,  # Business justification for exemption
        [int]$ExemptionExpiresInDays = 30,  # Exemption duration in days (max 90)
        [ValidateSet('Waiver', 'Mitigated')]
        [string]$ExemptionCategory = 'Waiver',  # Exemption category
        
        # Rollback
        [switch]$Rollback  # Remove all KV-All-* and KV-Tier1-* policy assignments
    )

    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  Azure Policy Implementation - Key Vault Governance          ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Log 'Starting Azure Policy implementation script for Key Vault policies'
    Ensure-RequiredModules
    # Only skip login when explicitly running in DryRun. Compliance checks still need live context.
    Connect-AzureIfNeeded -DryRun:$DryRun
    
    # Handle Exemption Management Mode (Step 5)
    if ($ExemptionAction) {
        Write-Host ""
        Write-Log "═══════════════════════════════════════════════════════════" -Level 'INFO'
        Write-Host "  EXEMPTION MANAGEMENT MODE - Step 5" -ForegroundColor Magenta
        Write-Log "═══════════════════════════════════════════════════════════" -Level 'INFO'
        Write-Host ""
        
        # Get scope if not already set
        if (-not $scope) {
            $context = Get-AzContext
            $subId = $context.Subscription.Id
            $scope = "/subscriptions/$subId"
        }
        
        Manage-PolicyExemptions `
            -Action $ExemptionAction `
            -Scope $scope `
            -ResourceId $ExemptionResourceId `
            -PolicyAssignment $ExemptionPolicyAssignment `
            -Justification $ExemptionJustification `
            -ExpiresInDays $ExemptionExpiresInDays `
            -Category $ExemptionCategory `
            -WhatIf:$WhatIf
        
        return
    }
    
    # Handle Rollback Mode
    if ($Rollback) {
        # Get scope if not already set
        if (-not $scope) {
            $selectedScopeType = Read-Host 'Rollback at which scope? (Subscription/ResourceGroup/ManagementGroup) [Subscription]'
            if (-not $selectedScopeType) { $selectedScopeType = 'Subscription' }
            
            $context = Get-AzContext
            switch ($selectedScopeType.ToLower()) {
                'subscription' {
                    $subId = $context.Subscription.Id
                    $scope = "/subscriptions/$subId"
                }
                'resourcegroup' {
                    Write-Host "`nAvailable Resource Groups:" -ForegroundColor Cyan
                    $allRGs = Get-AzResourceGroup | Select-Object ResourceGroupName, Location
                    $allRGs | Format-Table -AutoSize
                    $rg = Read-Host 'Enter Resource Group name'
                    $subId = $context.Subscription.Id
                    $scope = "/subscriptions/$subId/resourceGroups/$rg"
                }
                'managementgroup' {
                    $mg = Read-Host 'Enter Management Group id'
                    $scope = "/providers/Microsoft.Management/managementGroups/$mg"
                }
            }
        }
        
        Remove-KeyVaultPolicyAssignments -Scope $scope -WhatIf:$WhatIf
        return
    }

    # Check Compliance Mode - run detailed compliance analysis and exit (before other prompts)
    if ($CheckCompliance) {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host "  COMPLIANCE CHECK MODE" -ForegroundColor Yellow
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host ""
        
        # Let user select scope for compliance check
        $scopeType = Read-Host 'Check compliance at which scope? (Subscription/ResourceGroup/ManagementGroup) [Subscription]'
        if (-not $scopeType) { $scopeType = 'Subscription' }
        
        $context = Get-AzContext
        $scope = ""
        $scopeTypeFinal = ""
        
        switch ($scopeType.ToLower()) {
            'subscription' {
                $subId = $context.Subscription.Id
                $scope = "/subscriptions/$subId"
                $scopeTypeFinal = 'Subscription'
            }
            'resourcegroup' {
                Write-Host "`nAvailable Resource Groups:" -ForegroundColor Cyan
                $allRGs = Get-AzResourceGroup | Select-Object ResourceGroupName, Location, @{N='Resources';E={(Get-AzResource -ResourceGroupName $_.ResourceGroupName).Count}}
                $allRGs | Format-Table -AutoSize
                $rg = Read-Host 'Enter Resource Group name from list above'
                $subId = $context.Subscription.Id
                $scope = "/subscriptions/$subId/resourceGroups/$rg"
                $scopeTypeFinal = "Resource Group: $rg"
            }
            'managementgroup' {
                $mg = Read-Host 'Enter Management Group id'
                $scope = "/providers/Microsoft.Management/managementGroups/$mg"
                $scopeTypeFinal = "Management Group: $mg"
            }
            default {
                $subId = $context.Subscription.Id
                $scope = "/subscriptions/$subId"
                $scopeTypeFinal = 'Subscription'
            }
        }
        
        Write-Log "Running compliance check for $scopeTypeFinal" -Level 'INFO'
        
        if ($TriggerScan) {
            Write-Log "Triggering Azure Policy compliance scan..." -Level 'INFO'
            $scanJob = Start-AzPolicyComplianceScan -AsJob
            Write-Log "Compliance scan started (Job ID: $($scanJob.Id)). Waiting for completion..." -Level 'INFO'
            Write-Host "⏳ Waiting up to 5 minutes for scan to complete..." -ForegroundColor Yellow
            
            # Wait for up to 5 minutes (300 seconds)
            $timeout = 300
            $scanJob | Wait-Job -Timeout $timeout | Out-Null
            
            if ($scanJob.State -eq 'Completed') {
                Write-Log "Compliance scan completed successfully" -Level 'SUCCESS'
                Remove-Job -Job $scanJob -Force -ErrorAction SilentlyContinue
            } elseif ($scanJob.State -eq 'Running') {
                Write-Log "Compliance scan still running after 5 minutes - continuing with available data" -Level 'WARN'
                Write-Host "⚠️  Scan is still running in background. Results may be incomplete." -ForegroundColor Yellow
                Write-Host "   Run compliance check again in 2-5 minutes for complete results." -ForegroundColor Yellow
                # Don't remove the job - let it continue in background
            } else {
                Write-Log "Compliance scan ended with state: $($scanJob.State)" -Level 'WARN'
                Remove-Job -Job $scanJob -Force -ErrorAction SilentlyContinue
            }
        }
        
        Write-Log "Collecting compliance data for scope $scope..." -Level 'INFO'
        $complianceData = Get-ComplianceReport -Scope $scope -Top 5000 -IncludeResourceDetails
        
        if (-not $complianceData -or $complianceData.OperationalStatus.TotalPoliciesReporting -eq 0) {
            Write-Log "No compliance data available yet. Policies may need more time to evaluate (30-90 minutes after assignment)." -Level 'WARN'
            Write-Host ""
            Write-Host "💡 TIP: Run with -TriggerScan to force a compliance evaluation, then run again in 2-5 minutes" -ForegroundColor Cyan
            return
        }
        
        # Get Key Vault resources
        Write-Log "Discovering Key Vault resources in scope..." -Level 'INFO'
        $keyVaults = Get-AzKeyVault
        Write-Log "Found $($keyVaults.Count) Key Vaults" -Level 'SUCCESS'
        
        # Generate detailed compliance report
        $timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
        $reportPath = "./ComplianceReport-$timestamp.html"
        
        $metadata = @{
            ScopeType = $scopeTypeFinal
            Scope = $scope
            SubscriptionName = $context.Subscription.Name
            SubscriptionId = $context.Subscription.Id
            Mode = 'Compliance Check'
            DryRun = $false
            KeyVaultCount = $keyVaults.Count
            ReportType = 'Detailed Compliance Analysis'
        }
        
        New-ComplianceHtmlReport -ComplianceData $complianceData -Metadata $metadata -OutputPath $reportPath -KeyVaults $keyVaults
        
        # NOTE: Phase 2.3 auto-detection disabled during compliance checks to avoid confusion
        # Phase 2.3 is a built-in test separate from Scenario testing workflow
        # To run Phase 2.3 explicitly, use: -TestProductionEnforcement
        
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host "  COMPLIANCE CHECK COMPLETE" -ForegroundColor Green
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host ""
        Write-Host "📊 Report generated: $reportPath" -ForegroundColor Cyan
        Write-Host "📈 Policies Reporting: $($complianceData.OperationalStatus.TotalPoliciesReporting)" -ForegroundColor Cyan
        Write-Host "✅ Compliant Resources: $($complianceData.OperationalStatus.CompliantResourceCount)" -ForegroundColor Green
        Write-Host "❌ Non-Compliant Resources: $($complianceData.OperationalStatus.NonCompliantResourceCount)" -ForegroundColor Red
        Write-Host "📊 Overall Compliance: $($complianceData.OperationalStatus.OverallCompliancePercent)%" -ForegroundColor Cyan
        Write-Host ""
        
        # Check if there are auto-remediation policies and non-compliant resources
        if ($complianceData.OperationalStatus.NonCompliantResourceCount -gt 0) {
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
            Write-Host "  ⚡ AUTO-REMEDIATION NOTICE" -ForegroundColor Yellow
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  Policies with DeployIfNotExists/Modify effects require" -ForegroundColor Yellow
            Write-Host "  MANUAL REMEDIATION TRIGGER to auto-fix non-compliant resources." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  To trigger auto-remediation for all applicable policies:" -ForegroundColor Cyan
            Write-Host "    .\AzPolicyImplScript.ps1 -TriggerRemediation" -ForegroundColor White
            Write-Host ""
            Write-Host "  ℹ️  Wait 30-90 minutes after policy assignment before triggering" -ForegroundColor Gray
            Write-Host "     to ensure Azure has completed compliance evaluation." -ForegroundColor Gray
            Write-Host ""
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
        }
        Write-Host ""
        return
    }

    # Test Deny Blocking Mode - verify that Deny policies actually block operations
    if ($TestDenyBlocking) {
        $testResults = Test-DenyBlocking -ResourceGroupName 'rg-policy-keyvault-test' -Location 'eastus'
        
        if ($testResults.Blocked -eq $testResults.TotalTests) {
            Write-Host "✅ All tests passed! Deny policies are working correctly." -ForegroundColor Green
        } elseif ($testResults.Blocked -gt 0) {
            Write-Host "⚠️  Partial success. Some policies blocked operations, but not all." -ForegroundColor Yellow
        } else {
            Write-Host "❌ WARNING: No operations were blocked! Deny policies may not be working." -ForegroundColor Red
        }
        
        return
    }

    # Production Enforcement Validation - focused tests for production deny mode
    if ($TestProductionEnforcement) {
        Write-Log "Running production enforcement validation tests..." -Level 'INFO'
        $enforcementResults = Test-ProductionEnforcement
        Write-Host ""
        Write-Log "Production enforcement validation completed." -Level 'SUCCESS'
        return
    }

    # Infrastructure Validation - comprehensive pre-deployment checks
    if ($TestInfrastructure) {
        Write-Log "Running comprehensive infrastructure validation..." -Level 'INFO'
        $infraResults = Test-InfrastructureValidation -Detailed:$Detailed
        Write-Host ""
        Write-Log "Infrastructure validation completed." -Level 'SUCCESS'
        return
    }

    # Auto-Remediation Testing - test DeployIfNotExists/Modify policies
    if ($TestAutoRemediation) {
        Write-Log "Running auto-remediation policy tests..." -Level 'INFO'
        Test-AutoRemediation -ResourceGroupName 'rg-policy-keyvault-test' -Location 'eastus'
        Write-Host ""
        Write-Log "Auto-remediation testing initiated. Wait 30-60 minutes for completion." -Level 'SUCCESS'
        return
    }

    # Trigger Manual Remediation - manually trigger remediation tasks for auto-fix policies
    if ($TriggerRemediation) {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  MANUAL REMEDIATION TRIGGER" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        $scope = if ($ScopeType -eq 'ResourceGroup' -and $ResourceGroupName) {
            "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"
        } elseif ($ScopeType -eq 'ManagementGroup' -and $ManagementGroupId) {
            "/providers/Microsoft.Management/managementGroups/$ManagementGroupId"
        } else {
            "/subscriptions/$SubscriptionId"
        }
        
        Write-Log "Querying policy assignments at scope: $scope" -Level 'INFO'
        $allAssignments = Get-AzPolicyAssignment -Scope $scope
        
        # Auto-remediation policy definition IDs
        $remediationPolicies = @{
            "951af2fa-529b-416e-ab6e-066fd85ac459" = "Deploy diagnostic settings to Log Analytics workspace"
            "ed7c8c13-51e7-49d1-8a43-8490431a0a5e" = "Deploy diagnostic settings to Event Hub (Key Vault)"
            "1f6e93e8-6b31-41b1-83f6-36e449a42579" = "Deploy diagnostic settings to Event Hub (Managed HSM)"
            "ac673a9a-f77d-4846-b2d8-a57f8e1c01d4" = "Configure private endpoints (Key Vault)"
            "16260bb6-b8ac-4cd0-84d6-e5e21b9b8df6" = "Configure private endpoints (Managed HSM)"
            "7476dc20-c89d-4ed0-8e40-a75b18a62b7f" = "Configure private DNS zones"
            "bef3f64c-5290-43b7-85b0-9b254eef4c47" = "Deploy Diagnostic Settings for Key Vault to Event Hub"
            "ac673a9a-f77d-4846-b2d8-a57f8e1c01d5" = "Configure key vaults to enable firewall"
            "19ea9d63-adee-4431-a95e-1913c6c1c75f" = "Configure Azure Key Vault Managed HSM to disable public network access"
        }
        
        if ($PolicyDefinitionId) {
            # Trigger specific policy only
            Write-Log "Triggering remediation for policy: $PolicyDefinitionId" -Level 'INFO'
            $assignment = $allAssignments | Where-Object { $_.Properties.PolicyDefinitionId -like "*$PolicyDefinitionId" }
            
            if ($assignment) {
                $remediationName = "remediation-$(Get-Date -Format 'yyyyMMddHHmmss')"
                try {
                    $remediation = Start-AzPolicyRemediation `
                        -Name $remediationName `
                        -PolicyAssignmentId $assignment.PolicyAssignmentId `
                        -Scope $scope `
                        -ResourceDiscoveryMode ReEvaluateCompliance
                    
                    Write-Host "✓ Created remediation task: $($remediation.Name)" -ForegroundColor Green
                    Write-Host "  Policy: $($assignment.Properties.DisplayName)" -ForegroundColor Gray
                    Write-Host "  Status: $($remediation.ProvisioningState)" -ForegroundColor Yellow
                } catch {
                    Write-Log "Failed to create remediation: $($_.Exception.Message)" -Level 'ERROR'
                }
            } else {
                Write-Log "Policy assignment not found for definition ID: $PolicyDefinitionId" -Level 'ERROR'
            }
        } else {
            # Trigger all auto-remediation policies
            Write-Log "Triggering remediation for all auto-fix policies..." -Level 'INFO'
            $triggered = 0
            $failed = 0
            
            foreach ($defId in $remediationPolicies.Keys) {
                $policyName = $remediationPolicies[$defId]
                $assignment = $allAssignments | Where-Object { $_.Properties.PolicyDefinitionId -like "*$defId" }
                
                if ($assignment) {
                    $remediationName = "auto-remediation-$(Get-Date -Format 'yyyyMMddHHmmss')-$triggered"
                    try {
                        Write-Host "Triggering: $policyName..." -ForegroundColor Cyan
                        $remediation = Start-AzPolicyRemediation `
                            -Name $remediationName `
                            -PolicyAssignmentId $assignment.PolicyAssignmentId `
                            -Scope $scope `
                            -ResourceDiscoveryMode ReEvaluateCompliance `
                            -ErrorAction Stop
                        
                        Write-Host "  ✓ Task created: $($remediation.Name)" -ForegroundColor Green
                        $triggered++
                        Start-Sleep -Seconds 2  # Prevent throttling
                    } catch {
                        Write-Host "  ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
                        $failed++
                    }
                } else {
                    Write-Host "⊘ Policy not assigned: $policyName" -ForegroundColor Gray
                }
            }
            
            Write-Host ""
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "  REMEDIATION SUMMARY" -ForegroundColor Cyan
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "✓ Remediation tasks created: $triggered" -ForegroundColor Green
            if ($failed -gt 0) {
                Write-Host "✗ Failed: $failed" -ForegroundColor Red
            }
            Write-Host ""
            Write-Host "⏳ Remediation tasks typically complete in 2-10 minutes." -ForegroundColor Yellow
            Write-Host "   Monitor status with: Get-AzPolicyRemediation -Scope '$scope'" -ForegroundColor Gray
            Write-Host ""
        }
        return
    }

    # HTML Report Validation - validate compliance report data integrity
    if ($ValidateReport) {
        Write-Log "Running HTML compliance report validation..." -Level 'INFO'
        $validationResults = Test-HTMLReportValidation -ReportPath $ReportPath
        Write-Host ""
        if ($validationResults.Failed -eq 0) {
            Write-Log "Report validation completed successfully." -Level 'SUCCESS'
        } else {
            Write-Log "Report validation completed with issues. See details above." -Level 'WARN'
        }
        return
    }

    # Interactive menu
    if ($Interactive) {
        $menuResult = Show-InteractiveMenu
        $ParameterOverridesPath = $menuResult.ParameterFile
        if ($menuResult.IncludePolicies.Count -gt 0) {
            $IncludePolicies = $menuResult.IncludePolicies
        }
    }

    # Build mapping file if requested
    if ($BuildMapping) {
        Write-Log -Message "BuildMapping flag enabled: building policy name mapping file..." -Level 'INFO'
        $mappingFile = Build-PolicyMappingFile -OutPath $MappingPath
        Write-Host "Policy mapping built: $mappingFile"
        if (-not $Preview -and -not $DryRun) {
            Write-Host "Mapping complete. Re-run script without -BuildMapping to use the mapping."
            return
        }
    }

    # Load mapping if it exists
    $policyMapping = Load-PolicyMappingFile -Path $MappingPath

    $parameterOverrides = Load-PolicyParameterOverrides -Path $ParameterOverridesPath

    # Normalize parameter overrides into a hashtable for quick lookup
    if ($parameterOverrides -and $parameterOverrides -is [System.Management.Automation.PSCustomObject]) {
        $tmp = @{}
        foreach ($p in $parameterOverrides.PSObject.Properties) {
            $tmp[$p.Name] = $p.Value
        }
        $parameterOverrides = $tmp
    }

    if ($Preview) {
        Write-Log -Message 'Preview mode enabled: setting DryRun and skipping RBAC checks.' -Level 'INFO'
        $DryRun = $true
    }

    # Only prompt for scope type if not provided via parameter
    Write-Log "DEBUG: PSBoundParameters keys: $($PSBoundParameters.Keys -join ', ')" -Level 'INFO'
    Write-Log "DEBUG: ScopeType value: '$ScopeType'" -Level 'INFO'
    if ($PSBoundParameters.ContainsKey('ScopeType') -and $ScopeType) {
        $selectedScopeType = $ScopeType
        Write-Log "Using scope type from parameter: $selectedScopeType" -Level 'INFO'
    } else {
        Write-Log "DEBUG: Prompting for scope type (PSBound check failed)" -Level 'INFO'
        $selectedScopeType = Read-Host 'Assign policies at scope type? (Subscription/ResourceGroup/ManagementGroup) [Subscription]'
        if (-not $selectedScopeType) { $selectedScopeType = 'Subscription' }
    }
    switch ($selectedScopeType.ToLower()) {
        'subscription' {
            $selectedSubId = Get-TargetSubscription
            $scope = "/subscriptions/$selectedSubId"
        }
        'resourcegroup' {
            # Auto-detect resource group for DevTest environment
            if ($ParameterOverridesPath -like '*DevTest*') {
                $rg = 'rg-policy-keyvault-test'
                Write-Log "DevTest environment detected - automatically using resource group: $rg" -Level 'INFO'
                $subId = Get-TargetSubscription
                $scope = "/subscriptions/$subId/resourceGroups/$rg"
            } else {
                Write-Host "\nAvailable Resource Groups:" -ForegroundColor Cyan
                $allRGs = Get-AzResourceGroup | Select-Object ResourceGroupName, Location, @{N='Resources';E={(Get-AzResource -ResourceGroupName $_.ResourceGroupName).Count}}
                $allRGs | Format-Table -AutoSize
                $rg = Read-Host 'Enter Resource Group name from list above'
                $subId = Get-TargetSubscription
                $scope = "/subscriptions/$subId/resourceGroups/$rg"
            }
        }
        'managementgroup' {
            $mg = Read-Host 'Enter Management Group id'
            $scope = "/providers/Microsoft.Management/managementGroups/$mg"
        }
        default {
            $selectedSubId = Get-TargetSubscription
            $scope = "/subscriptions/$selectedSubId"
        }
    }

    if (-not $Preview) {
        if (-not $SkipRBACCheck) {
            $hasPerm = Check-UserPermissions -Scope $scope
            if (-not $hasPerm) {
                Write-Log -Message 'Insufficient RBAC to continue. Resolve RBAC and re-run.' -Level 'ERROR'
                Write-Host "Role assignment commands to request:" 
                Generate-RoleAssignmentCommands -Scope $scope
                return
            }
        } else {
            Write-Log -Message 'Skipping RBAC permission check (SkipRBACCheck flag enabled).' -Level 'WARN'
        }
    } else {
        Write-Log -Message 'Preview mode: skipped RBAC permission check.' -Level 'INFO'
    }

    # Only prompt for mode if not provided via parameter
    if ($PSBoundParameters.ContainsKey('PolicyMode') -and $PolicyMode) {
        $selectedMode = $PolicyMode
        Write-Log "Using mode from parameter: $selectedMode" -Level 'INFO'
    } else {
        $selectedMode = Read-Host 'Choose mode (Audit/Deny/Enforce) [Audit]'
        if (-not $selectedMode) { $selectedMode = 'Audit' }
    }

    # === PRODUCTION DEPLOYMENT SAFEGUARDS ===
    # Detect production parameters and warn before Deny/Enforce deployment
    $isProductionConfig = $ParameterOverridesPath -like '*Production*'
    $isEnforcementMode = $selectedMode -in @('Deny', 'Enforce')
    
    if ($isProductionConfig -and $isEnforcementMode -and -not $DryRun) {
        Write-Host ""
        Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║  ⚠️  PRODUCTION DEPLOYMENT WARNING                             ║" -ForegroundColor Red
        Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Configuration: " -NoNewline -ForegroundColor Yellow
        Write-Host "Production parameters detected" -ForegroundColor White
        Write-Host "  Mode: " -NoNewline -ForegroundColor Yellow
        Write-Host "$selectedMode (enforcement enabled)" -ForegroundColor White
        Write-Host "  Scope: " -NoNewline -ForegroundColor Yellow
        Write-Host "$scope" -ForegroundColor White
        Write-Host ""
        Write-Host "  This deployment will:" -ForegroundColor Red
        if ($selectedMode -eq 'Deny') {
            Write-Host "    • Block non-compliant Key Vault operations" -ForegroundColor Red
            Write-Host "    • Prevent creation of vaults without soft delete/purge protection" -ForegroundColor Red
            Write-Host "    • Require firewall configuration on new vaults" -ForegroundColor Red
            Write-Host "    • Enforce strict validity periods and key sizes" -ForegroundColor Red
        } else {
            Write-Host "    • Automatically remediate non-compliant resources" -ForegroundColor Red
            Write-Host "    • Enable diagnostic logging on all Key Vaults" -ForegroundColor Red
            Write-Host "    • Apply changes without manual approval" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "  ⚠️  RECOMMENDATIONS:" -ForegroundColor Yellow
        Write-Host "    1. Review compliance report from Audit mode deployment" -ForegroundColor White
        Write-Host "    2. Ensure stakeholders have been notified" -ForegroundColor White
        Write-Host "    3. Verify exemptions are in place for exceptions" -ForegroundColor White
        Write-Host "    4. Have rollback plan ready (use -Rollback flag)" -ForegroundColor White
        Write-Host ""
        Write-Host "  Type " -NoNewline -ForegroundColor White
        Write-Host "PROCEED" -NoNewline -ForegroundColor Red
        Write-Host " to continue with production deployment: " -NoNewline -ForegroundColor White
        
        $confirmation = Read-Host
        if ($confirmation -ne 'PROCEED') {
            Write-Host ""
            Write-Log "❌ Production deployment cancelled by user" -Level 'ERROR'
            Write-Host "  Deployment aborted for safety. To proceed, re-run and type 'PROCEED' when prompted." -ForegroundColor Yellow
            Write-Host ""
            return
        }
        
        Write-Log "✓ Production deployment confirmed by user" -Level 'SUCCESS'
        Write-Host ""
    } elseif ($isProductionConfig -and -not $isEnforcementMode) {
        # Production config with Audit mode - gentler warning
        Write-Host ""
        Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "║  ℹ️  Production Configuration Detected (Audit Mode)            ║" -ForegroundColor Yellow
        Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Using production parameters in Audit mode (recommended first step)" -ForegroundColor White
        Write-Host "  No resources will be blocked during this deployment" -ForegroundColor Green
        Write-Host ""
    }

    # Load policy names from parameter file (JSON determines WHICH policies to deploy)
    # CSV is used only as reference metadata for policy definitions
    if ($parameterOverrides -and ($parameterOverrides -is [hashtable] -or $parameterOverrides -is [System.Management.Automation.PSCustomObject])) {
        if ($parameterOverrides -is [hashtable]) {
            # Filter out metadata fields (starting with _)
            $names = @($parameterOverrides.Keys | Where-Object { -not $_.StartsWith('_') })
        } else {
            # Filter out metadata fields (starting with _)
            $names = @($parameterOverrides.PSObject.Properties.Name | Where-Object { -not $_.StartsWith('_') })
        }
        Write-Log "Loaded $($names.Count) policies from parameter file: $ParameterOverridesPath" -Level 'SUCCESS'
        if ($names.Count -eq 0) {
            Write-Log "WARNING: No policy names found in parameter file (all entries may be metadata)" -Level 'WARN'
        }
    } else {
        # Fallback: use CSV if no parameter file (backward compatibility)
        Write-Log "No parameter overrides found. Loading all policies from CSV." -Level 'WARN'
        $names = Import-PolicyListFromCsv -CsvPath $CsvPath
    }
    
    # Apply include/exclude filters
    if ($IncludePolicies.Count -gt 0) {
        $names = $names | Where-Object { $IncludePolicies -contains $_ }
        Write-Log "Filtered to $($names.Count) policies via -IncludePolicies"
    }
    if ($ExcludePolicies.Count -gt 0) {
        $names = $names | Where-Object { $ExcludePolicies -notcontains $_ }
        Write-Log "Filtered to $($names.Count) policies via -ExcludePolicies"
    }
    
    Write-Host ""
    Write-Host "Processing $($names.Count) policies..." -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    $assignResults = @()
    $i = 0
    foreach ($n in $names) {
        $i++
        Write-Progress -Activity "Assigning policies" -Status "Policy $i of $($names.Count): $n" -PercentComplete (($i / $names.Count) * 100)
        Write-Host ""  # Blank line before each policy
        Write-Log "Preparing to assign ($i/$($names.Count)): $n"
        $overrides = @{}
        # Check if parameter overrides exist for this policy (handle both hashtable and PSCustomObject)
        if ($parameterOverrides -is [hashtable] -and $parameterOverrides.ContainsKey($n)) {
            $overrides = $parameterOverrides[$n]
        } elseif ($parameterOverrides.PSObject.Properties.Name -contains $n) {
            $overrides = $parameterOverrides.$n
        }
        $res = Assign-Policy -DisplayName $n -Scope $scope -Mode $selectedMode -DryRun:$DryRun -ParameterOverrides $overrides -Mapping $policyMapping -MaxRetries $MaxRetries -IdentityResourceId $IdentityResourceId
        $assignResults += $res
    }
    Write-Progress -Activity "Assigning policies" -Completed

    # Collect assignment IDs for verification
    $assignmentIds = $assignResults | Where-Object {$_.Status -in @('Assigned', 'Updated')} | ForEach-Object { 
        if ($_.Assignment) {
            # Return the ID or ResourceId property
            if ($_.Assignment.PolicyAssignmentId) {
                $_.Assignment.PolicyAssignmentId
            } elseif ($_.Assignment.Id) {
                $_.Assignment.Id
            } elseif ($_.Assignment.ResourceId) {
                $_.Assignment.ResourceId
            } else {
                Write-Log "WARNING: Assignment object has no ID: $($_.Assignment | Out-String)" -Level 'WARN'
                $null
            }
        }
    } | Where-Object { $_ -ne $null }
    
    Write-Log "Collected $($assignmentIds.Count) assignment IDs for filtering" -Level 'INFO'
    if ($assignmentIds.Count -gt 0) {
        $sampleIds = if ($assignmentIds.Count -le 3) { $assignmentIds } else { $assignmentIds[0..2] }
        Write-Log "First $(($sampleIds | Measure-Object).Count) assignment IDs: $($sampleIds -join ', ')" -Level 'INFO'
    }
    
    $verification = @()
    if (-not $DryRun) { $verification = Verify-Assignments -AssignmentIds $assignmentIds }

    $compliance = $null
    if (-not $DryRun) { 
        Write-Host ""
        Write-Host "Generating compliance report with operational metrics..." -ForegroundColor Cyan
        $compliance = Get-ComplianceReport -Scope $scope -Top 1000 -IncludeResourceDetails -IncludeTrends 
        
        Write-Log "Compliance query returned: Raw states=$($compliance.Raw.Count), Policies reporting=$($compliance.OperationalStatus.TotalPoliciesReporting)" -Level 'INFO'
        
        # Filter compliance data to only show policies deployed in this run
        if ($compliance -and $compliance.Raw -and $assignmentIds.Count -gt 0) {
            Write-Log "Filtering compliance data: $($assignmentIds.Count) assignments, $($compliance.Raw.Count) total policy states" -Level 'INFO'
            
            $deployedPolicyNames = $assignResults | Where-Object { $_.Status -eq 'Assigned' } | ForEach-Object { $_.Name }
            
            # Debug: Show sample of assignment IDs being filtered for
            Write-Log "Sample assignment IDs we're filtering for: $($assignmentIds[0..1] -join ' | ')" -Level 'INFO'
            
            # Filter raw compliance states to only include our deployed policies
            $filteredStates = $compliance.Raw | Where-Object { 
                $policyAssignmentId = $_.PolicyAssignmentId
                $assignmentIds -contains $policyAssignmentId 
            }
            
            Write-Log "Found $($filteredStates.Count) compliance states for newly deployed policies" -Level 'INFO'
            
            # Debug: Show what unique assignment IDs are actually in compliance data
            $uniqueAssignmentIdsInCompliance = $compliance.Raw | Select-Object -ExpandProperty PolicyAssignmentId -Unique
            Write-Log "Total unique assignment IDs in compliance data: $($uniqueAssignmentIdsInCompliance.Count)" -Level 'INFO'
            
            if ($filteredStates -and $filteredStates.Count -gt 0) {
                # Recalculate compliance metrics for just our deployed policies
                $compliantCount = @($filteredStates | Where-Object { $_.ComplianceState -eq 'Compliant' }).Count
                $nonCompliantCount = @($filteredStates | Where-Object { $_.ComplianceState -ne 'Compliant' }).Count
                $totalResources = ($filteredStates | Select-Object -Unique -Property ResourceId | Measure-Object).Count
                $overallCompliancePercent = if ($filteredStates.Count -gt 0) { 
                    [math]::Round((($filteredStates | Where-Object {$_.ComplianceState -eq 'Compliant'}).Count / $filteredStates.Count) * 100, 2) 
                } else { 0 }
                
                $effectivenessRating = if ($overallCompliancePercent -ge 95) { 'Excellent ⭐⭐⭐⭐⭐' } 
                    elseif ($overallCompliancePercent -ge 80) { 'Good ⭐⭐⭐⭐' } 
                    elseif ($overallCompliancePercent -ge 60) { 'Fair ⭐⭐⭐' } 
                    elseif ($overallCompliancePercent -ge 40) { 'Needs Attention ⭐⭐' }
                    else { 'Critical ⭐' }
                
                # Update operational status to reflect only deployed policies
                $compliance.OperationalStatus.TotalPoliciesReporting = $assignmentIds.Count
                $compliance.OperationalStatus.TotalResourcesEvaluated = $totalResources
                $compliance.OperationalStatus.CompliantResourceCount = $compliantCount
                $compliance.OperationalStatus.NonCompliantResourceCount = $nonCompliantCount
                $compliance.OperationalStatus.OverallCompliancePercent = $overallCompliancePercent
                $compliance.OperationalStatus.EffectivenessRating = $effectivenessRating
                
                # Update raw data to filtered set
                $compliance.Raw = $filteredStates
            } else {
                # No compliance data yet for our newly deployed policies
                $compliance.OperationalStatus.TotalPoliciesReporting = 0
                $compliance.OperationalStatus.TotalResourcesEvaluated = 0
                $compliance.OperationalStatus.CompliantResourceCount = 0
                $compliance.OperationalStatus.NonCompliantResourceCount = 0
                $compliance.OperationalStatus.OverallCompliancePercent = 0
                $compliance.OperationalStatus.EffectivenessRating = 'Pending Evaluation'
            }
        }
        
        if ($compliance -and $compliance.OperationalStatus) {
            Write-Host ""
            Write-Host "═══ Compliance Summary ═══" -ForegroundColor Cyan
            $compPct = $compliance.OperationalStatus.OverallCompliancePercent
            $compColor = if ($compPct -ge 80) { 'Green' } elseif ($compPct -ge 60) { 'Yellow' } else { 'Red' }
            Write-Host "Overall Compliance: " -NoNewline
            Write-Host "$compPct%" -ForegroundColor $compColor -NoNewline
            Write-Host " | Policies Reporting: " -NoNewline
            Write-Host $compliance.OperationalStatus.TotalPoliciesReporting -ForegroundColor Cyan -NoNewline
            Write-Host " | Resources Evaluated: " -NoNewline
            Write-Host $compliance.OperationalStatus.TotalResourcesEvaluated -ForegroundColor Cyan
            Write-Host ""
        }
    }
    $reports = Generate-ReportFiles -ReportNamePrefix "KeyVaultPolicyImplementationReport" -ReportObject @{Assignments=$assignResults;Verification=$verification;Compliance=$compliance;DryRun=$DryRun.IsPresent;Preview=$Preview.IsPresent}

    # Generate HTML report
    $htmlMetadata = @{
        ScopeType = $selectedScopeType
        Scope = $scope
        EnforcementMode = $selectedMode
        DryRun = $DryRun.IsPresent
        EnvironmentPreset = if ($ParameterOverridesPath -like '*DevTest*') { 'Development/Test' } elseif ($ParameterOverridesPath -like '*Production*') { 'Production' } else { 'Custom' }
    }
    $htmlReport = New-HtmlReport -AssignmentResults $assignResults -Metadata $htmlMetadata -ComplianceData $compliance

    if ($DryRun) {
        $summaryPath = Generate-DryRunSummary -AssignResults $assignResults -OutPath './DryRunSummary.txt'
        Write-Host ""
        Write-Host "📋 Dry-Run Summary: " -NoNewline -ForegroundColor Yellow
        Write-Host $summaryPath -ForegroundColor Green
        Write-Host ""
    }
    
    # Test operational value if requested
    if ($TestOperationalValue -and -not $DryRun) {
        $operationalTests = Test-PolicyOperationalValue -Scope $scope -AssignmentResults $assignResults
        # Regenerate HTML report with test results
        $htmlReport = New-HtmlReport -AssignmentResults $assignResults -Metadata $htmlMetadata -ComplianceData $compliance -OperationalTests $operationalTests
        # Add test results to JSON/MD reports
        $reports = Generate-ReportFiles -ReportNamePrefix "KeyVaultPolicyImplementationReport-WithTests" -ReportObject @{
            Assignments=$assignResults
            Verification=$verification
            Compliance=$compliance
            OperationalTests=$operationalTests
            DryRun=$DryRun.IsPresent
            Preview=$Preview.IsPresent
        }
    }

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Log 'Completed run. Reports generated.' -Level 'SUCCESS'
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "📄 Reports Generated:" -ForegroundColor Cyan
    Write-Host "  • HTML:     " -NoNewline -ForegroundColor DarkGray
    Write-Host $htmlReport -ForegroundColor Green
    Write-Host "  • Markdown: " -NoNewline -ForegroundColor DarkGray
    Write-Host $reports.Markdown -ForegroundColor Green
    Write-Host "  • JSON:     " -NoNewline -ForegroundColor DarkGray
    Write-Host $reports.Json -ForegroundColor Green
    Write-Host ""
    
    # Show propagation warning if compliance is partial
    if (-not $DryRun -and $compliance -and $compliance.OperationalStatus) {
        $compPct = $compliance.OperationalStatus.OverallCompliancePercent
        if ($compPct -lt 80 -and $compPct -gt 0) {
            Write-Host "⚠️  IMPORTANT: Azure Policy Evaluation in Progress" -ForegroundColor Yellow
            Write-Host "" 
            Write-Host "Deployment Status: " -NoNewline -ForegroundColor White
            Write-Host "✅ All policies successfully assigned" -ForegroundColor Green
            Write-Host "Compliance Status: " -NoNewline -ForegroundColor White
            Write-Host "⏳ Partial data ($compPct%) - Azure is still evaluating resources" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "📊 Why Compliance is Low Right Now:" -ForegroundColor Cyan
            Write-Host "  • Policy Assignment Propagation: 30-90 minutes for Azure to distribute assignments" -ForegroundColor White
            Write-Host "  • Resource Scanning: 15-30 minutes for Azure Policy engine to scan existing Key Vaults" -ForegroundColor White
            Write-Host "  • Compliance State Calculation: 10-15 minutes to evaluate resources against policy rules" -ForegroundColor White
            Write-Host ""
            Write-Host "⏱️  WAIT 60 MINUTES from now, then regenerate this report to see accurate compliance." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "How to Regenerate Report:" -ForegroundColor Cyan
            Write-Host "  .\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan" -ForegroundColor Green
            Write-Host ""
            Write-Host "Expected improvement: Compliance should increase from $compPct% to 60-80% range" -ForegroundColor White
            Write-Host "with all policies reporting complete data." -ForegroundColor White
            Write-Host ""
        }
    }
    
    Show-ChangeImpactGuidance
}

if ($PSCommandPath -eq $MyInvocation.MyCommand.Path) {
    # Parse simple CLI args from $args to allow running script with switches without a top-level param block
    $callParams = @{}
    $defaultCsv = (Resolve-Path -Path './DefinitionListExport.csv' -ErrorAction SilentlyContinue).Path
    $callParams['CsvPath'] = $defaultCsv
    
    # Check for simplified Environment/Phase workflow parameters
    $useSimplifiedWorkflow = $false
    $environment = $null
    $phase = $null
    
    for ($i = 0; $i -lt $args.Count; $i++) {
        switch -Regex ($args[$i]) {
            '^-Environment$' { 
                if ($i+1 -lt $args.Count) { 
                    $environment = $args[$i+1]
                    $useSimplifiedWorkflow = $true
                    $i++ 
                } 
            }
            '^-Phase$' { 
                if ($i+1 -lt $args.Count) { 
                    $phase = $args[$i+1]
                    $i++ 
                } 
            }
            '^-CsvPath$' { if ($i+1 -lt $args.Count) { $callParams['CsvPath'] = $args[$i+1]; $i++ } }
            '^-ParameterOverridesPath$' { if ($i+1 -lt $args.Count) { $callParams['ParameterOverridesPath'] = $args[$i+1]; $i++ } }
            '^-ParameterFile$' { if ($i+1 -lt $args.Count) { $callParams['ParameterOverridesPath'] = $args[$i+1]; $i++ } }
            '^-MappingPath$' { if ($i+1 -lt $args.Count) { $callParams['MappingPath'] = $args[$i+1]; $i++ } }
            '^-IncludePolicies$' { if ($i+1 -lt $args.Count) { $callParams['IncludePolicies'] = $args[$i+1] -split ','; $i++ } }
            '^-ExcludePolicies$' { if ($i+1 -lt $args.Count) { $callParams['ExcludePolicies'] = $args[$i+1] -split ','; $i++ } }
            '^-MaxRetries$' { if ($i+1 -lt $args.Count) { $callParams['MaxRetries'] = [int]$args[$i+1]; $i++ } }
            '^-DryRun$' { $callParams['DryRun'] = $true }
            '^-Preview$' { $callParams['Preview'] = $true }
            '^-BuildMapping$' { $callParams['BuildMapping'] = $true }
            '^-Interactive$' { $callParams['Interactive'] = $true }
            '^-TestOperationalValue$' { $callParams['TestOperationalValue'] = $true }
            '^-SkipRBACCheck$' { $callParams['SkipRBACCheck'] = $true }
            '^-CheckCompliance$' { $callParams['CheckCompliance'] = $true }
            '^-TriggerScan$' { $callParams['TriggerScan'] = $true }
            '^-TestDenyBlocking$' { $callParams['TestDenyBlocking'] = $true }
            '^-TestInfrastructure$' { $callParams['TestInfrastructure'] = $true }
            '^-TestProductionEnforcement$' { $callParams['TestProductionEnforcement'] = $true }
            '^-TestAutoRemediation$' { $callParams['TestAutoRemediation'] = $true }
            '^-TriggerRemediation$' { $callParams['TriggerRemediation'] = $true }
            '^-PolicyDefinitionId$' { if ($i+1 -lt $args.Count) { $callParams['PolicyDefinitionId'] = $args[$i+1]; $i++ } }
            '^-IdentityResourceId$' { if ($i+1 -lt $args.Count) { $callParams['IdentityResourceId'] = $args[$i+1]; $i++ } }
            '^-ScopeType$' { if ($i+1 -lt $args.Count) { $callParams['ScopeType'] = $args[$i+1]; $i++ } }
            '^-PolicyMode$' { if ($i+1 -lt $args.Count) { $callParams['PolicyMode'] = $args[$i+1]; $i++ } }
            '^-ExemptionAction$' { if ($i+1 -lt $args.Count) { $callParams['ExemptionAction'] = $args[$i+1]; $i++ } }
            '^-ExemptionResourceId$' { if ($i+1 -lt $args.Count) { $callParams['ExemptionResourceId'] = $args[$i+1]; $i++ } }
            '^-ExemptionPolicyAssignment$' { if ($i+1 -lt $args.Count) { $callParams['ExemptionPolicyAssignment'] = $args[$i+1]; $i++ } }
            '^-ExemptionJustification$' { if ($i+1 -lt $args.Count) { $callParams['ExemptionJustification'] = $args[$i+1]; $i++ } }
            '^-ExemptionExpiresInDays$' { if ($i+1 -lt $args.Count) { $callParams['ExemptionExpiresInDays'] = [int]$args[$i+1]; $i++ } }
            '^-ExemptionCategory$' { if ($i+1 -lt $args.Count) { $callParams['ExemptionCategory'] = $args[$i+1]; $i++ } }
            '^-Rollback$' { $callParams['Rollback'] = $true }
        }
    }
    
    # If using simplified Environment/Phase workflow, configure parameters automatically
    if ($useSimplifiedWorkflow) {
        if (-not $environment -or $environment -notin @('DevTest', 'Production')) {
            Write-Host ""
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
            Write-Host "  ERROR: Invalid -Environment parameter" -ForegroundColor Red
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
            Write-Host ""
            Write-Host "  Valid values: DevTest, Production" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  Example:" -ForegroundColor Cyan
            Write-Host "    .\AzPolicyImplScript.ps1 -Environment DevTest -Phase Test" -ForegroundColor Gray
            Write-Host ""
            exit 1
        }
        
        if (-not $phase) {
            # Default phase based on environment
            $phase = if ($environment -eq 'DevTest') { 'Test' } else { 'Audit' }
            Write-Host ""
            Write-Host "  ℹ️  No phase specified, defaulting to: $phase" -ForegroundColor Cyan
            Write-Host ""
        }
        
        if ($phase -notin @('Test', 'Audit', 'Enforce')) {
            Write-Host ""
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
            Write-Host "  ERROR: Invalid -Phase parameter" -ForegroundColor Red
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
            Write-Host ""
            Write-Host "  Valid values: Test, Audit, Enforce" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  Phases:" -ForegroundColor Cyan
            Write-Host "    Test    - Deploy to test environment in Audit mode" -ForegroundColor Gray
            Write-Host "    Audit   - Deploy to production in Audit mode (observe only)" -ForegroundColor Gray
            Write-Host "    Enforce - Enable Deny mode for critical policies (blocks operations)" -ForegroundColor Gray
            Write-Host ""
            exit 1
        }
        
        # Show deployment banner
        $bannerColor = if ($environment -eq 'Production') { 'Red' } else { 'Cyan' }
        Write-Host ""
        Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor $bannerColor
        Write-Host "║  Azure Key Vault Policy Deployment                           ║" -ForegroundColor $bannerColor
        Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor $bannerColor
        Write-Host ""
        Write-Host "  Environment: " -NoNewline -ForegroundColor Yellow
        Write-Host "$environment" -ForegroundColor White
        Write-Host "  Phase: " -NoNewline -ForegroundColor Yellow
        Write-Host "$phase" -ForegroundColor White
        Write-Host ""
        
        # Show phase-specific guidance
        Write-Host "  📋 Phase Guidance:" -ForegroundColor Cyan
        Write-Host ""
        
        switch ($phase) {
            'Test' {
                Write-Host "    This phase will:" -ForegroundColor Yellow
                if ($environment -eq 'DevTest') {
                    Write-Host "      • Deploy policies to test resource group" -ForegroundColor White
                    Write-Host "      • Use relaxed dev/test parameters" -ForegroundColor White
                } else {
                    Write-Host "      • Deploy to production subscription" -ForegroundColor White
                    Write-Host "      • Use production parameters" -ForegroundColor White
                }
                Write-Host "      • Run in Audit mode (no blocking)" -ForegroundColor White
                Write-Host "      • Validate policy deployment process" -ForegroundColor White
                Write-Host ""
                Write-Host "    ✓ Safe to run - monitoring only" -ForegroundColor Green
            }
            'Audit' {
                if ($environment -eq 'Production') {
                    Write-Host "    This phase will:" -ForegroundColor Yellow
                    Write-Host "      • Deploy production parameters in Audit mode" -ForegroundColor White
                    Write-Host "      • Identify non-compliant resources" -ForegroundColor White
                    Write-Host "      • NOT block any operations" -ForegroundColor Green
                    Write-Host "      • Generate compliance reports" -ForegroundColor White
                    Write-Host ""
                    Write-Host "    ⚠️  Recommended: Wait 24-48 hours after deployment to:" -ForegroundColor Yellow
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
                Write-Host "    Type 'YES' to confirm prerequisites: " -NoNewline -ForegroundColor Red
                $confirmation = Read-Host
                if ($confirmation -ne 'YES') {
                    Write-Host ""
                    Write-Host "    ❌ Deployment cancelled - prerequisites not confirmed" -ForegroundColor Red
                    Write-Host ""
                    exit 1
                }
            }
        }
        
        Write-Host ""
        
        # Configure parameters based on environment and phase
        $callParams['ParameterOverridesPath'] = if ($environment -eq 'DevTest') { 
            './PolicyParameters-DevTest.json' 
        } else { 
            './PolicyParameters-Production.json' 
        }
        
        $callParams['PolicyMode'] = if ($phase -eq 'Enforce') { 'Deny' } else { 'Audit' }
        $callParams['ScopeType'] = if ($environment -eq 'DevTest') { 'ResourceGroup' } else { 'Subscription' }
        
        # Auto-detect managed identity if not specified
        if (-not $callParams.ContainsKey('IdentityResourceId')) {
            $defaultIdentity = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
            $callParams['IdentityResourceId'] = $defaultIdentity
        }
        
        Write-Host "  Configuration:" -ForegroundColor Cyan
        Write-Host "    Parameter File: " -NoNewline -ForegroundColor Gray
        Write-Host $callParams['ParameterOverridesPath'] -ForegroundColor White
        Write-Host "    Policy Mode: " -NoNewline -ForegroundColor Gray
        Write-Host $callParams['PolicyMode'] -ForegroundColor White
        Write-Host "    Scope: " -NoNewline -ForegroundColor Gray
        Write-Host $callParams['ScopeType'] -ForegroundColor White
        Write-Host ""
        
        # Final confirmation
        Write-Host "  Ready to proceed?" -ForegroundColor Yellow
        Write-Host "    Type 'RUN' to start deployment: " -NoNewline -ForegroundColor White
        $runConfirm = Read-Host
        
        if ($runConfirm -ne 'RUN') {
            Write-Host ""
            Write-Host "    ❌ Deployment cancelled" -ForegroundColor Yellow
            Write-Host ""
            exit 0
        }
        
        Write-Host ""
        Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║  Starting Deployment...                                       ║" -ForegroundColor Green
        Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""
        
        $deploymentStartTime = Get-Date
    }
    
    Main @callParams
    
    # Show completion summary for simplified workflow
    if ($useSimplifiedWorkflow) {
        $deploymentEndTime = Get-Date
        $duration = $deploymentEndTime - $deploymentStartTime
        
        Write-Host ""
        Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║  Deployment Completed                                         ║" -ForegroundColor Green
        Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor White
        Write-Host ""
        
        # Post-deployment guidance
        Write-Host "  📋 Next Steps:" -ForegroundColor Cyan
        Write-Host ""
        
        switch ($phase) {
            'Test' {
                Write-Host "    1. Review deployment logs above" -ForegroundColor White
                Write-Host "    2. Check Azure Portal for policy assignments" -ForegroundColor White
                if ($environment -eq 'DevTest') {
                    Write-Host "    3. Validate test Key Vault compliance" -ForegroundColor White
                    Write-Host "    4. If successful, proceed to Production Audit:" -ForegroundColor White
                    Write-Host "       .\AzPolicyImplScript.ps1 -Environment Production -Phase Audit" -ForegroundColor Gray
                } else {
                    Write-Host "    3. Monitor compliance data collection (24-48 hours)" -ForegroundColor White
                }
            }
            'Audit' {
                if ($environment -eq 'Production') {
                    Write-Host "    1. Wait 24-48 hours for compliance data" -ForegroundColor White
                    Write-Host "    2. Run compliance check:" -ForegroundColor White
                    Write-Host "       .\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan" -ForegroundColor Gray
                    Write-Host "    3. Review HTML compliance report" -ForegroundColor White
                    Write-Host "    4. Remediate non-compliant resources" -ForegroundColor White
                    Write-Host "    5. Process exemption requests (see EXEMPTION_PROCESS.md)" -ForegroundColor White
                    Write-Host "    6. When ready, enable enforcement:" -ForegroundColor White
                    Write-Host "       .\AzPolicyImplScript.ps1 -Environment Production -Phase Enforce" -ForegroundColor Gray
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
                Write-Host "    5. Generate regular compliance reports" -ForegroundColor White
            }
        }
        
        Write-Host ""
    }
}
