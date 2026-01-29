# Deployment Workflow Guide

## Overview

This guide shows **exactly which scripts to run** for each deployment scenario and **what outputs/evidence** they produce.

**Last Updated**: January 22, 2026

**📖 New**: See [Common Workflow Patterns](#-common-workflow-patterns) section for all 9 workflow variations with complete parameter examples.

---

## 📋 Complete Script Inventory

### Core Deployment Scripts (2 files)

| Script | Purpose | When to Use |
|--------|---------|-------------|
| **Setup-AzureKeyVaultPolicyEnvironment.ps1** | Infrastructure setup | One-time setup in new subscription |
| **AzPolicyImplScript.ps1** | Policy deployment, compliance, testing | All policy operations |

### Configuration Files (6 files)

| File | Purpose | When to Use |
|------|---------|-------------|
| **DefinitionListExport.csv** | 46 policy definitions | Required by deployment script |
| **PolicyParameters-DevTest.json** | DevTest: 30 policies, Audit mode | Safe first deployment |
| **PolicyParameters-DevTest-Full.json** | DevTest: 46 policies, Audit mode | Comprehensive testing |
| **PolicyParameters-DevTest-Full-Remediation.json** | DevTest: 46 policies, 8 auto-fix | Auto-remediation testing |
| **PolicyParameters-Production.json** | Production: 46 policies, Audit/Deny | Production deployment |
| **PolicyParameters-Production-Remediation.json** | Production: 46 policies, 8 auto-fix | Production auto-remediation |

**📖 Parameter File Guide**: See [PolicyParameters-QuickReference.md](PolicyParameters-QuickReference.md) for detailed selection guide

**Total Required: 7 files (1 script + 1 CSV + 5 parameter files)**

---

## Workflow 1: Infrastructure Setup

### Purpose
Create Azure infrastructure needed for policy deployment and remediation.

### Command

```powershell
.\Setup-AzureKeyVaultPolicyEnvironment.ps1
```

### What It Creates

| Resource | Resource Group | Purpose |
|----------|----------------|---------|
| **id-policy-remediation** | rg-policy-remediation | Managed identity for policy remediation tasks |
| **rg-policy-remediation** | (self) | Infrastructure resource group |
| **rg-policy-keyvault-test** | (self) | Test environment with sample Key Vaults |
| **kv-test-compliant-XXXX** | rg-policy-keyvault-test | Compliant Key Vault (soft delete + purge protection) |
| **kv-test-noncompliant-XXXX** | rg-policy-keyvault-test | Non-compliant Key Vault (for testing) |

### Expected Output

```
✓ Resource group 'rg-policy-remediation' created
✓ Managed identity 'id-policy-remediation' created
✓ RBAC assigned: Policy Contributor role
✓ Test resource group 'rg-policy-keyvault-test' created
✓ Test Key Vault 'kv-test-compliant-XXXX' created
✓ Test Key Vault 'kv-test-noncompliant-XXXX' created

Infrastructure setup complete!
```

### Time Required
**15-20 minutes**

### Verification

```powershell
# Verify managed identity exists
Get-AzUserAssignedIdentity -ResourceGroupName "rg-policy-remediation" -Name "id-policy-remediation"

# Verify RBAC assignment
Get-AzRoleAssignment -ObjectId <principal-id> | Where-Object { $_.RoleDefinitionName -eq 'Policy Contributor' }

# Verify test Key Vaults
Get-AzKeyVault -ResourceGroupName "rg-policy-keyvault-test"
```

---

## Workflow 2A: Deploy Policies in AUDIT Mode

### Purpose
Deploy all 46 policies in Audit mode to **observe compliance without blocking** operations.

### 2A-1: Dev/Test Environment (Audit Mode)

**Command:**
```powershell
.\AzPolicyImplScript.ps1 -Environment DevTest -Phase Test
```

**Configuration:**
- Uses: `PolicyParameters-DevTest.json`
- Scope: Resource Group (`rg-policy-keyvault-test`)
- Mode: All 46 policies in **Audit** mode
- Parameters: Relaxed (36-month validity, 2048-bit keys)

**⚠️ Auto-Remediation Parameter Requirements**:

When deploying **remediation parameter files** (policies with DeployIfNotExists/Modify effects), you **MUST** provide the `-IdentityResourceId` parameter:

```powershell
# ✅ CORRECT: Remediation policies WITH managed identity
.\.AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation" `
    -SkipRBACCheck

# ❌ INCORRECT: Remediation policies WITHOUT managed identity
# (Policies will be SKIPPED with warning)
.\.AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -SkipRBACCheck
```

**Which Parameter Files Require `-IdentityResourceId`?**

| Parameter File | Requires Identity? | Reason |
|----------------|-------------------|--------|
| `PolicyParameters-DevTest.json` | ❌ No | Audit mode only |
| `PolicyParameters-DevTest-Full.json` | ❌ No | Audit mode only |
| `PolicyParameters-DevTest-Full-Remediation.json` | ✅ **YES** | 8 DeployIfNotExists/Modify policies |
| `PolicyParameters-Production.json` | ❌ No | Audit/Deny mode only |
| `PolicyParameters-Production-Deny.json` | ❌ No | Deny mode only |
| `PolicyParameters-Production-Remediation.json` | ✅ **YES** | 8 DeployIfNotExists/Modify policies |

**What Happens Without `-IdentityResourceId`?**
- Remediation policies (DeployIfNotExists/Modify) are **SKIPPED**
- Script shows warning: `[WARN] Policy default effect 'DeployIfNotExists' requires managed identity. Skipping assignment - provide -IdentityResourceId to enable.`
- Only Audit/Deny policies are deployed
- No automatic remediation occurs

**📖 Complete Guide**: See [PolicyParameters-QuickReference.md](PolicyParameters-QuickReference.md) for detailed parameter file selection guide

**Workflow:**
1. Shows deployment banner (Cyan - dev/test)
2. Shows phase guidance (Test phase)
3. Displays configuration summary
4. Prompts for 'RUN' confirmation
5. Deploys policies
6. Shows completion summary with next steps

**Expected Output:**
```
✓ 46/46 policies assigned successfully
✓ All in Audit mode
✓ Scope: /subscriptions/<sub-id>/resourcegroups/rg-policy-keyvault-test
✓ HTML report: KeyVaultPolicyImplementationReport-<timestamp>.html
✓ Compliance report: ComplianceReport-<timestamp>.html
```

**Time Required:** 10-15 minutes

---

### 2A-2: Production Environment (Audit Mode)

**Command:**
```powershell
.\AzPolicyImplScript.ps1 -Environment Production -Phase Audit
```

**Configuration:**
- Uses: `PolicyParameters-Production.json`
- Scope: **Subscription** (entire subscription)
- Mode: All 46 policies in **Audit** mode initially
- Parameters: Strict (12-month validity, 4096-bit keys)

**Workflow:**
1. Shows deployment banner (Red - production warning)
2. Shows phase guidance (Audit phase - safe)
3. Warns to wait 24-48 hours for compliance data
4. Displays configuration summary
5. Prompts for 'RUN' confirmation
6. Deploys policies
7. Shows completion summary with next steps

**Expected Output:**
```
✓ 46/46 policies assigned successfully
✓ All in Audit mode (observing only)
✓ Scope: /subscriptions/<sub-id>
✓ Enforcement: Default (not blocking yet)
✓ Next: Wait 24-48 hours for compliance data
```

**Time Required:** 10-15 minutes

**⚠️ CRITICAL:** Wait 24-48 hours before checking compliance!

---

### 2A-3: Generate Compliance Report (After 24-48 Hours)

**Command:**
```powershell
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan
```

**What It Does:**
1. Triggers Azure Policy compliance scan
2. Waits for scan completion
3. Retrieves compliance data for all 46 policies
4. Generates HTML report with detailed compliance breakdown

**Output Files Generated:**

| File | Purpose | Content |
|------|---------|---------|
| **ComplianceReport-<timestamp>.html** | Visual compliance dashboard | ✅ Policy-by-policy compliance<br>✅ Resource-level details<br>✅ Compliance percentages<br>✅ Non-compliant resources list<br>✅ Remediation recommendations |
| **KeyVaultPolicyImplementationReport-<timestamp>.json** | Machine-readable data | Full compliance data for automation |
| **KeyVaultPolicyImplementationReport-<timestamp>.md** | Text summary | Markdown summary for documentation |

**HTML Report Contents:**

```html
Azure Key Vault Policy Compliance Report
Generated: 2026-01-14 15:30:00

══════════════════════════════════════════════════════════
OVERALL COMPLIANCE SUMMARY
══════════════════════════════════════════════════════════

Total Policies Deployed:        46
Policies Reporting Data:        46
Overall Compliance:             87.3%
Compliant Resources:            142
Non-Compliant Resources:        21
Total Resources Evaluated:      163

Effectiveness Rating:           Good ⭐⭐⭐⭐

══════════════════════════════════════════════════════════
POLICY-BY-POLICY BREAKDOWN
══════════════════════════════════════════════════════════

1. Key vaults should have soft delete enabled
   Status: ✓ 98% Compliant
   Compliant: 45 | Non-Compliant: 1
   Non-Compliant Resources:
   - /subscriptions/.../kv-legacy-vault-001

2. Key vaults should have deletion protection enabled
   Status: ⚠ 76% Compliant
   Compliant: 35 | Non-Compliant: 11
   Non-Compliant Resources:
   - /subscriptions/.../kv-test-vault-002
   - /subscriptions/.../kv-dev-vault-003
   [... list continues ...]

3. Key Vault secrets should have an expiration date
   Status: ✓ 92% Compliant
   Compliant: 234 secrets | Non-Compliant: 21 secrets
   Non-Compliant Resources:
   - /subscriptions/.../kv-app1/secrets/ConnectionString
   - /subscriptions/.../kv-app2/secrets/ApiKey
   [... list continues ...]

[... all 46 policies listed with compliance details ...]

══════════════════════════════════════════════════════════
REMEDIATION RECOMMENDATIONS
══════════════════════════════════════════════════════════

High Priority (Blocking Operations in Deny Mode):
  □ Enable purge protection on 11 Key Vaults
  □ Enable soft delete on 1 Key Vault
  □ Configure firewall on 8 Key Vaults

Medium Priority (Security Best Practices):
  □ Set expiration dates on 21 secrets
  □ Set expiration dates on 14 keys
  □ Enable diagnostic logging on 5 Key Vaults

══════════════════════════════════════════════════════════
```

**Time Required:** 5-10 minutes

**Verification:**
```powershell
# Open HTML report in browser
$latestReport = Get-ChildItem "ComplianceReport-*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Invoke-Item $latestReport.FullName
```

---

## Workflow 2B: Deploy Policies in DENY Mode

### Purpose
Enable enforcement to **block non-compliant operations** for critical policies.

### 2B-1: Production Environment (Enforcement Mode)

**⚠️ PREREQUISITES:**
- ✅ Audit mode has run for 24+ hours
- ✅ Compliance report reviewed
- ✅ Non-compliant resources remediated
- ✅ Exemptions created where needed
- ✅ Stakeholders notified
- ✅ Rollback plan ready

**Command:**
```powershell
.\AzPolicyImplScript.ps1 -Environment Production -Phase Enforce
```

**Configuration:**
- Uses: `PolicyParameters-Production.json`
- Scope: Subscription
- Mode: **9 critical policies in Deny mode** (blocks operations)
- Other 37 policies remain in Audit mode

**Critical Policies Enforced (Deny Mode):**

| Policy | Effect | What It Blocks |
|--------|--------|----------------|
| Key vaults should have soft delete enabled | **Deny** | Creating vaults without soft delete |
| Key vaults should have deletion protection enabled | **Deny** | Creating vaults without purge protection |
| Azure Key Vault Managed HSM should have purge protection | **Deny** | Creating HSM without purge protection |
| Key Vault secrets should have an expiration date | **Deny** | Creating secrets without expiration |
| Key Vault keys should have an expiration date | **Deny** | Creating keys without expiration |
| Azure Key Vault should disable public network access | **Deny** | Creating vaults with public access |
| Key vaults should use private link | **Deny** | Vaults without private endpoints |
| Keys should have more than the specified number of days before expiration | **Deny** | Keys expiring within threshold |
| Secrets should have more than the specified number of days before expiration | **Deny** | Secrets expiring within threshold |

**Workflow:**
1. Shows **RED WARNING BANNER** (Production Enforcement)
2. Lists prerequisites checklist
3. Requires typing **'YES'** to confirm prerequisites
4. Shows configuration summary
5. Prompts for **'RUN'** confirmation
6. Requires typing **'PROCEED'** in main script for Deny mode
7. Deploys policies with enforcement
8. Shows completion summary

**Expected Output:**
```
⚠️  ENFORCEMENT ENABLED ⚠️

✓ 46/46 policies assigned successfully
✓ 9 policies in DENY mode (blocking operations)
✓ 37 policies in AUDIT mode (monitoring)
✓ Scope: /subscriptions/<sub-id>

DENY MODE POLICIES:
  ✓ Soft delete enabled enforcement: ACTIVE
  ✓ Purge protection enforcement: ACTIVE
  ✓ Secret expiration enforcement: ACTIVE
  ✓ Key expiration enforcement: ACTIVE
  ✓ Public network access enforcement: ACTIVE
  [... and 4 more ...]

⚠️ Operations will now be BLOCKED if non-compliant
```

**Time Required:** 10-15 minutes

---

### 2B-2: Test Deny Blocking (Validation)

**Purpose:** Verify that Deny policies actually **block non-compliant operations**.

**Command:**
```powershell
.\AzPolicyImplScript.ps1 -TestDenyBlocking
```

**What It Does:**
1. Attempts to create non-compliant Key Vault (without purge protection)
2. Attempts to create vault with public network access
3. Attempts to create secret without expiration date
4. Attempts to create key without expiration date
5. Each attempt should be **BLOCKED by policy**

**Output Report:**

```
══════════════════════════════════════════════════════════
DENY BLOCKING TEST RESULTS
══════════════════════════════════════════════════════════

Test 1: Create Key Vault without purge protection
Result: ✓ BLOCKED by policy
Policy: Key vaults should have deletion protection enabled
Message: RequestDisallowedByPolicy - Resource creation denied

Test 2: Create Key Vault with public network access
Result: ✓ BLOCKED by policy  
Policy: Azure Key Vault should disable public network access
Message: RequestDisallowedByPolicy - Public access not allowed

Test 3: Create secret without expiration date
Result: ✓ BLOCKED by policy
Policy: Key Vault secrets should have an expiration date
Message: RequestDisallowedByPolicy - Expiration date required

Test 4: Create key without expiration date
Result: ✓ BLOCKED by policy
Policy: Key Vault keys should have an expiration date
Message: RequestDisallowedByPolicy - Expiration date required

══════════════════════════════════════════════════════════
SUMMARY
══════════════════════════════════════════════════════════

Total Tests:     4
Blocked:         4 ✓
Not Blocked:     0
Errors:          0

Pass Rate:       100%
Status:          ✓ ALL DENY POLICIES WORKING
══════════════════════════════════════════════════════════
```

**Output Files:**
- `DenyBlockingTestResults-<timestamp>.json` - Test results data
- Shows in console with color-coded results

**Time Required:** 5-10 minutes

**Verification:**
```powershell
# View latest test results
$latestTest = Get-ChildItem "DenyBlockingTestResults-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Get-Content $latestTest | ConvertFrom-Json | ConvertTo-Json -Depth 10
```

---

## Workflow 3: Compliance & Security Value Evidence

### Purpose
Show the **enhanced security value** of implementing 46 policies.

### 3A: Generate Comprehensive Compliance Dashboard

**Command:**
```powershell
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan
```

**Enhanced Security Metrics Shown:**

| Metric | Description | Value Example |
|--------|-------------|---------------|
| **Overall Compliance** | Percentage of compliant resources | 87.3% |
| **Policies Reporting** | Number of active policies | 46/46 |
| **Resources Protected** | Key Vaults under governance | 163 vaults |
| **Secrets Managed** | Secrets with expiration enforcement | 234 secrets |
| **Keys Managed** | Keys with expiration enforcement | 187 keys |
| **Non-Compliant Identified** | Issues found and flagged | 21 resources |
| **Effectiveness Rating** | Policy effectiveness score | Good ⭐⭐⭐⭐ |

**HTML Report Sections:**

1. **Executive Summary**
   - Overall compliance percentage
   - Total resources under governance
   - Effectiveness rating
   - Trend analysis (if available)

2. **Security Posture Improvements**
   - ✅ Soft delete enabled: 98% coverage (45/46 vaults)
   - ✅ Purge protection enabled: 76% coverage (35/46 vaults)
   - ✅ Diagnostic logging: 89% coverage (41/46 vaults)
   - ✅ Private endpoints: 67% coverage (31/46 vaults)
   - ✅ Firewall configured: 82% coverage (38/46 vaults)

3. **Policy-by-Policy Breakdown**
   - Each of 46 policies listed
   - Compliance percentage per policy
   - Non-compliant resources identified
   - Remediation recommendations

4. **Non-Compliant Resources**
   - Full list with resource IDs
   - Policy violations per resource
   - Suggested remediation actions

5. **Compliance Framework Mapping**
   - CIS Azure Foundations Benchmark alignment
   - Azure Security Benchmark coverage
   - Regulatory compliance (HIPAA, PCI-DSS, etc.)

---

### 3B: Security Value Summary

**Before Policies (Typical State):**
```
❌ No soft delete enforcement → Accidental vault deletion permanent
❌ No purge protection → Malicious deletion possible
❌ Secrets without expiration → Stale credentials remain active
❌ Keys without expiration → Rotation not enforced
❌ Public network access → Exposed to internet attacks
❌ No logging enforcement → Security incidents undetected
❌ No firewall rules → Unrestricted access
❌ Manual compliance checks → Time-consuming, error-prone
```

**After Implementing 46 Policies:**
```
✅ Soft delete enforced → 98% vaults protected from accidental deletion
✅ Purge protection enforced → 76% vaults protected from malicious deletion
✅ Secret expiration enforced → 92% secrets have lifecycle management
✅ Key expiration enforced → 89% keys require rotation
✅ Public access blocked → 67% vaults use private endpoints only
✅ Diagnostic logging required → 89% vaults logging to SIEM
✅ Firewall rules enforced → 82% vaults restrict network access
✅ Automated compliance → Real-time monitoring, instant alerts
```

**Risk Reduction Quantified:**

| Security Risk | Before | After | Improvement |
|---------------|--------|-------|-------------|
| **Accidental Data Loss** | High | Low | 98% protected |
| **Malicious Deletion** | High | Medium | 76% protected |
| **Credential Exposure** | High | Low | 92% managed |
| **Unauthorized Access** | High | Low | 82% restricted |
| **Security Visibility** | Low | High | 89% monitored |
| **Compliance Gaps** | Manual/Reactive | Automated/Proactive | 100% coverage |

---

### 3C: Generate Monthly Compliance Report

**Purpose:** Executive summary for leadership/compliance teams.

**Command:**
```powershell
# Generate compliance report with all metrics
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan

# Optional: Export to specific format
$latestReport = Get-ChildItem "ComplianceReport-*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Invoke-Item $latestReport.FullName
```

**Report Content Includes:**

1. **Executive Summary (1 page)**
   - Overall compliance: 87.3%
   - Policies deployed: 46/46
   - Resources protected: 163 Key Vaults
   - Trend: +12% compliance vs last month

2. **Key Findings (1 page)**
   - Top 3 compliance gaps
   - Remediation progress
   - New risks identified

3. **Detailed Breakdown (5-10 pages)**
   - Policy-by-policy compliance
   - Resource-level details
   - Exemption summary
   - Remediation tracking

4. **Recommendations (1 page)**
   - Priority remediation items
   - Policy tuning suggestions
   - Exemption reviews needed

**Time Required:** 5 minutes to generate

---

## Complete Workflow Summary

### Scenario 1: Fresh Deployment (Dev/Test → Production)

**Total Time: ~2-3 days (including 24-48h wait)**

| Step | Script/Command | Time | Output |
|------|----------------|------|--------|
| 1. Infrastructure Setup | `.\Setup-AzureKeyVaultPolicyEnvironment.ps1` | 15-20 min | ✅ Managed identity<br>✅ Resource groups<br>✅ Test vaults |
| 2. Dev/Test Deployment | `.\AzPolicyImplScript.ps1 -Environment DevTest -Phase Test` | 10-15 min | ✅ 46 policies (Audit)<br>✅ Resource group scope |
| 3. Validate Dev/Test | `.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan` | 5-10 min | ✅ HTML compliance report |
| 4. Production Audit | `.\AzPolicyImplScript.ps1 -Environment Production -Phase Audit` | 10-15 min | ✅ 46 policies (Audit)<br>✅ Subscription scope |
| 5. **WAIT** | (Compliance data collection) | **24-48 hours** | - |
| 6. Check Compliance | `.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan` | 5-10 min | ✅ Full compliance report<br>✅ Security metrics |
| 7. Remediate | (Manual fixes or exemptions) | 1-4 hours | ✅ Non-compliant resources fixed |
| 8. Production Enforce | `.\AzPolicyImplScript.ps1 -Environment Production -Phase Enforce` | 10-15 min | ✅ 9 Deny policies active<br>✅ Operations blocked |
| 9. Validate Blocking | `.\AzPolicyImplScript.ps1 -TestDenyBlocking` | 5-10 min | ✅ Deny test results |

**Total Active Time:** ~90 minutes  
**Total Calendar Time:** 2-3 days

---

### Scenario 2: Audit-Only Deployment (No Enforcement)

**Total Time: ~1 day (including 24-48h wait)**

| Step | Script/Command | Time | Output |
|------|----------------|------|--------|
| 1. Infrastructure Setup | `.\Setup-AzureKeyVaultPolicyEnvironment.ps1` | 15-20 min | ✅ Infrastructure |
| 2. Production Audit | `.\AzPolicyImplScript.ps1 -Environment Production -Phase Audit` | 10-15 min | ✅ 46 policies (Audit) |
| 3. **WAIT** | (Compliance data collection) | **24-48 hours** | - |
| 4. Generate Reports | `.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan` | 5-10 min | ✅ Compliance dashboard<br>✅ Security metrics |

**Total Active Time:** ~40 minutes  
**Total Calendar Time:** 1-2 days

---

### Scenario 3: Enforcement-Only (Already Have Audit Data)

**Total Time: ~30 minutes**

| Step | Script/Command | Time | Output |
|------|----------------|------|--------|
| 1. Enable Enforcement | `.\AzPolicyImplScript.ps1 -Environment Production -Phase Enforce` | 10-15 min | ✅ 9 Deny policies active |
| 2. Validate Blocking | `.\AzPolicyImplScript.ps1 -TestDenyBlocking` | 5-10 min | ✅ Blocking validation |
| 3. Monitor Compliance | `.\AzPolicyImplScript.ps1 -CheckCompliance` | 5 min | ✅ Updated compliance |

---

## 🚀 Common Workflow Patterns

This section shows **all 9 workflow variations** tested in the comprehensive workflow validation. Each pattern includes proper parameter combinations and when to use them.

**📖 Quick Selection**: See [PolicyParameters-QuickReference.md](PolicyParameters-QuickReference.md) for parameter file selection guide

---

### Pattern 1: DevTest (30 Policies, Audit Mode)

**Use When**: First-time deployment, safe testing with minimal policies

```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest.json `
    -DryRun `
    -SkipRBACCheck `
    -IdentityResourceId "/subscriptions/<sub-id>/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Details**:
- **Policies**: 30 policies in Audit mode
- **Scope**: Subscription (default)
- **Managed Identity**: Optional (no DeployIfNotExists/Modify policies)
- **Safe**: ✅ Yes - monitoring only, no blocking

---

### Pattern 2: DevTestFull (46 Policies, Audit Mode)

**Use When**: Comprehensive testing, all policies in monitoring mode

```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full.json `
    -DryRun `
    -SkipRBACCheck `
    -IdentityResourceId "/subscriptions/<sub-id>/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Details**:
- **Policies**: 46 policies in Audit mode
- **Scope**: Subscription (default)
- **Managed Identity**: Optional (no auto-remediation policies in this file)
- **Safe**: ✅ Yes - complete coverage, monitoring only

---

### Pattern 3: DevTestRemediation (46 Policies, 8 Auto-Remediation)

**Use When**: Testing auto-remediation capabilities in dev/test environment

```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -DryRun `
    -SkipRBACCheck `
    -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Details**:
- **Policies**: 46 policies (38 Audit + 8 DeployIfNotExists/Modify)
- **Scope**: Subscription (default)
- **Managed Identity**: ⚠️ **REQUIRED** - 8 policies need auto-remediation capability
- **What It Does**: Automatically fixes non-compliant resources (diagnostic settings, firewall, DNS)
- **Safe**: ✅ Yes in dev/test - auto-fixes are reversible

**⚠️ CRITICAL**: Without `-IdentityResourceId`, the 8 remediation policies are **SKIPPED** with warning:
```
[WARN] Policy default effect 'DeployIfNotExists' requires managed identity. Skipping assignment - provide -IdentityResourceId to enable.
```

---

### Pattern 4: Production (46 Policies, Audit Mode)

**Use When**: Initial production deployment, observing before enforcement

```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -DryRun `
    -SkipRBACCheck `
    -IdentityResourceId "/subscriptions/<sub-id>/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Details**:
- **Policies**: 46 policies in Audit mode (strict parameters)
- **Scope**: Subscription (default)
- **Managed Identity**: Optional
- **Safe**: ✅ Yes - monitoring only, stricter thresholds than DevTest
- **Timeline**: Deploy → Wait 24-48h → Review compliance → Plan remediation

---

### Pattern 5: ProductionDeny (46 Policies, Deny Mode)

**Use When**: Maximum enforcement - block ALL non-compliant operations

```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Deny.json `
    -DryRun `
    -SkipRBACCheck `
    -IdentityResourceId "/subscriptions/<sub-id>/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Details**:
- **Policies**: 46 policies in **Deny mode** (maximum enforcement)
- **Scope**: Subscription (default)
- **Managed Identity**: Optional (no auto-remediation, just blocking)
- **Safe**: ⚠️ **NO** - Blocks non-compliant operations immediately
- **Prerequisites**: 
  - ✅ Audit mode run for 30+ days
  - ✅ All non-compliant resources remediated
  - ✅ Exemptions created where needed
  - ✅ Stakeholders notified

**⚠️ WARNING**: This blocks operations like:
- Creating Key Vaults without soft delete
- Creating secrets/keys without expiration dates
- Disabling diagnostic logging
- Enabling public network access

---

### Pattern 6: ProductionRemediation (46 Policies, 8 Auto-Remediation)

**Use When**: Production auto-remediation with strict governance

```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -DryRun `
    -SkipRBACCheck `
    -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Details**:
- **Policies**: 46 policies (38 Audit/Deny + 8 DeployIfNotExists/Modify)
- **Scope**: Subscription (default)
- **Managed Identity**: ⚠️ **REQUIRED** - 8 auto-remediation policies
- **Safe**: ⚠️ Use with caution - auto-fixes production resources
- **What It Does**: Automatically enables logging, firewall, private DNS on non-compliant vaults

**Best Practice**: Test in dev/test with Pattern 3 first, then deploy to production

---

### Pattern 7: ResourceGroupScope (Targeted Deployment)

**Use When**: Testing in isolated resource group before subscription-wide deployment

```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest.json `
    -ScopeType ResourceGroup `
    -ResourceGroupName "rg-policy-keyvault-test" `
    -DryRun `
    -SkipRBACCheck `
    -IdentityResourceId "/subscriptions/<sub-id>/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Details**:
- **Policies**: Uses selected parameter file (DevTest in example)
- **Scope**: Single resource group only
- **Managed Identity**: Optional (depends on parameter file)
- **Safe**: ✅ Yes - limited blast radius
- **Use Case**: Validate policies in isolated environment before broader deployment

---

### Pattern 8: ManagementGroupScope (Enterprise-Wide Deployment)

**Use When**: Deploying governance policies across multiple subscriptions

```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -ScopeType ManagementGroup `
    -ManagementGroupId "<YOUR-MG-ID>" `
    -DryRun `
    -SkipRBACCheck `
    -IdentityResourceId "/subscriptions/<sub-id>/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Details**:
- **Policies**: Uses selected parameter file (Production in example)
- **Scope**: Entire management group hierarchy
- **Managed Identity**: Optional (depends on parameter file)
- **Safe**: ⚠️ Use caution - affects ALL subscriptions in management group
- **Prerequisites**: Management group must exist and you need Owner/Policy Contributor role

---

### Pattern 9: Tier-Based Deployment (Gradual Rollout)

**Use When**: Incremental enforcement - start with critical policies

```powershell
# Deploy Tier 1 (9 critical policies in Deny mode)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Tier1-Deny.json `
    -DryRun `
    -SkipRBACCheck

# After 30 days, deploy Tier 2 (additional policies)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Tier2-Audit.json `
    -DryRun `
    -SkipRBACCheck

# After validation, convert Tier 2 to Deny
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Tier2-Deny.json `
    -DryRun `
    -SkipRBACCheck
```

**Details**:
- **Policies**: Tiered approach (9 critical → 16 important → 21 recommended)
- **Scope**: Subscription (default)
- **Managed Identity**: Not needed for tier files (Audit/Deny only)
- **Safe**: ✅ Gradual rollout reduces risk
- **Timeline**: Tier 1 → Wait 30 days → Tier 2 Audit → Wait 30 days → Tier 2 Deny

---

### Parameter Combinations Reference

| Pattern | Parameter File | -IdentityResourceId Required? | -PolicyMode Required? | Scope | DryRun Recommended? |
|---------|---------------|------------------------------|---------------------|-------|---------------------|
| 1. DevTest | `PolicyParameters-DevTest.json` | ✅ **YES** | Audit | Subscription | ✅ Yes |
| 2. DevTestFull | `PolicyParameters-DevTest-Full.json` | ✅ **YES** | Audit | Subscription | ✅ Yes |
| 3. DevTestRemediation | `PolicyParameters-DevTest-Full-Remediation.json` | ✅ **YES** | Enforce | Subscription | ✅ Yes |
| 4. Production | `PolicyParameters-Production.json` | ✅ **YES** | Audit | Subscription | ✅ Yes |
| 5. ProductionDeny | `PolicyParameters-Production-Deny.json` | ✅ **YES** | Deny | Subscription | ✅ **ALWAYS** |
| 6. ProductionRemediation | `PolicyParameters-Production-Remediation.json` | ✅ **YES** | **Enforce** | Subscription | ✅ Yes |
| 7. ResourceGroup | Any parameter file | Depends on file | Depends | ResourceGroup | ✅ Yes |
| 8. ManagementGroup | Any parameter file | Depends on file | Depends | ManagementGroup | ✅ **ALWAYS** |
| 9. Tier-Based | Tier parameter files | ✅ **YES** | Audit/Deny | Subscription | ✅ Yes |

**CRITICAL NOTES**:
- ✅ **ALL scenarios now require `-IdentityResourceId`** to ensure DINE/Modify policies deploy correctly
- ⚠️ **Scenario 6 (Remediation) MUST use `-PolicyMode Enforce`** - using Audit prevents auto-remediation
- 🔧 **Recent fix**: `cryptographicType` → `allowedKeyTypes` in 4 parameter files

**Legend**:
- ✅ **YES** = Mandatory parameter (deployment will skip remediation policies without it)
- ❌ No = Optional (no auto-remediation policies in parameter file)
- **ALWAYS** = Always use DryRun first to validate configuration

---

## Workflow 7: Production Auto-Remediation (Scenario 7)

### Purpose
Deploy 46 policies with 8 auto-remediation policies (DeployIfNotExists/Modify) that automatically fix non-compliant resources.

### ⚠️ CRITICAL Requirements
1. **MUST use `-PolicyMode Enforce`** - Audit mode will NOT trigger auto-remediation
2. **MUST provide `-IdentityResourceId`** - Required for DINE/Modify policy execution
3. **Wait 60-90 minutes** - Azure Policy remediation tasks take time to execute
4. **Use `-Force`** - Bypass interactive confirmation for production deployment

### Command

```powershell
# Get managed identity (created by Setup-AzureKeyVaultPolicyEnvironment.ps1)
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# Start logging
Start-Transcript -Path ".\logs\Scenario7-Production-Remediation-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Deploy with ENFORCE mode (NOT Audit!)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -PolicyMode Enforce `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck `
    -Force

# Wait 75 minutes for remediation cycle
Write-Host "Waiting for remediation cycle... Check status at ~75 minutes" -ForegroundColor Yellow
Start-Sleep -Seconds 4500  # 75 minutes

# Check remediation tasks (should show 8 tasks)
Get-AzPolicyRemediation -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb" |
    Select-Object Name, ProvisioningState, @{N='ResourcesRemediated';E={$_.DeploymentSummary.TotalDeployments}}

# Trigger compliance scan
Start-AzPolicyComplianceScan -AsJob
Start-Sleep -Seconds 300  # Wait 5 min

# Regenerate compliance report
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck

Stop-Transcript
```

### What Auto-Remediation Policies Do

| # | Policy Name | Effect | Action |
|---|-------------|--------|--------|
| 1 | Configure Azure Key Vault Managed HSM with private endpoints | DINE | Deploys private endpoint for Managed HSMs |
| 2 | Configure Azure Key Vaults with private endpoints | DINE | Deploys private endpoint for Key Vaults |
| 3 | Deploy diagnostic settings to Event Hub for Managed HSM | DINE | Configures diagnostic logging to Event Hub |
| 4 | Deploy diagnostic settings to Event Hub for Key Vault | DINE | Configures diagnostic logging to Event Hub |
| 5 | Deploy diagnostic settings to Log Analytics for Key Vault | DINE | Configures diagnostic logging to Log Analytics |
| 6 | Configure Azure Key Vaults to use private DNS zones | DINE | Configures private DNS zone integration |
| 7 | Configure Azure Key Vault Managed HSM to disable public network access | Modify | Disables public network access |
| 8 | Configure key vaults to enable firewall | Modify | Enables firewall and network rules |

### Expected Output

```
✓ 46/46 policies assigned successfully
✓ 8 policies in Enforce mode (DINE/Modify)
✓ 38 policies in Audit mode
✓ Managed identity assigned to auto-remediation policies
✓ Scope: /subscriptions/<sub-id>
✓ Baseline compliance: ~30-40%
✓ Expected after remediation: 60-80%
✓ Reports: PolicyImplementationReport-<timestamp>.html/json/csv/md
```

### Timeline

| Phase | Duration | Activity |
|-------|----------|----------|
| **Deployment** | 3-5 minutes | Policy assignment with managed identity |
| **Evaluation** | 15-30 minutes | Azure Policy evaluates resources |
| **Task Creation** | 30-60 minutes | Remediation tasks created for non-compliant resources |
| **Execution** | 60-90 minutes | Remediation tasks execute (deploy endpoints, configure settings) |
| **Total** | **90 minutes** | Complete auto-remediation cycle |

### Verification Steps

```powershell
# 1. Check policy assignments
Get-AzPolicyAssignment | Where-Object { $_.Properties.DisplayName -like "*Key Vault*" } |
    Select-Object Name, @{N='DisplayName';E={$_.Properties.DisplayName}}, @{N='Mode';E={$_.Properties.EnforcementMode}}

# 2. Verify managed identity assignment
Get-AzPolicyAssignment | Where-Object { $_.Identity } |
    Select-Object Name, @{N='IdentityType';E={$_.Identity.Type}}, @{N='IdentityId';E={$_.Identity.UserAssignedIdentities.Keys}}

# 3. Check remediation task status
$remediations = Get-AzPolicyRemediation -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb"
$remediations | Format-Table Name, ProvisioningState, @{N='Created';E={$_.CreatedOn}}, @{N='Resources';E={$_.DeploymentSummary.TotalDeployments}}

# 4. Check specific vault changes
$vaultName = "kv-test-noncompliant-XXXX"  # Replace with actual vault name
Get-AzKeyVault -VaultName $vaultName | Select-Object VaultName, PublicNetworkAccess, PrivateEndpointConnections
Get-AzDiagnosticSetting -ResourceId "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/$vaultName"
```

### Common Mistakes

| Mistake | Impact | Solution |
|---------|--------|----------|
| ❌ Using `-PolicyMode Audit` | Auto-remediation doesn't trigger | Use `-PolicyMode Enforce` |
| ❌ Omitting `-IdentityResourceId` | Policies deploy but can't remediate | Always provide managed identity |
| ❌ Not waiting 90 minutes | Checking too early shows no results | Wait full cycle before checking |
| ❌ Checking wrong scope | Can't find remediation tasks | Use subscription scope: `/subscriptions/<sub-id>` |

### Success Criteria

- ✅ 46/46 policies deployed successfully
- ✅ 8 remediation tasks created (6 DINE + 2 Modify)
- ✅ All tasks show "Succeeded" status
- ✅ Compliance improves from ~30% to 60-80%
- ✅ Resources auto-fixed: private endpoints, diagnostics, firewall, network access
- ✅ No errors in remediation task logs

### VALUE-ADD from Auto-Remediation

- **Time Savings**: 83 hours/year avoided (manual remediation eliminated)
- **Cost Savings**: $9,200/year (83 hours × $111/hr cloud engineer rate)
- **Consistency**: 100% (automated vs manual variance)
- **Compliance**: Real-time enforcement vs periodic manual checks

**Time Required:** 5 minutes deployment + 90 minutes remediation = **95 minutes total**

---

## Quick Reference Card

### 🎯 One-Liners for Common Tasks

```powershell
# Setup infrastructure (one-time)
.\Setup-AzureKeyVaultPolicyEnvironment.ps1

# Get managed identity for all deployments
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# Scenario 1-3: Deploy to dev/test (30 policies, Audit mode)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -PolicyMode Audit -IdentityResourceId $identityId -ScopeType Subscription -SkipRBACCheck

# Scenario 4: DevTest Full (46 policies, Audit mode)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -PolicyMode Audit -IdentityResourceId $identityId -ScopeType Subscription -SkipRBACCheck

# Scenario 5: Production Audit (46 policies, Audit mode)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -PolicyMode Audit -IdentityResourceId $identityId -ScopeType Subscription -SkipRBACCheck

# Scenario 6: Production Deny (34 policies, Deny mode)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Deny.json -PolicyMode Deny -IdentityResourceId $identityId -ScopeType Subscription -SkipRBACCheck

# Scenario 7: Production Remediation (46 policies, 8 Enforce + 38 Audit) - CRITICAL: Use Enforce mode!
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Remediation.json -PolicyMode Enforce -IdentityResourceId $identityId -ScopeType Subscription -SkipRBACCheck -Force

# Check compliance
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck

# Test infrastructure
.\AzPolicyImplScript.ps1 -TestInfrastructure -Detailed -SkipRBACCheck

# Test deny blocking
.\AzPolicyImplScript.ps1 -TestAllDenyPolicies -SkipRBACCheck

# Check remediation tasks (Scenario 7)
Get-AzPolicyRemediation -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb" | Select-Object Name, ProvisioningState

# List exemptions
.\AzPolicyImplScript.ps1 -ExemptionAction List

# Rollback all policies
.\AzPolicyImplScript.ps1 -Rollback
```

### 📚 New Documentation References

- **[SCENARIO-COMMANDS-REFERENCE.md](SCENARIO-COMMANDS-REFERENCE.md)**: All 7 scenarios with validated commands
- **[POLICY-COVERAGE-MATRIX.md](POLICY-COVERAGE-MATRIX.md)**: 46 policies × 7 scenarios matrix
- **[PolicyParameters-QuickReference.md](PolicyParameters-QuickReference.md)**: Parameter file selection guide

---

## Evidence Files Generated

### For Audit Mode Deployment

| File | Purpose | When Generated |
|------|---------|----------------|
| `ComplianceReport-<timestamp>.html` | Visual compliance dashboard | After `-CheckCompliance` |
| `KeyVaultPolicyImplementationReport-<timestamp>.json` | Machine-readable compliance data | After deployment |
| `KeyVaultPolicyImplementationReport-<timestamp>.md` | Markdown summary | After deployment |

### For Deny Mode Deployment

| File | Purpose | When Generated |
|------|---------|----------------|
| `DenyBlockingTestResults-<timestamp>.json` | Deny validation test results | After `-TestDenyBlocking` |
| `ComplianceReport-<timestamp>.html` | Updated compliance with enforcement | After `-CheckCompliance` |
| `EnforcementValidation-<timestamp>.csv` | Policy enforcement summary | After deployment |

### Security Value Evidence

| Evidence | File/Source | Contains |
|----------|-------------|----------|
| **Compliance Metrics** | ComplianceReport HTML | Overall %, policy breakdown, trends |
| **Risk Reduction** | ComplianceReport HTML | Before/after comparison, improvement % |
| **Enforcement Proof** | DenyBlockingTestResults JSON | Blocked operations, test validation |
| **Resource Coverage** | ComplianceReport HTML | Vaults protected, secrets/keys managed |
| **Framework Alignment** | ComplianceReport HTML | CIS, Azure Security Benchmark mapping |

---

## Summary

**Scripts Needed:**
1. ✅ **Setup-AzureKeyVaultPolicyEnvironment.ps1** - Infrastructure (one-time)
2. ✅ **AzPolicyImplScript.ps1** - All policy operations (deploy, audit, enforce, test)

**Configuration Files:**
3. ✅ **DefinitionListExport.csv** - Policy inventory
4. ✅ **PolicyParameters-DevTest.json** - Dev/Test config
5. ✅ **PolicyParameters-Production.json** - Production config

**Total: 5 files to deploy and manage 46 Azure Key Vault policies end-to-end**

**Evidence Generated:**
- ✅ Compliance HTML reports (policy-by-policy breakdown)
- ✅ Deny blocking test results (validation of enforcement)
- ✅ Security value metrics (risk reduction, coverage percentages)
- ✅ Compliance framework mapping (CIS, Azure Security Benchmark)
