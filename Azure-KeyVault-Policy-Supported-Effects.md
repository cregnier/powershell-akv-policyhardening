# Azure Key Vault Policy Supported Effects Reference

**Source:** [Microsoft Learn - Azure Policy Built-in Definitions for Key Vault](https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies#key-vault)  
**Last Updated:** January 16, 2026  
**Purpose:** Official reference for supported policy effects to ensure parameter files match Azure Policy definitions

---

## Overview

This document lists all 46 Azure Key Vault built-in policies with their officially supported effect values from Microsoft documentation. Use this reference when creating or updating policy parameter JSON files to avoid deployment warnings.

**Effect Types:**
- **Audit**: Non-blocking monitoring (logs compliance violations)
- **Deny**: Blocks creation/update of non-compliant resources
- **DeployIfNotExists**: Auto-creates compliant configurations (requires managed identity)
- **Modify**: Auto-modifies resources for compliance (requires managed identity)
- **AuditIfNotExists**: Validates configurations exist
- **Disabled**: Policy not evaluated

---

## Key Vault Policies (46 Total)

### Group 1: Managed HSM Policies (Preview)

| Policy Display Name | Supported Effects | Recommended Production |
|---------------------|-------------------|------------------------|
| [Preview]: Azure Key Vault Managed HSM keys should have an expiration date | Audit, Deny, Disabled | Deny |
| [Preview]: Azure Key Vault Managed HSM Keys should have more than the specified number of days before expiration | Audit, Deny, Disabled | Audit |
| [Preview]: Azure Key Vault Managed HSM keys using elliptic curve cryptography should have the specified curve names | Audit, Deny, Disabled | Audit |
| [Preview]: Azure Key Vault Managed HSM keys using RSA cryptography should have a specified minimum key size | Audit, Deny, Disabled | Deny |
| [Preview]: Azure Key Vault Managed HSM should disable public network access | Audit, Deny, Disabled | Deny |
| [Preview]: Azure Key Vault Managed HSM should use private link | Audit, Disabled | Audit |
| [Preview]: Configure Azure Key Vault Managed HSM to disable public network access | **Modify, Disabled** | Modify |
| [Preview]: Configure Azure Key Vault Managed HSM with private endpoints | **DeployIfNotExists, Disabled** | DeployIfNotExists |

### Group 2: Key Vault Configuration & Governance

| Policy Display Name | Supported Effects | Recommended Production |
|---------------------|-------------------|------------------------|
| Azure Key Vault Managed HSM should have purge protection enabled | Audit, Deny, Disabled | Deny |
| Azure Key Vault should disable public network access | Audit, Deny, Disabled | Deny |
| Azure Key Vault should have firewall enabled or public network access disabled | Audit, Deny, Disabled | Deny |
| Azure Key Vault should use RBAC permission model | Audit, Deny, Disabled | Deny |
| Azure Key Vaults should use private link | **[parameters('audit_effect')]** | Audit (parameterized) |
| Configure Azure Key Vaults to use private DNS zones | **DeployIfNotExists, Disabled** | DeployIfNotExists |
| Configure Azure Key Vaults with private endpoints | **DeployIfNotExists, Disabled** | DeployIfNotExists |
| Configure key vaults to enable firewall | **Modify, Disabled** | Modify |
| Key vaults should have deletion protection enabled | Audit, Deny, Disabled | Deny |
| Key vaults should have soft delete enabled | Audit, Deny, Disabled | Deny |

### Group 3: Certificate Policies

| Policy Display Name | Supported Effects | Recommended Production |
|---------------------|-------------------|------------------------|
| Certificates should be issued by one of the specified non-integrated certificate authorities | Audit, Deny, Disabled | Audit |
| Certificates should be issued by the specified integrated certificate authority | audit, Audit, deny, Deny, disabled, Disabled | Deny |
| Certificates should be issued by the specified non-integrated certificate authority | audit, Audit, deny, Deny, disabled, Disabled | Audit |
| Certificates should have the specified lifetime action triggers | audit, Audit, deny, Deny, disabled, Disabled | Audit |
| Certificates should have the specified maximum validity period | audit, Audit, deny, Deny, disabled, Disabled | Deny |
| Certificates should not expire within the specified number of days | audit, Audit, deny, Deny, disabled, Disabled | Audit |
| Certificates should use allowed key types | audit, Audit, deny, Deny, disabled, Disabled | Deny |
| Certificates using elliptic curve cryptography should have allowed curve names | audit, Audit, deny, Deny, disabled, Disabled | Audit |
| Certificates using RSA cryptography should have the specified minimum key size | audit, Audit, deny, Deny, disabled, Disabled | Deny |

### Group 4: Key Policies

| Policy Display Name | Supported Effects | Recommended Production |
|---------------------|-------------------|------------------------|
| Key Vault keys should have an expiration date | Audit, Deny, Disabled | Deny |
| Keys should be backed by a hardware security module (HSM) | Audit, Deny, Disabled | Deny |
| Keys should be the specified cryptographic type RSA or EC | Audit, Deny, Disabled | Deny |
| Keys should have a rotation policy ensuring that their rotation is scheduled within the specified number of days after creation | Audit, Disabled | Audit |
| Keys should have more than the specified number of days before expiration | Audit, Deny, Disabled | Audit |
| Keys should have the specified maximum validity period | Audit, Deny, Disabled | Audit |
| Keys should not be active for longer than the specified number of days | Audit, Deny, Disabled | Audit |
| Keys using elliptic curve cryptography should have the specified curve names | Audit, Deny, Disabled | Audit |
| Keys using RSA cryptography should have a specified minimum key size | Audit, Deny, Disabled | Deny |

### Group 5: Secret Policies

| Policy Display Name | Supported Effects | Recommended Production |
|---------------------|-------------------|------------------------|
| Key Vault secrets should have an expiration date | Audit, Deny, Disabled | Deny |
| Secrets should have content type set | Audit, Deny, Disabled | Audit |
| Secrets should have more than the specified number of days before expiration | Audit, Deny, Disabled | Audit |
| Secrets should have the specified maximum validity period | Audit, Deny, Disabled | Audit |
| Secrets should not be active for longer than the specified number of days | Audit, Deny, Disabled | Audit |

### Group 6: Diagnostic & Monitoring Policies

| Policy Display Name | Supported Effects | Recommended Production |
|---------------------|-------------------|------------------------|
| Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace | **DeployIfNotExists, Disabled** | DeployIfNotExists |
| Deploy - Configure diagnostic settings to an Event Hub to be enabled on Azure Key Vault Managed HSM | **DeployIfNotExists, Disabled** | DeployIfNotExists |
| Deploy Diagnostic Settings for Key Vault to Event Hub | **DeployIfNotExists, Disabled** | DeployIfNotExists |
| Resource logs in Azure Key Vault Managed HSM should be enabled | AuditIfNotExists, Disabled | AuditIfNotExists |
| Resource logs in Key Vault should be enabled | AuditIfNotExists, Disabled | AuditIfNotExists |

---

## Common Mistakes & Corrections

### ❌ Invalid Effect Value: `Audit` for DeployIfNotExists Policies

**Problem:** Using "Audit" effect for policies designed for auto-remediation  
**Impact:** Policy uses default effect instead of specified value, generates [WARN] messages

**Incorrect Parameter File Entries:**
```json
{
  "Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace": {
    "effect": "Audit",  // ❌ WRONG - Not in allowed values
    "logAnalytics": ""
  },
  "Configure key vaults to enable firewall": {
    "effect": "Audit"  // ❌ WRONG - Should be "Modify"
  }
}
```

**Correct Parameter File Entries:**
```json
{
  "Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace": {
    "effect": "DeployIfNotExists",  // ✅ CORRECT
    "logAnalytics": ""
  },
  "Configure key vaults to enable firewall": {
    "effect": "Modify"  // ✅ CORRECT
  }
}
```

### ❌ Invalid Parameter: `cryptographicType`

**Problem:** Parameter doesn't exist in policy definition  
**Impact:** Parameter skipped, generates [WARN] message

**Incorrect:**
```json
{
  "Keys should be the specified cryptographic type RSA or EC": {
    "cryptographicType": ["RSA", "EC"],  // ❌ Invalid parameter
    "effect": "Deny"
  }
}
```

**Correct:**
```json
{
  "Keys should be the specified cryptographic type RSA or EC": {
    "effect": "Deny"  // ✅ No cryptographicType parameter needed
  }
}
```

---

## Effect Selection Guidelines

### DevTest Environments
- **Recommended:** Audit (non-blocking monitoring)
- **Use Case:** Learn compliance posture without blocking operations
- **Example:**
  ```json
  {
    "Azure Key Vault should disable public network access": {
      "effect": "Audit"
    }
  }
  ```

### Production Environments - Audit Phase (Month 1-3)
- **Recommended:** Audit
- **Use Case:** Establish baseline before enforcement
- **Example:**
  ```json
  {
    "Key vaults should have deletion protection enabled": {
      "effect": "Audit"
    }
  }
  ```

### Production Environments - Deny Phase (Month 4-6)
- **Recommended:** Deny (for blocking policies)
- **Use Case:** Prevent new non-compliant resources
- **Example:**
  ```json
  {
    "Key vaults should have deletion protection enabled": {
      "effect": "Deny"
    }
  }
  ```

### Production Environments - Enforce Phase (Month 7+)
- **Recommended:** DeployIfNotExists + Modify + Deny
- **Use Case:** Full automation with auto-remediation
- **Example:**
  ```json
  {
    "Configure key vaults to enable firewall": {
      "effect": "Modify"  // Auto-fixes existing resources
    },
    "Key vaults should have deletion protection enabled": {
      "effect": "Deny"  // Blocks new violations
    }
  }
  ```

---

## Managed Identity Requirements

**Required for these effect types:**
- **DeployIfNotExists** (7 policies)
- **Modify** (2 policies)

**Deployment Command:**
```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -IdentityResourceId '/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation' `
    -SkipRBACCheck
```

**Policies Requiring Managed Identity:**

1. Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace
2. Deploy - Configure diagnostic settings to an Event Hub to be enabled on Azure Key Vault Managed HSM
3. Deploy Diagnostic Settings for Key Vault to Event Hub
4. Configure Azure Key Vaults to use private DNS zones
5. Configure Azure Key Vaults with private endpoints
6. Configure key vaults to enable firewall (Modify)
7. [Preview]: Configure Azure Key Vault Managed HSM to disable public network access (Modify)
8. [Preview]: Configure Azure Key Vault Managed HSM with private endpoints

---

## Parameter File Validation Checklist

Before deploying, verify:

- [ ] All **DeployIfNotExists** policies have `"effect": "DeployIfNotExists"` (NOT "Audit")
- [ ] All **Modify** policies have `"effect": "Modify"` (NOT "Audit")
- [ ] No invalid parameters like `cryptographicType` are present
- [ ] Managed identity provided for remediation parameter files
- [ ] Effect values match one of the allowed values from Microsoft documentation
- [ ] Case-sensitive effect values used (e.g., "Audit" not "audit" for some policies)

---

## Quick Reference: Effect Type by Category

### Audit-Only Policies (35)
Certificate expiration, key rotation, secret management, RBAC validation, resource logs

### Deny Policies (4)
- Keys should be the specified cryptographic type RSA or EC
- Keys using elliptic curve cryptography should have the specified curve names
- Azure Key Vault should use RBAC permission model
- [Preview]: Azure Key Vault Managed HSM keys should have an expiration date

### DeployIfNotExists Policies (7)
All diagnostic settings, private endpoint, and private DNS policies

### Modify Policies (2)
- Configure key vaults to enable firewall
- [Preview]: Configure Azure Key Vault Managed HSM to disable public network access

### AuditIfNotExists Policies (2)
- Resource logs in Key Vault should be enabled
- Resource logs in Azure Key Vault Managed HSM should be enabled

---

## Related Documentation

- **Microsoft Learn:** https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies#key-vault
- **Azure Policy Effects:** https://learn.microsoft.com/en-us/azure/governance/policy/concepts/effects
- **Managed Identity Setup:** DEPLOYMENT-PREREQUISITES.md
- **Testing Plan:** COMPREHENSIVE-TESTING-PLAN.md
- **Parameter File Examples:**
  - PolicyParameters-DevTest.json (30 policies, Audit mode)
  - PolicyParameters-DevTest-Full.json (46 policies, Audit mode)
  - PolicyParameters-DevTest-Full-Remediation.json (46 policies, Remediation mode)
  - PolicyParameters-Production.json (46 policies, Deny mode)
  - PolicyParameters-Production-Remediation.json (46 policies, Enforce mode)

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2026-01-16 | 1.0 | Initial creation from Microsoft Learn documentation |
|  |  | Documented all 46 policies with supported effects |
|  |  | Added correction examples for common mistakes |
|  |  | Included managed identity requirements |

