# Actual Deployment Test Execution Plan
**Date**: January 22, 2026  
**Test Type**: Full end-to-end deployment validation  
**Duration Estimate**: 3-4 hours (includes Azure evaluation cycles)

---

## Test Execution Sequence

### Phase 1: Environment Preparation (30 minutes)

#### Step 1.1: Clean Up Old Artifacts
```powershell
# Remove all existing policy assignments
.\AzPolicyImplScript.ps1 -Rollback

# Delete and recreate test environment
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 `
    -CleanupFirst `
    -ActionGroupEmail "your-email@domain.com" `
    -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb"
```

**Expected Duration**: 15-20 minutes  
**Verification**:
- [ ] All KV-* policy assignments removed
- [ ] Old test resource group deleted
- [ ] Fresh resource group created

#### Step 1.2: Build New Test Environment
(Automatically done by Setup script above)

**Expected Resources Created**:
- [ ] Resource Group: rg-policy-keyvault-test
- [ ] Resource Group: rg-policy-remediation
- [ ] 3 Test Key Vaults: kv-compliant-test, kv-non-compliant-test, kv-partial-test
- [ ] Managed Identity: id-policy-remediation
- [ ] Log Analytics Workspace: law-policy-test-*
- [ ] Event Hub Namespace: eh-policy-test-*
- [ ] VNet + Subnet: vnet-policy-test
- [ ] Private DNS Zone: privatelink.vaultcore.azure.net
- [ ] Action Group + Alert Rules

**Output File**: `setup-environment-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt`

---

### Phase 2: Scenario Testing (2-3 hours)

#### Scenario 1: DevTest Baseline (30 Policies)
```powershell
# Start menu and select Scenario 1
.\Deploy-PolicyScenarios.ps1

# Select: 1 (DevTest Baseline)
# Mode: A (Actual)
# Confirm: Yes
```

**Capture Output**: Terminal → `scenario1-devtest-baseline-$(timestamp).txt`

**Validation Checklist**:
- [ ] Parameter File Used: PolicyParameters-DevTest.json
- [ ] Policy Count: 30 policies assigned
- [ ] No [ERROR] messages
- [ ] [WARN] messages only for expected cases (SkipRBACCheck, identity)
- [ ] Console Next Steps: Shows DevTest deployment guidance
- [ ] HTML Report Generated: ComplianceReport-*.html
- [ ] HTML Policy Count: 30 policies listed
- [ ] HTML Next Steps: DevTest-specific guidance

**Expected Duration**: 5 minutes

---

#### Scenario 2: DevTest Full (46 Policies)
```powershell
# Continue with menu, select Scenario 2
# Mode: A (Actual)
# Confirm: Yes
```

**Capture Output**: `scenario2-devtest-full-$(timestamp).txt`

**Validation Checklist**:
- [ ] Parameter File Used: PolicyParameters-DevTest-Full.json
- [ ] Policy Count: 46 policies assigned
- [ ] No [ERROR] messages
- [ ] Includes Managed HSM policies
- [ ] Console Next Steps: Shows comprehensive testing guidance
- [ ] HTML Report: 46 policies, all categories represented

**Expected Duration**: 5 minutes

---

#### Scenario 3: DevTest Auto-Remediation (46 Policies)
```powershell
# Select Scenario 3
# Managed Identity: /subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation
# Mode: A (Actual)
# Confirm: Yes
```

**Capture Output**: `scenario3-devtest-remediation-$(timestamp).txt`

**Validation Checklist**:
- [ ] Parameter File Used: PolicyParameters-DevTest-Full-Remediation.json
- [ ] Policy Count: 46 policies assigned
- [ ] Managed Identity: Confirmed in output
- [ ] 8 Policies with DeployIfNotExists/Modify effects
- [ ] No warnings about missing identity
- [ ] Console Next Steps: Shows remediation wait time (30-90 min)
- [ ] HTML Report: Remediation policies clearly marked

**Expected Duration**: 5 minutes (deployment) + 30-90 minutes (Azure evaluation - can continue testing)

---

#### Scenario 4: Production Audit (46 Policies)
```powershell
# Select Scenario 4
# Mode: A (Actual)
# Confirm: Yes
```

**Capture Output**: `scenario4-production-audit-$(timestamp).txt`

**Validation Checklist**:
- [ ] Parameter File Used: PolicyParameters-Production.json
- [ ] Policy Count: 46 policies assigned
- [ ] Production parameter values used
- [ ] Console Next Steps: Shows production audit guidance
- [ ] HTML Report: Production-specific recommendations

**Expected Duration**: 5 minutes

---

#### Scenario 5: Production Deny (35 Policies)
```powershell
# Select Scenario 5
# WARNING EXPECTED: High risk mode confirmation
# Mode: A (Actual)
# Confirm: Yes
```

**Capture Output**: `scenario5-production-deny-$(timestamp).txt`

**Validation Checklist**:
- [ ] Parameter File Used: PolicyParameters-Production-Deny.json
- [ ] Policy Count: 35 policies assigned (NOT 38 or 46)
- [ ] **CRITICAL**: NO warnings about Deny effect not supported
- [ ] All policies should use Deny effect successfully
- [ ] Console shows HIGH RISK warning
- [ ] Console Next Steps: Shows Deny mode guidance and rollback instructions
- [ ] HTML Report: 35 policies, explains excluded policies

**Expected Duration**: 5 minutes

---

#### Scenario 6: Production Auto-Remediation (46 Policies)
```powershell
# Select Scenario 6
# Managed Identity: (same as Scenario 3)
# Mode: A (Actual)
# Confirm: Yes
```

**Capture Output**: `scenario6-production-remediation-$(timestamp).txt`

**Validation Checklist**:
- [ ] Parameter File Used: PolicyParameters-Production-Remediation.json
- [ ] **Policy Count: 46 policies assigned** (NOT 8!)
- [ ] Managed Identity: Confirmed
- [ ] Console shows "46 policies" not "8 policies"
- [ ] Console Next Steps: Shows production remediation guidance
- [ ] HTML Report: 46 policies (38 Audit + 8 DINE/Modify)

**Expected Duration**: 5 minutes (deployment) + 30-90 minutes (Azure evaluation)

---

#### Scenario 7: Resource Group Scope (30 Policies)
```powershell
# Select Scenario 7
# Resource Group: rg-policy-keyvault-test
# Mode: A (Actual)
# Confirm: Yes
```

**Capture Output**: `scenario7-resource-group-scope-$(timestamp).txt`

**Validation Checklist**:
- [ ] Parameter File Used: PolicyParameters-DevTest.json
- [ ] Scope: Resource Group confirmed in output
- [ ] Resource Group Name: rg-policy-keyvault-test shown
- [ ] Policy Count: 30 policies assigned
- [ ] Console Next Steps: Shows resource group scope guidance
- [ ] HTML Report: Indicates RG scope

**Expected Duration**: 5 minutes

---

#### Scenario 8: Management Group Scope
**ACTION**: Skip - No management group available

**Documentation**:
- [ ] Mark as SKIPPED in test results
- [ ] Note: Requires management group ID

---

#### Scenario 9: Rollback (Remove All Policies)
```powershell
# Select Scenario 9
# Scope: Subscription
# Mode: A (Actual)
# Confirm: Yes
```

**Capture Output**: `scenario9-rollback-$(timestamp).txt`

**Validation Checklist**:
- [ ] All KV-* assignments removed
- [ ] Console shows count of removed assignments
- [ ] Console shows rollback completion message
- [ ] **NO HTML Report generated** (expected)
- [ ] Verify in Azure Portal: No KV-* assignments remain

**Expected Duration**: 3-5 minutes

---

### Phase 3: Validation & Documentation (30 minutes)

#### Step 3.1: Review Terminal Outputs
```powershell
# Review all scenario output files for:
Get-ChildItem -Filter "scenario*.txt" | ForEach-Object {
    Write-Host "`n=== $($_.Name) ===" -ForegroundColor Cyan
    Get-Content $_.FullName | Select-String -Pattern "ERROR|Parameter.*not in allowed|Successfully assigned"
}
```

**Validation**:
- [ ] No unexpected [ERROR] messages
- [ ] No "Parameter 'effect' value 'Deny' not in allowed values" in Scenario 5
- [ ] All scenarios show "Successfully assigned" or completion messages
- [ ] Parameter files correctly identified in logs

#### Step 3.2: Review HTML Reports
```powershell
# List all generated HTML reports
Get-ChildItem -Filter "ComplianceReport-*.html" | Sort-Object LastWriteTime
```

**Validation** (for each report):
- [ ] Policy counts match expected (30, 35, or 46)
- [ ] Compliance data displayed
- [ ] Next Steps section present and scenario-appropriate
- [ ] No placeholder text or errors
- [ ] Formatting correct

#### Step 3.3: Check Remediation Tasks (Scenarios 3 & 6)
```powershell
# After 30-90 minutes, check remediation
Get-AzPolicyRemediation -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb" |
    Select-Object Name, PolicyDefinitionReferenceId, ProvisioningState, CreatedOn |
    Format-Table
```

**Validation**:
- [ ] Remediation tasks created for Scenario 3
- [ ] Remediation tasks created for Scenario 6
- [ ] Tasks show ProvisioningState (Running/Succeeded)

#### Step 3.4: Create Test Results Summary
Document in `Actual-Deployment-Test-Results-$(date).md`:
- Scenarios executed and results
- Issues found (if any)
- Parameter file verification results
- HTML report validation results
- Overall test status (PASS/FAIL)

---

## Output Files Generated

### Terminal Outputs
- `setup-environment-TIMESTAMP.txt`
- `scenario1-devtest-baseline-TIMESTAMP.txt`
- `scenario2-devtest-full-TIMESTAMP.txt`
- `scenario3-devtest-remediation-TIMESTAMP.txt`
- `scenario4-production-audit-TIMESTAMP.txt`
- `scenario5-production-deny-TIMESTAMP.txt`
- `scenario6-production-remediation-TIMESTAMP.txt`
- `scenario7-resource-group-scope-TIMESTAMP.txt`
- `scenario9-rollback-TIMESTAMP.txt`

### HTML Reports (7 expected)
- Scenario 1-7 will generate ComplianceReport-*.html
- Scenario 9 (rollback) does NOT generate HTML

### History Tracking
- `.policy-deployment-history.json` (auto-created by Deploy-PolicyScenarios.ps1)

---

## Quick Start Commands

```powershell
# 1. Start fresh environment setup (with cleanup)
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 `
    -CleanupFirst `
    -ActionGroupEmail "your-email@domain.com" `
    -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" |
    Tee-Object -FilePath "setup-environment-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"

# 2. Start interactive deployment menu
.\Deploy-PolicyScenarios.ps1

# 3. Execute each scenario (1-7, skip 8, then 9)
#    For each scenario:
#    - Capture output: Start-Transcript before launching menu
#    - Select scenario number
#    - Choose mode: A (Actual)
#    - Confirm deployment
#    - Wait for completion
#    - Stop-Transcript
#    - Review output and HTML

# 4. Check remediation (after 30-90 min for Scenarios 3 & 6)
Get-AzPolicyRemediation -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb"
```

---

## Success Criteria

**All Scenarios Must**:
- ✅ Complete without [ERROR] messages
- ✅ Use correct parameter file (verified in output)
- ✅ Generate appropriate console next steps
- ✅ Generate valid HTML report (except rollback)
- ✅ Show correct policy counts

**Scenario 5 Specific**:
- ✅ **NO** "Deny not in allowed values" warnings
- ✅ Exactly 35 policies assigned

**Scenario 6 Specific**:
- ✅ Shows 46 policies (NOT 8)
- ✅ Clarifies 8 policies have remediation mode

**Scenarios 3 & 6**:
- ✅ Managed identity used successfully
- ✅ Remediation tasks created within 90 minutes

---

## Troubleshooting

**If Scenario 5 shows Deny warnings**:
- Check PolicyParameters-Production-Deny.json has 35 policies
- Verify 3 policies removed: Managed HSM public access, private link, key rotation

**If Scenario 6 shows only 8 policies**:
- Check script output for "Preparing to assign (1/46)" pattern
- Should process all 46 policies (not just 8)

**If remediation tasks not created**:
- Wait full 90 minutes
- Check managed identity RBAC roles
- Verify identity resource ID is correct

**If HTML reports missing next steps**:
- Check for deployment mode detection in output
- Verify script completed successfully
