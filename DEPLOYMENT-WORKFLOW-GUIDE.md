# Deployment Workflow Guide

## Overview

This guide shows **exactly which scripts to run** for each deployment scenario and **what outputs/evidence** they produce.

**Last Updated**: January 14, 2026

---

## 📋 Complete Script Inventory

### Core Deployment Scripts (2 files)

| Script | Purpose | When to Use |
|--------|---------|-------------|
| **Setup-AzureKeyVaultPolicyEnvironment.ps1** | Infrastructure setup | One-time setup in new subscription |
| **AzPolicyImplScript.ps1** | Policy deployment, compliance, testing | All policy operations |

### Configuration Files (3 files)

| File | Purpose | When to Use |
|------|---------|-------------|
| **DefinitionListExport.csv** | 46 policy definitions | Required by deployment script |
| **PolicyParameters-DevTest.json** | Dev/Test parameters (relaxed) | Testing environments |
| **PolicyParameters-Production.json** | Production parameters (strict) | Production environments |

**Total Required: 5 files (~322 KB)**

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

## Quick Reference Card

### 🎯 One-Liners for Common Tasks

```powershell
# Setup infrastructure (one-time)
.\Setup-AzureKeyVaultPolicyEnvironment.ps1

# Deploy to dev/test
.\AzPolicyImplScript.ps1 -Environment DevTest -Phase Test

# Deploy to production (Audit)
.\AzPolicyImplScript.ps1 -Environment Production -Phase Audit

# Check compliance
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan

# Enable enforcement
.\AzPolicyImplScript.ps1 -Environment Production -Phase Enforce

# Test deny blocking
.\AzPolicyImplScript.ps1 -TestDenyBlocking

# List exemptions
.\AzPolicyImplScript.ps1 -ExemptionAction List

# Rollback all policies
.\AzPolicyImplScript.ps1 -Rollback
```

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
