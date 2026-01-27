# Workflow Testing Summary - Quick Reference

**Date:** 2026-01-20  
**Tests Completed:** 6 of 9 workflows  
**Status:** \u26a0\ufe0f Critical issues identified requiring script fixes

---

## Test Results at a Glance

| # | Workflow | Status | Issues |
|---|----------|--------|--------|
| 1 | DevTestBaseline | \u2705 | 8 policies skipped (no identity) |
| 2 | DevTestFull | \u2705 | 8 policies skipped (no identity) |
| 3 | DevTestRemediation | \u2705 | Mode prompt (CRITICAL) |
| 4 | ProductionAudit | \u2705 | 8 policies skipped (no identity) |
| 5 | ProductionDeny | \u23f8\ufe0f | Missing parameter file |
| 6 | ProductionRemediation | \u2705 | Mode prompt (CRITICAL) |
| 7 | ResourceGroupScope | \u23f8\ufe0f | Not tested yet |
| 8 | ManagementGroupScope | \u23f8\ufe0f | Not tested yet |
| 9 | Rollback | \u2705 | No issues |

---

## \ud83d\udd34 CRITICAL Issue: Mode Prompt Overrides Parameter Files

**Problem:**  
Script prompts "Choose mode (Audit/Deny/Enforce)" even when parameter file defines effects.

**User Response:** Entering "Audit" overrides:
- ❌ DeployIfNotExists → Audit (breaks auto-remediation)
- ❌ Modify → Audit (breaks configuration enforcement)  
- ❌ Deny → Audit (weakens security)

**Workflows Affected:**
- Test 3: DevTestRemediation
- Test 6: ProductionRemediation

**Correct Values for Each Workflow (SHOULD NOT PROMPT):**

| Workflow | Scope | Subscription | Mode | Correct Behavior |
|----------|-------|--------------|------|------------------|
| DevTestBaseline | Subscription | Y | ❌ DON'T PROMPT | Use parameter file effects |
| DevTestFull | Subscription | Y | ❌ DON'T PROMPT | Use parameter file effects |
| DevTestRemediation | Subscription | Y | ❌ DON'T PROMPT | Use DeployIfNotExists from file |
| ProductionAudit | Subscription | Y | ❌ DON'T PROMPT | Use parameter file effects |
| ProductionDeny | Subscription | Y | ❌ DON'T PROMPT | Use Deny from file |
| ProductionRemediation | Subscription | Y | ❌ DON'T PROMPT | Use DeployIfNotExists from file |
| ResourceGroupScope | ResourceGroup | Y | ❌ DON'T PROMPT | Use parameter file effects |
| ManagementGroupScope | ManagementGroup | Y | ❌ DON'T PROMPT | Use parameter file effects |
| Rollback | Subscription | N/A | N/A | Only prompts for scope |

---

## Required Parameters Per Workflow

### DevTest Workflows (Testing Safe)

**Test 1: DevTestBaseline (30 Policies)**
```powershell
.\AzPolicyImplScript.ps1 `
  -ParameterFile .\PolicyParameters-DevTest.json `
  -DryRun `
  -SkipRBACCheck `
  -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Test 2: DevTestFull (46 Policies)**
```powershell
.\AzPolicyImplScript.ps1 `
  -ParameterFile .\PolicyParameters-DevTest-Full.json `
  -DryRun `
  -SkipRBACCheck `
  -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Test 3: DevTestRemediation (46 Policies + Auto-Remediation)**
```powershell
.\AzPolicyImplScript.ps1 `
  -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
  -DryRun `
  -SkipRBACCheck `
  -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

### Production Workflows (Strict Enforcement)

**Test 4: ProductionAudit (46 Policies - Monitoring Only)**
```powershell
.\AzPolicyImplScript.ps1 `
  -ParameterFile .\PolicyParameters-Production.json `
  -DryRun `
  -SkipRBACCheck `
  -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Test 5: ProductionDeny (46 Policies - Blocking Mode)**
```powershell
# BLOCKED: Requires PolicyParameters-Production-Deny.json (does not exist)
```

**Test 6: ProductionRemediation (46 Policies + Auto-Fix)**
```powershell
.\AzPolicyImplScript.ps1 `
  -ParameterFile .\PolicyParameters-Production-Remediation.json `
  -DryRun `
  -SkipRBACCheck `
  -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

### Scope-Based Workflows

**Test 7: ResourceGroupScope**
```powershell
.\AzPolicyImplScript.ps1 `
  -ParameterFile .\PolicyParameters-DevTest.json `
  -ScopeType ResourceGroup `
  -ResourceGroupName "rg-policy-keyvault-test" `
  -DryRun `
  -SkipRBACCheck `
  -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Test 8: ManagementGroupScope**
```powershell
.\AzPolicyImplScript.ps1 `
  -ParameterFile .\PolicyParameters-Production.json `
  -ScopeType ManagementGroup `
  -ManagementGroupId "<YOUR-MG-ID>" `
  -DryRun `
  -SkipRBACCheck `
  -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

### Cleanup Workflow

**Test 9: Rollback (Remove All Policies)**
```powershell
.\AzPolicyImplScript.ps1 -Rollback -DryRun
```

---

## 8 Policies Requiring Managed Identity

Without `-IdentityResourceId`, these policies are **SKIPPED**:

1. Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace
2. [Preview]: Configure Azure Key Vault Managed HSM to disable public network access
3. Configure key vaults to enable firewall
4. Configure Azure Key Vaults with private endpoints
5. Configure Azure Key Vaults to use private DNS zones
6. [Preview]: Configure Azure Key Vault Managed HSM with private endpoints
7. Deploy - Configure diagnostic settings to an Event Hub to be enabled on Azure Key Vault Managed HSM
8. Deploy Diagnostic Settings for Key Vault to Event Hub

**Effects:** DeployIfNotExists, Modify  
**Purpose:** Auto-remediation, security configuration deployment

---

## Next Actions

### Immediate (Fix Script):
1. \ud83d\udd34 Remove mode prompt when parameter file provided (AzPolicyImplScript.ps1 ~line 4050)
2. \ud83d\udfe1 Skip all prompts in DryRun mode
3. \ud83d\udfe1 Document `-IdentityResourceId` requirement in QUICKSTART.md

### Short-Term (Complete Testing):
4. Create PolicyParameters-Production-Deny.json
5. Re-run all 9 workflows with fixed script
6. Create WORKFLOW-TESTING-GUIDE.md

### Long-Term (Package Release):
7. Update all documentation with correct command syntax
8. Create v1.1 deployment package with fixes

---

## Documentation Files

- **Detailed Analysis:** [Workflow-Testing-Analysis.md](Workflow-Testing-Analysis.md)
- **Todo List:** See VS Code Todo List (11 items)
- **Original Issue:** User request to complete workflow tests 7, 8, 9 and fix issues

---

## Key Learnings

### \u2705 What Worked:
- Policy definition lookup (3,745 policies)
- Parameter validation against schemas
- Managed identity assignment
- Report generation (HTML/JSON/CSV/Markdown)
- Dry-run simulation

### \u274c What Needs Fixing:
- Mode prompt overrides parameter file effects
- DryRun mode still prompts for user input
- Missing documentation for required parameters
- No Deny-mode parameter file available

### \u2139\ufe0f Important Notes:
- Always use `-IdentityResourceId` for remediation workflows
- Parameter files are authoritative for policy effects
- 8 of 46 policies require managed identity
- Production values stricter than DevTest (90 vs 30 days, 4096 vs 2048 bits)
