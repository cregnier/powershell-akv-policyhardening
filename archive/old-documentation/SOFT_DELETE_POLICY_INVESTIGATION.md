# Investigation: "Key vaults should have soft delete enabled" Policy Blocking All Vault Creation

**Date:** January 14, 2026  
**Policy ID:** 1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d  
**Policy Name:** Key vaults should have soft delete enabled  
**Assignment:** Keyvaultsshouldhavesoftdeleteenabled-102842608  

---

## Summary

After deploying all 46 Key Vault policies in Deny mode, the "Key vaults should have soft delete enabled" policy is blocking ALL vault creation attempts, including compliant vaults that have soft-delete enabled. This investigation documents the root cause and solution.

---

## Problem Statement

**Observed Behavior:**
- ✅ Non-compliant vault (EnableSoftDelete:$false) → BLOCKED (expected)
- ❌ Compliant vault (default soft-delete) → BLOCKED (unexpected)
- ❌ Compliant vault (EnablePurgeProtection) → BLOCKED (unexpected)

**Error Message:**
```
Resource 'kv-compliant-XXXX' was disallowed by policy.
Policy identifiers: [{
  "policyAssignment": {
    "name": "Keyvaultsshouldhavesoftdeleteenabled-102842608",
    "id": "/subscriptions/.../Keyvaultsshouldhavesoftdeleteenabled-102842608"
  },
  "policyDefinition": {
    "name": "Key vaults should have soft delete enabled",
    "id": "/providers/Microsoft.Authorization/policyDefinitions/1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d"
  }
}]
```

---

## Investigation Steps

### 1. Checked Microsoft Documentation

**Source:** Microsoft Learn - Azure Key Vault Soft Delete Overview

**Key Findings:**
- ✅ Soft-delete is **ENABLED BY DEFAULT** on all new Key Vaults (since ~2020)
- ✅ Soft-delete **CANNOT BE DISABLED** once a vault is created
- ✅ The `New-AzKeyVault` cmdlet **does NOT have** `-EnableSoftDelete` parameter (it's automatic)
- ✅ All new vaults automatically have `EnableSoftDelete = true`
- ✅ Retention period defaults to 90 days (configurable 7-90 days during creation only)

**PowerShell Examples from MS Docs:**
```powershell
# Correct syntax - soft-delete is automatic
$vault = New-AzKeyVault -Name $kvName `
    -ResourceGroupName $rgName `
    -Location $location `
    -EnablePurgeProtection  # Optional, but recommended

# This creates a vault with:
#   EnableSoftDelete: True (automatic)
#   EnablePurgeProtection: True (explicit)
#   SoftDeleteRetentionInDays: 90 (default)
```

### 2. Verified Existing Vaults

**Command:**
```powershell
Get-AzKeyVault -VaultName "kv-compliant-5899" | Select EnableSoftDelete, EnablePurgeProtection
```

**Result:**
```
EnableSoftDelete      : True
EnablePurgeProtection : True
```

**Conclusion:** Existing vaults DO have soft-delete enabled correctly.

### 3. Checked Policy Assignment Parameters

**Command:**
```powershell
$assignment = Get-AzPolicyAssignment -Name "Keyvaultsshouldhavesoftdeleteenabled-102842608"
$assignment.Parameter
```

**Result:**
```
effect : @{value=Deny}
```

**Enforcement Mode:** `Default` (enforcing)

**Conclusion:** The assignment is configured with `effect=Deny` and is actively enforcing.

### 4. Attempted to Get Policy Definition

**Problem Encountered:**
```powershell
$policyDef = Get-AzPolicyDefinition -Id $assignment.Properties.PolicyDefinitionId
# ERROR: Cannot bind argument to parameter 'Id' because it is an empty string.
```

**Root Cause:** PowerShell cmdlet `Get-AzPolicyAssignment` does NOT populate the `.Properties` object. The correct property path is:
- ❌ Wrong: `$assignment.Properties.PolicyDefinitionId` (returns empty)
- ✅ Correct: `$assignment.PolicyDefinitionId`

**Fix:**
```powershell
# Correct way to access properties
$assignment.PolicyDefinitionId                      # ✅ Works
$assignment.EnforcementMode                         # ✅ Works
$assignment.Parameter                               # ✅ Works

# Wrong way (returns null)
$assignment.Properties.PolicyDefinitionId           # ❌ Empty
$assignment.Properties.EnforcementMode              # ❌ Empty
```

### 5. Azure CLI Not Installed

**Problem:**
```powershell
az policy assignment show ...
# ERROR: The term 'az' is not recognized
```

**Solution Options:**
1. Install Azure CLI: `winget install Microsoft.AzureCLI`
2. Use PowerShell cmdlets with correct property paths (recommended for this session)
3. Use REST API directly with Get-AzAccessToken

---

## Root Cause Analysis

### Hypothesis 1: Policy Doesn't Support Deny Effect

**Theory:** The "soft delete" policy might only support `[Audit, Disabled]` effects, and setting `effect=Deny` causes unexpected behavior.

**Evidence:**
- Script deployment showed warnings for OTHER policies: "Effect 'Deny' not supported... Using policy default"
- But did NOT show warning for THIS policy
- This suggests either:
  - a) Policy DOES support Deny (and there's another issue)
  - b) Script didn't validate properly for THIS policy

**Status:** ⏳ **UNCONFIRMED** - Unable to retrieve policy definition parameters due to:
  - PowerShell property access issue
  - Azure REST API authentication issues
  - Azure CLI not installed

### Hypothesis 2: Policy Definition Bug

**Theory:** The policy's evaluation logic might have a bug that causes it to block ALL vault creation when effect=Deny, regardless of compliance.

**Evidence:**
- Soft-delete is enabled by default on ALL new vaults
- Existing compliant vaults exist with EnableSoftDelete=True
- Yet new vault creation with same settings is blocked

**Possible Explanations:**
1. **Timing issue:** Policy checks `EnableSoftDelete` property DURING ARM template deployment, but Azure sets it AFTER deployment completes
2. **Property mismatch:** Policy checks a different property path than what `New-AzKeyVault` sets
3. **ARM vs PowerShell:** Policy works correctly with ARM templates but not with PowerShell cmdlet calls

### Hypothesis 3: Assignment Parameter Format Issue

**Theory:** Our script might have set the effect parameter in an incompatible format.

**Evidence:**
```powershell
$assignment.Parameter
# Returns: effect : @{value=Deny}
```

This is the correct format. Azure Policy expects: `@{ effect = @{ value = "Deny" } }`

**Status:** ✅ **RULED OUT** - Parameter format is correct.

---

## Recommended Solutions

### Option 1: Change Policy Effect to Audit (Recommended for Now)

Since the policy is blocking ALL vault creation (including compliant ones), revert this specific policy to Audit mode:

```powershell
$assignment = Get-AzPolicyAssignment -Name "Keyvaultsshouldhavesoftdeleteenabled-102842608"

Set-AzPolicyAssignment -Id $assignment.Id -PolicyParameter @{
    effect = @{ value = "Audit" }
}
```

**Justification:**
- Soft-delete is **already enforced by Azure platform** (enabled by default, cannot be disabled)
- Having this policy in Audit mode still provides visibility via compliance reports
- Removes blocker for legitimate vault creation

### Option 2: Create Exemption for This Policy

If you want to keep Deny mode for other policies, exempt this one:

```powershell
New-AzPolicyExemption `
    -Name "SoftDeleteEnforcedByPlatform" `
    -PolicyAssignment $assignment `
    -ExemptionCategory "Waiver" `
    -Description "Soft-delete is enforced by Azure platform (enabled by default). Policy blocks all vault creation including compliant vaults."
```

### Option 3: Use ARM Template for Vault Creation

Try creating vaults via ARM template instead of PowerShell cmdlet:

```json
{
  "type": "Microsoft.KeyVault/vaults",
  "apiVersion": "2023-02-01",
  "name": "[parameters('vaultName')]",
  "location": "[parameters('location')]",
  "properties": {
    "sku": {
      "family": "A",
      "name": "standard"
    },
    "tenantId": "[subscription().tenantId]",
    "enableSoftDelete": true,
    "softDeleteRetentionInDays": 90,
    "enablePurgeProtection": true
  }
}
```

**Note:** Explicitly setting `"enableSoftDelete": true` in ARM template might satisfy the policy check during deployment.

### Option 4: Install Azure CLI and Investigate Further

```powershell
# Install Azure CLI
winget install Microsoft.AzureCLI

# Get full policy definition
az policy definition show `
    --name "1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d" `
    --query "{allowedEffects: parameters.effect.allowedValues, defaultEffect: parameters.effect.defaultValue}"

# Check policy rule condition
az policy definition show `
    --name "1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d" `
    --query "policyRule.if"
```

This would definitively answer:
- Does the policy support Deny effect?
- What exact condition is the policy checking?
- Is there a bug in the policy rule logic?

---

## Impact Assessment

### Current State
- ✅ **46/46 policies deployed** (script claims success)
- ✅ **Deny enforcement working** (proven by successful block of non-compliant vault)
- ❌ **1 policy blocking ALL operations** (including compliant vaults)
- ⏸️ **Phase 3 validation blocked** (cannot create test vaults)

### Recommendations for Production

1. **✅ Keep Deny mode for most policies** - It's working correctly
2. **⚠️ Revert soft-delete policy to Audit** - Until root cause is understood
3. **✅ Document this as known limitation** - Update KEYVAULT_POLICY_REFERENCE.md
4. **📝 Create Azure Support ticket** - Report potential bug in policy definition

### Why Soft-Delete Policy in Audit is Acceptable

1. **Platform enforcement:** Azure enforces soft-delete by default (cannot be disabled)
2. **No risk:** Even in Audit mode, vaults will have soft-delete enabled
3. **Compliance visibility:** Audit mode still reports compliance state
4. **Unblocks testing:** Allows Phase 3 validation to continue

---

## Action Items

- [ ] **Immediate:** Revert soft-delete policy to Audit mode
- [ ] **Testing:** Retry compliant vault creation
- [ ] **Documentation:** Update KEYVAULT_POLICY_REFERENCE.md with this finding
- [ ] **Investigation:** Install Azure CLI and get full policy definition
- [ ] **Optional:** Create Azure Support ticket for potential policy bug
- [ ] **Follow-up:** Test ARM template vault creation as alternative

---

## Lessons Learned

### PowerShell Cmdlet Property Access

**Problem:** `Get-AzPolicyAssignment` returns objects with confusing property structure

**Solution:**
```powershell
# ✅ Correct property paths:
$assignment.PolicyDefinitionId     # Not .Properties.PolicyDefinitionId
$assignment.EnforcementMode        # Not .Properties.EnforcementMode
$assignment.Parameter              # Not .Properties.Parameters

# Check available properties:
$assignment | Get-Member -MemberType Properties
```

### Azure Policy Effect Validation

**Problem:** Script set effect=Deny on a policy that may not support it

**Solution:** Add validation in script:
```powershell
# Before setting effect, check if it's allowed
$policyDef = Get-AzPolicyDefinition -Id $assignment.PolicyDefinitionId
$allowedEffects = $policyDef.Properties.Parameters.effect.allowedValues

if($allowedEffects -notcontains $desiredEffect) {
    Write-Warning "Effect '$desiredEffect' not supported. Allowed: $($allowedEffects -join ', ')"
    # Use default or skip
}
```

### Platform-Enforced Policies

**Insight:** Some Azure features are enforced at the platform level, making policies redundant:
- Soft-delete is **always enabled** on new Key Vaults
- Cannot be disabled
- Policy adds visibility but not enforcement value

**Recommendation:** Consider exempting or using Audit mode for platform-enforced features.

---

## Next Steps

1. Revert soft-delete policy to Audit mode
2. Continue Phase 3 testing with remaining 45 policies in Deny mode
3. Document this as known limitation in production runbook
4. Consider investigating with Azure CLI or Support ticket
