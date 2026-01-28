# Unsupported Scenarios & Production Enablement Guide

**Version**: 1.1.0  
**Date**: January 28, 2026  
**Status**: Reference Documentation

---

## Overview

This document describes Azure Policy scenarios that cannot be tested in standard MSDN/Visual Studio subscriptions but can be enabled in production environments. It provides guidance on prerequisites, costs, and enablement procedures for each scenario.

---

## 📊 Summary

| Category | Policies | MSDN Status | Enterprise Status | Enablement Complexity |
|----------|----------|-------------|-------------------|----------------------|
| **Managed HSM** | 8 | ❌ Blocked (quota) | ✅ Supported | Medium (quota + cost) |
| **Integrated CA** | 1 | ❌ Requires setup | ✅ Supported | High (3rd party) |
| **Premium Features** | 2 | ⚠️ Limited | ✅ Full support | Low (tier upgrade) |
| **Total Unsupported** | **11/46** | **24% blocked** | **0% blocked** | Varies |

### Impact on Policy Coverage

**MSDN Subscriptions**:
- Testable policies: 38/46 (82.6%)
- Blocked by HSM: 8 policies (17.4%)
- Blocked by Integrated CA: 1 policy (2.2%)

**Enterprise Subscriptions**:
- Testable policies: 46/46 (100%)
- No limitations

---

## 🔐 Managed HSM Policies (8 Policies)

### Why These Are Blocked in MSDN

**Root Cause**: Azure Managed HSM requires dedicated subscription quota  
**MSDN Limitation**: Quota not available by default (security restriction)  
**Cost Barrier**: $1/hour minimum runtime (~$720/month for persistent HSM)

### Affected Policies

#### 1. Azure Key Vault Managed HSM should have purge protection enabled
- **Policy ID**: `c39ba22d-4428-4149-b981-70acb31fc383`
- **Effect**: Audit
- **Purpose**: Prevents permanent HSM deletion for 7-90 days
- **Production Impact**: Critical - prevents accidental data loss

#### 2. Configure Azure Key Vault Managed HSM with private endpoints
- **Policy ID**: `1ef66649-01cf-4b97-9c4c-0d3f6b9be61f`
- **Effect**: DeployIfNotExists
- **Purpose**: Auto-deploys private endpoints for HSMs
- **Production Impact**: High - eliminates public internet access

#### 3. Deploy - Configure diagnostic settings to Event Hub for Managed HSM
- **Policy ID**: `451ec586-8d33-442c-9088-08cefd72c0e3`
- **Effect**: DeployIfNotExists
- **Purpose**: Auto-configures audit logging to Event Hub
- **Production Impact**: High - required for compliance auditing

#### 4. Configure Azure Key Vaults to use private DNS zones (HSM DNS)
- **Policy ID**: `c113d845-cef0-4d37-83f6-ec8cd61a0d17`
- **Effect**: DeployIfNotExists
- **Purpose**: Associates private DNS for HSM name resolution
- **Production Impact**: High - enables private endpoint connectivity

#### 5. Configure Azure Key Vault Managed HSM to disable public network access
- **Policy ID**: `19ea9d63-adee-4431-a95e-1913c6c1c75f`
- **Effect**: Modify
- **Purpose**: Auto-disables public network access on HSMs
- **Production Impact**: Critical - enforces private-only access

#### 6. Resource logs in Key Vault Managed HSM should be enabled
- **Policy ID**: `a2a5b911-5617-447e-a49e-59dbe0e0434b`
- **Effect**: AuditIfNotExists
- **Purpose**: Ensures diagnostic logging enabled
- **Production Impact**: High - required for security monitoring

#### 7. Azure Key Vault Managed HSM keys should have an expiration date
- **Policy ID**: `1d478a74-21ba-4b9f-9d8f-8e6fced0eec5`
- **Effect**: Audit
- **Purpose**: Enforces key rotation policy
- **Production Impact**: Medium - reduces cryptographic risk

#### 8. Azure Key Vault Managed HSM keys using elliptic curve cryptography should have specified curve names
- **Policy ID**: `e58fd0c1-feac-4d12-92db-0a7e9421f53e`
- **Effect**: Audit
- **Purpose**: Enforces FIPS-compliant curve selection
- **Production Impact**: Medium - compliance requirement

### How to Enable in Production

#### Step 1: Request Managed HSM Quota

```powershell
# Create support ticket for quota increase
$ticket = @{
    Title = "Managed HSM Quota Request - Production Deployment"
    Severity = "C"  # Normal business impact
    ProblemClassification = "Service and subscription limits (quotas)"
    SupportPlanType = "Standard"
    Description = @"
Requesting Managed HSM quota for Azure Key Vault governance policy deployment.
Subscription ID: <your-subscription-id>
Region: East US
Required quota: 1-2 Managed HSMs for testing
Business justification: Enterprise key management with hardware security modules
"@
}

# Submit via Azure Portal: Support + troubleshooting → New support request
```

**Processing Time**: 1-3 business days  
**Cost**: Included in Azure support plan

#### Step 2: Create Test Managed HSM

```powershell
# WARNING: Managed HSM costs $1/hour minimum (~$720/month)
# For testing only - delete immediately after validation

# Create Managed HSM
New-AzKeyVaultManagedHsm `
    -Name "hsm-policy-test" `
    -ResourceGroupName "rg-policy-keyvault-test" `
    -Location "eastus" `
    -SoftDeleteRetentionInDays 7 `
    -EnablePurgeProtection

# Activate HSM (requires security domain setup)
# See: https://learn.microsoft.com/azure/key-vault/managed-hsm/quick-create-powershell
```

**Minimum Test Duration**: 1 hour (cost: ~$1)  
**Recommended**: Delete immediately after policy validation

#### Step 3: Deploy HSM-Enabled Policies

```powershell
# Use Enterprise parameter file (includes HSM policies)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Enterprise-Full.json `
    -PolicyMode Audit `
    -IdentityResourceId "<managed-identity-id>" `
    -ScopeType Subscription `
    -SkipRBACCheck
```

#### Step 4: Validate HSM Policy Compliance

```powershell
# Check HSM-specific compliance
Get-AzPolicyState -PolicyDefinitionName "c39ba22d-4428-4149-b981-70acb31fc383" |
    Where-Object { $_.ResourceType -eq "Microsoft.KeyVault/managedHSMs" } |
    Select-Object ResourceId, ComplianceState, Timestamp
```

#### Step 5: Cleanup (Critical for Cost Control)

```powershell
# Delete Managed HSM immediately after testing
Remove-AzKeyVaultManagedHsm `
    -Name "hsm-policy-test" `
    -ResourceGroupName "rg-policy-keyvault-test" `
    -Force

# Purge deleted HSM (stops billing)
Remove-AzKeyVaultManagedHsm `
    -Name "hsm-policy-test" `
    -Location "eastus" `
    -InRemovedState `
    -Force
```

**Cost Impact**: $1 for 1-hour test, $720/month if left running

### Production Deployment Strategy

**Option 1: Skip HSM Policies** (Recommended for non-HSM environments)
- Deploy 38 non-HSM policies only
- Use `PolicyParameters-Production.json` (excludes HSM)
- Coverage: 82.6% (sufficient for most organizations)

**Option 2: Enable HSM Policies** (Enterprise with Managed HSM)
- Deploy all 46 policies
- Use `PolicyParameters-Enterprise-Full.json`
- Coverage: 100%
- Requires: Managed HSM quota + existing HSMs

---

## 📜 Integrated CA Policy (1 Policy)

### Why This Is Limited

**Root Cause**: Requires third-party certificate authority integration  
**MSDN Limitation**: No default CA integration (manual setup required)  
**Cost Barrier**: DigiCert/GlobalSign licensing fees

### Affected Policy

#### Certificates should be issued by the specified integrated certificate authority
- **Policy ID**: `8e826246-c976-48f6-b03e-619bb92b3d82`
- **Effect**: Audit
- **Purpose**: Enforces certificates from approved CA providers
- **Production Impact**: High - compliance requirement for enterprise PKI

### How to Enable in Production

#### Step 1: Choose CA Provider

**Supported Providers**:
- DigiCert
- GlobalSign
- Microsoft-internal CA (Azure AD CS)

**Cost**:
- DigiCert: $175-1,000/year per certificate type
- GlobalSign: $200-800/year per certificate type

#### Step 2: Configure CA Integration

```powershell
# Example: DigiCert integration
Set-AzKeyVaultCertificateIssuer `
    -VaultName "kv-production-001" `
    -Name "DigiCert" `
    -IssuerProvider "DigiCert" `
    -AccountId "<digicert-account-id>" `
    -ApiKey (ConvertTo-SecureString -String "<api-key>" -AsPlainText -Force)
```

#### Step 3: Update Parameter File

```json
{
  "effect": {
    "value": "Audit"
  },
  "allowedCAs": {
    "value": [
      "CN=DigiCert Global Root G2, OU=www.digicert.com, O=DigiCert Inc, C=US",
      "CN=GlobalSign Root CA, OU=Root CA, O=GlobalSign nv-sa, C=BE"
    ]
  }
}
```

#### Step 4: Deploy with CA Policy

```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-IntegratedCA.json `
    -PolicyMode Audit `
    -ScopeType Subscription
```

### Production Deployment Strategy

**Option 1: Skip Integrated CA Policy** (Recommended for self-signed certs)
- Deploy 45/46 policies (exclude integrated CA)
- Use `PolicyParameters-Production.json`
- Coverage: 97.8%

**Option 2: Enable Integrated CA** (Enterprise PKI)
- Integrate DigiCert or GlobalSign
- Deploy all 46 policies
- Coverage: 100%
- Requires: CA licensing + integration

---

## ⚙️ Premium Feature Policies (2 Policies)

### Affected Policies

#### 1. Keys using elliptic curve cryptography should have the specified curve names
- **Policy ID**: `ff25f3c8-b739-4538-9d07-3d6d25cfb255`
- **Effect**: Audit
- **Purpose**: Enforces FIPS 186-4 compliant curves (P-256, P-384, P-521)
- **MSDN Impact**: May encounter RBAC delays (not blocked)

#### 2. Certificates using elliptic curve cryptography should have allowed curve names
- **Policy ID**: `bd78111f-4953-4367-9fd5-7e08808b54bf`
- **Effect**: Audit
- **Purpose**: Enforces FIPS-compliant certificate curves
- **MSDN Impact**: May encounter RBAC delays (not blocked)

### How to Enable in Production

**No special setup required** - these policies work in MSDN but may have slower RBAC propagation.

**Production Recommendation**: Use Premium tier Key Vaults for optimal performance.

```powershell
# Upgrade to Premium tier (optional)
Update-AzKeyVault `
    -VaultName "kv-production-001" `
    -ResourceGroupName "rg-production" `
    -Sku "Premium"
```

**Cost Impact**: Premium tier ~$0.03/10K operations (Standard ~$0.03/10K operations - minimal difference)

---

## 📋 Production Enablement Checklist

### Before Deploying to Production

- [ ] **Identify required policies**: Do you need HSM policies?
- [ ] **Check CA requirements**: Do you need integrated CA policy?
- [ ] **Request HSM quota** (if needed): 1-3 business days
- [ ] **Integrate CA provider** (if needed): 1-2 weeks setup
- [ ] **Choose parameter file**: DevTest vs Production vs Enterprise
- [ ] **Create exemptions**: Legacy vaults, third-party managed
- [ ] **Test in non-production** first: Validate with 38/46 policies
- [ ] **Plan phased rollout**: Audit → Deny → Enforce over 30 days

### During Production Deployment

- [ ] **Start with Audit mode**: Monitor for 7 days
- [ ] **Review compliance reports**: Identify non-compliant resources
- [ ] **Create exemptions**: Document waiver/mitigated reasons
- [ ] **Enable Deny mode**: Block new violations (34 policies)
- [ ] **Monitor impact**: Check for blocked legitimate operations
- [ ] **Enable auto-remediation**: DeployIfNotExists/Modify (8 policies)
- [ ] **Validate remediation tasks**: Check success/failure rates

### Post-Deployment Monitoring

- [ ] **Weekly compliance reports**: Track improvement trends
- [ ] **Monthly exemption review**: Remove expired exemptions
- [ ] **Quarterly policy review**: Update parameter values
- [ ] **Annual HSM validation** (if applicable): Re-test with test HSM

---

## 🎯 Recommended Deployment Matrix

| Environment | Policies | HSM | Integrated CA | Coverage | Use Case |
|-------------|----------|-----|---------------|----------|----------|
| **MSDN DevTest** | 38 | ❌ No | ❌ No | 82.6% | Development testing |
| **Production (Standard)** | 38 | ❌ No | ❌ No | 82.6% | Small/medium orgs |
| **Production (Premium)** | 45 | ❌ No | ✅ Yes | 97.8% | Enterprise PKI |
| **Enterprise (Full)** | 46 | ✅ Yes | ✅ Yes | 100% | Large orgs with HSM |

### Parameter File Selection

```powershell
# MSDN DevTest (38 policies, no HSM, no CA)
-ParameterFile .\PolicyParameters-DevTest-Full.json

# Production Standard (38 policies, no HSM, no CA)
-ParameterFile .\PolicyParameters-Production.json

# Production Premium (45 policies, no HSM, with CA)
-ParameterFile .\PolicyParameters-Production-IntegratedCA.json

# Enterprise Full (46 policies, with HSM, with CA)
-ParameterFile .\PolicyParameters-Enterprise-Full.json
```

---

## 💰 Cost Implications

### HSM Testing Costs

| Scenario | Duration | Cost | Recommendation |
|----------|----------|------|----------------|
| **Quick validation** | 1 hour | ~$1 | ✅ Acceptable |
| **Full testing** | 8 hours | ~$8 | ⚠️ Monitor closely |
| **Left overnight** | 24 hours | ~$24 | ❌ Avoid |
| **Left for month** | 720 hours | ~$720 | ❌ Critical - delete immediately |

### CA Integration Costs

| Provider | Certificate Type | Annual Cost | Recommendation |
|----------|------------------|-------------|----------------|
| **DigiCert** | Standard SSL | $175-295/year | ✅ Budget-friendly |
| **DigiCert** | EV SSL | $595-995/year | ⚠️ Enterprise only |
| **GlobalSign** | Standard SSL | $200-400/year | ✅ Budget-friendly |
| **GlobalSign** | EV SSL | $600-800/year | ⚠️ Enterprise only |

---

## 📞 Support Resources

### Managed HSM Documentation
- [Managed HSM Overview](https://learn.microsoft.com/azure/key-vault/managed-hsm/overview)
- [Quick Create PowerShell](https://learn.microsoft.com/azure/key-vault/managed-hsm/quick-create-powershell)
- [Best Practices](https://learn.microsoft.com/azure/key-vault/managed-hsm/best-practices)

### Integrated CA Documentation
- [Certificate Issuers](https://learn.microsoft.com/azure/key-vault/certificates/how-to-integrate-certificate-authority)
- [DigiCert Integration](https://learn.microsoft.com/azure/key-vault/certificates/how-to-integrate-certificate-authority#digicert)
- [GlobalSign Integration](https://learn.microsoft.com/azure/key-vault/certificates/how-to-integrate-certificate-authority#globalsign)

### Azure Policy Documentation
- [DeployIfNotExists](https://learn.microsoft.com/azure/governance/policy/concepts/effects#deployifnotexists)
- [Modify Effect](https://learn.microsoft.com/azure/governance/policy/concepts/effects#modify)
- [Policy Exemptions](https://learn.microsoft.com/azure/governance/policy/concepts/exemption-structure)

---

## ✅ Conclusion

**For most organizations**:
- 38/46 policies (82.6% coverage) is sufficient
- HSM policies not required unless using Managed HSM
- Integrated CA policy optional (self-signed certs acceptable for dev/test)

**For enterprise organizations**:
- 46/46 policies (100% coverage) recommended
- Budget for HSM testing ($1-10) or persistent HSM ($720/month)
- Integrate enterprise CA provider (DigiCert/GlobalSign)

**Production deployment strategy**:
1. Start with 38 policies (no HSM, no CA)
2. Monitor compliance for 30 days
3. Add HSM/CA policies if business requires them
4. Document exemptions for unsupported scenarios

**See [DEPLOYMENT-WORKFLOW-GUIDE.md](DEPLOYMENT-WORKFLOW-GUIDE.md) for production deployment procedures.**

---

**Document Version**: 1.0  
**Last Updated**: January 28, 2026  
**Status**: Final
