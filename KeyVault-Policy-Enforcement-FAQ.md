# Azure Key Vault Policy Enforcement - Comprehensive FAQ

**Version**: 1.0  
**Date**: January 14, 2026  
**Audience**: Cybersecurity Architects, Engineers, Cloud Governance Teams, and Stakeholders  
**Scope**: Azure Key Vault Built-In Policy Enforcement Strategy

---

## Table of Contents

1. [Program Overview](#program-overview)
2. [Goals & Objectives](#goals--objectives)
3. [Architecture & Coverage](#architecture--coverage)
4. [Policy Sensitivity & Risk](#policy-sensitivity--risk)
5. [Implementation Strategy](#implementation-strategy)
6. [Technical Details](#technical-details)
7. [Pitfalls & Concerns](#pitfalls--concerns)
8. [Timing & Scheduling](#timing--scheduling)
9. [Security Coverage](#security-coverage)
10. [RBAC & Identity Management](#rbac--identity-management)
11. [Exceptions & Exemptions](#exceptions--exemptions)
12. [Monitoring & Compliance](#monitoring--compliance)
13. [Rollback & Recovery](#rollback--recovery)
14. [Stakeholder Communications](#stakeholder-communications)

---

## Program Overview

### What is this initiative?

**Objective**: Deploy 46 Azure built-in policies to enforce security best practices across all Key Vaults in the organization.

**Scope**: Subscription-wide enforcement using Azure Policy with:
- 45 policies in **Deny mode** (actively blocking non-compliant resources)
- 1 policy in **Audit mode** (soft-delete - due to ARM platform limitation)
- Phased rollout over 4 weeks to minimize disruption

**Current Status**:
- ✅ Testing complete (all 46 policies validated)
- ✅ Documentation complete (implementation guides, FAQs, runbooks)
- ✅ Validation complete (enforcement confirmed in dev/test)
- ⏳ Production deployment: Pending approval

---

## Goals & Objectives

### Why are we doing this?

**Primary Goals**:
1. **Prevent Security Misconfigurations**: Block insecure Key Vault configurations before they're deployed
2. **Enforce Compliance**: Align with industry frameworks (NIST, CIS, FedRAMP, ISO 27001)
3. **Reduce Risk**: Eliminate common attack vectors (public access, weak crypto, no purge protection)
4. **Automate Governance**: Shift-left security controls to prevent issues rather than detect them

### What problems are we solving?

**Common Key Vault Security Issues**:
- ✅ Public network access without firewall rules
- ✅ Access Policy model instead of RBAC (legacy, less secure)
- ✅ No purge protection (allows permanent secret deletion)
- ✅ Weak cryptographic algorithms (RSA <2048 bits, non-approved curves)
- ✅ Keys/secrets/certificates without expiration dates
- ✅ Certificates from non-approved Certificate Authorities
- ✅ Insufficient diagnostic logging

### Success Criteria

**Metrics**:
- **Compliance Rate**: >85% within 30 days of full deployment
- **Exemption Rate**: <10% per policy (targeted waivers only)
- **Zero Incidents**: No production outages due to policy enforcement
- **User Satisfaction**: <20 support tickets per deployment phase

---

## Architecture & Coverage

### What resources are covered?

**In Scope**:
- **Key Vaults**: All vaults (new and existing configurations)
- **Keys**: RSA, EC, HSM-backed keys
- **Secrets**: All secret types
- **Certificates**: All certificate types

**Out of Scope**:
- **Existing Keys/Secrets/Certificates**: Policies apply to NEW resources only (grandfather existing)
- **Managed HSM**: Different resource type, requires separate policies
- **Other Azure Services**: This initiative focuses ONLY on Key Vault

### Architecture Components

```
┌─────────────────────────────────────────────────────────────┐
│  Azure Policy Service (Subscription Scope)                  │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Policy Definitions (46 Built-In Policies)        │    │
│  │  - 45 Deny Mode (blocking enforcement)            │    │
│  │  - 1 Audit Mode (soft-delete ARM bug)             │    │
│  └────────────────────────────────────────────────────┘    │
│                        │                                     │
│                        ▼                                     │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Policy Assignments (Subscription-wide)            │    │
│  │  - EnforcementMode: Default                        │    │
│  │  - Identity: User-Assigned Managed Identity        │    │
│  └────────────────────────────────────────────────────┘    │
│                        │                                     │
│                        ▼                                     │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Evaluation Engine                                  │    │
│  │  - Pre-deployment validation (CREATE)              │    │
│  │  - Post-deployment validation (UPDATE)             │    │
│  │  - Compliance scanning (continuous)                │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  Key Vault Resource Manager                                 │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Vault Config │  │ Keys/Secrets │  │ Certificates │     │
│  │ - Firewall   │  │ - Expiration │  │ - CA         │     │
│  │ - RBAC       │  │ - Key Size   │  │ - Algorithms │     │
│  │ - Purge Prot │  │ - Algorithms │  │ - Validity   │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  Compliance Dashboard                                        │
│  - Real-time compliance metrics                             │
│  - Policy violation reports                                 │
│  - Exemption tracking                                       │
└─────────────────────────────────────────────────────────────┘
```

### How does enforcement work?

**Policy Evaluation Points**:

1. **Pre-Deployment (CREATE/UPDATE)**:
   - ARM template validation
   - **Deny policies**: Block non-compliant resources BEFORE creation
   - **Audit policies**: Log violation, allow creation
   - Result: Immediate feedback to user

2. **Post-Deployment (Compliance Scan)**:
   - Periodic evaluation (every 24 hours)
   - Identify drift from compliant state
   - Generate compliance reports
   - Result: Dashboard metrics, alerts

3. **Auto-Remediation** (select policies):
   - **Firewall policies**: Automatically set `DefaultAction: Deny`
   - **RBAC policies**: Automatically enable `EnableRbacAuthorization: True`
   - Result: Compliant configuration without blocking

---

## Policy Sensitivity & Risk

### How sensitive are these policies?

**Risk Categorization** (4 levels):

#### 🟢 LOW RISK (12 policies)
**Impact**: Affects FUTURE resources only (NEW keys/secrets/certs)

**Policies**:
- Certificate validity periods (max 12 months)
- Certificate expiration warnings (30+ days before expiry)
- Certificate issuance from integrated CAs
- Allowed key types and sizes
- Diagnostic logging

**Why Low Risk**:
- Does NOT affect existing resources
- Does NOT block vault creation/updates
- Only enforces best practices for NEW resources
- Users have control over expiration dates

**Example**:
```
❌ Blocked: Creating new certificate with 25-month validity
✅ Allowed: Existing certificate with 24-month validity (grandfathered)
✅ Allowed: Creating new certificate with 12-month validity
```

#### 🟡 MEDIUM RISK (18 policies)
**Impact**: May affect existing vault configurations

**Policies**:
- Firewall required (DefaultAction: Deny)
- RBAC permission model required
- Crypto algorithm restrictions
- Key size minimums (RSA ≥2048 bits)
- Allowed elliptic curves

**Why Medium Risk**:
- **Auto-remediation** reduces impact (vaults not blocked, just configured)
- Common configurations already compliant
- Some legacy vaults may use Access Policies (RBAC required)
- Public vaults without firewall will be auto-configured

**Example**:
```
✅ Auto-Remediated: Vault created → Firewall automatically set to Deny
⚠️ Blocked: Creating RSA 1024-bit key (weak crypto)
✅ Allowed: Creating RSA 2048-bit key
```

#### 🔴 HIGH RISK (15 policies)
**Impact**: HIGH - Many vaults likely non-compliant

**Policies**:
- **Purge Protection** (cannot add post-creation!)
- Required expirations for keys/secrets/certificates
- HSM firewall requirements
- Private endpoint enforcement

**Why High Risk**:
- **Purge Protection**: Many existing vaults lack this (cannot be added later)
- **Impact**: NEW vaults MUST enable purge protection during creation
- **Exemptions Required**: Vaults that cannot enable purge protection need waivers
- **User Disruption**: Users must change deployment templates

**CRITICAL Example - Purge Protection**:
```
❌ Blocked: New-AzKeyVault -Name "vault1" (no purge protection)
✅ Allowed: New-AzKeyVault -Name "vault1" -EnablePurgeProtection
⚠️ Important: Cannot add purge protection to existing vaults!
```

#### ⚠️ SPECIAL CASE (1 policy)
**Policy**: Soft-delete must be enabled

**Why Special**:
- **ARM Timing Bug**: Policy checks field that doesn't exist during validation
- **Result**: Deny mode blocks ALL vault creation (even compliant)
- **Workaround**: Use Audit mode instead
- **Security**: Acceptable because soft-delete is platform-enforced (enabled by default, cannot be disabled)

**Technical Details**:
```json
// Policy checks this condition:
{ "field": "Microsoft.KeyVault/vaults/enableSoftDelete", "exists": "false" }

// Problem: Field doesn't exist UNTIL AFTER ARM validation completes
// Result: Policy evaluates "exists: false" as TRUE → blocks vault
```

**Validation** (tested in dev/test):
```powershell
# Test Result: Deny mode DOES enforce (blocks all vaults)
New-AzKeyVault -EnablePurgeProtection
# ❌ Blocked: "Resource disallowed by policy: Key vaults should have soft delete enabled"

# Solution: Use Audit mode (soft-delete platform-enforced anyway)
```

---

## Implementation Strategy

### How will we deploy?

**Phased Rollout** (4 weeks total):

#### Phase 1: LOW RISK (Week 1)
**Policies**: 12  
**Notification**: 3 days prior  
**Impact**: Minimal (NEW resources only)  
**Success Criteria**: >95% compliance, <5 support tickets

**Policies Deployed**:
- Certificate validity periods
- Key/secret expiration policies
- Diagnostic logging

#### Phase 2: MEDIUM RISK (Week 2)
**Policies**: 18  
**Notification**: 5 days prior  
**Impact**: Moderate (auto-remediation for most)  
**Success Criteria**: >90% compliance, <20 support tickets

**Policies Deployed**:
- Firewall requirements (auto-remediation)
- RBAC requirements (auto-remediation)
- Crypto algorithm restrictions

**CRITICAL ALERT**:
- Users with public vaults: Firewall auto-configured (may break access patterns)
- Users with Access Policies: RBAC auto-enabled (may require role assignments)

#### Phase 3: HIGH RISK (Week 3)
**Policies**: 15  
**Notification**: 10 days prior  
**Impact**: HIGH  
**Success Criteria**: >85% compliance, <20 incidents, <10% exemptions

**Policies Deployed**:
- **Purge Protection** (CRITICAL - cannot be added post-creation)
- Required expirations for NEW keys/secrets/certificates
- HSM controls

**Pre-Deployment Audit Required**:
```powershell
# Identify vaults without purge protection
Get-AzKeyVault | Where-Object { $_.EnablePurgeProtection -ne $true }
# Result: List of vaults that CANNOT comply (exemptions needed)
```

#### Phase 4: SPECIAL CASE (Week 4)
**Policies**: 1 (soft-delete)  
**Notification**: Informational only  
**Impact**: None (Audit mode, monitoring only)

**Communication**:
- Explain ARM timing bug
- Confirm soft-delete platform-enforced
- No action required from users

### What happens if something breaks?

**Emergency Rollback** (5-30 minutes):
```powershell
# Option 1: Disable enforcement (fastest)
Set-AzPolicyAssignment -EnforcementMode DoNotEnforce
# Policies remain, compliance tracked, but no blocking

# Option 2: Full removal
Remove-AzPolicyAssignment -Id <assignment-id>
# Complete removal, no compliance tracking
```

---

## Technical Details

### What technologies are used?

**Azure Policy Framework**:
- **Engine**: Azure Resource Manager (ARM) policy evaluation
- **Scope**: Subscription-level assignments
- **Evaluation**: Pre-deployment + periodic compliance scans
- **Enforcement**: Deny effect (blocks non-compliant), Audit effect (logs only)

**Policy Types**:
- **Deny**: Blocks resource creation/update (45 policies)
- **Audit**: Logs violation without blocking (1 policy - soft-delete)
- **DeployIfNotExists (DINE)**: Not used (no auto-remediation policies in Key Vault set)
- **Modify**: Not used

**Identity & Permissions**:
- **Managed Identity**: `id-policy-remediation` (User-Assigned)
- **Purpose**: Future DINE policy support (not currently required)
- **Permissions**: None required (Deny/Audit don't need identity)

### How are policies evaluated?

**Evaluation Timeline**:

```
User Action: New-AzKeyVault -Name "vault1"
     │
     ▼
ARM Template Validation (PRE-DEPLOYMENT)
     │
     ├─► Policy 1: Purge Protection → Check: EnablePurgeProtection exists?
     │                                  Result: ❌ Not set → DENY (block creation)
     │
     ├─► Policy 2: Firewall Required → Check: NetworkAcls.DefaultAction?
     │                                  Result: ⚠️ Not set → MODIFY to "Deny" (auto-remediate)
     │
     ├─► Policy 3: RBAC Required → Check: EnableRbacAuthorization?
     │                              Result: ⚠️ Not set → MODIFY to "True" (auto-remediate)
     │
     └─► Policy 46: Soft-Delete → Check: enableSoftDelete exists?
                                   Result: ⚠️ Field doesn't exist during validation
                                   Effect: Audit mode (no blocking)
     │
     ▼
Resource Created (if all Deny policies pass)
     │
     ▼
Compliance Scan (POST-DEPLOYMENT, every 24 hours)
     │
     └─► Evaluate all policies against deployed resources
         Result: Compliance dashboard updated
```

### What happens during policy evaluation?

**Scenario 1: Compliant Vault**
```powershell
New-AzKeyVault -Name "vault1" -EnablePurgeProtection -EnableRbacAuthorization
# Result: ✅ Created successfully
# Firewall: Auto-set to DefaultAction: Deny
# RBAC: Already enabled
# Purge Protection: Enabled
# Soft-Delete: Platform-enforced (Audit mode logs compliance)
```

**Scenario 2: Non-Compliant Vault**
```powershell
New-AzKeyVault -Name "vault2"
# Result: ❌ Blocked by policy
# Error: "Resource 'vault2' was disallowed by policy.
#         Policy assignment: 'Key vaults should have deletion protection enabled'"
```

**Scenario 3: Partial Compliance**
```powershell
New-AzKeyVault -Name "vault3" -EnablePurgeProtection
# Result: ✅ Created (purge protection satisfied)
# Auto-Remediation:
#   - Firewall: Set to DefaultAction: Deny
#   - RBAC: EnableRbacAuthorization set to True
```

---

## Pitfalls & Concerns

### What could go wrong?

#### Concern #1: Purge Protection Cannot Be Added Post-Creation
**Issue**: Vaults created without purge protection cannot enable it later

**Impact**:
- Existing vaults: Cannot comply (exemption required)
- NEW vaults: MUST enable during creation (policy blocks otherwise)

**Mitigation**:
- **Pre-Deployment Audit**: Identify non-compliant vaults BEFORE Phase 3
- **Exemptions**: Grant waivers for vaults that cannot comply
- **User Guidance**: Update deployment templates to include `-EnablePurgeProtection`

**Exemption Example**:
```powershell
# Vault created before policy deployment (no purge protection)
$vault = Get-AzKeyVault -Name "legacy-vault"
# EnablePurgeProtection: False (cannot change)

# Solution: Exempt from policy
New-AzPolicyExemption -Name "legacy-vault-purge-protection" `
    -PolicyAssignment $assignment -ExemptionCategory Waiver `
    -Description "Pre-existing vault, cannot enable purge protection"
```

#### Concern #2: RBAC vs Access Policy Breaking Change
**Issue**: Policy enforces RBAC, but legacy vaults use Access Policies

**Impact**:
- **Auto-Remediation**: New vaults auto-enable RBAC
- **Access Policies**: Converted to RBAC (role assignments needed)
- **Service Principals**: May lose access until roles assigned

**Mitigation**:
- **Pre-Deployment Audit**: Identify vaults using Access Policies
- **Notification**: 5-day warning with migration guide
- **Exemptions**: Short-term waivers during migration
- **Migration Scripts**: Automate Access Policy → RBAC conversion

**Migration Example**:
```powershell
# Identify vaults using Access Policies
Get-AzKeyVault | Where-Object { $_.EnableRbacAuthorization -ne $true }

# For each vault:
# 1. Review existing Access Policies
# 2. Map to equivalent RBAC roles:
#    - Get/List secrets → "Key Vault Secrets User"
#    - Set secrets → "Key Vault Secrets Officer"
#    - Admin → "Key Vault Administrator"
# 3. Assign roles to users/SPs
# 4. Enable RBAC
# 5. Remove Access Policies
```

#### Concern #3: Firewall Breaking Public Access
**Issue**: Policy sets DefaultAction to Deny (blocks public access)

**Impact**:
- **Public vaults**: Access blocked unless IP whitelisted
- **DevOps pipelines**: May fail if IP not whitelisted
- **Automated processes**: Service Principals may lose access

**Mitigation**:
- **Auto-Remediation**: Policy sets firewall, doesn't block creation
- **Notification**: Users alerted 5 days prior
- **Guidance**: How to whitelist IPs, configure service endpoints
- **Private Endpoints**: Recommended for production

**Access Restoration**:
```powershell
# Add IP address to firewall
Add-AzKeyVaultNetworkRule -VaultName "vault1" `
    -IpAddressRange "203.0.113.0/24"

# Or use service endpoint
Add-AzKeyVaultNetworkRule -VaultName "vault1" `
    -VirtualNetworkResourceId $subnet.Id
```

#### Concern #4: Certificate Validity Disruption
**Issue**: Policies enforce 12-month max validity for NEW certificates

**Impact**:
- Existing certs: Grandfathered (no impact)
- NEW certs: Cannot exceed 12 months (policy blocks)
- Automated renewal: May fail if configured for 24-month certs

**Mitigation**:
- **Phase 1 Deployment**: LOW RISK (only affects new certs)
- **Notification**: 3-day warning
- **Exemptions**: Available for specific use cases
- **Guidance**: Update renewal scripts to 12-month validity

#### Concern #5: Soft-Delete ARM Timing Bug
**Issue**: Deny mode blocks ALL vault creation (even compliant)

**Root Cause**: Policy checks `enableSoftDelete` field during ARM validation, but field doesn't exist until AFTER validation

**Impact**:
- Cannot use Deny mode for soft-delete policy
- Must use Audit mode (monitoring only)

**Mitigation**:
- **Audit Mode**: Acceptable workaround (soft-delete platform-enforced)
- **Validation**: Tested in dev/test (Deny mode does block all vaults)
- **Security**: Not compromised (soft-delete mandatory since 2019, cannot be disabled)
- **Monitoring**: Compliance dashboard tracks audit findings

**Why This Is Acceptable**:
1. Soft-delete is **platform-enforced** (enabled by default)
2. Users **cannot disable** soft-delete (removed from API in 2019)
3. Audit mode **confirms compliance** without blocking
4. Other 45 policies **use Deny mode** successfully

---

## Timing & Scheduling

### When will this happen?

**Deployment Timeline** (subject to approval):

| Phase | Week | Policies | Notification | Go-Live | Impact |
|-------|------|----------|--------------|---------|--------|
| 1 | Week 1 | 12 LOW RISK | Day -3 | Day 0 | Minimal (NEW resources only) |
| 2 | Week 2 | 18 MEDIUM RISK | Day -5 | Day 0 | Moderate (auto-remediation) |
| 3 | Week 3 | 15 HIGH RISK | Day -10 | Day 0 | HIGH (purge protection, exemptions likely) |
| 4 | Week 4 | 1 SPECIAL CASE | Informational | Day 0 | None (Audit mode) |

**Pre-Deployment Activities**:

**Week 0** (Before Phase 1):
- [ ] Stakeholder approval
- [ ] Communication plan finalized
- [ ] Exemption process published
- [ ] Support team trained

**Week 1 - Phase 1**:
- [ ] Day -3: User notification sent
- [ ] Day 0: Deploy 12 LOW RISK policies
- [ ] Day +1: Monitor compliance dashboard
- [ ] Day +3: 72-hour review

**Week 2 - Phase 2**:
- [ ] Day -5: User notification + compliance reports
- [ ] Day -3: Exemption window opens
- [ ] Day 0: Deploy 18 MEDIUM RISK policies
- [ ] Day +7: Weekly review

**Week 3 - Phase 3** (CRITICAL):
- [ ] Day -10: **CRITICAL notification** + audit reports
- [ ] Day -7: Remediation workshops
- [ ] Day -5: Exemption deadline
- [ ] Day -3: Go/no-go decision
- [ ] Day 0: Deploy 15 HIGH RISK policies
- [ ] Day +14: Two-week review

**Week 4 - Phase 4**:
- [ ] Day -3: Informational email (soft-delete Audit mode)
- [ ] Day 0: Verify soft-delete in Audit mode
- [ ] Day +1: Confirm no blocking

### How long does policy evaluation take?

**Real-Time Enforcement**:
- **Pre-Deployment**: Immediate (ARM validation during resource creation)
- **Result**: User receives error within seconds if blocked

**Compliance Scanning**:
- **Frequency**: Every 24 hours (periodic scan)
- **Dashboard Update**: Within 1 hour of scan completion
- **Historical Data**: 90-day retention

**Policy Propagation**:
- **Assignment**: 5-15 minutes (across subscription)
- **Update**: 5-15 minutes (parameter changes)
- **Disable**: 5-30 minutes (EnforcementMode change)
- **Remove**: Immediate (assignment deletion)

---

## Security Coverage

### What security controls are enforced?

**11 Security Domains Covered**:

#### 1. **Data Protection**
**Policies**: Purge protection, soft-delete
**Controls**:
- ✅ Prevent permanent deletion (purge protection)
- ✅ Soft-delete enables recovery (90-day retention)
- ✅ Protect against accidental/malicious deletion

#### 2. **Network Security**
**Policies**: Firewall rules, private endpoints, public network access
**Controls**:
- ✅ Block public internet access (firewall DefaultAction: Deny)
- ✅ Require IP whitelisting or service endpoints
- ✅ Enforce private endpoints for production vaults

#### 3. **Cryptographic Standards**
**Policies**: Key sizes, algorithms, elliptic curves
**Controls**:
- ✅ RSA keys ≥2048 bits (prevent weak crypto)
- ✅ Approved elliptic curves (P-256, P-384, P-521)
- ✅ Block deprecated algorithms

#### 4. **Certificate Management**
**Policies**: Validity periods, expiration, issuance
**Controls**:
- ✅ Max 12-month validity (prevent long-lived certs)
- ✅ Expiration warnings (30+ days before expiry)
- ✅ Integrated CAs only (prevent untrusted issuers)

#### 5. **Key/Secret Lifecycle**
**Policies**: Expiration requirements
**Controls**:
- ✅ Keys MUST have expiration dates
- ✅ Secrets MUST have expiration dates
- ✅ Prevent indefinite secret storage

#### 6. **Access Control (RBAC)**
**Policies**: RBAC permission model
**Controls**:
- ✅ Enforce RBAC (modern, granular permissions)
- ✅ Block Access Policy model (legacy, broad permissions)
- ✅ Azure AD integration required

#### 7. **Audit & Logging**
**Policies**: Diagnostic settings
**Controls**:
- ✅ Diagnostic logs enabled
- ✅ Log Analytics integration
- ✅ Audit trail for compliance

#### 8. **HSM Security**
**Policies**: HSM firewall, private endpoints
**Controls**:
- ✅ HSM-backed keys require firewall
- ✅ HSM vaults require private endpoints
- ✅ Enhanced protection for high-value keys

#### 9. **DNS Security**
**Policies**: Private DNS zones
**Controls**:
- ✅ Private Link uses private DNS
- ✅ Prevent DNS hijacking
- ✅ Secure name resolution

#### 10. **Compliance Frameworks**
**Supported Standards**:
- ✅ NIST 800-53
- ✅ CIS Azure Foundations Benchmark
- ✅ FedRAMP Moderate/High
- ✅ ISO 27001
- ✅ PCI-DSS 3.2.1
- ✅ HIPAA

#### 11. **Lifecycle Actions**
**Policies**: Auto-renewal, rotation
**Controls**:
- ✅ Certificates support lifetime actions
- ✅ Auto-renewal configurations
- ✅ Prevent expiration disruptions

### What is NOT covered?

**Out of Scope**:
- ❌ **Key Rotation**: Policies don't enforce rotation schedules
- ❌ **Secret Content**: Policies don't validate secret values
- ❌ **Access Patterns**: Policies don't monitor who accesses what
- ❌ **Data Encryption**: Policies don't enforce customer-managed keys
- ❌ **Backup**: Policies don't enforce vault backups

**Recommendation**: Use Azure Security Center, Sentinel, or third-party tools for:
- Key rotation monitoring
- Access analytics
- Threat detection
- Backup validation

---

## RBAC & Identity Management

### How does this affect RBAC roles?

**Policy Requirement**: All vaults MUST use RBAC permission model

**Impact on Roles**:

#### Current State (Access Policies - Legacy)
```
Vault → Access Policies → Users/SPs
       (All or nothing: Get, List, Set, Delete)
```

#### Future State (RBAC - Required)
```
Vault → Azure AD RBAC Roles → Users/SPs
       (Granular: Secrets User, Officer, Administrator)
```

**Role Mapping**:

| Access Policy Permission | RBAC Role Equivalent |
|--------------------------|----------------------|
| Get/List secrets | `Key Vault Secrets User` |
| Set secrets | `Key Vault Secrets Officer` |
| Delete secrets | `Key Vault Secrets Officer` |
| All permissions | `Key Vault Administrator` |
| Get/List certificates | `Key Vault Certificates User` |
| Create certificates | `Key Vault Certificates Officer` |
| Get/List keys | `Key Vault Crypto User` |
| Create keys | `Key Vault Crypto Officer` |
| Encrypt/Decrypt | `Key Vault Crypto User` |
| Sign/Verify | `Key Vault Crypto User` |
| Management operations | `Key Vault Contributor` |

**Migration Process**:

1. **Audit Current Access**:
   ```powershell
   $vault = Get-AzKeyVault -Name "vault1"
   $vault.AccessPolicies | Select-Object DisplayName, PermissionsToKeys, PermissionsToSecrets
   ```

2. **Map to RBAC Roles**:
   - Identify users/SPs with Access Policies
   - Determine equivalent RBAC role
   - Document role assignments

3. **Assign RBAC Roles**:
   ```powershell
   # Example: Grant Secrets User role
   New-AzRoleAssignment -ObjectId $user.Id `
       -RoleDefinitionName "Key Vault Secrets User" `
       -Scope "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/vault1"
   ```

4. **Enable RBAC**:
   ```powershell
   Update-AzKeyVault -VaultName "vault1" -EnableRbacAuthorization $true
   ```

5. **Remove Access Policies**:
   ```powershell
   Remove-AzKeyVaultAccessPolicy -VaultName "vault1" -ObjectId $user.Id
   ```

### What about Managed Identities?

**Policy Requirement**: User-Assigned Managed Identity for policy assignments

**Current Identity**:
- **Name**: `id-policy-remediation`
- **Resource Group**: `rg-policy-remediation`
- **Purpose**: Future DINE policy support (not currently required)

**Permissions Required**:
- **Current**: None (Deny/Audit policies don't require identity)
- **Future**: If DINE policies added, identity needs:
  - `Key Vault Contributor` (to modify vaults)
  - `Reader` (to query compliance state)

**Service Principal Access**:
- **Impact**: Service Principals using Access Policies may lose access during RBAC migration
- **Mitigation**: Assign RBAC roles before enabling RBAC on vaults

**Example**:
```powershell
# Service Principal loses access after RBAC enabled
$sp = Get-AzADServicePrincipal -DisplayName "DevOps-Pipeline"

# Solution: Grant RBAC role
New-AzRoleAssignment -ObjectId $sp.Id `
    -RoleDefinitionName "Key Vault Secrets User" `
    -Scope $vault.ResourceId
```

---

## Exceptions & Exemptions

### When are exemptions allowed?

**Exemption Categories**:

#### 1. **Waiver** (Business Exception)
**Use Case**: Business requirement prevents compliance

**Examples**:
- Legacy vault without purge protection (cannot be added)
- Third-party integration requires Access Policies
- Regulatory requirement for 24-month certificates

**Approval**: Security architect + business owner
**Expiration**: 90 days (renewable)
**Limit**: <10% of resources per policy

#### 2. **Mitigated** (Compensating Controls)
**Use Case**: Alternative security control provides equivalent protection

**Examples**:
- Public vault with compensating MFA + conditional access
- Access Policies with enhanced monitoring + alerting
- Weak crypto for backward compatibility (time-limited)

**Approval**: Security architect
**Expiration**: 60 days (renewable)
**Limit**: <5% of resources per policy

### How to request an exemption?

**Process**:

1. **Submit Request**:
   ```
   Subject: Policy Exemption Request - [Vault Name] - [Policy Name]
   
   Vault: vault-name
   Policy: Key vaults should have deletion protection enabled
   Category: Waiver
   Justification: Legacy vault created before policy deployment, 
                  cannot enable purge protection post-creation
   Compensating Controls: Daily backups, restricted access, audit logging
   Duration Requested: 90 days
   ```

2. **Security Review** (48-72 hours):
   - Validate justification
   - Assess risk
   - Approve/reject

3. **Exemption Creation**:
   ```powershell
   New-AzPolicyExemption -Name "vault1-purge-protection" `
       -PolicyAssignment $assignment `
       -ExemptionCategory Waiver `
       -Description "Legacy vault, cannot enable purge protection. Daily backups + restricted access." `
       -ExpiresOn (Get-Date).AddDays(90)
   ```

4. **Tracking**:
   - Exemption logged in compliance dashboard
   - Expiration alerts (14 days before)
   - Renewal process (if needed)

**SLA**:
- **Phase 1 (LOW RISK)**: 48 hours
- **Phase 2 (MEDIUM RISK)**: 72 hours
- **Phase 3 (HIGH RISK)**: 5 business days

**Exemption Limit**:
- **Maximum**: 10% of resources per policy
- **Exceeding Limit**: Triggers security review (policy may be disabled)

---

## Monitoring & Compliance

### How do we track compliance?

**Compliance Dashboard** (Azure Portal):

**Metrics**:
- **Overall Compliance**: % of compliant resources
- **Per-Policy Compliance**: % per individual policy
- **Non-Compliant Resources**: Count and list
- **Exemptions**: Count and expiration dates
- **Trends**: 30/60/90-day compliance trends

**Access**:
```
Azure Portal → Policy → Compliance → [Subscription]
```

**Report Export**:
```powershell
# Export compliance data
$compliance = Get-AzPolicyStateSummary -SubscriptionId "sub-id"
$compliance | Export-Csv "ComplianceReport-$(Get-Date -Format yyyyMMdd).csv"
```

**Automated Alerts**:
- **Non-Compliance Spike**: >10% drop in compliance
- **Exemption Expiration**: 14-day warning
- **Policy Violation**: Real-time alert on Deny policy block

**Custom Dashboards**:
- **Power BI**: Connect to Azure Policy compliance API
- **Grafana**: Integrate with Azure Monitor
- **Datadog/Splunk**: Custom integrations

### What happens when a policy is violated?

**Deny Mode (45 policies)**:
1. User attempts non-compliant operation
2. ARM validation fails
3. **Error returned immediately**:
   ```
   ❌ Resource 'vault1' was disallowed by policy.
      Policy assignment: 'Key vaults should have deletion protection enabled'
      Policy definition: '0b60c0b2-2dc2-4e1c-b5c9-abbed971de53'
   ```
4. Resource **NOT created**
5. Compliance state: Not applicable (resource doesn't exist)
6. User action: Fix configuration, retry

**Audit Mode (1 policy - soft-delete)**:
1. User creates resource (allowed)
2. Policy evaluation runs
3. **Violation logged** (no blocking)
4. Compliance state: Non-compliant (tracked in dashboard)
5. User action: None required (informational)

---

## Rollback & Recovery

### What if we need to rollback?

**Rollback Scenarios**:

#### Scenario 1: Emergency Disable (Production Outage)
**Timeline**: 5-30 minutes  
**Impact**: Policies remain, but no enforcement

```powershell
# Disable ALL policy enforcement
Get-AzPolicyAssignment | Where-Object { $_.Properties.DisplayName -like "*Key Vault*" } |
    ForEach-Object {
        Set-AzPolicyAssignment -Id $_.ResourceId -EnforcementMode DoNotEnforce
    }

# Result: Compliance tracking continues, but no blocking
```

#### Scenario 2: Partial Rollback (Single Policy Issue)
**Timeline**: 5-15 minutes  
**Impact**: One policy disabled, others active

```powershell
# Disable specific policy (e.g., purge protection)
$assignment = Get-AzPolicyAssignment | Where-Object { 
    $_.Properties.DisplayName -like "*deletion protection*" 
}
Set-AzPolicyAssignment -Id $assignment.ResourceId -EnforcementMode DoNotEnforce
```

#### Scenario 3: Full Removal (Complete Rollback)
**Timeline**: Immediate  
**Impact**: All policies removed, no compliance tracking

```powershell
# Remove ALL Key Vault policy assignments
Get-AzPolicyAssignment | Where-Object { $_.Properties.DisplayName -like "*Key Vault*" } |
    ForEach-Object {
        Remove-AzPolicyAssignment -Id $_.ResourceId
    }
```

### How do we recover from issues?

**Recovery Procedures**:

**Issue**: Users cannot create vaults (Deny policy too strict)

**Recovery**:
1. **Immediate**: Disable enforcement (DoNotEnforce)
2. **Investigation**: Identify root cause (parameter error? ARM bug?)
3. **Exemption**: Grant temporary waiver for affected users
4. **Fix**: Update policy parameters or create exemption
5. **Re-Enable**: Test in dev/test, then production

**Issue**: Compliance drops unexpectedly

**Recovery**:
1. **Audit**: Review compliance dashboard for non-compliant resources
2. **Root Cause**: Identify why resources non-compliant (drift? new deployments?)
3. **Communication**: Notify users of violations
4. **Remediation**: Guide users to fix configurations
5. **Exemptions**: Grant waivers if compliance not feasible

**Issue**: Service outage due to RBAC migration

**Recovery**:
1. **Emergency**: Temporarily enable Access Policies (if possible)
2. **Workaround**: Grant emergency RBAC roles to affected SPs/users
3. **Communication**: Notify stakeholders of incident
4. **Remediation**: Complete RBAC role assignments
5. **Verification**: Test access restoration

---

## Stakeholder Communications

### How will users be notified?

**Communication Channels**:
- **Email**: Primary notification method
- **Teams/Slack**: Announcement channels
- **Portal Banner**: Azure Portal notification
- **Change Management**: ServiceNow tickets

**Notification Templates**:

#### Phase 1 Notification (LOW RISK)
**Subject**: [ACTION REQUIRED] Key Vault Policy Enforcement - Phase 1 (LOW RISK)

**Body**:
```
Dear Azure Users,

WHAT: Azure Key Vault security policies (Phase 1 - LOW RISK)
WHEN: January 20, 2026 (3 days from now)
IMPACT: Minimal - affects NEW keys/secrets/certificates only

POLICIES DEPLOYED:
- Certificate validity periods (max 12 months)
- Key/secret expiration requirements
- Diagnostic logging

WHAT THIS MEANS:
✅ Existing resources: No impact (grandfathered)
✅ Vault creation: No changes
⚠️ NEW certificates: Cannot exceed 12-month validity
⚠️ NEW keys/secrets: Must have expiration dates

ACTION REQUIRED:
1. Update deployment scripts to set expiration dates
2. Review certificate renewal configurations
3. No action needed for existing resources

QUESTIONS: security@company.com
DOCUMENTATION: https://docs.company.com/keyvault-policies
EXEMPTIONS: https://exemptions.company.com/policy
```

#### Phase 3 Notification (HIGH RISK - CRITICAL)
**Subject**: [CRITICAL ACTION REQUIRED] Key Vault Policy Enforcement - Phase 3 (HIGH RISK)

**Body**:
```
Dear Azure Users,

⚠️ CRITICAL NOTICE ⚠️

WHAT: Azure Key Vault security policies (Phase 3 - HIGH RISK)
WHEN: February 3, 2026 (10 days from now)
IMPACT: HIGH - NEW vaults MUST enable purge protection

POLICIES DEPLOYED:
❗ Purge Protection REQUIRED (cannot be added post-creation)
- Required expirations for NEW keys/secrets/certificates
- HSM firewall/private endpoint enforcement

CRITICAL IMPACT:
❌ NEW VAULTS: MUST include -EnablePurgeProtection during creation
❌ EXISTING VAULTS: Cannot comply if purge protection not enabled
⚠️ Exemptions required for non-compliant existing vaults

PRE-DEPLOYMENT AUDIT:
We have identified [X] vaults without purge protection:
[List of vaults]

ACTION REQUIRED (URGENT):
1. Review your vaults (see attached report)
2. NEW DEPLOYMENTS: Update templates to include -EnablePurgeProtection
3. EXISTING VAULTS: Request exemption if purge protection not enabled
4. TESTING: Validate templates in dev/test environment

EXEMPTION DEADLINE: January 29, 2026 (5 days before deployment)

QUESTIONS: security@company.com (urgent support available)
DOCUMENTATION: https://docs.company.com/keyvault-policies/phase3
EXEMPTIONS: https://exemptions.company.com/policy (SLA: 5 business days)
```

### Who needs to be informed?

**Stakeholders**:

1. **Azure Users**:
   - Developers creating Key Vaults
   - DevOps engineers with deployment pipelines
   - Application owners using Key Vault

2. **Security Teams**:
   - Security architects
   - Compliance officers
   - Incident response teams

3. **Management**:
   - IT leadership (CIO/CTO)
   - Business unit leaders
   - Compliance/audit teams

4. **Support Teams**:
   - Cloud operations
   - Service desk
   - Application support

**Communication Timeline**:
- **T-14 days**: Executive briefing (Phase 3 only)
- **T-10 days**: Security team readiness (Phase 3)
- **T-5 days**: User notification (Phase 2)
- **T-3 days**: User notification (Phase 1)
- **T-1 day**: Final reminder + support team alert
- **T-0**: Deployment + monitoring
- **T+1 day**: 24-hour status update
- **T+7 days**: Weekly review

---

## Appendix: Quick Reference

### Policy Count by Risk Level
- 🟢 LOW RISK: 12 policies (NEW resources only)
- 🟡 MEDIUM RISK: 18 policies (auto-remediation)
- 🔴 HIGH RISK: 15 policies (purge protection, expiration)
- ⚠️ SPECIAL CASE: 1 policy (soft-delete Audit mode)

### Deployment Timeline
- Week 1: Phase 1 (12 policies)
- Week 2: Phase 2 (18 policies)
- Week 3: Phase 3 (15 policies)
- Week 4: Phase 4 (1 policy)

### Key Contacts
- **Security Team**: security@company.com
- **Policy Questions**: cloudgovernance@company.com
- **Exemption Requests**: exemptions@company.com
- **Emergency Support**: cloudsupport@company.com (24/7)

### Important Links
- **Policy Documentation**: [Internal Wiki]
- **Compliance Dashboard**: Azure Portal → Policy → Compliance
- **Exemption Portal**: [Internal Portal]
- **Training Materials**: [Learning Portal]

### Emergency Procedures
- **Disable Enforcement**: `Set-AzPolicyAssignment -EnforcementMode DoNotEnforce`
- **Remove Assignment**: `Remove-AzPolicyAssignment -Id <assignment-id>`
- **Escalation**: Contact CloudSupport immediately

---

**Document Version**: 1.0  
**Last Updated**: January 14, 2026  
**Next Review**: February 14, 2026 (30 days post-deployment)  
**Owner**: Cloud Governance Team
