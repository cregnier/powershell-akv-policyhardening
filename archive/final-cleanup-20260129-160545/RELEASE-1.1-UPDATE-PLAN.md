# Release 1.1 Update Plan - Package Refinements

**Date**: January 28, 2026  
**Status**: In Progress

---

## ✅ Changes Completed

### 1. PACKAGE-README.md - UPDATED
- ✅ Fixed value proposition (was $50K, now $60K with complete metrics)
- ✅ Added 4 VALUE-ADD metrics table (100% security, 135 hrs/yr, $60K/yr, 98.2% faster)
- ✅ Added missing documentation file (RELEASE-1.1.0-VERIFICATION-REPORT.md)
- ✅ Added clickable markdown links to all documentation files
- ✅ Replaced "MSDN subscriptions" with "Dev/Test subscriptions"
- ✅ Added LICENSE reference with clickable link
- ✅ Updated all documentation references to use relative markdown links

### 2. LICENSE File - CREATED
- ✅ Created MIT License file in package root
- ✅ Referenced in PACKAGE-README.md

---

## 🔄 Changes In Progress

### 3. QUICKSTART.md - PARTIALLY UPDATED

**Completed**:
- ✅ Removed GitHub clone step (Step 4)
- ✅ Replaced with "Extract release package ZIP" instruction
- ✅ Added infrastructure setup section (Dev/Test vs Production)
- ✅ Clarified production creates ONLY policy-required artifacts (managed identity, monitoring)
- ✅ Clarified dev/test creates complete test environment
- ✅ Replaced hardcoded subscription ID with variable: `$subscriptionId = (Get-AzContext).Subscription.Id`
- ✅ Updated file paths to use `.\scripts\` and `.\parameters\` prefixes
- ✅ Added VALUE-ADD metrics to expected results
- ✅ Removed reference to MasterTestReport HTML file

**Still Needed**:
- ⏳ Replace remaining hardcoded subscription IDs throughout file (multiple locations)
- ⏳ Add clickable markdown links to other documentation
- ⏳ Add production deployment scenario with -Environment Production flag
- ⏳ Update cleanup section with proper package references
- ⏳ Add navigation links at top and bottom of document

---

## 📋 Remaining Changes Needed

### 4. All .md Files - Add Clickable Links

**Files to Update**:
- README.md (master index)
- DEPLOYMENT-WORKFLOW-GUIDE.md
- DEPLOYMENT-PREREQUISITES.md
- SCENARIO-COMMANDS-REFERENCE.md
- POLICY-COVERAGE-MATRIX.md
- CLEANUP-EVERYTHING-GUIDE.md
- UNSUPPORTED-SCENARIOS.md
- Comprehensive-Test-Plan.md

**Changes Needed**:
```markdown
# Add navigation header to each file:
**Quick Links**: [README](README.md) | [Quick Start](QUICKSTART.md) | [Workflows](DEPLOYMENT-WORKFLOW-GUIDE.md) | [Prerequisites](DEPLOYMENT-PREREQUISITES.md) | [Cleanup](CLEANUP-EVERYTHING-GUIDE.md)

# Convert all documentation references to clickable links:
- Instead of: "See DEPLOYMENT-WORKFLOW-GUIDE.md"
- Use: "See [DEPLOYMENT-WORKFLOW-GUIDE.md](DEPLOYMENT-WORKFLOW-GUIDE.md)"
```

### 5. All .md Files - Remove Sensitive/Repo References

**Search and Replace Needed**:

| Find | Replace With |
|------|--------------|
| `ab1336c7-687d-4107-b0f6-9649a0458adb` | `<your-subscription-id>` or `$(Get-AzContext).Subscription.Id` |
| `github.com/cregnier/powershell-akv-policyhardening` | `Extract azure-keyvault-policy-governance-1.1.0-FINAL.zip` |
| `cregnier/powershell-akv-policyhardening` | `the release package` |
| `MSDN subscription` | `dev/test subscription` |
| `MSDN DevTest` | `Dev/Test Environment` |

**Files to Update**:
- QUICKSTART.md (partially done)
- DEPLOYMENT-WORKFLOW-GUIDE.md
- DEPLOYMENT-PREREQUISITES.md
- SCENARIO-COMMANDS-REFERENCE.md
- UNSUPPORTED-SCENARIOS.md

### 6. DEPLOYMENT-WORKFLOW-GUIDE.md - Production Scenario

**Add Production-Specific Guidance**:

```markdown
## 🏭 Production Deployment Considerations

### What Already Exists in Production
- ✅ Azure subscription with existing Key Vaults
- ✅ Existing secrets, keys, certificates in production vaults
- ✅ Existing Azure Policies (may need audit before deployment)
- ✅ Existing RBAC assignments

### What We Create for Policy Governance
- 🆕 User-assigned managed identity (for auto-remediation)
- 🆕 Event Hub namespace (for diagnostic logs)
- 🆕 Log Analytics workspace (for monitoring)
- 🆕 46 Azure Policy assignments

### What We Do NOT Create in Production
- ❌ Key Vaults (policies monitor EXISTING vaults)
- ❌ Test data (secrets, keys, certificates)
- ❌ Resource groups (use existing)

### Production Setup Command
```powershell
# Create production infrastructure (minimal)
.\scripts\Setup-AzureKeyVaultPolicyEnvironment.ps1 -Environment Production

# Deploy policies in Audit mode first
.\scripts\AzPolicyImplScript.ps1 `
    -ParameterFile .\parameters\PolicyParameters-Production.json `
    -PolicyMode Audit `
    -IdentityResourceId "/subscriptions/$subscriptionId/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation" `
    -ScopeType Subscription `
    -SkipRBACCheck
```
```

### 7. Setup Script - Production Mode Enhancement

**File**: `Setup-AzureKeyVaultPolicyEnvironment.ps1`

**Current Behavior**: Always creates test vaults

**Needed Change**:
```powershell
# Add -Environment parameter handling
param(
    [ValidateSet('DevTest', 'Production')]
    [string]$Environment = 'DevTest'
)

# Skip test vault creation if Production
if ($Environment -eq 'Production') {
    Write-Host "Production mode: Skipping test vault creation" -ForegroundColor Yellow
    Write-Host "Policies will monitor your EXISTING Key Vaults" -ForegroundColor Cyan
    # Create only: Managed Identity, Event Hub, Log Analytics
} else {
    # Create full dev/test environment
}
```

---

## 🎯 Implementation Priority

### High Priority (Required for v1.1 release)
1. ✅ PACKAGE-README.md value proposition - DONE
2. ✅ LICENSE file - DONE
3. ⏳ QUICKSTART.md - Remove all hardcoded subscription IDs - IN PROGRESS
4. ⏳ QUICKSTART.md - Add clickable links - IN PROGRESS
5. ⏳ All .md files - Replace "MSDN" with "Dev/Test" - PENDING
6. ⏳ All .md files - Remove hardcoded subscription IDs - PENDING

### Medium Priority (Important for usability)
7. Setup script `-Environment Production` parameter
8. Add navigation links to all documentation
9. DEPLOYMENT-WORKFLOW-GUIDE.md production guidance
10. Add production scenario to QUICKSTART.md

### Low Priority (Nice to have)
11. Cross-reference links between related sections
12. Add "Back to Top" links in long documents
13. Table of contents in each document

---

## 📊 Progress Tracking

| Task | Status | Files Affected | Estimated Time |
|------|--------|----------------|----------------|
| Value proposition fix | ✅ Done | PACKAGE-README.md | 5 min |
| LICENSE creation | ✅ Done | LICENSE, PACKAGE-README.md | 2 min |
| Remove GitHub references | ⏳ In Progress | QUICKSTART.md, DEPLOYMENT-WORKFLOW-GUIDE.md | 20 min |
| Remove subscription IDs | ⏳ In Progress | All .md files with examples | 30 min |
| Add clickable links | ⏳ Pending | All 10 .md files | 40 min |
| Production guidance | ⏳ Pending | QUICKSTART.md, DEPLOYMENT-WORKFLOW-GUIDE.md | 30 min |
| Setup script enhancement | ⏳ Pending | Setup-AzureKeyVaultPolicyEnvironment.ps1 | 20 min |
| **Total Estimated** | | | **2.5 hours** |

---

## Next Steps

1. Complete QUICKSTART.md updates (remove all sensitive IDs, add links)
2. Create search/replace script for bulk updates across all .md files
3. Test Setup script with -Environment Production parameter
4. Rebuild release package with all updates
5. Create new ZIP file: azure-keyvault-policy-governance-1.1.1-FINAL.zip

---

**Document Version**: 1.0  
**Last Updated**: January 28, 2026 14:45 PM
