# PolicyParameters-Production.json - Quick Reference
**For**: Stakeholder Meeting (January 30, 2026)  
**Purpose**: Clarify parameter file confusion

---

## ⚠️ CRITICAL: This is NOT Audit-Only!

**PolicyParameters-Production.json** has **MIXED enforcement**:
- 18 Deny policies (BLOCKS resources)
- 16 Audit policies (monitoring only)
- 8 DeployIfNotExists (AUTO-REMEDIATES)
- 2 Modify policies (AUTO-CHANGES)

**For today's meeting, you need an audit-only file!**

---

## Quick Answers

### Q1: Why does Production.json have "Deny" if we want audit-only?

**Answer**: The file comment says "Production environment - All 46 policies with strict security parameters and **Deny enforcement on critical policies**"

This is designed for **FUTURE enforcement** (after pilot success), NOT for initial deployment.

### Q2: What should I use for the stakeholder meeting?

**Answer**: Use **PolicyParameters-Production.json** with `-PolicyMode Audit`!

✅ **NO NEED** to create a new JSON file!  
✅ The `-PolicyMode Audit` parameter **OVERRIDES** all effect values in the JSON  
✅ Script automatically converts all Deny/DINE/Modify → Audit

### Q3: How does -PolicyMode Audit override the JSON file?

**Code Logic** (from AzPolicyImplScript.ps1):
```powershell
# Script overrides effect parameter based on -PolicyMode
$desiredEffect = if ($Mode -eq 'Deny' -or $Mode -eq 'Enforce') { 'Deny' } else { 'Audit' }

if ($allowedEffects -contains $desiredEffect) {
    $parameters['effect'] = $desiredEffect  # ← OVERRIDES JSON!
}
```

**Result**: `-PolicyMode Audit` forces ALL policies to Audit mode, regardless of JSON values!

---

## Effect Breakdown

| Effect | Count | Risk | Use When |
|--------|-------|------|----------|
| **Deny** | 18 | ❌ HIGH | After pilot success, remediation complete |
| **Audit** | 16 | ✅ ZERO | Initial deployment, monitoring |
| **DINE** | 8 | ⚠️ MED | Auto-remediation phase |
| **Modify** | 2 | ⚠️ MED | Auto-remediation phase |

---

## Correct Deployment Command

### For Stakeholder Meeting Demo (ZERO RISK - Production.json + PolicyMode Override)

```powershell
# Get managed identity
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# Deploy ALL 46 policies in Audit mode (PolicyMode overrides JSON Deny/DINE/Modify)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Audit `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck
```

**What Happens**:
- ✅ Reads PolicyParameters-Production.json (46 policies with Deny/DINE/Modify)
- ✅ **-PolicyMode Audit OVERRIDES all effects to Audit**
- ✅ Sets EnforcementMode = 'DoNotEnforce' (double protection)
- ✅ **RESULT**: Pure monitoring, zero production impact

**No Need to Create Audit-Only JSON!** The script handles it automatically!

## Deployment Stages (Same File, Different -PolicyMode)

### Stage 1: Initial Visibility
**File**: PolicyParameters-Production.json  
**Command**: `-PolicyMode Audit`  
**Duration**: 1-2 weeks  
**Purpose**: Baseline compliance, identify gaps  
**Risk**: ZERO (monitoring only)

### Stage 2: Auto-Remediation
**File**: PolicyParameters-Production.json  
**Command**: `-PolicyMode Enforce`  
**Duration**: 2-4 weeks  
**Purpose**: Fix non-compliant resources automatically  
**Risk**: MEDIUM (makes changes, requires testing)

### Stage 3: Full Enforcement
**File**: PolicyParameters-Production.json  
**Command**: `-PolicyMode Deny` or `-PolicyMode Enforce`  
**Duration**: Ongoing  
**Purpose**: Block new non-compliant resources  
**Risk**: HIGH (breaks non-compliant deployments)

---

## For Your Meeting

**Say This**:
> "We'll deploy in **Audit mode only** - pure monitoring, zero production impact. The Production.json file exists for a **future enforcement phase** after we've proven success and remediated non-compliant resources."

**NOT This**:
> "We'll deploy Production.json" ← This will scare stakeholders (Deny mode!)

---

## Files Created for You

1. **[PolicyParameters-Production-ANALYSIS.md](c:\Source\powershell-akv-policyhardening\PolicyParameters-Production-ANALYSIS.md)** - Full breakdown of all 46 policies
2. **[S-C-K-GAP-ANALYSIS.md](c:\Source\powershell-akv-policyhardening\S-C-K-GAP-ANALYSIS.md)** - Proof that 0/30 policies are deployed
3. **THIS FILE** - Quick reference

---

**Action Required Before Meeting**:
1. ✅ Use PolicyParameters-Production.json with `-PolicyMode Audit` (no new file needed!)
2. ✅ Update meeting materials to emphasize "-PolicyMode Audit OVERRIDES to monitoring only"
3. ✅ Clarify: "Same file supports all phases - we just change -PolicyMode parameter"

**Estimated Time**: 2 minutes (just update talking points)
