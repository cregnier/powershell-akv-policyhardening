<#
.SYNOPSIS
  Azure Policy implementation helper for Key Vault policies.

.DESCRIPTION
  This script automates assigning built-in Azure Policy definitions (Key Vault
  related) and provides tools to check assignments, query compliance, create
  reporting artifacts, and scaffold alerting. It documents actions as it runs
  and emits detailed reports with headers and footers.

.NOTES
  - Requires Az PowerShell modules. The script can install missing modules.
  - Run interactively from a user account with sufficient RBAC (Owner or
    Policy Contributor) for the target scope. If you lack roles the script
    prints a request template to ask your security/infra team.

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
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Azure Policy Implementation Assistant" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Choose environment preset:" -ForegroundColor Yellow
    Write-Host "  1) Dev/Test  - Relaxed parameters, all Audit mode, longer validity periods"
    Write-Host "  2) Production - Strict parameters, critical policies Deny, shorter validity periods"
    Write-Host "  3) Custom    - Use existing PolicyParameters.json"
    Write-Host ""
    $envChoice = Read-Host "Select environment [1-3]"
    
    $paramFile = './PolicyParameters.json'
    switch ($envChoice) {
        '1' { 
            $paramFile = './PolicyParameters-DevTest.json'
            Write-Host "✓ Dev/Test preset selected" -ForegroundColor Green
        }
        '2' { 
            $paramFile = './PolicyParameters-Production.json'
            Write-Host "✓ Production preset selected" -ForegroundColor Green
        }
        '3' { 
            Write-Host "✓ Using custom PolicyParameters.json" -ForegroundColor Green
        }
        default { 
            Write-Host "✓ Default to custom PolicyParameters.json" -ForegroundColor Green
        }
    }
    
    Write-Host ""
    Write-Host "Choose policy scope:" -ForegroundColor Yellow
    Write-Host "  1) All 46 policies from CSV"
    Write-Host "  2) Critical policies only (soft delete, purge protection, expiration dates)"
    Write-Host "  3) Custom selection (you'll provide list)"
    Write-Host ""
    $scopeChoice = Read-Host "Select scope [1-3]"
    
    $includePolicies = @()
    switch ($scopeChoice) {
        '1' { 
            Write-Host "✓ All 46 policies selected" -ForegroundColor Green
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
            Write-Host "✓ Critical policies selected ($($includePolicies.Count) policies)" -ForegroundColor Green
        }
        '3' {
            Write-Host "Enter comma-separated policy names (or leave blank to review CSV first):"
            $customInput = Read-Host "Policy names"
            if ($customInput) {
                $includePolicies = $customInput -split ',' | ForEach-Object { $_.Trim() }
                Write-Host "✓ Custom selection: $($includePolicies.Count) policies" -ForegroundColor Green
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
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  DENY BLOCKING TEST MODE" -ForegroundColor Magenta
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "This will test that Deny policies block non-compliant operations." -ForegroundColor White
    Write-Host "Expected result: All test operations should be DENIED by policy." -ForegroundColor Yellow
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
            Write-Host "⚠️  Resource group '$ResourceGroupName' not found. Creating..." -ForegroundColor Yellow
            $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
            Write-Host "✅ Resource group created." -ForegroundColor Green
        }
    } catch {
        Write-Host "❌ Failed to access/create resource group: $_" -ForegroundColor Red
        return $testResults
    }
    
    # Test 1: Create Key Vault WITHOUT purge protection (should be DENIED)
    Write-Host ""
    Write-Host "🧪 Test 1: Create Key Vault WITHOUT purge protection" -ForegroundColor Cyan
    Write-Host "   Expected: DENIED by policy" -ForegroundColor Gray
    $testResults.TotalTests++
    
    $testVaultName = "kv-deny-test-" + (Get-Random -Minimum 1000 -Maximum 9999)
    try {
        # Note: SoftDelete is always enabled by default now, can't be disabled
        # Test purge protection instead
        $vault = New-AzKeyVault -Name $testVaultName -ResourceGroupName $ResourceGroupName `
            -Location $Location -ErrorAction Stop
        
        Write-Host "   ❌ FAIL: Vault created without purge protection (policy did NOT block)" -ForegroundColor Red
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
            Write-Host "   ✅ PASS: Blocked by policy" -ForegroundColor Green
            Write-Host "   Policy: $($errorMessage -replace '.*PolicyDefinitionName\s*:\s*([^,]+).*','$1')" -ForegroundColor Gray
            $testResults.Blocked++
            $testResults.TestDetails += @{
                Test = "Create vault without purge protection"
                Result = "BLOCKED"
                PolicyName = ($errorMessage -replace '.*PolicyDefinitionName\s*:\s*([^,]+).*','$1')
                Message = $errorMessage.Split([Environment]::NewLine)[0]
            }
        } else {
            Write-Host "   ⚠️  ERROR: Unexpected failure" -ForegroundColor Yellow
            Write-Host "   $errorMessage" -ForegroundColor Gray
            $testResults.Errors += "Test 1: $errorMessage"
        }
    }
    
    # Test 2: Create Key Vault with public network access (should be DENIED if policy enforces private-only)
    Write-Host ""
    Write-Host "🧪 Test 2: Create Key Vault with public network access enabled" -ForegroundColor Cyan
    Write-Host "   Expected: DENIED by policy (if public network disabled policy is in Enforce)" -ForegroundColor Gray
    $testResults.TotalTests++
    
    $testVaultName = "kv-deny-test-" + (Get-Random -Minimum 1000 -Maximum 9999)
    try {
        $vault = New-AzKeyVault -Name $testVaultName -ResourceGroupName $ResourceGroupName `
            -Location $Location -EnablePurgeProtection -PublicNetworkAccess 'Enabled' -ErrorAction Stop
        
        Write-Host "   ⚠️  INFO: Vault created with public access (policy may be Audit-only or not enforcing this)" -ForegroundColor Yellow
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
            Write-Host "   ✅ PASS: Blocked by policy" -ForegroundColor Green
            Write-Host "   Policy: $($errorMessage -replace '.*PolicyDefinitionName\s*:\s*([^,]+).*','$1')" -ForegroundColor Gray
            $testResults.Blocked++
            $testResults.TestDetails += @{
                Test = "Create vault without purge protection"
                Result = "BLOCKED"
                PolicyName = ($errorMessage -replace '.*PolicyDefinitionName\s*:\s*([^,]+).*','$1')
                Message = $errorMessage.Split([Environment]::NewLine)[0]
            }
        } else {
            Write-Host "   ⚠️  ERROR: Unexpected failure" -ForegroundColor Yellow
            Write-Host "   $errorMessage" -ForegroundColor Gray
            $testResults.Errors += "Test 2: $errorMessage"
        }
    }
    
    # Test 3: Create compliant vault, then try to add key WITHOUT expiration (should be DENIED)
    Write-Host ""
    Write-Host "🧪 Test 3: Create key WITHOUT expiration date" -ForegroundColor Cyan
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
            
            Write-Host "   ❌ FAIL: Key created without expiration (policy did NOT block)" -ForegroundColor Red
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
                Write-Host "   ✅ PASS: Blocked by policy" -ForegroundColor Green
                Write-Host "   Policy: $($errorMessage -replace '.*PolicyDefinitionName\s*:\s*([^,]+).*','$1')" -ForegroundColor Gray
                $testResults.Blocked++
                $testResults.TestDetails += @{
                    Test = "Create key without expiration"
                    Result = "BLOCKED"
                    PolicyName = ($errorMessage -replace '.*PolicyDefinitionName\s*:\s*([^,]+).*','$1')
                    Message = $errorMessage.Split([Environment]::NewLine)[0]
                }
            } else {
                Write-Host "   ⚠️  ERROR: Unexpected failure" -ForegroundColor Yellow
                Write-Host "   $errorMessage" -ForegroundColor Gray
                $testResults.Errors += "Test 3: $errorMessage"
            }
        }
        
        # Clean up compliant vault
        Remove-AzKeyVault -Name $compliantVaultName -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-Host "   ⚠️  ERROR: Failed to create compliant vault for testing" -ForegroundColor Yellow
        Write-Host "   $($_.Exception.Message)" -ForegroundColor Gray
        $testResults.Errors += "Test 3 setup: $($_.Exception.Message)"
    }
    
    # Test 4: Create certificate WITHOUT expiration (should be DENIED)
    Write-Host ""
    Write-Host "🧪 Test 4: Create certificate with excessive validity period" -ForegroundColor Cyan
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
            
            Write-Host "   ❌ FAIL: Certificate created with 60-month validity (policy did NOT block)" -ForegroundColor Red
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
                Write-Host "   ✅ PASS: Blocked by policy" -ForegroundColor Green
                Write-Host "   Policy: $($errorMessage -replace '.*PolicyDefinitionName\s*:\s*([^,]+).*','$1')" -ForegroundColor Gray
                $testResults.Blocked++
                $testResults.TestDetails += @{
                    Test = "Create certificate with excessive validity period"
                    Result = "BLOCKED"
                    PolicyName = ($errorMessage -replace '.*PolicyDefinitionName\s*:\s*([^,]+).*','$1')
                    Message = $errorMessage.Split([Environment]::NewLine)[0]
                }
            } else {
                Write-Host "   ⚠️  ERROR: Unexpected failure" -ForegroundColor Yellow
                Write-Host "   $errorMessage" -ForegroundColor Gray
                $testResults.Errors += "Test 4: $errorMessage"
            }
        }
        
        # Clean up cert vault
        Remove-AzKeyVault -Name $certVaultName -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-Host "   ⚠️  ERROR: Failed to create vault for certificate testing" -ForegroundColor Yellow
        Write-Host "   $($_.Exception.Message)" -ForegroundColor Gray
        $testResults.Errors += "Test 4 setup: $($_.Exception.Message)"
    }
    
    # Display summary
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  TEST SUMMARY" -ForegroundColor Magenta
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "Total Tests: $($testResults.TotalTests)" -ForegroundColor White
    Write-Host "✅ Blocked (PASS): $($testResults.Blocked)" -ForegroundColor Green
    Write-Host "❌ Not Blocked (FAIL): $($testResults.NotBlocked)" -ForegroundColor Red
    Write-Host "⚠️  Errors: $($testResults.Errors.Count)" -ForegroundColor Yellow
    
    $successRate = if ($testResults.TotalTests -gt 0) {
        [math]::Round(($testResults.Blocked / $testResults.TotalTests) * 100, 2)
    } else { 0 }
    
    Write-Host ""
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 75) { 'Green' } elseif ($successRate -ge 50) { 'Yellow' } else { 'Red' })
    Write-Host ""
    
    # Display detailed results
    if ($testResults.TestDetails.Count -gt 0) {
        Write-Host "Detailed Results:" -ForegroundColor Cyan
        foreach ($detail in $testResults.TestDetails) {
            Write-Host "  • $($detail.Test): $($detail.Result)" -ForegroundColor White
            if ($detail.PolicyName) {
                Write-Host "    Policy: $($detail.PolicyName)" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }
    
    if ($testResults.Errors.Count -gt 0) {
        Write-Host "Errors Encountered:" -ForegroundColor Yellow
        foreach ($error in $testResults.Errors) {
            Write-Host "  • $error" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Generate JSON report
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $reportPath = "DenyBlockingTestResults-$timestamp.json"
    $testResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "📄 Test results saved to: $reportPath" -ForegroundColor Cyan
    Write-Host ""
    
    return $testResults
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
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  PHASE 2.3: ENFORCEMENT MODE TESTING" -ForegroundColor Magenta
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
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
    Write-Host "🧪 Test 1: Verify Enforce mode policy assignments exist" -ForegroundColor Cyan
    Write-Host "   Scope: $Scope" -ForegroundColor Gray
    try {
        $assignments = Get-AzPolicyAssignment -Scope $Scope -ErrorAction Stop | Where-Object { $_.EnforcementMode -eq 'Default' }
        $enforceCount = @($assignments | Where-Object { $_.EnforcementMode -eq 'Default' }).Count
        
        if ($enforceCount -gt 0) {
            Write-Host "   ✅ PASS: $enforceCount policies in Enforce mode" -ForegroundColor Green
            $phase23Results.Tests['EnforceAssignmentsExist'] = @{Result='PASS'; Count=$enforceCount; Message="Found $enforceCount Enforce-mode assignments"}
        } else {
            Write-Host "   ❌ FAIL: No Enforce mode assignments found" -ForegroundColor Red
            $phase23Results.Tests['EnforceAssignmentsExist'] = @{Result='FAIL'; Count=0; Message="No Enforce-mode assignments detected"}
            $phase23Results.Issues += "No Enforce mode assignments found at scope $Scope"
        }
    } catch {
        Write-Host "   ⚠️  ERROR: Failed to query assignments - $($_)" -ForegroundColor Yellow
        $phase23Results.Tests['EnforceAssignmentsExist'] = @{Result='ERROR'; Message="$($_)"}
        $phase23Results.Issues += "Failed to retrieve policy assignments: $($_)"
    }
    
    # Test 2: Check compliance data availability
    Write-Host ""
    Write-Host "🧪 Test 2: Verify compliance data is being collected" -ForegroundColor Cyan
    try {
        # Get-AzPolicyState doesn't have -Scope parameter, use -Filter or query all and filter
        $complianceStates = Get-AzPolicyState -Top 100 -ErrorAction Stop | Where-Object { $_.ResourceId -like "$Scope*" }
        $resourceCount = @($complianceStates | Select-Object -Unique -Property ResourceId).Count
        $policyCount = @($complianceStates | Select-Object -Unique -Property PolicyAssignmentId).Count
        
        if ($complianceStates -and $resourceCount -gt 0) {
            Write-Host "   ✅ PASS: Compliance data available" -ForegroundColor Green
            Write-Host "   Resources evaluated: $resourceCount | Policies: $policyCount | States: $($complianceStates.Count)" -ForegroundColor Gray
            $phase23Results.Tests['ComplianceDataAvailable'] = @{Result='PASS'; ResourceCount=$resourceCount; PolicyCount=$policyCount; StateCount=$complianceStates.Count}
        } else {
            Write-Host "   ⚠️  WARNING: No compliance data yet (may need 30-90 min after assignment)" -ForegroundColor Yellow
            $phase23Results.Tests['ComplianceDataAvailable'] = @{Result='PENDING'; Message="Policies may still be evaluating"}
            $phase23Results.Issues += "Compliance data not yet available - policies still evaluating"
        }
    } catch {
        Write-Host "   ⚠️  ERROR: Failed to query compliance - $($_)" -ForegroundColor Yellow
        $phase23Results.Tests['ComplianceDataAvailable'] = @{Result='ERROR'; Message="$($_)"}
        $phase23Results.Issues += "Failed to retrieve compliance data: $($_)"
    }
    
    # Test 3: Check for remediation tasks (if SubscriptionId provided)
    Write-Host ""
    Write-Host "🧪 Test 3: Check for active remediation tasks" -ForegroundColor Cyan
    if ($SubscriptionId) {
        try {
            $remediations = Get-AzPolicyRemediation -Scope "/subscriptions/$SubscriptionId" -ErrorAction Stop
            $remediationCount = @($remediations).Count
            
            if ($remediationCount -gt 0) {
                $succeeded = @($remediations | Where-Object { $_.ProvisioningState -eq 'Succeeded' }).Count
                $inProgress = @($remediations | Where-Object { $_.ProvisioningState -eq 'InProgress' }).Count
                $failed = @($remediations | Where-Object { $_.ProvisioningState -eq 'Failed' }).Count
                
                Write-Host "   ✅ PASS: Remediations detected" -ForegroundColor Green
                Write-Host "   Total: $remediationCount | Succeeded: $succeeded | InProgress: $inProgress | Failed: $failed" -ForegroundColor Gray
                $phase23Results.Tests['RemediationTasks'] = @{Result='PASS'; Total=$remediationCount; Succeeded=$succeeded; InProgress=$inProgress; Failed=$failed}
            } else {
                Write-Host "   ℹ️  INFO: No active remediations (expected if all remediation-eligible policies have already been remediated)" -ForegroundColor Cyan
                $phase23Results.Tests['RemediationTasks'] = @{Result='INFO'; Count=0; Message="No active remediations detected"}
            }
        } catch {
            Write-Host "   ⚠️  ERROR: Failed to query remediations - $($_)" -ForegroundColor Yellow
            $phase23Results.Tests['RemediationTasks'] = @{Result='ERROR'; Message="$($_)"}
        }
    } else {
        Write-Host "   ⚠️  SKIPPED: SubscriptionId not provided (needed for remediation check)" -ForegroundColor Yellow
        $phase23Results.Tests['RemediationTasks'] = @{Result='SKIPPED'; Message="SubscriptionId required for remediation queries"}
    }
    
    # Test 4: Verify managed identity permissions (if principal ID provided)
    Write-Host ""
    Write-Host "🧪 Test 4: Verify managed identity has required roles" -ForegroundColor Cyan
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
                Write-Host "   ✅ PASS: Identity has required roles" -ForegroundColor Green
                Write-Host "   Roles assigned: $($roles -join ', ')" -ForegroundColor Gray
                $phase23Results.Tests['IdentityPermissions'] = @{Result='PASS'; Roles=$roles; HasRequiredRole=$true}
            } else {
                Write-Host "   ⚠️  WARNING: Identity lacks recommended roles for remediation" -ForegroundColor Yellow
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
        Write-Host "   ⚠️  SKIPPED: ManagedIdentityPrincipalId not provided" -ForegroundColor Yellow
        $phase23Results.Tests['IdentityPermissions'] = @{Result='SKIPPED'; Message="Principal ID required for role verification"}
    }
    
    # Generate summary
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  PHASE 2.3 TEST SUMMARY" -ForegroundColor Magenta
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""
    
    $passedTests = @($phase23Results.Tests.Values | Where-Object { $_.Result -eq 'PASS' }).Count
    $totalTests = @($phase23Results.Tests.Values | Where-Object { $_.Result -in 'PASS','FAIL','ERROR' }).Count
    $successRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 2) } else { 0 }
    
    Write-Host "✅ Passed: $passedTests/$totalTests" -ForegroundColor Green
    Write-Host "📊 Success Rate: $successRate%" -ForegroundColor Cyan
    Write-Host ""
    
    if ($phase23Results.Issues.Count -gt 0) {
        Write-Host "⚠️  Issues Found:" -ForegroundColor Yellow
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
        if ($definedParams.PSObject.Properties.Name -contains $paramName) {
            $paramDef = $definedParams.$paramName
            $proposedValue = $ProposedParameters[$paramName]
            
            # Validate against allowedValues if present
            if ($paramDef.allowedValues -and $paramDef.allowedValues.Count -gt 0) {
                if ($paramDef.allowedValues -notcontains $proposedValue) {
                    $warnings += "Parameter '$paramName' value '$proposedValue' not in allowed values [$($paramDef.allowedValues -join ', ')]. Skipping to avoid PolicyParameterValueNotAllowed error."
                    continue
                }
            }
            
            $cleanedParams[$paramName] = $proposedValue
        } else {
            $warnings += "Parameter '$paramName' not defined in policy. Skipping to avoid UndefinedPolicyParameter error."
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
    if ($existingAssignment) {
        Write-Log "Assignment already exists for '$DisplayName' at this scope. Using existing assignment." -Level 'INFO'
        return @{Name=$DisplayName; Status='Assigned'; Assignment=$existingAssignment; DefinitionType='Policy'; IsExisting=$true}
    }
    
    $randomSuffix = '-' + (Get-Random)
    $maxBaseLength = 64 - $randomSuffix.Length
    if ($cleanName.Length -gt $maxBaseLength) {
        $cleanName = $cleanName.Substring(0, $maxBaseLength)
    }
    $assignmentName = $cleanName + $randomSuffix
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
        $assignment = Invoke-WithRetry -MaxRetries $MaxRetries -ScriptBlock {
            if ($isPolicySet) {
                New-AzPolicyAssignment @props -PolicySetDefinition $def -ErrorAction Stop
            } else {
                New-AzPolicyAssignment @props -PolicyDefinition $def -ErrorAction Stop
            }
        }
        
        Write-Log "Assigned as $($assignment.PolicyAssignmentId)" -Level 'SUCCESS'
        return @{Name=$DisplayName; Status='Assigned'; Assignment=$assignment; DefinitionType=($isPolicySet ? 'PolicySet' : 'Policy')}
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
    Write-Host "Switching a policy from Audit to Deny/Enforce: Guidance"
    Write-Host "- Risk: Deny effects can break provisioning or updates for existing resources that don't meet policy."
    Write-Host "- Recommendation: Run in Audit/DoNotEnforce for 30-90 days to gather telemetry and fix non-compliant resources."
    Write-Host "- Phased approach: Audit -> Remediate (auto-remediation or manual) -> Enforce.
  - Use exclusions for critical resources.
  - Schedule change windows and notify stakeholders.
  - Validate automation (ARM/Bicep/TF) in CI before enforcing."
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
        
        $html += @"
                    <tr>
                        <td><strong>$($policy.PolicyName)</strong></td>
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
                <ol style="margin-left: 20px; line-height: 2;">
                    <li><strong>Review non-compliant resources</strong> in the table above</li>
                    <li><strong>Plan remediation</strong> for existing violations (update Key Vault configurations, certificates, keys, secrets)</li>
                    <li><strong>Test in Deny mode</strong> on a single resource group first</li>
                    <li><strong>Monitor blocked operations</strong> for 30-60 days in Deny mode</li>
                    <li><strong>Move to Enforce mode</strong> with remediation tasks to auto-fix non-compliant resources</li>
                </ol>
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
    $successful = @($AssignmentResults | Where-Object { $_.Status -eq 'Assigned' })
    $dryRun = @($AssignmentResults | Where-Object { $_.Status -eq 'DryRun' })
    $failed = @($AssignmentResults | Where-Object { $_.Status -notin @('Assigned', 'DryRun') })
    
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
        [string]$IdentityResourceId,  # Resource ID of managed identity for DeployIfNotExists/Modify policies
        [string]$ScopeType,  # Scope type for policy assignment: Subscription, ResourceGroup, ManagementGroup
        [string]$PolicyMode  # Policy enforcement mode: Audit, Deny, Enforce
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
            Write-Host "⏳ This may take 2-5 minutes for initial scan..." -ForegroundColor Yellow
            $scanJob | Wait-Job | Out-Null
            Write-Log "Compliance scan completed" -Level 'SUCCESS'
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
        
        # Detect if we have Enforce mode policies and run Phase 2.3 validation
        Write-Host ""
        Write-Host "🔍 Checking for Enforce mode policies..." -ForegroundColor Cyan
        $enforceAssignments = Get-AzPolicyAssignment -Scope $scope -ErrorAction SilentlyContinue | Where-Object { $_.EnforcementMode -eq 'Default' }
        $enforceCount = @($enforceAssignments).Count
        
        if ($enforceCount -gt 0) {
            Write-Host "   Found $enforceCount Enforce-mode policies - running Phase 2.3 validation..." -ForegroundColor Yellow
            Write-Host ""
            
            # Extract managed identity principal ID if provided
            $principalId = $null
            if ($IdentityResourceId) {
                try {
                    # Parse resource ID to get resource group and name
                    if ($IdentityResourceId -match '/resourcegroups/([^/]+)/providers/Microsoft.ManagedIdentity/userAssignedIdentities/([^/]+)') {
                        $rgName = $Matches[1]
                        $identityName = $Matches[2]
                        $identity = Get-AzUserAssignedIdentity -ResourceGroupName $rgName -Name $identityName -ErrorAction Stop
                        $principalId = $identity.PrincipalId
                    } else {
                        Write-Log "Could not parse managed identity resource ID format" -Level 'WARN'
                    }
                } catch {
                    Write-Log "Could not resolve managed identity principal ID: $($_)" -Level 'WARN'
                }
            }
            
            # Run Phase 2.3 tests
            $phase23Results = Test-Phase2Point3Enforcement -Scope $scope -ManagedIdentityPrincipalId $principalId -SubscriptionId $subId
            
            Write-Host ""
        } else {
            Write-Host "   No Enforce-mode policies detected (Phase 2.3 validation skipped)" -ForegroundColor Gray
            Write-Host ""
        }
        
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
            Write-Host "\nAvailable Resource Groups:" -ForegroundColor Cyan
            $allRGs = Get-AzResourceGroup | Select-Object ResourceGroupName, Location, @{N='Resources';E={(Get-AzResource -ResourceGroupName $_.ResourceGroupName).Count}}
            $allRGs | Format-Table -AutoSize
            $rg = Read-Host 'Enter Resource Group name from list above'
            $subId = Get-TargetSubscription
            $scope = "/subscriptions/$subId/resourceGroups/$rg"
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

    $names = Import-PolicyListFromCsv -CsvPath $CsvPath
    
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
    $assignmentIds = $assignResults | Where-Object {$_.Status -eq 'Assigned'} | ForEach-Object { 
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
    Show-ChangeImpactGuidance
}

if ($PSCommandPath -eq $MyInvocation.MyCommand.Path) {
    # Parse simple CLI args from $args to allow running script with switches without a top-level param block
    $callParams = @{}
    $defaultCsv = (Resolve-Path -Path './DefinitionListExport.csv' -ErrorAction SilentlyContinue).Path
    $callParams['CsvPath'] = $defaultCsv
    for ($i = 0; $i -lt $args.Count; $i++) {
        switch -Regex ($args[$i]) {
            '^-CsvPath$' { if ($i+1 -lt $args.Count) { $callParams['CsvPath'] = $args[$i+1]; $i++ } }
            '^-ParameterOverridesPath$' { if ($i+1 -lt $args.Count) { $callParams['ParameterOverridesPath'] = $args[$i+1]; $i++ } }
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
            '^-IdentityResourceId$' { if ($i+1 -lt $args.Count) { $callParams['IdentityResourceId'] = $args[$i+1]; $i++ } }
            '^-ScopeType$' { if ($i+1 -lt $args.Count) { $callParams['ScopeType'] = $args[$i+1]; $i++ } }
            '^-PolicyMode$' { if ($i+1 -lt $args.Count) { $callParams['PolicyMode'] = $args[$i+1]; $i++ } }
        }
    }
    Main @callParams
}
