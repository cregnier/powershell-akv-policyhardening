# PowerShell Script Consolidation Analysis

**Generated**: January 14, 2026  
**Workspace**: C:\Temp  
**Total Scripts**: 22 (excluding backups and history)

---

## Executive Summary

✅ **Consolidation Recommendation**: **Minimal consolidation needed**

The workspace has 1 primary script (`AzPolicyImplScript.ps1`) with 21 supporting scripts that serve distinct purposes. Most scripts are lightweight wrappers or utilities that should remain separate for clarity and maintainability.

### Consolidation Actions

| Action | Scripts | Recommendation |
|--------|---------|----------------|
| **KEEP AS-IS** | 18 scripts | Distinct functionality, remain separate |
| **CONSOLIDATE** | 3 scripts | Merge into main script as documented examples |
| **DEPRECATE** | 1 script | Superseded by main script functionality |

---

## Script Inventory by Category

### 🎯 Main Script (1)

| Script | Size | Purpose | Status |
|--------|------|---------|--------|
| **AzPolicyImplScript.ps1** | 176 KB | Primary implementation with all features | ✅ KEEP - Core script |

**Capabilities**:
- Policy deployment (Audit/Deny/Enforce modes)
- Compliance checking and HTML reporting
- Deny blocking tests
- Exemption management
- Rollback functionality
- Interactive menu
- Parameter overrides

---

### 🚀 Deployment Scripts (4)

| Script | Size | Purpose | Consolidation Action |
|--------|------|---------|---------------------|
| **DeployAll46PoliciesDenyMode.ps1** | 21 KB | Deploy all 46 in Deny mode | ✅ KEEP - Documented example |
| **DeployTier1Production.ps1** | 16 KB | Deploy critical policies to prod | ✅ KEEP - Production workflow |
| **Setup-AzureKeyVaultPolicyEnvironment.ps1** | 37 KB | Complete environment setup | ✅ KEEP - One-time setup utility |
| **Setup-PolicyTestingEnvironment.ps1** | 41 KB | Test environment setup | ⚠️ REVIEW - May overlap with above |

**Analysis**:
- **DeployAll46PoliciesDenyMode.ps1**: Wrapper calling main script with specific parameters. Keep as documented example.
- **DeployTier1Production.ps1**: Production-specific workflow with safeguards. Keep separate.
- **Setup-AzureKeyVaultPolicyEnvironment.ps1**: Creates resource groups, managed identity, role assignments. Essential setup utility.
- **Setup-PolicyTestingEnvironment.ps1**: Similar to above but for testing. May have overlap - needs review.

**Recommendation**: Keep all 4, but review Setup scripts for overlap.

---

### 🧪 Testing Scripts (7)

| Script | Size | Purpose | Consolidation Action |
|--------|------|---------|---------------------|
| **QuickTest.ps1** | 4 KB | Syntax validation and file checks | ❌ DEPRECATE - Basic checks only |
| **RunFullTest.ps1** | 780 bytes | Wrapper: Audit mode deployment | 🔀 CONSOLIDATE - Document in README |
| **RunPolicyTest.ps1** | 1.3 KB | Non-interactive wrapper | 🔀 CONSOLIDATE - Document in README |
| **TestParameterBinding.ps1** | 477 bytes | Debug script for parameters | ❌ DEPRECATE - Development artifact |
| **TestReadiness.ps1** | 8.5 KB | Readiness checks before deployment | ✅ KEEP - Pre-deployment validation |
| **ValidateAll46PoliciesBlocking.ps1** | 16 KB | Comprehensive Deny blocking test | ✅ KEEP - Validation utility |
| **ProductionEnforcementValidation.ps1** | 13 KB | Production enforcement validation | ✅ KEEP - Production testing |

**Analysis**:
- **QuickTest.ps1**: Basic syntax check. Main script has better validation.
- **RunFullTest.ps1**: Simple wrapper. Can document in README examples.
- **RunPolicyTest.ps1**: Simple wrapper. Can document in README examples.
- **TestParameterBinding.ps1**: Debug artifact from development. No longer needed.
- **TestReadiness.ps1**: Pre-deployment checks. Useful standalone utility.
- **ValidateAll46PoliciesBlocking.ps1**: Comprehensive validation. Keep separate.
- **ProductionEnforcementValidation.ps1**: Production-specific testing. Keep separate.

**Recommendation**: Deprecate 2, consolidate 2 as README examples, keep 3.

---

### 📊 Reporting/Analysis Scripts (7)

| Script | Size | Purpose | Consolidation Action |
|--------|------|---------|---------------------|
| **AnalyzePolicyEffects.ps1** | 10 KB | Analyze policy effect capabilities | ✅ KEEP - Analysis utility |
| **CreateComplianceDashboard.ps1** | 18 KB | Generate Power BI dashboard config | ✅ KEEP - Dashboard creation |
| **GenerateMonthlyReport.ps1** | 20 KB | Monthly compliance reporting | ✅ KEEP - Reporting automation |
| **MonitorTier1Compliance.ps1** | 12 KB | Monitor critical policies | ✅ KEEP - Monitoring utility |
| **ParseReport.ps1** | 3.6 KB | Parse compliance report | 🔀 REVIEW - May be superseded |
| **parse_kv_report.ps1** | 2.2 KB | Parse Key Vault report | 🔀 REVIEW - May be superseded |
| **VerifyPolicyEffects.ps1** | 6.5 KB | Verify policy effect configuration | ✅ KEEP - Validation utility |

**Analysis**:
- **AnalyzePolicyEffects.ps1**: Policy capability analysis. Useful standalone.
- **CreateComplianceDashboard.ps1**: Power BI integration. Keep separate.
- **GenerateMonthlyReport.ps1**: Scheduled reporting. Keep separate.
- **MonitorTier1Compliance.ps1**: Continuous monitoring. Keep separate.
- **ParseReport.ps1**: Lightweight parser. May be superseded by main script's HTML reports.
- **parse_kv_report.ps1**: Lightweight parser. May be superseded by main script's HTML reports.
- **VerifyPolicyEffects.ps1**: Effect verification. Keep separate.

**Recommendation**: Keep 5, review 2 parsers for redundancy with main script's reporting.

---

### 🔄 Maintenance Scripts (3)

| Script | Size | Purpose | Consolidation Action |
|--------|------|---------|---------------------|
| **FixMissing9Policies.ps1** | 23 KB | Deploy missing policies (historical) | ✅ KEEP - Historical fix script |
| **RollbackTier1Policies.ps1** | 13 KB | Rollback critical policies | ⚠️ REVIEW - Main script has rollback |
| **SetupAzureMonitorAlerts.ps1** | 10 KB | Configure Azure Monitor alerts | ✅ KEEP - Alert configuration |

**Analysis**:
- **FixMissing9Policies.ps1**: Historical fix for deployment gap. Keep for audit trail.
- **RollbackTier1Policies.ps1**: Main script has `-Rollback` parameter. May be redundant.
- **SetupAzureMonitorAlerts.ps1**: Alert configuration. Standalone utility.

**Recommendation**: Keep all 3, but document that main script has rollback capability.

---

## Detailed Consolidation Recommendations

### ❌ Scripts to Deprecate (2)

#### 1. QuickTest.ps1
**Reason**: Basic syntax validation superseded by main script's error handling
```powershell
# Current: QuickTest.ps1 (89 lines)
# Alternative: Main script has comprehensive validation

# Replace with:
.\AzPolicyImplScript.ps1 -DryRun -Preview  # Validates without deploying
```

#### 2. TestParameterBinding.ps1
**Reason**: Development debug script, no longer needed
```powershell
# Current: TestParameterBinding.ps1 (18 lines)
# Purpose: Debug parameter binding during development
# Status: Development artifact, can be removed
```

**Action**: Move to `backups/deprecated_scripts/` folder

---

### 🔀 Scripts to Consolidate as README Examples (2)

#### 1. RunFullTest.ps1
**Current**:
```powershell
# RunFullTest.ps1 (20 lines)
$config = Get-Content ".\PolicyImplementationConfig.json" | ConvertFrom-Json
.\AzPolicyImplScript.ps1 -PolicyMode Audit -ScopeType Subscription -SkipRBACCheck -IdentityResourceId $config.ManagedIdentityId
```

**Recommendation**: Document in README.md as example usage
```markdown
## Example: Automated Deployment

```powershell
# Load configuration
$config = Get-Content ".\PolicyImplementationConfig.json" | ConvertFrom-Json

# Deploy all policies in Audit mode
.\AzPolicyImplScript.ps1 `
    -PolicyMode Audit `
    -ScopeType Subscription `
    -SkipRBACCheck `
    -IdentityResourceId $config.ManagedIdentityResourceId
```
```

**Action**: Delete script, add example to README.md

#### 2. RunPolicyTest.ps1
**Current**:
```powershell
# RunPolicyTest.ps1 (40 lines)
# Similar to RunFullTest.ps1 but with more error checking
```

**Recommendation**: Document in README.md as robust example
**Action**: Delete script, add example to README.md

---

### ⚠️ Scripts to Review for Overlap (4)

#### 1. Setup-PolicyTestingEnvironment.ps1 vs Setup-AzureKeyVaultPolicyEnvironment.ps1
**Potential Overlap**: Both create resource groups, managed identities, role assignments

**Analysis Needed**:
```powershell
# Compare functionality
diff <(grep "New-AzResourceGroup" Setup-PolicyTestingEnvironment.ps1) `
     <(grep "New-AzResourceGroup" Setup-AzureKeyVaultPolicyEnvironment.ps1)
```

**Recommendation**: 
- If overlap >80%: Merge into single `Setup-PolicyEnvironment.ps1` with `-EnvironmentType` parameter
- If distinct: Keep both with clear naming (e.g., `Setup-TestEnvironment.ps1`, `Setup-ProductionEnvironment.ps1`)

#### 2. ParseReport.ps1 and parse_kv_report.ps1
**Potential Overlap**: Both parse compliance reports

**Current Main Script**: Has HTML report generation with remediation guidance

**Recommendation**:
- If parsers are for legacy JSON reports: Keep as-is for backward compatibility
- If parsers are for current HTML reports: Deprecate (main script has superior reporting)

#### 3. RollbackTier1Policies.ps1
**Overlap**: Main script has `-Rollback` parameter

**Main Script Capability**:
```powershell
.\AzPolicyImplScript.ps1 -Rollback  # Removes all KV-All-* and KV-Tier1-* assignments
```

**Recommendation**:
- **Keep separate** if it has additional logic (backup/restore, compliance snapshots)
- **Deprecate** if it's a simple wrapper to main script's rollback function

---

## Proposed File Structure

### Current Structure (22 scripts)
```
C:\Temp\
├── AzPolicyImplScript.ps1           [KEEP - Main]
├── DeployAll46PoliciesDenyMode.ps1  [KEEP]
├── DeployTier1Production.ps1        [KEEP]
├── Setup-*.ps1 (2)                  [REVIEW for merge]
├── Test*.ps1 (5)                    [DEPRECATE 2, CONSOLIDATE 2, KEEP 1]
├── Validate*.ps1 (2)                [KEEP]
├── Reporting*.ps1 (7)               [KEEP 5, REVIEW 2]
├── Maintenance*.ps1 (3)             [KEEP, document overlap]
```

### Recommended Structure (17-18 scripts)
```
C:\Temp\
├── 📂 scripts/
│   ├── AzPolicyImplScript.ps1               [Main script]
│   │
│   ├── 📂 deployment/
│   │   ├── Deploy-All46PoliciesDenyMode.ps1
│   │   ├── Deploy-Tier1Production.ps1
│   │   └── Setup-PolicyEnvironment.ps1      [Merged setup script]
│   │
│   ├── 📂 testing/
│   │   ├── Test-Readiness.ps1
│   │   ├── Validate-All46PoliciesBlocking.ps1
│   │   └── Validate-ProductionEnforcement.ps1
│   │
│   ├── 📂 reporting/
│   │   ├── Analyze-PolicyEffects.ps1
│   │   ├── Create-ComplianceDashboard.ps1
│   │   ├── Generate-MonthlyReport.ps1
│   │   ├── Monitor-Tier1Compliance.ps1
│   │   ├── Verify-PolicyEffects.ps1
│   │   └── Parse-Report.ps1                  [If kept]
│   │
│   ├── 📂 maintenance/
│   │   ├── Fix-Missing9Policies.ps1          [Historical]
│   │   ├── Rollback-Tier1Policies.ps1        [If distinct from main]
│   │   └── Setup-AzureMonitorAlerts.ps1
│   │
│   └── 📂 deprecated/
│       ├── QuickTest.ps1                     [Moved here]
│       ├── TestParameterBinding.ps1          [Moved here]
│       ├── RunFullTest.ps1                   [Documented in README]
│       └── RunPolicyTest.ps1                 [Documented in README]
│
└── README.md                                  [Add examples from deprecated wrappers]
```

---

## Implementation Plan

### Phase 1: Deprecate Simple Scripts (5 minutes)
```powershell
# Create deprecated folder
New-Item -Path ".\scripts\deprecated" -ItemType Directory -Force

# Move deprecated scripts
Move-Item "QuickTest.ps1" ".\scripts\deprecated\"
Move-Item "TestParameterBinding.ps1" ".\scripts\deprecated\"
```

### Phase 2: Document Wrapper Examples in README (10 minutes)
```markdown
# Add to README.md

## Example Usage Patterns

### Automated Deployment
[Content from RunFullTest.ps1]

### Non-Interactive Deployment
[Content from RunPolicyTest.ps1]
```

### Phase 3: Review Overlap Scripts (30 minutes)
```powershell
# Compare setup scripts
code --diff Setup-PolicyTestingEnvironment.ps1 Setup-AzureKeyVaultPolicyEnvironment.ps1

# Compare parser scripts
code --diff ParseReport.ps1 parse_kv_report.ps1

# Review rollback overlap
grep -A 10 "function Remove-KeyVaultPolicyAssignments" AzPolicyImplScript.ps1
code RollbackTier1Policies.ps1
```

### Phase 4: Organize into Folders (15 minutes)
```powershell
# Create folder structure
New-Item -Path ".\scripts\deployment" -ItemType Directory -Force
New-Item -Path ".\scripts\testing" -ItemType Directory -Force
New-Item -Path ".\scripts\reporting" -ItemType Directory -Force
New-Item -Path ".\scripts\maintenance" -ItemType Directory -Force

# Move scripts (example)
Move-Item "Deploy*.ps1" ".\scripts\deployment\"
Move-Item "Test*.ps1" ".\scripts\testing\"
# ... etc
```

---

## Benefits of Consolidation

### ✅ Improved Maintainability
- Clear folder structure by purpose
- Deprecated scripts separated
- Reduced script count (22 → 17-18)

### ✅ Better Discoverability
- Scripts organized by workflow stage
- Main script clearly identified
- Examples documented in README

### ✅ Reduced Confusion
- Wrapper scripts replaced with README examples
- Overlapping scripts reviewed and merged
- Historical scripts clearly marked

### ✅ Easier Onboarding
- New users see organized structure
- Clear distinction between main script and utilities
- Deprecated artifacts don't clutter workspace

---

## Risks and Mitigation

### ⚠️ Risk: Breaking Existing Automation
**Scenario**: CI/CD pipelines reference `RunFullTest.ps1`

**Mitigation**:
1. Keep deprecated scripts for 30 days with deprecation notice
2. Add redirects in deprecated scripts:
   ```powershell
   # RunFullTest.ps1 (deprecated)
   Write-Warning "This script is deprecated. Use: .\AzPolicyImplScript.ps1 -PolicyMode Audit -ScopeType Subscription"
   # Redirect to main script (temporary)
   .\AzPolicyImplScript.ps1 -PolicyMode Audit -ScopeType Subscription -SkipRBACCheck -IdentityResourceId $config.ManagedIdentityResourceId
   ```
3. Update all documentation to reference main script

### ⚠️ Risk: Losing Functionality
**Scenario**: Deprecated script has unique logic

**Mitigation**:
1. Review all scripts before deprecation (done above)
2. Move to `backups/deprecated_scripts/` instead of deleting
3. Keep Git history intact

---

## Final Recommendation

### Immediate Actions (Low Risk)
1. ✅ **Deprecate 2 scripts**: Move QuickTest.ps1 and TestParameterBinding.ps1 to deprecated folder
2. ✅ **Document 2 wrappers**: Add RunFullTest.ps1 and RunPolicyTest.ps1 examples to README.md
3. ✅ **Create folder structure**: Organize remaining scripts into deployment/testing/reporting/maintenance folders

### Follow-Up Review (Requires Analysis)
1. ⚠️ **Compare setup scripts**: Determine if Setup-PolicyTestingEnvironment.ps1 and Setup-AzureKeyVaultPolicyEnvironment.ps1 should merge
2. ⚠️ **Review parsers**: Check if ParseReport.ps1 and parse_kv_report.ps1 are still needed with new HTML reporting
3. ⚠️ **Validate rollback**: Confirm RollbackTier1Policies.ps1 adds value beyond main script's `-Rollback`

### Do NOT Consolidate
- ❌ **Do not merge** reporting scripts into main (would bloat main script to >250 KB)
- ❌ **Do not merge** testing scripts into main (distinct use cases)
- ❌ **Do not delete** FixMissing9Policies.ps1 (historical audit trail)

---

## Conclusion

**Consolidation Status**: ✅ **MINIMAL CONSOLIDATION RECOMMENDED**

The current script organization is mostly sound. Consolidation should focus on:
1. Removing development artifacts (2 scripts)
2. Documenting simple wrappers in README (2 scripts)
3. Organizing scripts into logical folders (cosmetic improvement)
4. Reviewing 4 scripts for potential overlap

**Estimated Effort**: 1-2 hours  
**Risk Level**: Low (changes are mostly organizational)  
**Impact**: Improved clarity and discoverability without losing functionality

---

**Analysis Complete**: January 14, 2026  
**Analyzed By**: GitHub Copilot  
**Next Steps**: Implement Phase 1 (deprecate 2 scripts) and update README with wrapper examples
