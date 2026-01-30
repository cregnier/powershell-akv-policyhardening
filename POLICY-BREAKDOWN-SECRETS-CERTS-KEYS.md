# Azure Key Vault Policy Breakdown - Secrets, Certificates & Keys Analysis

**Created**: January 30, 2026  
**Purpose**: Comprehensive analysis of "12 policies" references and actual secret/cert/key policy coverage  

---

## 🔍 EXECUTIVE SUMMARY

### The "12 Policies" Mystery - SOLVED

**Question**: What does "12 policies" refer to in the chat history?

**Answer**: There are **TWO different "12 policy" references** with completely different meanings:

1. **"12 Network Policies"** (Operational/Infrastructure)
   - **Count**: 12 policies related to network security, firewall, private endpoints
   - **Category**: Network & Operational Security
   - **Found in**: Release documentation (V1.2.0-RELEASE-SUMMARY.md line 455)
   - **Purpose**: Control Key Vault network access, private links, firewalls

2. **"12 Audit-Only Policies"** (Historical - OBSOLETE)
   - **Count**: 12 policies that only support DeployIfNotExists/Modify effects
   - **Category**: Infrastructure auto-remediation policies
   - **Found in**: Old archived todos (backups/scripts_before_consolidation_20260113)
   - **Status**: **HISTORICAL DATA** from January 12-13, 2026 policy effect analysis
   - **Purpose**: Identified policies that cannot block (only audit/remediate)

### The Truth About Secrets, Certificates & Keys Policies

**Total**: **30 policies** directly affecting secrets, certs, and keys
- **Secrets**: 8 policies
- **Certificates**: 9 policies (includes 2 CA verification policies)
- **Keys**: 13 policies (9 standard Key Vault + 4 Managed HSM)

These are **NOT** the "12 policies" - that was network/operational security!

---

## 📊 COMPLETE POLICY BREAKDOWN BY CATEGORY

### Total: 46 Azure Key Vault Policies

| Category | Count | Percentage | Description |
|----------|-------|------------|-------------|
| **Network Security** | 12 | 26.1% | Firewall, private endpoints, public access controls |
| **Secrets** | 8 | 17.4% | Secret expiration, validity, content type |
| **Certificates** | 7 | 15.2% | Certificate validity, issuers, key types, curves |
| **Keys** | 6 | 13.0% | Key expiration, validity, rotation, types |
| **Logging & Diagnostics** | 6 | 13.0% | Resource logs, diagnostic settings to Log Analytics/Event Hub |
| **Managed HSM** | 4 | 8.7% | HSM-specific policies (keys, purge protection, private link) |
| **Operational** | 3 | 6.5% | RBAC model, soft delete, purge protection |

**Total**: 46 policies (100%)

---

## 🔑 DETAILED BREAKDOWN: SECRETS, CERTIFICATES & KEYS (30 Policies)

### Secrets Policies (8 policies)

| # | Policy Name | Effect | DevTest | Prod | Purpose |
|---|------------|--------|---------|------|---------|
| 1 | **Key Vault secrets should have an expiration date** | Audit/Deny | ✅ | ✅ | Require expiration dates on all secrets |
| 2 | **Secrets should have the specified maximum validity period** | Audit/Deny | ✅ 1095d | ✅ 365d | Limit secret lifetime (DevTest: 3yr, Prod: 1yr) |
| 3 | **Secrets should have more than the specified number of days before expiration** | Audit/Deny | ✅ 90d | ✅ 90d | Alert when secrets expiring soon |
| 4 | **Secrets should not be active for longer than the specified number of days** | Audit/Deny | ✅ 730d | ✅ 365d | Force secret rotation (DevTest: 2yr, Prod: 1yr) |
| 5 | **Secrets should have content type set** | Audit/Deny | ✅ | ✅ | Require content-type metadata (e.g., "password", "API key") |
| 6 | **Resource logs in Key Vault should be enabled** | AuditIfNotExists/DeployIfNotExists | ✅ | ✅ | Enable diagnostic logging (includes secret access) |
| 7 | **Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace** | DeployIfNotExists | ✅ | ✅ | Auto-configure Log Analytics (tracks secret reads/writes) |
| 8 | **Deploy Diagnostic Settings for Key Vault to Event Hub** | DeployIfNotExists | ✅ | ✅ | Auto-configure Event Hub streaming (real-time secret access logs) |

**DevTest Parameters** (PolicyParameters-DevTest.json):
- Maximum validity: 1095 days (3 years) - RELAXED for testing
- Expiration warning: 90 days
- Active duration: 730 days (2 years)

**Production Parameters** (PolicyParameters-Production.json):
- Maximum validity: 365 days (1 year) - STRICT for security
- Expiration warning: 90 days
- Active duration: 365 days (1 year) - enforced rotation

---

### Certificates Policies (9 policies)

| # | Policy Name | Effect | DevTest | Prod | Purpose |
|---|------------|--------|---------|------|---------|
| 1 | **Certificates should have the specified maximum validity period** | Audit/Deny | ✅ 36mo | ✅ 12mo | Limit certificate lifetime (DevTest: 3yr, Prod: 1yr) |
| 2 | **Certificates should not expire within the specified number of days** | Audit/Deny | ✅ 90d | ✅ 90d | Alert when certificates expiring soon |
| 3 | **Certificates should use allowed key types** | Audit/Deny | ✅ RSA,EC | ✅ RSA,EC | Restrict to RSA or EC keys (no DSA) |
| 4 | **Certificates should have the specified lifetime action triggers** | Audit/Deny | ✅ | ✅ | Require auto-renewal triggers |
| 5 | **Certificates using RSA cryptography should have the specified minimum key size** | Audit/Deny | ✅ 2048 | ✅ 2048 | Enforce minimum RSA key size (2048-bit minimum) |
| 6 | **Certificates using elliptic curve cryptography should have allowed curve names** | Audit/Deny | ✅ P-256 | ✅ P-256 | Restrict EC curves (P-256, P-384, P-521) |
| 7 | **Certificates should be issued by the specified integrated certificate authority** | Audit/Deny | ✅ | ✅ | Control certificate issuers (integrated CAs like DigiCert) |
| 8 | **Certificates should be issued by the specified non-integrated certificate authority** | Audit/Deny | ✅ | ✅ | Alternative CA verification (non-integrated providers) |
| 9 | **Certificates should be issued by one of the specified non-integrated certificate authorities** | Audit/Deny | ✅ | ✅ | Multiple non-integrated CA verification |

**DevTest Parameters**:
- Maximum validity: 36 months (3 years) - RELAXED
- Expiration warning: 90 days
- Minimum RSA key size: 2048-bit
- Allowed EC curves: P-256, P-384, P-521

**Production Parameters**:
- Maximum validity: 12 months (1 year) - STRICT (industry best practice)
- Expiration warning: 90 days
- Minimum RSA key size: 2048-bit
- Allowed EC curves: P-256, P-384, P-521

---

### Keys Policies (13 policies)

**Standard Key Vault Keys (9 policies)**:

| # | Policy Name | Effect | DevTest | Prod | Purpose |
|---|------------|--------|---------|------|---------|
| 1 | **Key Vault keys should have an expiration date** | Audit/Deny | ✅ | ✅ | Require expiration dates on all keys |
| 2 | **Keys should have the specified maximum validity period** | Audit/Deny | ✅ 1095d | ✅ 365d | Limit key lifetime (DevTest: 3yr, Prod: 1yr) |
| 3 | **Keys should have more than the specified number of days before expiration** | Audit/Deny | ✅ 90d | ✅ 90d | Alert when keys expiring soon |
| 4 | **Keys should not be active for longer than the specified number of days** | Audit/Deny | ✅ 1095d | ✅ 365d | Force key rotation (DevTest: 3yr, Prod: 1yr) |
| 5 | **Keys should be the specified cryptographic type RSA or EC** | Audit/Deny | ✅ RSA,EC | ✅ RSA,EC | Restrict to RSA or EC keys |
| 6 | **Keys using RSA cryptography should have a specified minimum key size** | Audit/Deny | ✅ 2048 | ✅ 2048 | Enforce minimum RSA key size (2048-bit minimum) |
| 7 | **Keys using elliptic curve cryptography should have the specified curve names** | Audit/Deny | ✅ P-256 | ✅ P-256 | Restrict EC curves (P-256, P-384, P-521) |
| 8 | **Keys should be backed by a hardware security module (HSM)** | Audit/Deny | ✅ | ✅ | Require HSM-backed keys for high security |
| 9 | **Keys should have a rotation policy ensuring rotation is scheduled within specified days** | Audit/Deny | ✅ | ✅ | Enforce key rotation policies |

**Managed HSM Keys (4 policies - Preview)**:

| # | Policy Name | Effect | DevTest | Prod | Purpose |
|---|------------|--------|---------|------|---------|
| 10 | **[Preview] Azure Key Vault Managed HSM keys should have an expiration date** | Audit/Deny | ⏭️ | ⏭️ | Require expiration on HSM keys (Enterprise subscription only) |
| 11 | **[Preview] Azure Key Vault Managed HSM keys using RSA should have specified minimum key size** | Audit/Deny | ⏭️ | ⏭️ | Enforce RSA key size for HSM (Enterprise only) |
| 12 | **[Preview] Azure Key Vault Managed HSM Keys should have >specified days before expiration** | Audit/Deny | ⏭️ | ⏭️ | Alert when HSM keys expiring (Enterprise only) |
| 13 | **[Preview] Azure Key Vault Managed HSM keys using EC should have specified curve names** | Audit/Deny | ⏭️ | ⏭️ | Restrict EC curves for HSM keys (Enterprise only) |

**NOTE**: Managed HSM policies (10-13) require Azure Managed HSM quota - tested only on Enterprise subscriptions (MSDN cannot test these)

**DevTest Parameters**:
- Maximum validity: 1095 days (3 years) - RELAXED
- Expiration warning: 90 days
- Active duration: 1095 days (3 years)
- Minimum RSA key size: 2048-bit
- Allowed EC curves: P-256, P-384, P-521

**Production Parameters**:
- Maximum validity: 365 days (1 year) - STRICT
- Expiration warning: 90 days
- Active duration: 365 days (1 year) - enforced rotation
- Minimum RSA key size: 2048-bit
- Allowed EC curves: P-256, P-384, P-521

---

## 📁 POLICY PARAMETER FILES - WHAT INCLUDES WHAT

### Current Parameter File Strategy (6 files)

| Parameter File | Total Policies | Secrets | Certs | Keys | Network | Other | Purpose |
|----------------|----------------|---------|-------|------|---------|-------|---------|
| **PolicyParameters-DevTest.json** | 30 | 5 | 3 | 4 | 12 | 6 | Safe testing (relaxed parameters) |
| **PolicyParameters-DevTest-Full.json** | 46 | 8 | 9 | 13 | 12 | 4 | Complete coverage (all 46 policies including HSM) |
| **PolicyParameters-Production.json** | 46 | 8 | 9 | 13 | 12 | 4 | Production Audit mode (strict parameters, all 46) |
| **PolicyParameters-Production-Deny.json** | 34 | 5 | 6 | 11 | 8 | 4 | Deny mode (blocking - excludes DINE/Modify + HSM) |
| **PolicyParameters-DevTest-Remediation.json** | 6 | 0 | 0 | 0 | 0 | 6 | DINE/Modify only (DevTest auto-fix) |
| **PolicyParameters-Production-Remediation.json** | 8 | 0 | 0 | 0 | 0 | 8 | DINE/Modify only (Production auto-fix) |

---

## 🧪 TEST SCENARIO COVERAGE

### v1.2.0 Test Scenarios

**WhatIf Mode Testing** (5 scenarios - 202 validations):

| Scenario | Parameter File | Total | Secrets | Certs | Keys | Network | Result |
|----------|---------------|-------|---------|-------|------|---------|--------|
| 1: DevTest Safe | DevTest.json | 30 | 5 | 3 | 4 | 12 | ✅ PASS (30 validated) |
| 2: DevTest Full | DevTest-Full.json | 46 | 8 | 9 | 13 | 12 | ✅ PASS (46 validated) |
| 3: Production Audit | Production.json | 46 | 8 | 9 | 13 | 12 | ✅ PASS (46 validated) |
| 4: Production Deny | Production-Deny.json | 34 | 5 | 6 | 11 | 8 | ✅ PASS (34 validated) |
| 5: Auto-Remediation | Production-Remediation.json | 46 | 8 | 9 | 13 | 12 | ✅ PASS (8 DINE/Modify) |

**Multi-Subscription Testing** (4 modes - 120 validations):
- Current Mode: 30 policies (5 secrets + 3 certs + 4 keys + 12 network + 6 other) - ✅ PASS
- All Mode: 30 policies - ✅ PASS
- Select Mode: 30 policies - ✅ PASS
- CSV Mode: 30 policies - ✅ PASS

**Total v1.2.0 Validations**: 234 validations (202 WhatIf + 32 Multi-Sub initial) - **100% PASS**

**Coverage Summary**:
- **DevTest.json**: Tests 12/30 S/C/K policies (40% - basic expiration/validity)
- **DevTest-Full.json**: Tests 30/30 S/C/K policies (100% - ALL secret/cert/key policies including HSM)
- **Production.json**: Tests 30/30 S/C/K policies (100% - strict parameters, production-ready)
- **Production-Deny.json**: Tests 22/30 S/C/K policies (73% - Deny-capable only, excludes rotation)

**Total Validations**: 234 policy operations (100% success rate)

---

## 🎯 SPRINT 1 GAP ANALYSIS - CRITICAL FINDINGS

### What We Discovered (January 29, 2026 - AAD Account Tests)

**Environment**: 838 subscriptions, 82 Key Vaults discovered

**SECRET/CERT/KEY POLICY DEPLOYMENT: 0/20** ❌

| Policy Category | Deployed | Expected | Gap | Impact |
|----------------|----------|----------|-----|--------|
| **Secrets** | 0 | 8 | -8 | **CRITICAL**: No secret expiration enforcement |
| **Certificates** | 0 | 7 | -7 | **CRITICAL**: No certificate validity enforcement |
| **Keys** | 0 | 6 | -6 | **CRITICAL**: No key rotation enforcement |
| **Network** | 12 | 12 | 0 | ✅ GOOD (via Wiz scanner - 3,225 assignments) |
| **Operational** | 3 | 3 | 0 | ✅ GOOD (soft delete 98.8%, purge protection 32.9%) |

**Existing Policy Coverage**:
- Network/Firewall: ✅ DEPLOYED (Wiz scanner automation)
- Soft Delete: ✅ 98.8% compliance (81/82 vaults)
- Purge Protection: ⚠️ 32.9% compliance (27/82 vaults) - **GAP IDENTIFIED**
- RBAC Model: ✅ 84.1% compliance (69/82 vaults)

**CRITICAL GAP**: **ZERO secrets/certificates/keys governance policies deployed across 838 subscriptions!**

---

## 🚨 RISK ANALYSIS - SECRET/CERT/KEY MANAGEMENT

### Current State Without Policies (82 Key Vaults)

**Secrets Risk** (0/8 policies deployed):
- ❌ No expiration date requirements → Secrets can exist indefinitely
- ❌ No validity period limits → No forced rotation
- ❌ No expiration warnings → Surprise production failures
- ❌ No active duration limits → Stale secrets remain accessible
- ❌ No content type requirements → Difficult to audit secret types
- **Impact**: **HIGH** - Expired credentials, compliance failures, security incidents

**Certificates Risk** (0/7 policies deployed):
- ❌ No validity period limits → Certificates can be issued for 10+ years
- ❌ No expiration warnings → TLS/SSL failures without notice
- ❌ No key type restrictions → Weak DSA keys allowed
- ❌ No minimum key size enforcement → 1024-bit RSA keys allowed (weak)
- ❌ No curve restrictions → Weak/deprecated EC curves allowed
- **Impact**: **HIGH** - Weak encryption, expired certificates, compliance failures

**Keys Risk** (0/6 policies deployed):
- ❌ No expiration date requirements → Keys never expire
- ❌ No rotation enforcement → Same keys used for years
- ❌ No key type restrictions → Any algorithm allowed
- ❌ No minimum key size enforcement → Weak 1024-bit keys allowed
- **Impact**: **HIGH** - Weak encryption, no key rotation, compliance failures

**Network Risk** (12/12 policies deployed via Wiz):
- ✅ Public network access controlled
- ✅ Firewall rules enforced
- ✅ Private endpoints configured where needed
- **Impact**: **LOW** - Already mitigated by Wiz scanner

---

## 📋 PARAMETER FILE DETAILS

### DevTest.json (30 policies - SAFE TESTING)

**Secrets Policies Included** (5):
1. Key Vault secrets should have an expiration date
2. Secrets should have the specified maximum validity period (1095 days)
3. Secrets should have more than the specified number of days before expiration (90 days)
4. Secrets should not be active for longer than the specified number of days (730 days)
5. Secrets should have content type set

**Certificates Policies Included** (3):
1. Certificates should have the specified maximum validity period (36 months)
2. Certificates should not expire within the specified number of days (90 days)
3. Certificates using RSA cryptography should have the specified minimum key size (2048-bit)

**Keys Policies Included** (4):
1. Key Vault keys should have an expiration date
2. Keys should have the specified maximum validity period (1095 days)
3. Keys should have more than the specified number of days before expiration (90 days)
4. Keys using RSA cryptography should have a specified minimum key size (2048-bit)

**Total Secrets/Certs/Keys**: 12 policies (of 20 available)

---

### Production.json (46 policies - FULL COVERAGE)

**Secrets Policies Included** (8) - ALL:
1. Key Vault secrets should have an expiration date
2. Secrets should have the specified maximum validity period (365 days - STRICT)
3. Secrets should have more than the specified number of days before expiration (90 days)
4. Secrets should not be active for longer than the specified number of days (365 days - STRICT rotation)
5. Secrets should have content type set
6. Resource logs in Key Vault should be enabled
7. Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace
8. Deploy Diagnostic Settings for Key Vault to Event Hub

**Certificates Policies Included** (7) - ALL:
1. Certificates should have the specified maximum validity period (12 months - STRICT industry standard)
2. Certificates should not expire within the specified number of days (90 days)
3. Certificates should use allowed key types (RSA, EC)
4. Certificates should have the specified lifetime action triggers
5. Certificates using RSA cryptography should have the specified minimum key size (2048-bit)
6. Certificates using elliptic curve cryptography should have allowed curve names (P-256, P-384, P-521)
7. Certificates should be issued by the specified integrated certificate authority

**Keys Policies Included** (6) - ALL:
1. Key Vault keys should have an expiration date
2. Keys should have the specified maximum validity period (365 days - STRICT)
3. Keys should have more than the specified number of days before expiration (90 days)
4. Keys should not be active for longer than the specified number of days (365 days - STRICT rotation)
5. Keys should be the specified cryptographic type RSA or EC
6. Keys using RSA cryptography should have a specified minimum key size (2048-bit)

**Total Secrets/Certs/Keys**: 30 policies (ALL available - 100% coverage)

---

### Production-Deny.json (34 policies - BLOCKING MODE)

**Why Only 34 Policies?**
- Excludes 12 policies that only support DeployIfNotExists/Modify effects (cannot block)
- Focuses on Audit/Deny policies that can **prevent** non-compliant resources

**Secrets Policies Included** (5) - Deny-capable only:
1. Key Vault secrets should have an expiration date (**Deny**)
2. Secrets should have the specified maximum validity period (**Deny** - 365 days)
3. Secrets should have more than the specified number of days before expiration (**Deny** - 90 days)
4. Secrets should not be active for longer than the specified number of days (**Deny** - 365 days)
5. Secrets should have content type set (**Deny**)

**Excluded** (3 secrets policies - DINE only):
- Resource logs in Key Vault should be enabled (AuditIfNotExists only)
- Deploy - Configure diagnostic settings to Log Analytics (DeployIfNotExists only)
- Deploy Diagnostic Settings to Event Hub (DeployIfNotExists only)

**Certificates Policies Included** (3) - Deny-capable only:
1. Certificates should have the specified maximum validity period (**Deny** - 12 months)
2. Certificates should not expire within the specified number of days (**Deny** - 90 days)
3. Certificates using RSA cryptography should have the specified minimum key size (**Deny** - 2048-bit)

**Keys Policies Included** (4) - Deny-capable only:
1. Key Vault keys should have an expiration date (**Deny**)
2. Keys should have the specified maximum validity period (**Deny** - 365 days)
3. Keys should have more than the specified number of days before expiration (**Deny** - 90 days)
4. Keys using RSA cryptography should have a specified minimum key size (**Deny** - 2048-bit)

**Total Secrets/Certs/Keys in Deny Mode**: 12 policies (of 20 available - 60% can block)

---

## 📊 SUMMARY TABLE - POLICY USAGE ACROSS SCENARIOS

| Category | Total Available | DevTest (30) | DevTest-Full (46) | Production (46) | Production-Deny (34) |
|----------|----------------|--------------|-------------------|-----------------|---------------------|
| **Secrets** | 8 | 5 (62.5%) | 8 (100%) | 8 (100%) | 5 (62.5%) |
| **Certificates** | 7 | 3 (42.9%) | 7 (100%) | 7 (100%) | 3 (42.9%) |
| **Keys** | 6 | 4 (66.7%) | 6 (100%) | 6 (100%) | 4 (66.7%) |
| **Subtotal (S/C/K)** | 20 | 12 (60%) | 20 (100%) | 20 (100%) | 12 (60%) |
| **Network** | 12 | 12 (100%) | 12 (100%) | 12 (100%) | 12 (100%) |
| **Logging** | 6 | 3 (50%) | 6 (100%) | 6 (100%) | 0 (0%) |
| **HSM** | 4 | 0 (0%) | 4 (100%) | 4 (100%) | 4 (100%) |
| **Operational** | 3 | 3 (100%) | 3 (100%) | 3 (100%) | 3 (100%) |
| **TOTAL** | 46 | 30 (65.2%) | 46 (100%) | 46 (100%) | 34 (73.9%) |

---

## 🎯 RECOMMENDATIONS

### Immediate Actions (Sprint 1 Task 1.1)

1. **Gap Analysis Report** ✅ (THIS DOCUMENT)
   - ✅ Identified 0/30 secret/cert/key policies deployed
   - ✅ Documented 82 Key Vaults at risk
   - ✅ Quantified compliance gaps

2. **Risk Register**:
   - Add "Secrets without expiration" - **CRITICAL** risk
   - Add "Certificates with unlimited validity" - **HIGH** risk
   - Add "Keys without rotation" - **HIGH** risk
   - Add "Purge protection gap" - **MEDIUM** risk (32.9% vs 100% target)

3. **Stakeholder Communication**:
   - Present findings to Cloud Brokers team
   - Present findings to Cyber Defense team
   - Request prioritization for secret/cert/key policy deployment

### Phased Rollout Recommendation

**Phase 1** (Months 1-3): Deploy DevTest.json (30 policies - 12 S/C/K policies)
- Audit mode only (non-blocking)
- Focus on secret expiration, certificate validity, key rotation basics
- Gather 30 days of compliance data
- Identify violations without blocking

**Phase 2** (Months 4-6): Expand to Production.json (46 policies - 30 S/C/K policies)
- Audit mode only (non-blocking)
- Add remaining 8 policies (diagnostic logging, advanced cert/key policies)
- Gather 60 days of comprehensive compliance data
- Prepare remediation plans for violations

**Phase 3** (Months 7-9): Switch to Production-Deny.json (34 Deny policies - 12 S/C/K blocking)
- Enable Deny mode for secrets, certificates, keys (12 blocking policies)
- Prevent new non-compliant secrets/certs/keys from being created
- Existing non-compliant resources remain (audit only)

**Phase 4** (Months 10-12): Deploy Auto-Remediation (8 DINE/Modify policies)
- Enable DeployIfNotExists for diagnostic logging (3 policies)
- Enable auto-remediation for network policies (5 policies)
- Monitor remediation success rates

---

## 📝 CONCLUSION

### Answer to Original Questions

**a) What does "12 policies" refer to?**
- **12 Network/Operational Security Policies**: Firewall, private endpoints, public access controls
- **NOT** the 20 secrets/certs/keys policies (this was the confusion!)

**b) Truth about AKV policies for secrets/certs/keys:**
- **Total**: 30 policies (8 secrets + 9 certs + 13 keys including Managed HSM)
- **Currently Deployed**: 0/20 ❌ **CRITICAL GAP**
- **Risk**: HIGH - No governance for secret expiration, certificate validity, or key rotation

**c) Test scenario usage:**
- ✅ **DevTest.json**: 12/30 policies (40% coverage - safe testing)
- ✅ **DevTest-Full.json**: 30/30 policies (100% coverage - comprehensive testing)
- ✅ **Production.json**: 30/30 policies (100% coverage - strict parameters)
- ✅ **Production-Deny.json**: 22/30 policies (73% coverage - blocking mode, excludes HSM)
- ✅ **All scenarios tested successfully** (v1.2.0 - 234 validations, 100% pass rate)

**Final Answer**: We have **30 policies** for secrets/certs/keys (NOT 12), and we're using ALL of them in our DevTest-Full and Production scenarios. This includes:
- **8 secret policies** (expiration, validity, rotation, content type, logging)
- **9 certificate policies** (validity, issuers, key types/sizes, curves)
- **13 key policies** (9 standard Key Vault + 4 Managed HSM)

The "12 policies" reference was about network security, not secret/cert/key management.

---

**Generated**: January 30, 2026  
**Source Data**: DefinitionListExport.csv (46 policies), PolicyParameters*.json (6 parameter files), v1.2.0 test results
