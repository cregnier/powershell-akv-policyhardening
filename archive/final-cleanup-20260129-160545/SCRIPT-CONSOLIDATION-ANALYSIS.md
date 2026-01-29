# Script Consolidation Analysis & Parameter File Usage Guide

**Date**: 2026-01-27  
**Purpose**: Document script consolidation opportunities and policy parameter file usage scenarios  
**Status**: Analysis Complete - Recommendations Provided

---

## 📊 Current Script Inventory

### Core Scripts (DO NOT CONSOLIDATE - Production Ready)

| Script | Lines | Purpose | Status |
|--------|-------|---------|--------|
| **AzPolicyImplScript.ps1** | 6,695 | Main deployment, testing, compliance | ✅ FINAL |
| **Setup-AzureKeyVaultPolicyEnvironment.ps1** | 1,220 | Infrastructure setup | ✅ FINAL |

**Recommendation**: Keep these separate - they serve distinct purposes and consolidation would reduce maintainability.

---

### Utility Scripts (CONSOLIDATION OPPORTUNITIES)

#### 1. ✅ **Check-Scenario7-Status.ps1** (102 lines)
**Purpose**: Monitor Scenario 7 remediation progress  
**Current Usage**: Standalone monitoring script  

**Consolidation Recommendation**: **ADD to AzPolicyImplScript.ps1**

**Rationale**:
- This is scenario-specific monitoring logic
- Could be added as `-CheckRemediationStatus` parameter
- Would reduce file count and improve discoverability

**Proposed Integration**:
```powershell
# Add new parameter to AzPolicyImplScript.ps1
[switch]$CheckRemediationStatus

# Add new function
function Check-RemediationProgress {
    param([datetime]$DeploymentTime)
    # Copy logic from Check-Scenario7-Status.ps1
}
```

**Migration Effort**: Low (30 minutes)

---

#### 2. ⚠️ **Generate-MasterHtmlReport.ps1** (898 lines)
**Purpose**: Generate comprehensive stakeholder report  
**Current Usage**: Standalone report generation  

**Consolidation Recommendation**: **KEEP SEPARATE**

**Rationale**:
- Large, complex report generation logic (898 lines)
- Used independently after all scenarios complete
- Adding to AzPolicyImplScript.ps1 would increase complexity
- Stakeholders may run this without deployment permissions

**Keep As-Is**: Standalone script is appropriate here

---

#### 3. ✅ **Capture-ScenarioOutput.ps1** (69 lines)
**Purpose**: Wrapper for transcript capture during testing  
**Current Usage**: Development/testing only  

**Consolidation Recommendation**: **ARCHIVE - No longer needed**

**Rationale**:
- AzPolicyImplScript.ps1 has built-in logging at lines 5800+ (Start-Transcript)
- Redundant functionality
- Move to `archive/deprecated-utilities/`

**Migration Effort**: None (already replaced)

---

#### 4. ⚠️ **Cleanup-Workspace.ps1** (192 lines)
**Purpose**: Archive old reports and maintain clean workspace  
**Current Usage**: Periodic maintenance  

**Consolidation Recommendation**: **KEEP SEPARATE**

**Rationale**:
- Housekeeping task, not deployment logic
- Should be run independently (weekly/monthly)
- Could be added to `.github/workflows` for automation

**Enhancement Opportunity**: Add `-CleanupArchive` parameter to AzPolicyImplScript.ps1 that calls this script

---

### Archived Scripts (ALREADY CONSOLIDATED)

These scripts in `archive/scripts/` were previously consolidated into AzPolicyImplScript.ps1:

| Script | Consolidated Into | Notes |
|--------|-------------------|-------|
| TestReadiness.ps1 | AzPolicyImplScript.ps1 | Now `-TestInfrastructure` |
| RunFullTest.ps1 | AzPolicyImplScript.ps1 | Now `-TestAllDenyPolicies` |
| TestParameterBinding.ps1 | Development testing | No longer needed |
| RollbackTier1Policies.ps1 | AzPolicyImplScript.ps1 | Now `-Rollback` |
| SetupAzureMonitorAlerts.ps1 | Setup-AzureKeyVaultPolicyEnvironment.ps1 | Integrated |

---

## 📋 Policy Parameter Files - Scenario Mapping

### Complete Parameter File Inventory

| # | File | Policies | Mode | Scenario(s) | -PolicyMode | -IdentityResourceId |
|---|------|----------|------|-------------|-------------|---------------------|
| 1 | **PolicyParameters-DevTest.json** | 30 | Audit | S1-3 | Audit | ⚠️ Recommended* |
| 2 | **PolicyParameters-DevTest-Full.json** | 46 | Audit | S4 | Audit | ⚠️ Recommended* |
| 3 | **PolicyParameters-DevTest-Full-Remediation.json** | 46 | 8 Enforce + 38 Audit | S4 (Testing) | Enforce | ✅ **REQUIRED** |
| 4 | **PolicyParameters-Production.json** | 46 | Audit | S5 | Audit | ⚠️ Recommended* |
| 5 | **PolicyParameters-Production-Deny.json** | 34 | Deny | S6 | Deny | ❌ Not needed |
| 6 | **PolicyParameters-Production-Remediation.json** | 46 | 8 Enforce + 38 Audit | S7 | Enforce | ✅ **REQUIRED** |
| 7 | **PolicyParameters-Tier1-Audit.json** | Tier 1 | Audit | Optional | Audit | ⚠️ Recommended* |
| 8 | **PolicyParameters-Tier1-Deny.json** | Tier 1 | Deny | Optional | Deny | ❌ Not needed |
| 9 | **PolicyParameters-Tier2-Audit.json** | Tier 2 | Audit | Optional | Audit | ⚠️ Recommended* |
| 10 | **PolicyParameters-Tier2-Deny.json** | Tier 2 | Deny | Optional | Deny | ❌ Not needed |

**\*Note**: `-IdentityResourceId` is recommended for ALL scenarios to ensure 8 DINE/Modify policies deploy correctly, even in Audit mode.

---

### Scenario-to-Parameter File Mapping

#### **Scenario 1-3: DevTest Safe Start** (30 policies)
```powershell
# File: PolicyParameters-DevTest.json
# Use Case: Initial testing, safe baseline
# Policies: 30 core policies
# Expected Duration: 5 min deployment + 15-30 min evaluation

$identityId = "/subscriptions/.../id-policy-remediation"

.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest.json `
    -PolicyMode Audit `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck
```

**When to Use**:
- ✅ First-time deployment to new subscription
- ✅ Testing infrastructure without full policy suite
- ✅ Quick validation before full testing
- ✅ Training/demonstration purposes

---

#### **Scenario 4: DevTest Full Testing** (46 policies)
```powershell
# File: PolicyParameters-DevTest-Full.json
# Use Case: Comprehensive testing of all policies
# Policies: All 46 policies in Audit mode
# Expected Duration: 5 min deployment + 30 min evaluation

$identityId = "/subscriptions/.../id-policy-remediation"

.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full.json `
    -PolicyMode Audit `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck
```

**When to Use**:
- ✅ Complete policy suite validation
- ✅ Before production deployment
- ✅ Establishing compliance baseline
- ✅ Testing all policy effects (Audit mode)

**Alternative - Auto-Remediation Testing**:
```powershell
# File: PolicyParameters-DevTest-Full-Remediation.json
# CRITICAL: Must use -PolicyMode Enforce for auto-remediation to work!

.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -PolicyMode Enforce `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck
```

**When to Use**:
- ✅ Testing DINE/Modify policies in isolation
- ✅ Validating auto-remediation logic
- ✅ Before Scenario 7 (production auto-remediation)

---

#### **Scenario 5: Production Audit Baseline** (46 policies)
```powershell
# File: PolicyParameters-Production.json
# Use Case: Production monitoring without blocking
# Policies: All 46 policies in Audit mode
# Expected Duration: 5 min deployment + 30 min evaluation

$identityId = "/subscriptions/.../id-policy-remediation"

.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Audit `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck
```

**When to Use**:
- ✅ Initial production deployment
- ✅ Establishing compliance baseline
- ✅ 30-day monitoring period before enforcement
- ✅ Gathering evidence for stakeholder review

---

#### **Scenario 6: Production Deny Mode** (34 policies)
```powershell
# File: PolicyParameters-Production-Deny.json
# Use Case: Block non-compliant resource creation
# Policies: 34 Deny-mode policies (12 excluded*)
# Expected Duration: 5 min deployment

$identityId = "/subscriptions/.../id-policy-remediation"

.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Deny.json `
    -PolicyMode Deny `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck
```

**When to Use**:
- ✅ After 30-day Audit period (Scenario 5)
- ✅ Enforcing critical security policies
- ✅ Preventing new non-compliant resources
- ✅ Production enforcement (blocks violations)

**\*12 Excluded Policies**:
- 8 DINE/Modify policies (auto-remediation, not blocking)
- 4 Audit-only policies (monitoring, not enforceable)

---

#### **Scenario 7: Production Auto-Remediation** (46 policies)
```powershell
# File: PolicyParameters-Production-Remediation.json
# Use Case: Automatically fix non-compliant resources
# Policies: 8 Enforce (DINE/Modify) + 38 Audit
# Expected Duration: 5 min deployment + 90 min remediation cycle
# CRITICAL: MUST use -PolicyMode Enforce (NOT Audit!)

$identityId = "/subscriptions/.../id-policy-remediation"

.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -PolicyMode Enforce `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck `
    -Force
```

**When to Use**:
- ✅ After Scenario 5/6 (baseline established)
- ✅ Automatically fixing existing non-compliance
- ✅ Reducing manual remediation effort
- ✅ Production compliance enforcement

**What Gets Auto-Fixed**:
1. Private endpoints deployed
2. Diagnostic settings configured (Log Analytics + Event Hub)
3. Private DNS zones configured
4. Public network access disabled
5. Firewall enabled with network rules

---

### Tier-Based Parameter Files (Optional)

#### **Tier 1: Critical Security Policies** (Deny Mode)
```powershell
# File: PolicyParameters-Tier1-Deny.json
# Use Case: Phase 1 enforcement (highest priority)
# Policies: ~12 critical policies

.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Tier1-Deny.json `
    -PolicyMode Deny `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck
```

**Policies Included**:
- Key/secret/certificate expiration requirements
- Minimum key sizes
- Public network access restrictions
- Soft delete + purge protection

---

#### **Tier 2: High Priority Policies** (Audit Mode)
```powershell
# File: PolicyParameters-Tier2-Audit.json
# Use Case: Phase 2 monitoring (important but not critical)
# Policies: ~15 high-priority policies

.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Tier2-Audit.json `
    -PolicyMode Audit `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck
```

**Policies Included**:
- Diagnostic settings
- Private endpoints
- Firewall configurations
- RBAC authorization

---

## 🎯 Recommended Consolidation Actions

### High Priority (Do Now)

1. **✅ Consolidate Check-Scenario7-Status.ps1 into AzPolicyImplScript.ps1**
   - Add `-CheckRemediationStatus` parameter
   - Effort: 30 minutes
   - Benefit: Reduces file count, improves discoverability

2. **✅ Archive Capture-ScenarioOutput.ps1**
   - Move to `archive/deprecated-utilities/`
   - Effort: 5 minutes
   - Benefit: Reduces confusion (functionality already in main script)

### Medium Priority (Next Phase)

3. **⚠️ Add Cleanup Integration**
   - Add `-CleanupArchive` parameter to AzPolicyImplScript.ps1
   - Calls Cleanup-Workspace.ps1 internally
   - Effort: 15 minutes
   - Benefit: Integrated housekeeping option

### Low Priority (Future Enhancement)

4. **📝 Update PolicyParameters-QuickReference.md**
   - Add Scenario 7 correct command (with -PolicyMode Enforce)
   - Add recent parameter fix notes
   - Document tier-based deployment strategy
   - Effort: 20 minutes

---

## 📚 Documentation Status

### ✅ Comprehensive Parameter File Documentation

**Existing Documentation**:
1. ✅ **PolicyParameters-QuickReference.md** (317 lines) - Complete file-by-file guide
2. ✅ **SCENARIO-COMMANDS-REFERENCE.md** (400+ lines) - All 7 scenarios with commands
3. ✅ **POLICY-COVERAGE-MATRIX.md** (15.8 KB) - 46 policies × 7 scenarios matrix
4. ✅ **DEPLOYMENT-WORKFLOW-GUIDE.md** (Updated today) - Workflow 7 + parameter table
5. ✅ **QUICKSTART.md** (Updated today) - Scenario 7 command + parameter notes

**Coverage**: **100% - All parameter files documented across multiple guides**

---

## ✅ Summary & Next Steps

### What We Found

**Core Scripts**: 
- ✅ **2 production-ready scripts** (AzPolicyImplScript.ps1, Setup-AzureKeyVaultPolicyEnvironment.ps1)
- ✅ **Keep separate** - consolidation would reduce maintainability

**Utility Scripts**:
- ✅ **1 script to consolidate** (Check-Scenario7-Status.ps1 → add to main script)
- ✅ **1 script to archive** (Capture-ScenarioOutput.ps1 → redundant)
- ✅ **2 scripts to keep separate** (Generate-MasterHtmlReport.ps1, Cleanup-Workspace.ps1)

**Parameter Files**:
- ✅ **10 parameter files** - All documented and scenario-mapped
- ✅ **100% documentation coverage** across 5 guide documents
- ✅ **Recent updates**: Scenario 7 commands, parameter fixes, MSDN limitations

### Recommendations

1. **Script Consolidation**: Low-effort improvements available (45 min total)
2. **Documentation**: Already comprehensive - no gaps identified
3. **Parameter Files**: Well-organized and fully documented
4. **Next Focus**: Scenario 7 remediation monitoring (17:45 checkpoint)

---

**Last Updated**: 2026-01-27 17:06  
**Analysis Complete**: All scripts reviewed, consolidation opportunities identified  
**Documentation Status**: Comprehensive - no gaps
