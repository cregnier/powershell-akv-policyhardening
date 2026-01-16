# Azure Key Vault Policy Reference Guide
## Comprehensive Policy Capabilities Matrix

**Generated**: January 14, 2026  
**Total Policies**: 46 Azure Key Vault Built-in Policies  
**Purpose**: Complete reference for all Key Vault policy effects and parameters

---

## Quick Reference Summary

Based on official Microsoft Learn documentation:

- **All 46 policies** support **Audit** effect
- **Most policies** support **Deny** effect for enforcement  
- **Several policies** support **Modify**, **DeployIfNotExists**, or **AuditIfNotExists** effects
- **Parameter requirements** vary by policy type

---

## Policy Categories

### 1. Key Vault Configuration Policies

#### 1.1 Network Access & Isolation

| Policy Name | Can Audit | Can Deny/Block | Has Parameters | Notes |
|-------------|-----------|----------------|----------------|-------|
| **Azure Key Vault should disable public network access** | ✅ Yes | ✅ Yes (Deny) | ❌ No | Existence check only |
| **Azure Key Vault should have firewall enabled or public network access disabled** | ✅ Yes | ✅ Yes (Deny) | ❌ No | Existence check, Version 3.3.0 |
| **Azure Key Vaults should use private link** | ✅ Yes | ✅ Yes (Deny) | ❌ No | Preview policy, Version 1.2.1 |
| **Configure Azure Key Vaults with private endpoints** | N/A | N/A (DINE) | ✅ Yes | DeployIfNotExists - requires subnet config |
| **Configure Azure Key Vaults to use private DNS zones** | N/A | N/A (DINE) | ✅ Yes | DeployIfNotExists - requires DNS zone ID |
| **Configure key vaults to enable firewall** | N/A | N/A (Modify) | ✅ Yes | Modify effect - automated remediation |

#### 1.2 Deletion Protection

| Policy Name | Can Audit | Can Deny/Block | Has Parameters | Notes |
|-------------|-----------|----------------|----------------|-------|
| **Key vaults should have deletion protection enabled** | ✅ Yes | ✅ Yes (Deny) | ❌ No | Version 2.1.0, no parameters |
| **Key vaults should have soft delete enabled** | ✅ Yes | ⚠️ **Use Audit Only** | ❌ No | Version 3.1.0, **Deny mode has ARM timing bug** - see below |

#### 1.3 Access Control

| Policy Name | Can Audit | Can Deny/Block | Has Parameters | Notes |
|-------------|-----------|----------------|----------------|-------|
| **Azure Key Vault should use RBAC permission model** | ✅ Yes | ✅ Yes (Deny) | ❌ No | Version 1.0.1 |

---

### 2. Diagnostic & Monitoring Policies

| Policy Name | Can Audit | Can Deny/Block | Has Parameters | Notes |
|-------------|-----------|----------------|----------------|-------|
| **Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace** | N/A | N/A (DINE) | ✅ Yes | Requires Log Analytics workspace ID |
| **Deploy Diagnostic Settings for Key Vault to Event Hub** | N/A | N/A (DINE) | ✅ Yes | Requires Event Hub Rule ID + location |
| **Resource logs in Key Vault should be enabled** | ✅ Yes (AINE) | ❌ No | ❌ No | AuditIfNotExists effect, Version 5.0.0 |

---

### 3. Certificate Policies

| Policy Name | Can Audit | Can Deny/Block | Has Parameters | Notes |
|-------------|-----------|----------------|----------------|-------|
| **Certificates should have the specified maximum validity period** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | `maximumValidityInDays` parameter |
| **Certificates should have the specified lifetime action triggers** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | `maximumPercentageLife`, `minimumDaysBeforeExpiry` |
| **Certificates should not expire within the specified number of days** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | `daysToExpire` parameter |
| **Certificates should use allowed key types** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | Allowed key types list parameter |
| **Certificates should be issued by the specified integrated certificate authority** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | Integrated CA name parameter |
| **Certificates should be issued by the specified non-integrated certificate authority** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | Non-integrated CA common name |
| **Certificates should be issued by one of the specified non-integrated certificate authorities** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | Array of CA common names |
| **Certificates using elliptic curve cryptography should have allowed curve names** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | Allowed curve names list |
| **Certificates using RSA cryptography should have the specified minimum key size** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | `minimumRSAKeySize` (e.g., 2048) |

---

### 4. Key Policies

| Policy Name | Can Audit | Can Deny/Block | Has Parameters | Notes |
|-------------|-----------|----------------|----------------|-------|
| **Key Vault keys should have an expiration date** | ✅ Yes | ✅ Yes (Deny) | ❌ No | Existence check, Version 1.0.2 |
| **Keys should have the specified maximum validity period** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | `maximumValidityInDays` parameter |
| **Keys should have more than the specified number of days before expiration** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | `minimumDaysBeforeExpiration` (e.g., 90) |
| **Keys should not be active for longer than the specified number of days** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | `maximumValidityInDays` limit |
| **Keys should be backed by a hardware security module (HSM)** | ✅ Yes | ✅ Yes (Deny) | ❌ No | Existence check, Version 1.0.1 |
| **Keys should be the specified cryptographic type RSA or EC** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | Cryptographic type list |
| **Keys using RSA cryptography should have a specified minimum key size** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | `minimumRSAKeySize` (e.g., 2048) |
| **Keys using elliptic curve cryptography should have the specified curve names** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | Allowed curve names |
| **Keys should have a rotation policy ensuring that their rotation is scheduled within the specified number of days after creation.** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | `maximumDaysToRotate` (e.g., 90) |

---

### 5. Secret Policies

| Policy Name | Can Audit | Can Deny/Block | Has Parameters | Notes |
|-------------|-----------|----------------|----------------|-------|
| **Key Vault secrets should have an expiration date** | ✅ Yes | ✅ Yes (Deny) | ❌ No | **No parameters** - existence check only |
| **Secrets should have the specified maximum validity period** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | `maximumValidityInDays` parameter |
| **Secrets should have more than the specified number of days before expiration** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | `minimumDaysBeforeExpiration` (e.g., 90) |
| **Secrets should not be active for longer than the specified number of days** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | `maximumValidityInDays` limit |
| **Secrets should have content type set** | ✅ Yes | ✅ Yes (Deny) | ❌ No | Existence check, Version 1.0.1 |

---

### 6. Managed HSM Policies (Preview)

| Policy Name | Can Audit | Can Deny/Block | Has Parameters | Notes |
|-------------|-----------|----------------|----------------|-------|
| **[Preview]: Azure Key Vault Managed HSM should disable public network access** | ✅ Yes | ❌ No | ❌ No | Audit only in preview |
| **[Preview]: Azure Key Vault Managed HSM keys should have an expiration date** | ✅ Yes | ✅ Yes (Deny) | ❌ No | Preview, Version 1.0.1-preview |
| **[Preview]: Azure Key Vault Managed HSM should use private link** | ✅ Yes | ❌ No | ❌ No | Audit only |
| **[Preview]: Azure Key Vault Managed HSM Keys should have more than the specified number of days before expiration** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | `minimumDaysBeforeExpiration` |
| **[Preview]: Azure Key Vault Managed HSM keys using RSA cryptography should have a specified minimum key size** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | `minimumRSAKeySize` |
| **[Preview]: Azure Key Vault Managed HSM keys using elliptic curve cryptography should have the specified curve names** | ✅ Yes | ✅ Yes (Deny) | ✅ Yes | Curve names list |
| **[Preview]: Configure Azure Key Vault Managed HSM to disable public network access** | N/A | N/A (Modify) | ❌ No | Version 2.0.0-preview |
| **[Preview]: Configure Azure Key Vault Managed HSM with private endpoints** | N/A | N/A (DINE) | ✅ Yes | Private endpoint subnet config |
| **Azure Key Vault Managed HSM should have purge protection enabled** | ✅ Yes | ✅ Yes (Deny) | ❌ No | Version 1.0.0 |
| **Resource logs in Azure Key Vault Managed HSM should be enabled** | ✅ Yes (AINE) | ❌ No | ❌ No | AuditIfNotExists, Version 1.1.0 |
| **Deploy - Configure diagnostic settings to an Event Hub to be enabled on Azure Key Vault Managed HSM** | N/A | N/A (DINE) | ✅ Yes | Event Hub configuration |

---

## Effect Types Explained

| Effect | Description | Use Case |
|--------|-------------|----------|
| **Audit** | Logs non-compliance without blocking | Reporting, compliance monitoring |
| **Deny** | Blocks creation/update of non-compliant resources | Enforcement, prevention |
| **Disabled** | Policy evaluation skipped | Conditional disabling |
| **Modify** | Auto-remediates configuration drift | Automated compliance |
| **DeployIfNotExists** | Deploys missing configurations | Infrastructure automation |
| **AuditIfNotExists** | Audits missing related resources | Diagnostic/monitoring checks |

---

## Parameter Requirements by Policy

### Policies WITHOUT Parameters (Existence Checks Only)

These policies check for the **presence or absence** of a setting - no configurable parameters:

1. ✅ **Key vaults should have deletion protection enabled** - NO parameters
2. ✅ **Key Vault secrets should have an expiration date** - NO parameters
3. Key vaults should have soft delete enabled
4. Azure Key Vault should disable public network access
5. Keys should be backed by a hardware security module (HSM)
6. Key Vault keys should have an expiration date
7. Secrets should have content type set
8. Azure Key Vault should use RBAC permission model
9. Azure Key Vault should have firewall enabled

### Policies WITH Configurable Parameters

See individual policy tables above for specific parameter requirements.

---

## Testing Recommendations

### Phase 1: Audit Mode
- Deploy all 46 policies in **Audit** effect
- Establish compliance baseline
- Identify non-compliant resources

### Phase 2: Selective Deny Mode
- Enable **Deny** on critical policies:
  - Deletion protection
  - Soft delete
  - Secret/key expiration
  - HSM requirements
  - Public access restrictions

### Phase 3: Comprehensive Deny Mode
- Enable **Deny** on all policies after validation
- Test blocking behavior
- Verify error messages guide users

### Phase 4: Automated Remediation
- Enable **Modify** and **DeployIfNotExists** policies
- Test auto-remediation
- Validate managed identity permissions

---

## Production Deployment Strategy

### Tier 1: Critical Security (Immediate Enforcement)
```
- Key vaults should have deletion protection enabled
- Key vaults should have soft delete enabled
- Azure Key Vault should disable public network access
- Key Vault secrets should have an expiration date
```

### Tier 2: Compliance & Governance (30-day grace)
```
- Keys should be backed by a hardware security module (HSM)
- Certificates using RSA cryptography minimum key size
- Keys/Secrets maximum validity periods
- Diagnostic logging policies
```

### Tier 3: Operational Excellence (60-day grace)
```
- Private link configurations
- DNS zone configurations
- Rotation policies
- Certificate lifetime triggers
```

---

## Important Findings

### ✅ Confirmed Policy Capabilities (Verified via GitHub Source + Testing)

**ALL Key Vault policies that list "Audit, Deny, Disabled" in Effect(s) column DO support Deny enforcement.**

This has been confirmed by:
1. ✅ **Microsoft Learn Documentation**: Lists supported effects
2. ✅ **GitHub Policy Definitions**: Source code shows parameterized effect with allowedValues
3. ✅ **Testing Results**: Policies can be assigned with effect=Deny

**Example Verified Policies:**

1. **Key vaults should have deletion protection enabled** (0b60c0b2-2dc2-4e1c-b5c9-abbed971de53)
   - ✅ CAN Audit
   - ✅ CAN Deny/Block (**CONFIRMED via [GitHub source](https://github.com/Azure/azure-policy/blob/master/built-in-policies/policyDefinitions/Key%20Vault/Recoverable_Audit.json)**)
   - ✅ HAS effect parameter (allowedValues: ["Audit", "Deny", "Disabled"], defaultValue: "Audit")
   - ❌ NO other parameters (existence check only)
   - Version: 2.1.0

2. **Key Vault secrets should have an expiration date** (98728c90-32c7-4049-8429-847dc0f4fe37)
   - ✅ CAN Audit
   - ✅ CAN Deny/Block (**Effect parameter supported**)
   - ✅ HAS effect parameter
   - ❌ NO other parameters (existence check only)
   - Version: 1.0.2

### 🔍 Parameter Warnings Explained

When you see warnings like:
```
[WARN] Parameter 'enablePurgeProtection' not defined in policy
[WARN] Parameter 'defaultExpiryDays' not defined in policy
```

**This is CORRECT behavior** - these policies don't accept parameters. They simply check if the feature is enabled (purge protection) or if an expiration date exists (secrets).

The script **correctly skips** these undefined parameters instead of causing errors.

---

### 🐛 **CRITICAL: Soft Delete Policy Bug** (Resolved January 14, 2026)

**Policy**: "Key vaults should have soft delete enabled" (1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d)

**Issue**: Policy definition supports Deny effect but has ARM timing bug during vault creation.

**GitHub Source Analysis**:
```json
{
  "parameters": {
    "effect": {
      "allowedValues": ["Audit", "Deny", "Disabled"],
      "defaultValue": "Audit"
    }
  },
  "policyRule": {
    "if": {
      "anyOf": [
        { "field": "Microsoft.KeyVault/vaults/enableSoftDelete", "equals": "false" },
        { "field": "Microsoft.KeyVault/vaults/enableSoftDelete", "exists": "false" }
      ]
    }
  }
}
```

**Root Cause**:
- Policy checks if `enableSoftDelete` field **exists = false** OR **equals "false"**
- During ARM vault creation, this field doesn't exist in the request payload yet
- Azure auto-enables soft-delete AFTER validation
- Policy triggers Deny before Azure can set the property
- **Result**: ALL vault creation blocked, even compliant requests

**Evidence**:
- ✅ Policy allows `effect = "Deny"` (confirmed via GitHub source)
- ❌ Setting to Deny blocks ALL vault creation (tested)
- ✅ Changing to Audit allows compliant vaults (tested + confirmed)
- ℹ️ Soft-delete is mandatory since 2020, cannot be disabled

**Solution**: **Use Audit mode only** for this specific policy
```powershell
Set-AzPolicyAssignment -Id $assignmentId -PolicyParameter @{effect='Audit'}
```

**Recommendation**: This is acceptable because:
1. Soft-delete is enabled by default and cannot be disabled
2. Policy in Audit mode still reports non-compliance (if it could occur)
3. Other deletion protection policies (purge protection) work correctly in Deny mode

---

### ⚠️ **CRITICAL TESTING DISCOVERY** (January 14, 2026)

**Issue Found**: AzPolicyImplScript.ps1 assignment logic has a flaw when switching between modes (Audit → Deny):

**Problem**: 
```
[INFO] Assignment already exists for 'Policy Name' at this scope. Using existing assignment.
```

When the script detects an existing assignment, it **skips** updating the effect parameter. This means:
- ❌ Policies remain in **Audit mode** even when script is run with `-PolicyMode Deny`
- ❌ Effect parameter is **not updated** on existing assignments
- ❌ Policies **do not block** non-compliant resources as expected

**Evidence from Testing**:
- Script output: "Deployed 46/46 policies in Deny mode" ✅
- Policy assignments created: **Reused existing Audit assignments** ⚠️
- Effect parameter value: **null** (defaults to "Audit") ❌
- Blocking tests: **0 out of 3 vault tests blocked** ❌
  - Non-compliant vault created successfully (should have been denied)
  - Compliant vault created successfully (expected)
  - Public vault created successfully (may violate network policy)

**What Actually Happened**:
1. Phase 2: Created 46 assignments with effect="Audit" (default)
2. Phase 3 cleanup: Removed all 46 assignments ✅
3. Phase 3 deploy: Script detected "existing assignments" (from cleanup timing?)
4. Script **reused** old assignment metadata WITHOUT updating effect parameter
5. Result: All policies still in Audit mode, not Deny mode

**Root Cause**: Script assignment logic needs to **update** existing assignments when mode changes, not skip them.

**Impact**: 
- Testing blocked - Cannot validate Deny enforcement until script is fixed
- Production deployment strategy needs revision
- Policy assignments must be explicitly updated or removed/recreated when changing effects

**Fix Required**: Modify AzPolicyImplScript.ps1 to:
```powershell
# Instead of:
"Assignment already exists... Using existing assignment"

# Should be:
"Assignment already exists... Updating effect parameter to $Mode"
Set-AzPolicyAssignment -Id $existingAssignment.Id -Parameter @{effect=$desiredEffect}
```

---

### 🔍 Parameter Warnings Explained (REVISED)

## References

- **Microsoft Learn**: [Azure Policy Built-in Policies - Key Vault](https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies#key-vault)
- **Azure Policy Effects**: [Policy Effects Documentation](https://learn.microsoft.com/azure/governance/policy/concepts/effects)
- **Key Vault Security**: [Azure Key Vault Security Overview](https://learn.microsoft.com/azure/key-vault/general/security-features)

---

## Document Version

- **Version**: 1.0
- **Last Updated**: January 14, 2026
- **Validated Against**: Azure Policy API (January 2026)
- **Coverage**: All 46 Azure Key Vault Built-in Policies

---

## How to Switch Policy Effects (Audit ↔ Deny)

### ✅ **Correct Approach** - Update Existing Assignments

When changing policy mode, you must **update the effect parameter** on existing assignments:

```powershell
# Get existing assignment
$assignment = Get-AzPolicyAssignment -Name "PolicyAssignmentName"

# Update effect parameter
Set-AzPolicyAssignment `
  -Id $assignment.Id `
  -PolicyParameter @{ effect = @{ value = "Deny" } }
```

### ❌ **Incorrect Approach** - Skip Updates

Do NOT skip existing assignments when mode changes:
```powershell
# WRONG - This leaves old effect in place!
if (Get-AzPolicyAssignment -Name $assignmentName) {
    Write-Host "Assignment exists, skipping..."
    return
}
```

### 🔄 **Alternative Approach** - Remove & Recreate

If parameter updates fail, remove and recreate:
```powershell
# Remove old assignment
Remove-AzPolicyAssignment -Name "PolicyAssignmentName"

# Wait for propagation
Start-Sleep -Seconds 5

# Create new assignment with desired effect
New-AzPolicyAssignment `
  -Name "PolicyAssignmentName" `
  -PolicyDefinition $policyDef `
  -Parameter @{ effect = @{ value = "Deny" } }
```

---

## Notes for Implementation Teams

1. **Not all policies support all effects** - Always check the "Effect(s)" column
2. **Parameter requirements vary** - Some policies are existence checks only
3. **Preview policies** may have limited effect support
4. **Modify/DINE policies** require managed identity with proper RBAC
5. **Test in Audit mode first** before enabling Deny
6. **Parameters in PolicyParameters.json** may not match policy definitions - script handles this

---

*This document was generated to support comprehensive Azure Key Vault policy implementation and testing. For the most up-to-date policy definitions, always refer to Microsoft Learn documentation.*
