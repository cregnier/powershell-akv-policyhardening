# Azure Key Vault Policy - Scenario Commands Reference

**Last Updated**: 2026-01-27  
**Script Version**: AzPolicyImplScript.ps1 (6,679 lines)  
**Status**: ✅ All commands validated and tested

---

## 🎯 Quick Command Reference

### Required Parameters for ALL Scenarios
```powershell
# Managed Identity (required for all DINE/Modify policies)
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# Common parameters
-IdentityResourceId $identityId   # Always required
-ScopeType Subscription           # Recommended for all scenarios
-SkipRBACCheck                    # Speeds up deployment
-Force                            # Bypasses interactive prompts
```

---

## Scenario 1-3: DevTest Environment (30 Policies)

### Purpose
Test core Azure Key Vault policies in isolated DevTest environment with 3 test vaults.

### Parameter File
`PolicyParameters-DevTest.json` (30 policies)

### Command
```powershell
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest.json `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -PolicyMode Audit `
    -SkipRBACCheck `
    -Force
```

### Expected Results
- **Policies Deployed**: 30/30
- **Test Vaults**: 3 (kv-compliant-test, kv-non-compliant-test, kv-partial-test)
- **Compliance**: 40-60% (varies by test vault configuration)
- **Duration**: 3-5 minutes

### Verification
```powershell
# Check policy assignments
Get-AzPolicyAssignment -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb" |
    Where-Object { $_.Properties.DisplayName -like '*Key*Vault*' } | Measure-Object

# Expected: 30 assignments
```

---

## Scenario 4: DevTest Full Testing (46 Policies)

### Purpose
Test ALL 46 policies including 8 auto-remediation policies in DevTest environment.

### Parameter File
`PolicyParameters-DevTest-Full.json` (46 policies)

### Command
```powershell
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full.json `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -PolicyMode Audit `
    -SkipRBACCheck `
    -Force
```

### Expected Results
- **Policies Deployed**: 46/46
- **DINE/Modify Policies**: 8 (6 DeployIfNotExists + 2 Modify)
- **Compliance**: 35-55%
- **Duration**: 5-7 minutes

### Key Difference from Scenario 1-3
Includes 16 additional policies:
- 8 auto-remediation policies (DINE/Modify)
- 8 advanced diagnostic/monitoring policies

---

## Scenario 5: Production Audit Mode (46 Policies)

### Purpose
Monitor production Key Vaults for compliance violations WITHOUT blocking operations.

### Parameter File
`PolicyParameters-Production.json` (46 policies, all Audit effect)

### Command
```powershell
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -PolicyMode Audit `
    -SkipRBACCheck `
    -Force
```

### Expected Results
- **Policies Deployed**: 46/46 (all in Audit mode)
- **Blocking**: None (monitoring only)
- **Compliance**: Baseline measurement
- **Duration**: 5-7 minutes

### Use Case
Run this BEFORE Scenario 6 to:
1. Identify compliance violations
2. Create exemptions for legitimate exceptions
3. Notify stakeholders of upcoming enforcement

---

## Scenario 6: Production Deny Mode (34 Policies)

### Purpose
Block NEW violations in production while allowing existing non-compliant resources.

### Parameter File
`PolicyParameters-Production-Deny.json` (34 Deny policies)

### Command
```powershell
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Deny.json `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -PolicyMode Deny `
    -SkipRBACCheck `
    -Force
```

### Expected Results
- **Policies Deployed**: 34/34 (Deny mode)
- **Excluded Policies**: 12 policies (cannot use Deny effect)
  - 6 DeployIfNotExists policies
  - 2 Modify policies
  - 4 policies requiring Audit mode only
- **Blocking**: NEW non-compliant Key Vault operations blocked
- **Duration**: 5-7 minutes

### Testing Deny Mode
Use built-in test function:
```powershell
.\AzPolicyImplScript.ps1 -TestAllDenyPolicies

# Expected: 25/34 PASS (74% coverage in MSDN subscription)
# 8 HSM policies: SKIP (requires Enterprise subscription)
# 1 Integrated CA policy: SKIP (requires $500+ third-party setup)
```

---

## Scenario 7: Production Auto-Remediation (8 DINE/Modify Policies)

### Purpose
Automatically FIX non-compliant Key Vaults (enable firewalls, create private endpoints, deploy diagnostic settings).

### Parameter File
`PolicyParameters-Production-Remediation.json` (46 policies, 8 with DINE/Modify)

### **CRITICAL**: Use `-PolicyMode Enforce`
**DO NOT use `-PolicyMode Audit`** - this prevents auto-remediation!

### Command
```powershell
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -PolicyMode Enforce `
    -SkipRBACCheck `
    -Force
```

### Expected Results
- **Policies Deployed**: 46/46
- **Auto-Remediation Policies**: 8 (Enforce mode)
  - 6 DeployIfNotExists
  - 2 Modify
- **Remaining Policies**: 38 (Audit mode)
- **Remediation Timeline**:
  - Policy assignment: Immediate (3-5 min)
  - Resource evaluation: 15-30 minutes
  - Remediation task creation: 30-60 minutes
  - Task execution: 60-90 minutes
  - **Total**: 90 minutes minimum
- **Compliance Improvement**: 35% → 60-80%

### The 8 Auto-Remediation Policies
1. **Configure Azure Key Vaults with private endpoints** (DINE)
2. **Configure Azure Key Vaults to use private DNS zones** (DINE)
3. **Deploy - Configure diagnostic settings to Log Analytics** (DINE)
4. **Deploy - Configure diagnostic settings to Event Hub** (DINE)
5. **Configure Azure Key Vault Managed HSM with private endpoints** (DINE)
6. **Deploy - Configure diagnostic settings for Managed HSM to Event Hub** (DINE)
7. **Configure key vaults to enable firewall** (Modify)
8. **Configure Azure Key Vault Managed HSM to disable public network access** (Modify)

### Monitoring Progress
```powershell
# Check remediation tasks (run after 60 min)
Get-AzPolicyRemediation -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb" |
    Select-Object Name, ProvisioningState, @{N='ResourcesRemediated';E={$_.DeploymentSummary.TotalDeployments}}

# Expected: 8 tasks with ProvisioningState = Succeeded
```

### ⚠️ Common Mistake
```powershell
# ❌ WRONG - Uses Audit mode (no auto-remediation)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Remediation.json -PolicyMode Audit

# ✅ CORRECT - Uses Enforce mode (enables auto-remediation)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Remediation.json -PolicyMode Enforce
```

---

## Testing Functions

### Test Infrastructure Validation (11 Checks)
```powershell
.\AzPolicyImplScript.ps1 -TestInfrastructure -Detailed

# Validates:
# - VNet and subnets
# - Private DNS zones
# - Log Analytics workspace
# - Event Hub namespace
# - Managed identity with Contributor role
# - 3 test Key Vaults
# - Network configuration
```

### Test Production Enforcement (Deny Mode)
```powershell
.\AzPolicyImplScript.ps1 -TestProductionEnforcement

# Tests 4 blocking scenarios:
# 1. Create vault without purge protection
# 2. Create vault with public network access
# 3. Add certificate without minimum key size
# 4. Create secret without expiration date
```

### Test Auto-Remediation (Full Cycle)
```powershell
.\AzPolicyImplScript.ps1 -TestAutoRemediation

# Duration: 60-90 minutes
# Creates non-compliant vault, waits for auto-remediation, verifies fixes
```

### Test All Deny Policies (Comprehensive)
```powershell
.\AzPolicyImplScript.ps1 -TestAllDenyPolicies

# Duration: 20-25 minutes
# Tests all 34 Deny mode policies
# Expected: 25/34 PASS (74% coverage in MSDN)
# MSDN Limitations: 8 HSM policies require Enterprise subscription
```

---

## Compliance Reporting

### Generate HTML Report
```powershell
.\AzPolicyImplScript.ps1 -CheckCompliance -SkipRBACCheck

# Generates:
# - ComplianceReport-YYYYMMDD-HHMMSS.html
# - ComplianceReport-YYYYMMDD-HHMMSS.json
# - ComplianceReport-YYYYMMDD-HHMMSS.csv
```

### Trigger Compliance Scan (Force Immediate Evaluation)
```powershell
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck

# Triggers:
# 1. On-demand compliance evaluation
# 2. Waits 5 minutes for scan completion
# 3. Generates updated reports
```

---

## Rollback and Cleanup

### Remove ALL Key Vault Policy Assignments
```powershell
.\AzPolicyImplScript.ps1 -Rollback

# Removes all assignments starting with "KV-*"
# Use this to completely reset policy state
```

### Remove Specific Scenario Policies
```powershell
# List all assignments first
$assignments = Get-AzPolicyAssignment -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb"
$kvAssignments = $assignments | Where-Object { $_.Properties.DisplayName -like '*Key*Vault*' }

# Remove specific assignment
Remove-AzPolicyAssignment -Id $kvAssignments[0].ResourceId
```

---

## Exemption Management

### Create Exemption (Exclude Specific Resources)
```powershell
.\AzPolicyImplScript.ps1 -CreateExemption `
    -AssignmentName "KV-AzureKeyVaultshoulddisablepublicnetworkaccess" `
    -ExemptionName "DevVault-PublicAccess-Waiver" `
    -ResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-dev/providers/Microsoft.KeyVault/vaults/kv-dev-test" `
    -Reason "Waiver" `
    -Description "Dev environment requires public access for testing" `
    -ExpiresOn "2026-12-31"
```

### List All Exemptions
```powershell
.\AzPolicyImplScript.ps1 -ListExemptions
```

### Export Exemptions to JSON
```powershell
.\AzPolicyImplScript.ps1 -ExportExemptions -OutputPath ".\exemptions-backup.json"
```

### Remove Exemption
```powershell
.\AzPolicyImplScript.ps1 -RemoveExemption -ExemptionName "DevVault-PublicAccess-Waiver"
```

---

## Parameter File Structure

### Standard Format
```json
{
  "_comment": "Description of scenario",
  
  "Policy Display Name": {
    "effect": "Audit|Deny|DeployIfNotExists|Modify",
    "parameter1": "value1",
    "parameter2": "value2"
  }
}
```

### Example: Auto-Remediation Policy
```json
{
  "Configure Azure Key Vaults with private endpoints": {
    "effect": "DeployIfNotExists",
    "privateEndpointSubnetId": "/subscriptions/.../subnets/subnet-keyvault"
  },
  
  "Configure key vaults to enable firewall": {
    "effect": "Modify"
  }
}
```

---

## Troubleshooting

### Issue: Mode Selection Prompt Appears Despite `-Force`
**Solution**: Always provide `-PolicyMode` parameter explicitly:
```powershell
-PolicyMode Audit   # For monitoring
-PolicyMode Deny    # For blocking
-PolicyMode Enforce # For auto-remediation
```

### Issue: No Remediation Tasks Created After 90 Minutes
**Cause**: Deployed with `-PolicyMode Audit` instead of `-PolicyMode Enforce`

**Solution**: Redeploy Scenario 7 with correct mode:
```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -PolicyMode Enforce `  # CRITICAL!
    -IdentityResourceId $identityId `
    -SkipRBACCheck `
    -Force
```

### Issue: "Managed identity not found" Error
**Cause**: Managed identity not created by Setup script

**Solution**: Run Setup script first:
```powershell
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -ResourceGroupName "rg-policy-keyvault-test"
```

### Issue: Deny Policy Tests Fail with "Forbidden" Error
**Cause**: MSDN subscription quota limitations (Managed HSM not available)

**Solution**: Expected behavior - 8 HSM policies cannot be tested in MSDN subscriptions
- Document as MSDN limitation
- Test in Enterprise/Pay-As-You-Go subscription

---

## Best Practices

### 1. Always Use Subscription Scope
```powershell
-ScopeType Subscription  # Applies to all Key Vaults in subscription
```

### 2. Deploy Scenarios in Order
1. **Scenario 1-3** (DevTest): Learn policy behavior safely
2. **Scenario 4** (DevTest Full): Test all 46 policies
3. **Scenario 5** (Production Audit): Baseline compliance
4. **Scenario 6** (Production Deny): Block new violations
5. **Scenario 7** (Production Remediation): Auto-fix existing violations

### 3. Always Include Managed Identity
Even for Audit mode deployments - ensures DINE/Modify policies can be enabled later:
```powershell
-IdentityResourceId $identityId
```

### 4. Use -Force for Automation
Bypasses interactive prompts:
```powershell
-Force
```

### 5. Monitor Auto-Remediation Progress
Don't expect instant results - Azure Policy requires 60-90 minutes:
```powershell
# Check every 15 minutes
.\AzPolicyImplScript.ps1 -CheckCompliance
Get-AzPolicyRemediation -Scope "/subscriptions/..."
```

---

## Summary Table

| Scenario | Parameter File | Policies | Mode | Purpose | Duration |
|----------|---------------|----------|------|---------|----------|
| 1-3 | PolicyParameters-DevTest.json | 30 | Audit | DevTest baseline | 3-5 min |
| 4 | PolicyParameters-DevTest-Full.json | 46 | Audit | Full DevTest testing | 5-7 min |
| 5 | PolicyParameters-Production.json | 46 | Audit | Production monitoring | 5-7 min |
| 6 | PolicyParameters-Production-Deny.json | 34 | Deny | Block new violations | 5-7 min |
| 7 | PolicyParameters-Production-Remediation.json | 46 | **Enforce** | Auto-remediation | 90 min |

---

## Related Documentation

- **QUICKSTART.md**: Step-by-step deployment guide
- **DEPLOYMENT-WORKFLOW-GUIDE.md**: Detailed deployment process
- **DEPLOYMENT-PREREQUISITES.md**: Setup requirements
- **PolicyParameters-QuickReference.md**: Parameter file selection guide
- **Comprehensive-Test-Plan.md**: Complete testing strategy

---

**Last Validated**: 2026-01-27  
**Validation Status**: ✅ All scenarios tested and verified  
**MSDN Subscription Limitations**: 8 HSM policies require Enterprise subscription
