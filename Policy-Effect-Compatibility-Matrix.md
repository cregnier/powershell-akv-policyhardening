# Azure Key Vault Policy Effect Compatibility Matrix

**Source**: [Microsoft Learn - Azure Policy Built-in Definitions for Key Vault](https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies#key-vault)  
**Last Updated**: January 22, 2026  
**Purpose**: Quick reference for which policies support Audit, Deny, DeployIfNotExists, Modify effects

---

## Executive Summary

**Total Policies**: 46  
**Audit-Compatible**: 46 (100%)  
**Deny-Compatible**: 35 (76%)  
**DeployIfNotExists-Compatible**: 8 (17%)  
**Modify-Compatible**: 2 (4%)  
**AuditIfNotExists-Compatible**: 2 (4%)

---

## Effect Compatibility Matrix

### Legend
- ✅ = Supported
- ❌ = Not Supported
- 🔹 = Primary recommended effect

| # | Policy Display Name | Audit | Deny | DINE* | Modify | AuditIfNotExists | Disabled |
|---|---------------------|:-----:|:----:|:-----:|:------:|:----------------:|:--------:|
| **MANAGED HSM POLICIES (8)** |
| 1 | [Preview]: Azure Key Vault Managed HSM keys should have an expiration date | ✅ | ✅🔹 | ❌ | ❌ | ❌ | ✅ |
| 2 | [Preview]: Azure Key Vault Managed HSM Keys should have more than the specified number of days before expiration | ✅🔹 | ✅ | ❌ | ❌ | ❌ | ✅ |
| 3 | [Preview]: Azure Key Vault Managed HSM keys using elliptic curve cryptography should have the specified curve names | ✅🔹 | ✅ | ❌ | ❌ | ❌ | ✅ |
| 4 | [Preview]: Azure Key Vault Managed HSM keys using RSA cryptography should have a specified minimum key size | ✅ | ✅🔹 | ❌ | ❌ | ❌ | ✅ |
| 5 | [Preview]: Azure Key Vault Managed HSM should disable public network access | ✅ | ✅🔹 | ❌ | ❌ | ❌ | ✅ |
| 6 | [Preview]: Azure Key Vault Managed HSM should use private link | ✅🔹 | ❌ | ❌ | ❌ | ❌ | ✅ |
| 7 | [Preview]: Configure Azure Key Vault Managed HSM to disable public network access | ❌ | ❌ | ❌ | ✅🔹 | ❌ | ✅ |
| 8 | [Preview]: Configure Azure Key Vault Managed HSM with private endpoints | ❌ | ❌ | ✅🔹 | ❌ | ❌ | ✅ |
| **KEY VAULT CONFIGURATION (10)** |
| 9 | Azure Key Vault Managed HSM should have purge protection enabled | ✅ | ✅🔹 | ❌ | ❌ | ❌ | ✅ |
| 10 | Azure Key Vault should disable public network access | ✅ | ✅🔹 | ❌ | ❌ | ❌ | ✅ |
| 11 | Azure Key Vault should have firewall enabled or public network access disabled | ✅ | ✅🔹 | ❌ | ❌ | ❌ | ✅ |
| 12 | Azure Key Vault should use RBAC permission model | ✅ | ✅🔹 | ❌ | ❌ | ❌ | ✅ |
| 13 | Azure Key Vaults should use private link | ✅🔹 | ✅ | ❌ | ❌ | ❌ | ✅ |
| 14 | Configure Azure Key Vaults to use private DNS zones | ❌ | ❌ | ✅🔹 | ❌ | ❌ | ✅ |
| 15 | Configure Azure Key Vaults with private endpoints | ❌ | ❌ | ✅🔹 | ❌ | ❌ | ✅ |
| 16 | Configure key vaults to enable firewall | ❌ | ❌ | ❌ | ✅🔹 | ❌ | ✅ |
| 17 | Key vaults should have deletion protection enabled | ✅ | ✅🔹 | ❌ | ❌ | ❌ | ✅ |
| 18 | Key vaults should have soft delete enabled | ✅ | ✅🔹 | ❌ | ❌ | ❌ | ✅ |
| **CERTIFICATE POLICIES (9)** |
| 19 | Certificates should be issued by one of the specified non-integrated certificate authorities | ✅🔹 | ✅ | ❌ | ❌ | ❌ | ✅ |
| 20 | Certificates should be issued by the specified integrated certificate authority | ✅ | ✅🔹 | ❌ | ❌ | ❌ | ✅ |
| 21 | Certificates should be issued by the specified non-integrated certificate authority | ✅🔹 | ✅ | ❌ | ❌ | ❌ | ✅ |
| 22 | Certificates should have the specified lifetime action triggers | ✅🔹 | ✅ | ❌ | ❌ | ❌ | ✅ |
| 23 | Certificates should have the specified maximum validity period | ✅ | ✅🔹 | ❌ | ❌ | ❌ | ✅ |
| 24 | Certificates should not expire within the specified number of days | ✅🔹 | ✅ | ❌ | ❌ | ❌ | ✅ |
| 25 | Certificates should use allowed key types | ✅ | ✅🔹 | ❌ | ❌ | ❌ | ✅ |
| 26 | Certificates using elliptic curve cryptography should have allowed curve names | ✅🔹 | ✅ | ❌ | ❌ | ❌ | ✅ |
| 27 | Certificates using RSA cryptography should have the specified minimum key size | ✅ | ✅🔹 | ❌ | ❌ | ❌ | ✅ |
| **KEY POLICIES (9)** |
| 28 | Key Vault keys should have an expiration date | ✅ | ✅🔹 | ❌ | ❌ | ❌ | ✅ |
| 29 | Keys should be backed by a hardware security module (HSM) | ✅ | ✅🔹 | ❌ | ❌ | ❌ | ✅ |
| 30 | Keys should be the specified cryptographic type RSA or EC | ✅ | ✅🔹 | ❌ | ❌ | ❌ | ✅ |
| 31 | Keys should have a rotation policy ensuring that their rotation is scheduled within the specified number of days after creation | ✅🔹 | ❌ | ❌ | ❌ | ❌ | ✅ |
| 32 | Keys should have more than the specified number of days before expiration | ✅🔹 | ✅ | ❌ | ❌ | ❌ | ✅ |
| 33 | Keys should have the specified maximum validity period | ✅🔹 | ✅ | ❌ | ❌ | ❌ | ✅ |
| 34 | Keys should not be active for longer than the specified number of days | ✅🔹 | ✅ | ❌ | ❌ | ❌ | ✅ |
| 35 | Keys using elliptic curve cryptography should have the specified curve names | ✅🔹 | ✅ | ❌ | ❌ | ❌ | ✅ |
| 36 | Keys using RSA cryptography should have a specified minimum key size | ✅ | ✅🔹 | ❌ | ❌ | ❌ | ✅ |
| **SECRET POLICIES (5)** |
| 37 | Key Vault secrets should have an expiration date | ✅ | ✅🔹 | ❌ | ❌ | ❌ | ✅ |
| 38 | Secrets should have content type set | ✅🔹 | ✅ | ❌ | ❌ | ❌ | ✅ |
| 39 | Secrets should have more than the specified number of days before expiration | ✅🔹 | ✅ | ❌ | ❌ | ❌ | ✅ |
| 40 | Secrets should have the specified maximum validity period | ✅🔹 | ✅ | ❌ | ❌ | ❌ | ✅ |
| 41 | Secrets should not be active for longer than the specified number of days | ✅🔹 | ✅ | ❌ | ❌ | ❌ | ✅ |
| **DIAGNOSTIC & MONITORING (5)** |
| 42 | Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace | ❌ | ❌ | ✅🔹 | ❌ | ❌ | ✅ |
| 43 | Deploy - Configure diagnostic settings to an Event Hub to be enabled on Azure Key Vault Managed HSM | ❌ | ❌ | ✅🔹 | ❌ | ❌ | ✅ |
| 44 | Deploy Diagnostic Settings for Key Vault to Event Hub | ❌ | ❌ | ✅🔹 | ❌ | ❌ | ✅ |
| 45 | Resource logs in Azure Key Vault Managed HSM should be enabled | ❌ | ❌ | ❌ | ❌ | ✅🔹 | ✅ |
| 46 | Resource logs in Key Vault should be enabled | ❌ | ❌ | ❌ | ❌ | ✅🔹 | ✅ |

*DINE = DeployIfNotExists

---

## Effect Groupings

### 📊 Audit-Only Policies (13)
*These policies CANNOT use Deny mode*

1. [Preview]: Azure Key Vault Managed HSM should use private link
2. Keys should have a rotation policy ensuring that their rotation is scheduled within the specified number of days after creation
3. [Preview]: Azure Key Vault Managed HSM Keys should have more than the specified number of days before expiration
4. [Preview]: Azure Key Vault Managed HSM keys using elliptic curve cryptography should have the specified curve names
5. Certificates should be issued by one of the specified non-integrated certificate authorities
6. Certificates should be issued by the specified non-integrated certificate authority
7. Certificates should have the specified lifetime action triggers
8. Certificates should not expire within the specified number of days
9. Certificates using elliptic curve cryptography should have allowed curve names
10. Keys should have more than the specified number of days before expiration
11. Keys should have the specified maximum validity period
12. Keys should not be active for longer than the specified number of days
13. Keys using elliptic curve cryptography should have the specified curve names
14. Secrets should have content type set
15. Secrets should have more than the specified number of days before expiration
16. Secrets should have the specified maximum validity period
17. Secrets should not be active for longer than the specified number of days

### 🚫 Deny-Compatible Policies (35)
*These can block non-compliant resource creation*

**Managed HSM (5):**
- Azure Key Vault Managed HSM keys should have an expiration date
- Azure Key Vault Managed HSM keys using RSA cryptography should have a specified minimum key size
- Azure Key Vault Managed HSM should disable public network access
- Azure Key Vault Managed HSM should have purge protection enabled
- Azure Key Vault Managed HSM Keys should have more than the specified number of days before expiration

**Key Vault Configuration (8):**
- Azure Key Vault should disable public network access
- Azure Key Vault should have firewall enabled or public network access disabled
- Azure Key Vault should use RBAC permission model
- Azure Key Vaults should use private link
- Key vaults should have deletion protection enabled
- Key vaults should have soft delete enabled

**Certificates (9):**
- Certificates should be issued by one of the specified non-integrated certificate authorities
- Certificates should be issued by the specified integrated certificate authority
- Certificates should be issued by the specified non-integrated certificate authority
- Certificates should have the specified lifetime action triggers
- Certificates should have the specified maximum validity period
- Certificates should not expire within the specified number of days
- Certificates should use allowed key types
- Certificates using elliptic curve cryptography should have allowed curve names
- Certificates using RSA cryptography should have the specified minimum key size

**Keys (8):**
- Key Vault keys should have an expiration date
- Keys should be backed by a hardware security module (HSM)
- Keys should be the specified cryptographic type RSA or EC
- Keys should have more than the specified number of days before expiration
- Keys should have the specified maximum validity period
- Keys should not be active for longer than the specified number of days
- Keys using elliptic curve cryptography should have the specified curve names
- Keys using RSA cryptography should have a specified minimum key size

**Secrets (5):**
- Key Vault secrets should have an expiration date
- Secrets should have content type set
- Secrets should have more than the specified number of days before expiration
- Secrets should have the specified maximum validity period
- Secrets should not be active for longer than the specified number of days

### 🔧 DeployIfNotExists Policies (8)
*Auto-remediation - requires managed identity*

1. [Preview]: Configure Azure Key Vault Managed HSM with private endpoints
2. Configure Azure Key Vaults to use private DNS zones
3. Configure Azure Key Vaults with private endpoints
4. Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace
5. Deploy - Configure diagnostic settings to an Event Hub to be enabled on Azure Key Vault Managed HSM
6. Deploy Diagnostic Settings for Key Vault to Event Hub

### ⚙️ Modify Policies (2)
*Auto-fix existing resources - requires managed identity*

1. [Preview]: Configure Azure Key Vault Managed HSM to disable public network access
2. Configure key vaults to enable firewall

### 🔍 AuditIfNotExists Policies (2)
*Validate configurations exist*

1. Resource logs in Azure Key Vault Managed HSM should be enabled
2. Resource logs in Key Vault should be enabled

---

## Parameter File Compatibility

### PolicyParameters-DevTest.json (30 policies)
- **Effects**: Audit only
- **Deny-compatible**: 25/30 (83%)
- **DINE-compatible**: 5/30 (17%)

### PolicyParameters-DevTest-Full.json (46 policies)
- **Effects**: Audit only
- **Deny-compatible**: 35/46 (76%)
- **DINE-compatible**: 8/46 (17%)

### PolicyParameters-Production-Deny.json (35 policies)
- **Effects**: Deny mode
- **Excluded**: 11 policies (3 Audit-only, 8 DINE/Modify/AuditIfNotExists)

### PolicyParameters-Production-Remediation.json (46 policies)
- **Effects**: 38 Audit + 8 DeployIfNotExists/Modify
- **Requires**: Managed identity for 8 auto-remediation policies

---

## Common Deployment Mistakes

### ❌ Mistake 1: Using Deny on Audit-Only Policies
**Error**: `Parameter 'effect' value 'Deny' not in allowed values [Audit, Disabled]`

**Example Policies**:
- Keys should have a rotation policy...
- [Preview]: Azure Key Vault Managed HSM should use private link

**Fix**: Use Audit or remove from Deny parameter file

### ❌ Mistake 2: Using Deny on DeployIfNotExists Policies
**Error**: `Parameter 'effect' value 'Deny' not in allowed values [DeployIfNotExists, Disabled]`

**Example Policies**:
- Deploy Diagnostic Settings for Key Vault to Event Hub
- Configure Azure Key Vaults with private endpoints

**Fix**: Use DeployIfNotExists with managed identity or remove from Deny parameter file

### ❌ Mistake 3: Missing Managed Identity for Auto-Remediation
**Warning**: `Policy default effect 'DeployIfNotExists' requires managed identity. Skipping assignment`

**Example Policies**:
- All 8 DeployIfNotExists policies
- All 2 Modify policies

**Fix**: Provide `-IdentityResourceId` parameter

---

## Testing Strategies by Effect Type

### Audit Mode Testing
- ✅ No managed identity required
- ✅ No resource blocking
- ✅ Safe for all environments
- 📊 Check compliance reports 30-90 min after deployment

### Deny Mode Testing
- ⚠️ Test in non-production first
- ⚠️ Use -Preview flag to validate
- ⚠️ May break existing workflows
- 🔍 Test with compliant and non-compliant resource creation

### DeployIfNotExists/Modify Testing
- 🔑 Requires managed identity with proper RBAC
- ⏱️ Azure evaluation cycle: 30-90 minutes
- 📝 Check remediation task status after evaluation
- ✅ Verify auto-created/modified resources

---

## Quick Reference: Effect Counts by Category

| Category | Total | Audit | Deny | DINE | Modify | AuditIfNotExists |
|----------|-------|-------|------|------|--------|------------------|
| Managed HSM | 8 | 6 | 5 | 1 | 1 | 0 |
| Key Vault Config | 10 | 8 | 8 | 3 | 1 | 0 |
| Certificates | 9 | 9 | 9 | 0 | 0 | 0 |
| Keys | 9 | 9 | 8 | 0 | 0 | 0 |
| Secrets | 5 | 5 | 5 | 0 | 0 | 0 |
| Diagnostics | 5 | 0 | 0 | 3 | 0 | 2 |
| **TOTAL** | **46** | **46** | **35** | **8** | **2** | **2** |

