# Azure Key Vault Secret, Certificate & Key Lifecycle Policies
## Complete Reference Matrix

---

## 📊 Policy Categories

### 🔑 Secret Management Policies (4 policies)

| Policy Name | Version | Effect | Purpose | Risk Level |
|------------|---------|--------|---------|------------|
| **Key Vault secrets should have an expiration date** | 1.0.2 | Audit, Deny, Disabled | Ensures all secrets have expiration dates set | 🔴 CRITICAL |
| **Secrets should have the specified maximum validity period** | 1.0.1 | Audit, Deny, Disabled | Limits secret lifespan (e.g., max 90 days) | 🟡 HIGH |
| **Secrets should have more than the specified number of days before expiration** | 1.0.1 | Audit, Deny, Disabled | Warns when secrets expire soon (e.g., <30 days) | 🟡 HIGH |
| **Secrets should not be active for longer than the specified number of days** | 1.0.1 | Audit, Deny, Disabled | Enforces secret rotation by age | 🟡 MEDIUM |

**Additional Secret Policy**:
- **Secrets should have content type set** (1.0.1) - Ensures secrets have metadata for identification

---

### 📜 Certificate Management Policies (8 policies)

| Policy Name | Version | Effect | Purpose | Risk Level |
|------------|---------|--------|---------|------------|
| **Certificates should have the specified maximum validity period** | 2.2.1 | Audit, Deny, Disabled | Limits certificate lifespan (e.g., max 12 months) | 🔴 CRITICAL |
| **Certificates should have the specified lifetime action triggers** | 2.1.0 | Audit, Deny, Disabled | Ensures auto-renewal configured (e.g., renew 30 days before expiry) | 🔴 CRITICAL |
| **Certificates should not expire within the specified number of days** | 2.1.1 | Audit, Deny, Disabled | Warns when certificates expire soon (e.g., <30 days) | 🟡 HIGH |
| **Certificates should be issued by the specified integrated certificate authority** | 2.1.0 | Audit, Deny, Disabled | Restricts to DigiCert or GlobalSign (Azure-integrated CAs) | 🟢 LOW |
| **Certificates should be issued by the specified non-integrated certificate authority** | 2.1.1 | Audit, Deny, Disabled | Restricts to specific non-Azure CA (e.g., Entrust, Sectigo) | 🟢 LOW |
| **Certificates should be issued by one of the specified non-integrated certificate authorities** | 1.0.1 | Audit, Deny, Disabled | Allows multiple approved non-Azure CAs | 🟢 LOW |
| **Certificates should use allowed key types** | 2.1.0 | Audit, Deny, Disabled | Restricts to RSA or EC keys | 🟢 LOW |
| **Certificates using RSA cryptography should have the specified minimum key size** | 2.1.0 | Audit, Deny, Disabled | Enforces minimum RSA key size (e.g., 2048-bit, 4096-bit) | 🟡 MEDIUM |
| **Certificates using elliptic curve cryptography should have allowed curve names** | 2.1.0 | Audit, Deny, Disabled | Restricts to secure curves (e.g., P-256, P-384, P-521) | 🟢 LOW |

---

### 🔐 Key Management Policies (8 policies)

| Policy Name | Version | Effect | Purpose | Risk Level |
|------------|---------|--------|---------|------------|
| **Key Vault keys should have an expiration date** | 1.0.2 | Audit, Deny, Disabled | Ensures all keys have expiration dates set | 🔴 CRITICAL |
| **Keys should have the specified maximum validity period** | 1.0.1 | Audit, Deny, Disabled | Limits key lifespan (e.g., max 2 years) | 🟡 HIGH |
| **Keys should have more than the specified number of days before expiration** | 1.0.1 | Audit, Deny, Disabled | Warns when keys expire soon (e.g., <90 days) | 🟡 HIGH |
| **Keys should not be active for longer than the specified number of days** | 1.0.1 | Audit, Deny, Disabled | Enforces key rotation by age | 🟡 MEDIUM |
| **Keys should have a rotation policy ensuring that their rotation is scheduled within the specified number of days after creation** | 1.0.0 | Audit, Deny, Disabled | Enforces automatic key rotation policies | 🟡 HIGH |
| **Keys should be backed by a hardware security module (HSM)** | 1.0.1 | Audit, Deny, Disabled | Requires HSM-backed keys for enhanced security | 🟡 MEDIUM |
| **Keys should be the specified cryptographic type RSA or EC** | 1.0.1 | Audit, Deny, Disabled | Restricts key types to RSA or EC | 🟢 LOW |
| **Keys using RSA cryptography should have a specified minimum key size** | 1.0.1 | Audit, Deny, Disabled | Enforces minimum RSA key size (e.g., 2048-bit) | 🟡 MEDIUM |
| **Keys using elliptic curve cryptography should have the specified curve names** | 1.0.1 | Audit, Deny, Disabled | Restricts to secure curves (e.g., P-256, P-384, P-521) | 🟢 LOW |

---

### 🔒 Managed HSM Policies (4 policies - Preview)

| Policy Name | Version | Effect | Purpose |
|------------|---------|--------|---------|
| **[Preview]: Azure Key Vault Managed HSM keys should have an expiration date** | 1.0.1-preview | Audit, Deny, Disabled | HSM key expiration enforcement |
| **[Preview]: Azure Key Vault Managed HSM Keys should have more than the specified number of days before expiration** | 1.0.1-preview | Audit, Deny, Disabled | HSM key expiration warnings |
| **[Preview]: Azure Key Vault Managed HSM keys using RSA cryptography should have a specified minimum key size** | 1.0.1-preview | Audit, Deny, Disabled | HSM RSA key size enforcement |
| **[Preview]: Azure Key Vault Managed HSM keys using elliptic curve cryptography should have the specified curve names** | 1.0.1-preview | Audit, Deny, Disabled | HSM EC key curve restrictions |

---

## 🚨 Critical Policies for Production Deployment

### Immediate Priority (Deploy First)

These 3 policies prevent the most common production outages:

1. **Key Vault secrets should have an expiration date** (Audit mode)
   - **Why**: Prevents secrets from being created without expiration
   - **Impact**: 2,156 vaults need monitoring
   - **Deployment**: [SECRET-CERTIFICATE-MANAGEMENT-ANALYSIS.md](SECRET-CERTIFICATE-MANAGEMENT-ANALYSIS.md)

2. **Secrets should have more than the specified number of days before expiration** (Audit mode)
   - **Why**: Provides early warning (30 days) before expiration
   - **Impact**: Prevents service outages from expired API keys, connection strings
   - **Parameter**: `minimumDaysBeforeExpiration: 30`

3. **Certificates should have the specified maximum validity period** (Audit mode)
   - **Why**: Enforces 12-month certificate lifespans (industry best practice)
   - **Impact**: Prevents SSL/TLS outages
   - **Parameter**: `maximumValidityInMonths: 12`

---

## 📋 Policy Matrix by Use Case

### Use Case 1: Prevent Expired Secrets/Certificates (HIGH PRIORITY)

**Goal**: Avoid production outages from expired credentials

| Object Type | Policy | Effect | Parameters |
|------------|--------|--------|------------|
| Secrets | Key Vault secrets should have an expiration date | Audit | None |
| Secrets | Secrets should have more than X days before expiration | Audit | minimumDaysBeforeExpiration: 30 |
| Certificates | Certificates should not expire within X days | Audit | daysToExpire: 30 |
| Keys | Key Vault keys should have an expiration date | Audit | None |
| Keys | Keys should have more than X days before expiration | Audit | minimumDaysBeforeExpiration: 90 |

**Deployment File**: `PolicyParameters-Production-ExpirationMonitoring.json`

---

### Use Case 2: Enforce Short Credential Lifespans (MEDIUM PRIORITY)

**Goal**: Limit blast radius of compromised credentials

| Object Type | Policy | Effect | Parameters |
|------------|--------|--------|------------|
| Secrets | Secrets should have the specified maximum validity period | Deny | maximumValidityInDays: 90 |
| Certificates | Certificates should have the specified maximum validity period | Deny | maximumValidityInMonths: 12 |
| Keys | Keys should have the specified maximum validity period | Deny | maximumValidityInDays: 730 (2 years) |

**Use Case**: Applications with high security requirements (PCI-DSS, HIPAA, FedRAMP)

---

### Use Case 3: Enforce Automatic Rotation (ADVANCED)

**Goal**: Eliminate manual rotation tasks

| Object Type | Policy | Effect | Parameters |
|------------|--------|--------|------------|
| Keys | Keys should have a rotation policy ensuring rotation is scheduled within X days | Audit | maximumDaysToRotate: 90 |
| Certificates | Certificates should have the specified lifetime action triggers | Audit | minimumDaysBeforeExpiry: 30 |

**Note**: Requires Azure Key Vault rotation policies configured on vaults

---

### Use Case 4: Cryptographic Compliance (SECURITY)

**Goal**: Meet cryptographic standards (NIST, FIPS, SOC2)

| Object Type | Policy | Effect | Parameters |
|------------|--------|--------|------------|
| Keys (RSA) | Keys using RSA cryptography should have a specified minimum key size | Deny | minimumRSAKeySize: 2048 (or 4096 for high-security) |
| Keys (EC) | Keys using elliptic curve cryptography should have the specified curve names | Deny | allowedECNames: ["P-256", "P-384", "P-521"] |
| Certificates (RSA) | Certificates using RSA cryptography should have the specified minimum key size | Deny | minimumRSAKeySize: 2048 |
| Certificates (EC) | Certificates using elliptic curve cryptography should have allowed curve names | Deny | allowedECNames: ["P-256", "P-384", "P-521"] |
| Keys | Keys should be backed by a hardware security module (HSM) | Audit | None |

**Use Case**: Government, healthcare, financial services with strict compliance requirements

---

## 🎯 Recommended Deployment Strategy

### Phase 1: Audit Mode (Week 1-2)
Deploy all expiration policies in **Audit** mode to:
- Assess current compliance posture
- Identify vaults with expired secrets/certs
- Measure scope of remediation needed

**Policies**:
- Key Vault secrets should have an expiration date (Audit)
- Certificates should not expire within 30 days (Audit)
- Keys should have an expiration date (Audit)

### Phase 2: Expiration Warnings (Week 3-4)
Add advanced warning policies:
- Secrets should have more than 30 days before expiration (Audit)
- Keys should have more than 90 days before expiration (Audit)

### Phase 3: Enforcement (Month 2)
Switch to **Deny** mode for new resources:
- Key Vault secrets should have an expiration date (Deny)
- Certificates should have maximum 12-month validity (Deny)

### Phase 4: Rotation Automation (Month 3)
Implement rotation policies:
- Keys should have a rotation policy (Audit)
- Certificates should have lifetime action triggers (Audit)

---

## 📊 Current Deployment Status (AAD Environment)

**From [SECRET-CERTIFICATE-MANAGEMENT-ANALYSIS.md](SECRET-CERTIFICATE-MANAGEMENT-ANALYSIS.md)**:

| Category | Available Policies | Deployed Policies | Coverage |
|----------|-------------------|-------------------|----------|
| Secrets | 4 | **0** | ❌ 0% |
| Certificates | 8 | **0** | ❌ 0% |
| Keys | 8 | **0** | ❌ 0% |
| **TOTAL** | **20** | **0** | **❌ 0%** |

**Risk Assessment**: 🔴 **CRITICAL** - 2,156 Key Vaults with zero secret/certificate/key lifecycle monitoring

---

## 🛠️ Deployment Commands

### Deploy Expiration Monitoring (Phase 1)

```powershell
# Get managed identity
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# Deploy secret/certificate/key expiration policies
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-ExpirationMonitoring.json `
    -PolicyMode Audit `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck
```

### Check Compliance

```powershell
# Wait 30 minutes for Azure Policy evaluation, then check compliance
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan

# Generate HTML report
# Report will show which vaults have secrets/certs without expiration
```

---

## 📖 Additional Resources

- **Azure Policy Documentation**: https://learn.microsoft.com/azure/key-vault/general/policy-reference
- **Key Vault Best Practices**: https://learn.microsoft.com/azure/key-vault/general/best-practices
- **Secret Management**: [SECRET-CERTIFICATE-MANAGEMENT-ANALYSIS.md](SECRET-CERTIFICATE-MANAGEMENT-ANALYSIS.md)
- **Deployment Guide**: [AUTO-REMEDIATION-GUIDE.md](AUTO-REMEDIATION-GUIDE.md)
- **Parameter Files**: [PARAMETER-FILE-USAGE-GUIDE.md](PARAMETER-FILE-USAGE-GUIDE.md)

---

**Document Created**: January 29, 2026  
**Total Policies**: 30 secret/certificate/key lifecycle policies (8 secrets + 9 certs + 13 keys)  
**Deployment Priority**: 🔴 CRITICAL (0% coverage across 2,156 vaults)  
**Next Action**: Deploy Phase 1 expiration monitoring policies this week
