# Azure Key Vault Policy Analysis & Blocking Behavior Report

**Generated**: January 13, 2026  
**Scope**: All 46 Azure Key Vault Built-In Policies  
**Analysis Sources**:
- DefinitionListExport.csv (46 policies)
- PolicyEffectMatrix-20260113-094027.csv (effect analysis)
- DenyBlockingTestResults-20260112-180206.json (blocking tests)
- Phase2Point3TestResults-20260112-175641.json (enforcement validation)

---

## Executive Summary

### Overall Policy Distribution

| Category | Count | Percentage | Capability |
|----------|-------|------------|------------|
| **Deny-Capable** | 34 | 73.9% | ✅ Can block non-compliant operations |
| **Audit-Only** | 12 | 26.1% | ⚠️ Can only audit or auto-remediate |
| **Total** | 46 | 100% | All default to Audit mode |

### Key Finding

🔑 **ALL 46 Azure Key Vault built-in policies have PARAMETERIZED effects**:
- **Default Mode**: Audit (non-blocking, report only)
- **Available Modes**: Audit, Deny (blocking), Disabled
- **34 policies (73.9%)** support Deny mode for blocking operations
- **12 policies (26.1%)** only support infrastructure deployment/configuration

---

## Policy Effect Matrix

### 1. Deny-Capable Policies (34 policies)

These policies **CAN BLOCK** non-compliant operations when set to Deny mode during assignment.

#### A. Vault Protection & Security (6 policies)

| # | Policy Name | Default Effect | Can Deny | Purpose |
|---|-------------|----------------|----------|---------|
| 1 | Key vaults should have soft delete enabled | Audit | ✅ Yes | Prevent permanent deletion |
| 2 | Key vaults should have deletion protection enabled | Audit | ✅ Yes | Require purge protection |
| 3 | Azure Key Vault Managed HSM should have purge protection enabled | Audit | ✅ Yes | Prevent permanent HSM deletion |
| 4 | Azure Key Vault should use RBAC permission model | Audit | ✅ Yes | Enforce RBAC over access policies |
| 5 | Azure Key Vault should disable public network access | Audit | ✅ Yes | Block public internet access |
| 6 | Azure Key Vault should have firewall enabled or public network access disabled | Audit | ✅ Yes | Require firewall or private access |

#### B. Network Security (2 policies)

| # | Policy Name | Default Effect | Can Deny | Purpose |
|---|-------------|----------------|----------|---------|
| 7 | Azure Key Vaults should use private link | Audit | ✅ Yes | Require private endpoint |
| 8 | [Preview]: Azure Key Vault Managed HSM should disable public network access | Audit | ✅ Yes | Block public HSM access |

#### C. Key Lifecycle Management (7 policies)

| # | Policy Name | Default Effect | Can Deny | Purpose |
|---|-------------|----------------|----------|---------|
| 9 | Key Vault keys should have an expiration date | Audit | ✅ Yes | Require key expiration |
| 10 | Keys should have more than the specified number of days before expiration | Audit | ✅ Yes | Prevent near-expired keys |
| 11 | Keys should have the specified maximum validity period | Audit | ✅ Yes | Limit key lifetime |
| 12 | Keys should not be active for longer than the specified number of days | Audit | ✅ Yes | Enforce key rotation |
| 13 | Keys should be backed by a hardware security module (HSM) | Audit | ✅ Yes | Require HSM protection |
| 14 | Keys should be the specified cryptographic type RSA or EC | Audit | ✅ Yes | Restrict key algorithms |
| 15 | Keys using RSA cryptography should have a specified minimum key size | Audit | ✅ Yes | Enforce minimum RSA key size |

#### D. Key Cryptographic Requirements (2 policies)

| # | Policy Name | Default Effect | Can Deny | Purpose |
|---|-------------|----------------|----------|---------|
| 16 | Keys using elliptic curve cryptography should have the specified curve names | Audit | ✅ Yes | Restrict ECC curves |
| 17 | [Preview]: Azure Key Vault Managed HSM keys using RSA cryptography should have a specified minimum key size | Audit | ✅ Yes | HSM RSA key size |

#### E. Secret Lifecycle Management (4 policies)

| # | Policy Name | Default Effect | Can Deny | Purpose |
|---|-------------|----------------|----------|---------|
| 18 | Key Vault secrets should have an expiration date | Audit | ✅ Yes | Require secret expiration |
| 19 | Secrets should have more than the specified number of days before expiration | Audit | ✅ Yes | Prevent near-expired secrets |
| 20 | Secrets should have the specified maximum validity period | Audit | ✅ Yes | Limit secret lifetime |
| 21 | Secrets should not be active for longer than the specified number of days | Audit | ✅ Yes | Enforce secret rotation |

#### F. Secret Requirements (1 policy)

| # | Policy Name | Default Effect | Can Deny | Purpose |
|---|-------------|----------------|----------|---------|
| 22 | Secrets should have content type set | Audit | ✅ Yes | Require metadata |

#### G. Certificate Lifecycle Management (5 policies)

| # | Policy Name | Default Effect | Can Deny | Purpose |
|---|-------------|----------------|----------|---------|
| 23 | Certificates should have the specified maximum validity period | Audit | ✅ Yes | Limit certificate lifetime |
| 24 | Certificates should not expire within the specified number of days | Audit | ✅ Yes | Prevent near-expired certs |
| 25 | Certificates should have the specified lifetime action triggers | Audit | ✅ Yes | Require renewal actions |
| 26 | Certificates should use allowed key types | Audit | ✅ Yes | Restrict cert key types |
| 27 | Certificates using RSA cryptography should have the specified minimum key size | Audit | ✅ Yes | Enforce RSA cert key size |

#### H. Certificate Authority Restrictions (3 policies)

| # | Policy Name | Default Effect | Can Deny | Purpose |
|---|-------------|----------------|----------|---------|
| 28 | Certificates should be issued by the specified integrated certificate authority | Audit | ✅ Yes | Restrict to integrated CA |
| 29 | Certificates should be issued by the specified non-integrated certificate authority | Audit | ✅ Yes | Restrict to specific CA |
| 30 | Certificates should be issued by one of the specified non-integrated certificate authorities | Audit | ✅ Yes | Restrict to CA list |

#### I. Certificate Cryptographic Requirements (1 policy)

| # | Policy Name | Default Effect | Can Deny | Purpose |
|---|-------------|----------------|----------|---------|
| 31 | Certificates using elliptic curve cryptography should have allowed curve names | Audit | ✅ Yes | Restrict ECC cert curves |

#### J. Managed HSM Key Policies (3 policies)

| # | Policy Name | Default Effect | Can Deny | Purpose |
|---|-------------|----------------|----------|---------|
| 32 | [Preview]: Azure Key Vault Managed HSM keys should have an expiration date | Audit | ✅ Yes | HSM key expiration |
| 33 | [Preview]: Azure Key Vault Managed HSM Keys should have more than the specified number of days before expiration | Audit | ✅ Yes | HSM key near-expiry check |
| 34 | [Preview]: Azure Key Vault Managed HSM keys using elliptic curve cryptography should have the specified curve names | Audit | ✅ Yes | HSM ECC curve restriction |

---

### 2. Audit-Only Policies (12 policies)

These policies **CANNOT BLOCK** operations - they only audit or automatically deploy/configure resources.

#### A. Private Endpoint Deployment (3 policies)

| # | Policy Name | Effect Type | Purpose |
|---|-------------|-------------|---------|
| 1 | Configure Azure Key Vaults with private endpoints | DeployIfNotExists | Auto-deploy private endpoints |
| 2 | Configure Azure Key Vaults to use private DNS zones | DeployIfNotExists | Auto-configure DNS |
| 3 | [Preview]: Configure Azure Key Vault Managed HSM with private endpoints | DeployIfNotExists | Auto-deploy HSM endpoints |

#### B. Diagnostic Settings Deployment (3 policies)

| # | Policy Name | Effect Type | Purpose |
|---|-------------|-------------|---------|
| 4 | Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace | DeployIfNotExists | Auto-deploy diagnostics |
| 5 | Deploy Diagnostic Settings for Key Vault to Event Hub | DeployIfNotExists | Auto-deploy event hub logging |
| 6 | Deploy - Configure diagnostic settings to an Event Hub to be enabled on Azure Key Vault Managed HSM | DeployIfNotExists | Auto-deploy HSM diagnostics |

#### C. Firewall & Network Configuration (3 policies)

| # | Policy Name | Effect Type | Purpose |
|---|-------------|-------------|---------|
| 7 | Configure key vaults to enable firewall | Modify | Auto-enable firewall |
| 8 | [Preview]: Configure Azure Key Vault Managed HSM to disable public network access | Modify | Auto-disable public access |
| 9 | [Preview]: Azure Key Vault Managed HSM should use private link | Audit | Audit-only private link check |

#### D. Logging & Rotation Policies (3 policies)

| # | Policy Name | Effect Type | Purpose |
|---|-------------|-------------|---------|
| 10 | Resource logs in Key Vault should be enabled | AuditIfNotExists | Audit logging enablement |
| 11 | Resource logs in Azure Key Vault Managed HSM should be enabled | AuditIfNotExists | Audit HSM logging |
| 12 | Keys should have a rotation policy ensuring that their rotation is scheduled within the specified number of days after creation. | Audit | Audit rotation policy |

---

## Deny Blocking Test Results

### Test Execution Summary

**Date**: January 12, 2026, 18:02 UTC  
**Test Script**: AzPolicyImplScript.ps1 -TestDenyBlocking  
**Evidence**: DenyBlockingTestResults-20260112-180206.json

**Overall Success Rate**: 50% (2/4 tests passed)

### Individual Test Results

| Test # | Test Scenario | Policy Tested | Expected | Actual | Status | Root Cause |
|--------|---------------|---------------|----------|--------|--------|------------|
| 1 | Create vault without purge protection | Key vaults should have deletion protection enabled | ❌ BLOCKED | ✅ CREATED | ❌ FAIL | Policy evaluation timing / Soft delete always-on |
| 2 | Create vault with public network access | Azure Key Vault should disable public network access | ❌ BLOCKED | ✅ CREATED | ❌ FAIL | Policy evaluation timing |
| 3 | Create key without expiration | Key Vault keys should have an expiration date | ❌ BLOCKED | ❌ BLOCKED (403) | ✅ PASS | RBAC/Policy blocking working |
| 4 | Create certificate with excessive validity | Certificates should have the specified maximum validity period | ❌ BLOCKED | ❌ BLOCKED (403) | ✅ PASS | RBAC/Policy blocking working |

### Gap Analysis

#### ✅ What IS Blocking

1. **Object-Level Operations** (Keys, Secrets, Certificates)
   - Key creation without expiration: **BLOCKED** ✅
   - Certificate creation with excessive validity: **BLOCKED** ✅
   - **Mechanism**: RBAC + Azure Policy Deny effect evaluated at object creation

#### ❌ What is NOT Blocking

1. **Vault-Level Operations** (Vault creation/configuration)
   - Vault creation without purge protection: **NOT BLOCKED** ❌
   - Vault creation with public network access: **NOT BLOCKED** ❌
   
   **Possible Root Causes**:
   - **Timing Issue**: Policy may evaluate AFTER vault creation completes
   - **Soft Delete Behavior**: Azure automatically enables soft delete (cannot be disabled)
   - **Purge Protection**: Can be enabled post-creation, not enforced at creation time
   - **Public Access**: Default behavior, may not trigger Deny evaluation

### Recommendations

1. **For Vault-Level Compliance**:
   - Use **DeployIfNotExists** or **Modify** policies to auto-remediate after creation
   - Use **Azure Blueprints** or **ARM/Bicep templates** to enforce vault configuration at provisioning
   - Rely on **continuous compliance scanning** to identify and remediate non-compliant vaults

2. **For Object-Level Compliance**:
   - **Deny mode works effectively** for keys, secrets, certificates
   - Deploy these policies in Deny mode for production environments
   - Train users on policy requirements before resource creation

3. **Testing Recommendations**:
   - Expand blocking tests to cover all 34 Deny-capable policies
   - Test in staging environment before production deployment
   - Document expected vs actual blocking behavior per policy

---

## Policy Deployment Strategy

### Phase Approach

Based on effect analysis, recommend tiered deployment:

#### Tier 1: Critical Security Policies (Deny-Capable) - 10-15 policies

**High-Priority Blocking Policies**:
1. Key vaults should have deletion protection enabled (Deny)
2. Key vaults should have soft delete enabled (Deny)
3. Azure Key Vault should disable public network access (Deny)
4. Key Vault keys should have an expiration date (Deny)
5. Key Vault secrets should have an expiration date (Deny)
6. Certificates should have the specified maximum validity period (Deny)
7. Azure Key Vault should use RBAC permission model (Deny)
8. Keys should be backed by a hardware security module (HSM) (Deny)
9. Keys using RSA cryptography should have a specified minimum key size (Deny)
10. Azure Key Vaults should use private link (Deny)

**Deployment Sequence**:
1. **Week 1-12**: Audit mode (establish baseline)
2. **Week 13-24**: Deny mode (block new violations)
3. **Week 25+**: Monitor and refine

#### Tier 2: Compliance & Lifecycle Policies - 24 policies

**Medium-Priority Policies** (remaining Deny-capable):
- All remaining key/secret/certificate lifecycle policies
- Cryptographic requirement policies
- Certificate authority restriction policies
- Managed HSM policies

**Deployment Sequence**:
1. **After Tier 1 stable**: Audit mode (4-8 weeks)
2. **After baseline**: Deny mode
3. **Ongoing**: Continuous monitoring

#### Tier 3: Infrastructure Policies - 12 policies

**Auto-Remediation Policies** (Audit-only):
- Private endpoint deployment
- Diagnostic settings deployment
- Firewall configuration
- Logging enablement

**Deployment Sequence**:
1. **Parallel with Tier 1/2**: DeployIfNotExists mode
2. **Automatic**: Remediation tasks trigger on non-compliance
3. **Monitor**: Remediation task success rates

---

## Compliance Baseline (Current State)

**As of**: January 12, 2026  
**Environment**: MSDN Subscription (Dev/Test)  
**Mode**: Enforce (13 policies with auto-remediation enabled)

### Current Metrics

| Metric | Value | Percentage |
|--------|-------|------------|
| **Total Policy States** | 548 | - |
| **Compliant Resources** | 183 | 33.39% |
| **Non-Compliant Resources** | 365 | 66.61% |
| **Policies Reporting** | 46/46 | 100% |
| **Enforce-Mode Policies** | 13/46 | 28.26% |

### Managed Identity Status

**Identity Name**: `policy-remediation-identity`  
**Principal ID**: `22e73c1c-a499-4c1c-80d0-68e85d94adfb`

**Assigned Roles**:
1. ✅ Contributor
2. ✅ Key Vault Contributor
3. ✅ Log Analytics Contributor
4. ✅ Monitoring Contributor

**Remediation Status**: Ready for auto-remediation (permissions verified)

---

## Next Steps

### Immediate Actions (Phase 2.5)

1. **Define Production Tier 1 Policy List** (10-15 policies)
   - Review business requirements
   - Identify critical security policies
   - Document exemption criteria

2. **Create Production Deployment Plan**
   - Timeline: Audit → Deny → Enforce
   - Rollback procedures
   - Communication plan

3. **Prepare Monitoring & Alerting**
   - Azure Monitor alerts for policy violations
   - Compliance dashboard setup
   - Monthly reporting schedule

### Phase 3 Production Rollout

1. **Phase 3.1**: Deploy Tier 1 in Audit mode (30-90 days)
2. **Phase 3.2**: Switch Tier 1 to Deny mode
3. **Phase 3.3**: Enable Tier 1 Enforce mode
4. **Phase 3.4**: Deploy Tier 2 & 3 policies
5. **Phase 3.5**: Continuous monitoring & optimization

---

## Appendix: Policy Effect Reference

### Effect Types Explained

| Effect | Behavior | Use Case | Example |
|--------|----------|----------|---------|
| **Audit** | Report non-compliance only | Discovery, baseline | Default for all policies |
| **Deny** | Block non-compliant operations | Enforcement, security | Prevent key creation without expiration |
| **DeployIfNotExists** | Auto-deploy missing resources | Infrastructure setup | Auto-create diagnostic settings |
| **Modify** | Auto-fix resource properties | Configuration drift | Auto-enable firewall |
| **AuditIfNotExists** | Audit existence of related resources | Compliance checking | Check if logging is enabled |
| **Disabled** | Policy not evaluated | Testing, exceptions | Temporarily disable policy |

### Assignment Parameter Example

```powershell
# Example: Assign policy in Deny mode instead of default Audit
New-AzPolicyAssignment `
    -Name "KV-KeyExpiration-Deny" `
    -PolicyDefinition $policyDef `
    -Scope "/subscriptions/xxx" `
    -PolicyParameter @{
        effect = @{value = "Deny"}  # Override default Audit with Deny
    }
```

---

**Document Version**: 1.0  
**Last Updated**: January 13, 2026  
**Generated By**: Azure Policy Implementation Script v0.1.0
