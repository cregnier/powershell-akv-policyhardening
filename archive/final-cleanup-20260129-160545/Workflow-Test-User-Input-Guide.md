# Deployment Scenario Guide - Complete Reference

**Purpose**: Comprehensive guide for all 9 Azure Key Vault Policy deployment scenarios  
**Last Updated**: January 22, 2026  
**Status**: Active - Use for deployment planning and execution

---

## 📋 Quick Reference Table

| Scenario | Parameter File | Policies | Effect(s) | Managed Identity | Scope | Purpose |
|----------|----------------|----------|-----------|------------------|-------|---------|
| 1. DevTest Baseline | PolicyParameters-DevTest.json | 30 | Audit | Optional | Subscription | Safe initial testing with core policies |
| 2. DevTest Full | PolicyParameters-DevTest-Full.json | 46 | Audit | Optional | Subscription | Comprehensive testing of all policies |
| 3. DevTest Auto-Remediation | PolicyParameters-DevTest-Full-Remediation.json | 46 (8 DINE) | Audit + DeployIfNotExists | **Required** | Subscription | Test automated compliance fixes |
| 4. Production Audit | PolicyParameters-Production.json | 46 | Audit | Optional | Subscription | Production monitoring without blocking |
| 5. Production Deny | PolicyParameters-Production-Deny.json | 35 | Deny | No | Subscription | Maximum enforcement (blocks non-compliant) |
| 6. Production Auto-Remediation | PolicyParameters-Production-Remediation.json | 46 (8 DINE) | Audit + DeployIfNotExists | **Required** | Subscription | Production automated compliance |
| 7. Resource Group Scope | PolicyParameters-DevTest.json | 30 | Audit | Optional | Resource Group | Limited scope testing |
| 8. Management Group Scope | PolicyParameters-Production.json | 46 | Audit | Optional | Management Group | Organization-wide governance |
| 9. Rollback | N/A | All | N/A | No | Any | Remove all policy assignments |

---

---

## 📖 Detailed Scenario Breakdown

### Scenario 1: DevTest Baseline (30 Policies)

**Purpose**: Safe initial deployment to validate infrastructure and test core governance policies without risk.

**Use Case**:
- First-time deployment in dev/test environment
- Validating Azure Policy infrastructure setup
- Testing parameter file syntax and policy assignments
- Establishing baseline compliance metrics

**Strategy**:
- Audit mode only (no resource blocking)
- 30 core policies covering critical security requirements
- No managed identity required
- Safe to deploy to any environment

**Parameter File**: `PolicyParameters-DevTest.json`

**Key Policies Included**:
- Soft delete and purge protection (6 policies)
- Certificate management (9 policies)
- Key/Secret expiration (6 policies)
- Diagnostic logging (2 policies)
- Network security (5 policies)
- RBAC configuration (2 policies)

**Deployment Command**:
```powershell
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -SkipRBACCheck
```

**Expected Results**:
- ✅ 30 policy assignments created
- ✅ Compliance report available after 30-90 minutes
- ✅ No resource blocking or operational impact
- ✅ HTML report shows all policy statuses

**User Input** (if not using -Preview):
- Scope: Subscription (press Enter)
- Use current subscription: Y (press Enter)

---

### Scenario 2: DevTest Full (46 Policies)

**Purpose**: Comprehensive testing of all available Azure Key Vault governance policies in non-production.

**Use Case**:
- Complete policy coverage assessment
- Understanding full compliance requirements
- Preparing for production deployment
- Testing all policy categories (certificates, keys, secrets, configuration)

**Strategy**:
- All 46 policies in Audit mode
- Includes Managed HSM policies (preview)
- Diagnostic and monitoring policies
- Network security and encryption policies

**Parameter File**: `PolicyParameters-DevTest-Full.json`

**Policy Breakdown**:
- Managed HSM: 8 policies (preview features)
- Key Vault Configuration: 10 policies
- Certificates: 9 policies
- Keys: 9 policies
- Secrets: 5 policies
- Diagnostics: 5 policies

**Deployment Command**:
```powershell
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -SkipRBACCheck
```

**Expected Results**:
- ✅ 46 policy assignments created
- ✅ Complete compliance visibility
- ⚠️ Lower compliance percentage expected (stricter requirements)
- ✅ Identifies gaps before production deployment

**Comparison to Scenario 1**:
- +16 additional policies
- Includes preview Managed HSM policies
- More comprehensive monitoring
- Lower expected compliance (tighter requirements)

---

### Scenario 3: DevTest Auto-Remediation (46 Policies)

**Purpose**: Test automated compliance remediation in dev/test environment before production use.

**Use Case**:
- Validating auto-remediation policies work correctly
- Testing managed identity RBAC permissions
- Understanding Azure Policy evaluation timing
- Preparing for production auto-remediation deployment

**Strategy**:
- 38 policies in Audit mode (monitoring)
- 8 policies with DeployIfNotExists/Modify effects (auto-fix)
- Requires managed identity with proper RBAC roles
- 30-90 minute Azure evaluation cycle required

**Parameter File**: `PolicyParameters-DevTest-Full-Remediation.json`

**Auto-Remediation Policies** (8 total):
1. Resource logs in Key Vault should be enabled (DeployIfNotExists)
2. Resource logs in Azure Key Vault Managed HSM should be enabled (DeployIfNotExists)
3. Deploy Diagnostic Settings for Key Vault to Event Hub (DeployIfNotExists)
4. Deploy - Configure diagnostic settings to an Event Hub to be enabled on Azure Key Vault Managed HSM (DeployIfNotExists)
5. Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace (DeployIfNotExists)
6. Configure Azure Key Vaults with private endpoints (DeployIfNotExists)
7. Configure Azure Key Vaults to use private DNS zones (DeployIfNotExists)
8. Configure key vaults to enable firewall (Modify)

**⚠️ CRITICAL WARNINGS:**

```
⚠️  Auto-remediation will MODIFY existing test Key Vaults:
    • Creates private endpoints (may impact connectivity)
    • Enables firewall (may block access)
    • Creates diagnostic settings (increases logging costs)
    
⏰ Timeline: Allow 30-60 minutes for Azure Policy evaluation cycle
    • Policy assignment: Immediate
    • Resource evaluation: 15-30 minutes
    • Remediation tasks created: 30-60 minutes
    • Total: 60-90 minutes minimum
    
✅ Safe for Testing: Only affects 3 test vaults (kv-compliant-*, kv-partial-*, kv-noncompliant-*)
    
📚 Review: See AUTO-REMEDIATION-GUIDE.md for complete details
```

**Deployment Command**:
```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -PolicyMode Enforce `
    -IdentityResourceId "/subscriptions/<sub-id>/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation" `
    -ScopeType Subscription `
    -SkipRBACCheck
```

**Prerequisites**:
- ✅ Managed identity created: `id-policy-remediation`
- ✅ RBAC roles assigned: Contributor, Network Contributor, Log Analytics Contributor, Private DNS Zone Contributor
- ✅ Log Analytics workspace deployed
- ✅ Event Hub namespace deployed
- ✅ Private DNS zones configured
- ✅ VNet + Subnet deployed (for private endpoints)
- ✅ 3 test Key Vaults exist (kv-compliant, kv-partial, kv-noncompliant)

**Expected Results**:
- ✅ 46 policy assignments created (38 Audit + 8 DINE/Modify)
- ⏱️ Wait 30-90 minutes for Azure evaluation
- ✅ Remediation tasks created automatically
- ✅ Non-compliant resources auto-fixed
- 📊 Check remediation task status in Azure Portal → Policy → Remediation

**Testing Timeline**:
1. Deploy policies: 5 minutes
2. Azure evaluation cycle: 30-90 minutes (cannot be bypassed - Azure backend process)
3. Remediation tasks execute: 10-15 minutes
4. Verify compliance: 5 minutes
5. **Total: Allow 60-90 minutes minimum**

**Validation**:
```powershell
# After 30-60 minute wait, test remediation results
.\AzPolicyImplScript.ps1 -TestAutoRemediation
```

---

### Scenario 4: Production Audit (46 Policies)

```powershell
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -DryRun -SkipRBACCheck -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Prompts & Responses:**
1. `Assign policies at scope type? (Subscription/ResourceGroup/ManagementGroup) [Subscription]:`
   - **Enter:** `Subscription` (or just press Enter for default)

2. `Use this subscription? (Y/N) [Y]:`
   - **Enter:** `Y` (or just press Enter for default)

3. `Choose mode (Audit/Deny/Enforce) [Audit]:`
   - **Enter:** ❌ **DO NOT PROMPT** (this is the bug we're fixing)
   - **Temporary workaround:** Press Enter (accepts default "Audit")

---

### Test 2: DevTestFull (46 Policies)

```powershell
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -DryRun -SkipRBACCheck -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Prompts & Responses:**
1. `Assign policies at scope type? (Subscription/ResourceGroup/ManagementGroup) [Subscription]:`
   - **Enter:** `Subscription`

2. `Use this subscription? (Y/N) [Y]:`
   - **Enter:** `Y`

3. `Choose mode (Audit/Deny/Enforce) [Audit]:`
   - **Enter:** ❌ **DO NOT PROMPT**
   - **Temporary workaround:** Press Enter (accepts "Audit")

---

### Test 3: DevTestRemediation (46 Policies + Auto-Fix)

```powershell
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json -DryRun -SkipRBACCheck -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Prompts & Responses:**
1. `Assign policies at scope type? (Subscription/ResourceGroup/ManagementGroup) [Subscription]:`
   - **Enter:** `Subscription`

2. `Use this subscription? (Y/N) [Y]:`
   - **Enter:** `Y`

3. `Choose mode (Audit/Deny/Enforce) [Audit]:`
   - **⚠️ CRITICAL BUG:** This prompt should NOT appear
   - **What happens:** Entering "Audit" overrides "DeployIfNotExists" effects from parameter file
   - **Correct behavior:** Script should use effects from parameter file (DeployIfNotExists, Modify)
   - **Temporary workaround:** Press Enter, but note that auto-remediation may not work correctly

---

### Test 4: ProductionAudit (46 Policies)

```powershell
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -DryRun -SkipRBACCheck -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Prompts & Responses:**
1. `Assign policies at scope type? (Subscription/ResourceGroup/ManagementGroup) [Subscription]:`
   - **Enter:** `Subscription`

2. `Use this subscription? (Y/N) [Y]:`
   - **Enter:** `Y`

3. `Choose mode (Audit/Deny/Enforce) [Audit]:`
   - **Enter:** ❌ **DO NOT PROMPT**
   - **Temporary workaround:** Press Enter

---

### Test 5: ProductionDeny (46 Policies - Blocking Mode)

**Status:** ⏸️ BLOCKED - No parameter file exists

**Required:** Create `PolicyParameters-Production-Deny.json` first

**Command (after file created):**
```powershell
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Deny.json -DryRun -SkipRBACCheck -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Expected Prompts:**
1. Scope type: `Subscription`
2. Use subscription: `Y`
3. Mode: ❌ **SHOULD NOT PROMPT** (all policies should use "Deny" from file)

---

### Test 6: ProductionRemediation (46 Policies + Auto-Fix)

**⚠️ PRODUCTION WARNING:**

```
🚨 CRITICAL: This deploys auto-remediation to PRODUCTION subscription!

⚠️  Auto-remediation will MODIFY ALL production Key Vaults:
    • Creates private endpoints (may impact application connectivity)
    • Enables firewall (may block unauthorized access)
    • Disables public network access (may break apps without VNet)
    • Creates diagnostic settings (increases logging costs)

📋 MANDATORY Prerequisites (ALL must be complete):
    ☐ Scenario 4 (DevTest) passed successfully
    ☐ Scenario 5 (Production Audit) validated violations
    ☐ Private endpoint connectivity tested from applications
    ☐ Firewall IP whitelists documented and approved
    ☐ Managed identity has all 4 required RBAC roles
    ☐ Maintenance window scheduled (off-peak hours: 2am-6am)
    ☐ Stakeholders notified 7-14 days in advance
    ☐ Rollback procedure documented and tested
    ☐ Azure subscription quotas checked (private endpoints)
    ☐ Monitoring alerts configured for policy violations
    ☐ Change request approved (if required by governance)
    ☐ On-call engineer available during deployment

⏰ Timeline: 60-90 minutes total
    • Policy assignment: Immediate
    • Resource evaluation: 15-30 minutes
    • Remediation tasks created: 30-60 minutes
    • Total: Allow 90 minutes minimum

💰 Value: Fixes 100+ Key Vaults in 90 min vs 2 weeks manual work (~$10k savings)

📚 Review: See AUTO-REMEDIATION-GUIDE.md for complete details
```

**Deployment Command** (Use with EXTREME caution):
```powershell
# PRODUCTION - Only deploy after completing all prerequisites above!
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -PolicyMode Enforce `
    -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation" `
    -ScopeType Subscription `
    -SkipRBACCheck
```

**DRY-RUN (Testing Only)**:
```powershell
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Remediation.json -DryRun -SkipRBACCheck -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Prompts & Responses:**
1. **Auto-Remediation Warning Banner**:
   - Script displays comprehensive warning with prerequisites checklist
   - Prompt: `Do you want to deploy auto-remediation NOW or DEFER to later? (Now/Defer) [Defer]:`
   - **Enter:** Type `Now` if ALL prerequisites complete, or press Enter to defer

2. `Assign policies at scope type? (Subscription/ResourceGroup/ManagementGroup) [Subscription]:`
   - **Enter:** `Subscription` (or press Enter for default)

3. `Use this subscription? (Y/N) [Y]:`
   - **Enter:** `Y` (or press Enter for default)

**Post-Deployment Monitoring**:
1. Azure Portal → Policy → Remediation → Filter by "KeyVault"
2. Azure Activity Log → Filter by "Microsoft.PolicyInsights"
3. Check compliance after 90 minutes:
   ```powershell
   .\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan
   ```

**Rollback** (if needed):
```powershell
.\AzPolicyImplScript.ps1 -Rollback
```

---

### Test 7: ResourceGroupScope

```powershell
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -ScopeType ResourceGroup -ResourceGroupName "rg-policy-keyvault-test" -DryRun -SkipRBACCheck -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Prompts & Responses:**
1. `Assign policies at scope type? (Subscription/ResourceGroup/ManagementGroup) [Subscription]:`
   - **Note:** With `-ScopeType ResourceGroup` parameter, this prompt **should be skipped**
   - **If prompted anyway:** Enter `ResourceGroup`

2. `Enter Resource Group name:`
   - **Note:** With `-ResourceGroupName` parameter, this prompt **should be skipped**
   - **If prompted anyway:** Enter `rg-policy-keyvault-test`

3. `Use this subscription? (Y/N) [Y]:`
   - **Enter:** `Y`

4. `Choose mode (Audit/Deny/Enforce) [Audit]:`
   - **Enter:** ❌ **DO NOT PROMPT**
   - **Temporary workaround:** Press Enter

---

### Test 8: ManagementGroupScope

```powershell
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -ScopeType ManagementGroup -ManagementGroupId "<YOUR-MG-ID>" -DryRun -SkipRBACCheck -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**⚠️ Note:** Replace `<YOUR-MG-ID>` with actual Management Group ID

**Prompts & Responses:**
1. `Assign policies at scope type? (Subscription/ResourceGroup/ManagementGroup) [Subscription]:`
   - **Note:** With `-ScopeType ManagementGroup` parameter, this prompt **should be skipped**
   - **If prompted anyway:** Enter `ManagementGroup`

2. `Enter Management Group ID:`
   - **Note:** With `-ManagementGroupId` parameter, this prompt **should be skipped**
   - **If prompted anyway:** Enter your Management Group ID

3. `Choose mode (Audit/Deny/Enforce) [Audit]:`
   - **Enter:** ❌ **DO NOT PROMPT**
   - **Temporary workaround:** Press Enter

---

### Test 9: Rollback

```powershell
.\AzPolicyImplScript.ps1 -Rollback -DryRun
```

**Prompts & Responses:**
1. `Rollback at which scope? (Subscription/ResourceGroup/ManagementGroup) [Subscription]:`
   - **Enter:** `Subscription` (or press Enter for default)

**Note:** No mode prompt for rollback operations.

---

## Summary Table

| Test # | Workflow | Scope Type | Use Subscription | Mode | Notes |
|--------|----------|-----------|------------------|------|-------|
| 1 | DevTestBaseline | Subscription | Y | ❌ DON'T PROMPT | Bug: prompts anyway |
| 2 | DevTestFull | Subscription | Y | ❌ DON'T PROMPT | Bug: prompts anyway |
| 3 | DevTestRemediation | Subscription | Y | ❌ DON'T PROMPT | **CRITICAL**: Overrides DeployIfNotExists |
| 4 | ProductionAudit | Subscription | Y | ❌ DON'T PROMPT | Bug: prompts anyway |
| 5 | ProductionDeny | Subscription | Y | ❌ DON'T PROMPT | Blocked: no parameter file |
| 6 | ProductionRemediation | Subscription | Y | ❌ DON'T PROMPT | **CRITICAL**: Overrides DeployIfNotExists |
| 7 | ResourceGroupScope | ResourceGroup* | Y | ❌ DON'T PROMPT | *Should skip prompt |
| 8 | ManagementGroupScope | ManagementGroup* | N/A | ❌ DON'T PROMPT | *Should skip prompt |
| 9 | Rollback | Subscription | N/A | N/A | Only scope prompt |

---

## After Fixes Applied

**Todo #2 (Mode Prompt Fix):**
- ✅ Mode prompt will be **skipped** when parameter file provided
- ✅ Script will use effects from parameter file (Audit/Deny/DeployIfNotExists/Modify)
- ✅ Tests 3 & 6 will work correctly with auto-remediation

**Todo #4 (DryRun Prompt Fix):**
- ✅ All prompts will be **skipped** in DryRun mode
- ✅ Defaults used: Subscription scope, current subscription, no mode prompt
- ✅ Fully automated testing enabled

**After fixes, the commands will work with ZERO user input required!**

---

## Quick Copy-Paste Commands (For Now)

Until prompts are fixed, here's how to run each test quickly:

```powershell
# Test 1: DevTestBaseline
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -DryRun -SkipRBACCheck -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
# When prompted: Subscription, Y, Enter

# Test 2: DevTestFull
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -DryRun -SkipRBACCheck -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
# When prompted: Subscription, Y, Enter

# Test 3: DevTestRemediation (⚠️ Mode prompt breaks auto-remediation)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json -DryRun -SkipRBACCheck -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
# When prompted: Subscription, Y, Enter

# Test 4: ProductionAudit
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -DryRun -SkipRBACCheck -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
# When prompted: Subscription, Y, Enter

# Test 6: ProductionRemediation (⚠️ Mode prompt breaks auto-remediation)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Remediation.json -DryRun -SkipRBACCheck -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
# When prompted: Subscription, Y, Enter

# Test 7: ResourceGroupScope
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -ScopeType ResourceGroup -ResourceGroupName "rg-policy-keyvault-test" -DryRun -SkipRBACCheck -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
# When prompted: Y, Enter (scope should be pre-set)

# Test 9: Rollback
.\AzPolicyImplScript.ps1 -Rollback -DryRun
# When prompted: Subscription (or just Enter)
```
