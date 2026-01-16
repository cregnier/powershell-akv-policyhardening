# Policy Parameter Override Recommendations

## Overview
Analysis of 46 Key Vault policies to identify which require custom parameters for Dev/Test vs Production environments.

---

## Policies Requiring Parameter Overrides (20 policies)

### 1. **Expiration and Validity Periods** (6 policies)

#### Certificates should have the specified maximum validity period
- **Default**: 12 months
- **Dev/Test**: 36 months (longer for testing)
- **Production**: 12 months (strict)
- **Parameter**: `maximumValidityInMonths`

#### Keys should have the specified maximum validity period
- **Default**: 90 days
- **Dev/Test**: 1095 days (3 years)
- **Production**: 365 days (1 year)
- **Parameter**: `maximumValidityInDays`

#### Secrets should have the specified maximum validity period
- **Default**: 90 days
- **Dev/Test**: 1095 days (3 years)
- **Production**: 365 days (1 year)
- **Parameter**: `maximumValidityInDays`

#### Keys should have more than the specified number of days before expiration
- **Default**: 90 days
- **Dev/Test**: 30 days (shorter warning)
- **Production**: 90 days (longer lead time for rotation)
- **Parameter**: `minimumDaysBeforeExpiration`

#### Secrets should have more than the specified number of days before expiration
- **Default**: 90 days
- **Dev/Test**: 30 days
- **Production**: 90 days
- **Parameter**: `minimumDaysBeforeExpiration`

#### Certificates should not expire within the specified number of days
- **Default**: 30 days
- **Dev/Test**: 30 days
- **Production**: 90 days (more advance notice)
- **Parameter**: `minimumDaysBeforeExpiry`

---

### 2. **Active Lifetime Limits** (2 policies)

#### Keys should not be active for longer than the specified number of days
- **Default**: 90 days
- **Dev/Test**: 730 days (2 years, relaxed)
- **Production**: 365 days (1 year, stricter rotation)
- **Parameter**: `maximumActiveDays`

#### Secrets should not be active for longer than the specified number of days
- **Default**: 90 days
- **Dev/Test**: 730 days
- **Production**: 365 days
- **Parameter**: `maximumActiveDays`

---

### 3. **Rotation Policies** (1 policy)

#### Keys should have a rotation policy ensuring rotation is scheduled within specified days after creation
- **Default**: 180 days
- **Dev/Test**: 180 days (relaxed)
- **Production**: 90 days (stricter rotation)
- **Parameter**: `maximumDaysToRotate`

---

### 4. **Cryptographic Key Sizes** (3 policies)

#### Keys using RSA cryptography should have a specified minimum key size
- **Default**: 2048 bits
- **Dev/Test**: 2048 bits (acceptable)
- **Production**: 4096 bits (stricter security)
- **Parameter**: `minimumRSAKeySize`

#### Certificates using RSA cryptography should have the specified minimum key size
- **Default**: 2048 bits
- **Dev/Test**: 2048 bits
- **Production**: 4096 bits
- **Parameter**: `minimumRSAKeySize`

#### [Preview] Azure Key Vault Managed HSM keys using RSA cryptography should have a specified minimum key size
- **Default**: 2048 bits
- **Dev/Test**: 2048 bits
- **Production**: 4096 bits (Audit only - preview)
- **Parameter**: `minimumRSAKeySize`

---

### 5. **Network Access and Security** (4 policies)

#### Azure Key Vault should disable public network access
- **Default**: Audit
- **Dev/Test**: Audit (allow public for development)
- **Production**: Deny (enforce private endpoints)
- **Parameter**: `effect`

#### Azure Key Vault should have firewall enabled or public network access disabled
- **Default**: Audit
- **Dev/Test**: Audit
- **Production**: Deny
- **Parameter**: `effect`

#### [Preview] Azure Key Vault Managed HSM should disable public network access
- **Default**: Audit
- **Dev/Test**: Audit
- **Production**: Audit (preview - don't deny yet)
- **Parameter**: `effect`

#### Azure Key Vault Managed HSM should have purge protection enabled
- **Default**: Audit
- **Dev/Test**: Audit
- **Production**: Deny
- **Parameter**: `effect`

---

### 6. **Logging and Monitoring** (2 policies)

#### Resource logs in Key Vault should be enabled
- **Default**: AuditIfNotExists
- **Dev/Test**: Audit (shorter retention: 30 days)
- **Production**: Deny (longer retention: 365 days)
- **Parameters**: `effect`, `requiredRetentionDays`

#### Resource logs in Azure Key Vault Managed HSM should be enabled
- **Default**: AuditIfNotExists
- **Dev/Test**: Audit
- **Production**: Deny
- **Parameter**: `effect`

---

### 7. **Data Protection** (2 policies)

#### Key vaults should have soft delete enabled
- **Default**: Audit
- **Dev/Test**: Audit (allow disable for testing)
- **Production**: Deny (enforce)
- **Parameter**: `effect`

#### Key vaults should have deletion protection enabled
- **Default**: Audit
- **Dev/Test**: Audit
- **Production**: Deny
- **Parameter**: `effect`

---

## Policies NOT Requiring Overrides (26 policies)

These policies work well with built-in defaults or don't have customizable parameters:

### Expiration Date Enforcement (Mandatory)
- Key Vault keys should have an expiration date
- Key Vault secrets should have an expiration date
- [Preview] Azure Key Vault Managed HSM keys should have an expiration date

### Cryptographic Standards
- Keys should be the specified cryptographic type RSA or EC
- Keys using elliptic curve cryptography should have the specified curve names
- Certificates using elliptic curve cryptography should have allowed curve names
- [Preview] Azure Key Vault Managed HSM keys using elliptic curve cryptography should have the specified curve names
- Keys should be backed by a hardware security module (HSM)

### Certificate Authority Management
- Certificates should be issued by the specified integrated certificate authority
- Certificates should be issued by the specified non-integrated certificate authority
- Certificates should be issued by one of the specified non-integrated certificate authorities

### Certificate Configuration
- Certificates should use allowed key types
- Certificates should have the specified lifetime action triggers

### Security Best Practices
- Secrets should have content type set
- Azure Key Vault should use RBAC permission model

### Networking (Deploy Configs - Safe Defaults)
- Azure Key Vaults should use private link
- [Preview] Azure Key Vault Managed HSM should use private link
- Configure Azure Key Vaults with private endpoints
- Configure Azure Key Vaults to use private DNS zones
- Configure key vaults to enable firewall
- [Preview] Configure Azure Key Vault Managed HSM with private endpoints
- [Preview] Configure Azure Key Vault Managed HSM to disable public network access

### Diagnostic Settings (Deploy Configs)
- Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace
- Deploy - Configure diagnostic settings to an Event Hub to be enabled on Azure Key Vault Managed HSM
- Deploy Diagnostic Settings for Key Vault to Event Hub

---

## Recommended Parameter Files

### ✅ Created Files:
1. **PolicyParameters-DevTest.json** - 20 policies with relaxed parameters
2. **PolicyParameters-Production.json** - 28 policies with strict parameters

### Usage:
```powershell
# Dev/Test
.\AzPolicyImplScript.ps1 -ParameterOverridesPath .\PolicyParameters-DevTest.json

# Production
.\AzPolicyImplScript.ps1 -ParameterOverridesPath .\PolicyParameters-Production.json

# Interactive selection
.\AzPolicyImplScript.ps1 -Interactive
```

---

## Critical vs Non-Critical Policies

### Critical (Enforce in Production with Deny)
1. Key vaults should have soft delete enabled
2. Key vaults should have deletion protection enabled
3. Azure Key Vault Managed HSM should have purge protection enabled
4. Key Vault secrets should have an expiration date
5. Key Vault keys should have an expiration date
6. Azure Key Vault should disable public network access
7. Resource logs in Key Vault should be enabled

### High Priority (Start with Audit, move to Deny after compliance)
- Certificate/key/secret validity periods
- RSA minimum key sizes
- Rotation policies
- Active lifetime limits

### Standard (Audit Mode Sufficient)
- Cryptographic curve standards
- Certificate authority policies
- Content type requirements
- RBAC permission model

---

## Interactive Menu Options

The script now offers three preset modes:

1. **Dev/Test**: All policies Audit mode, relaxed timelines
2. **Production**: Critical policies Deny, strict timelines
3. **Custom**: Use your own PolicyParameters.json

Plus policy scope choices:
- All 46 policies
- Critical 7 policies only
- Custom selection

Run with: `.\AzPolicyImplScript.ps1 -Interactive`
