# PolicyParameters-Production.json Analysis
**Analysis Date**: January 30, 2026  
**Analyst**: Your request for clarity on production parameters

---

## ⚠️ CRITICAL FINDING: This is NOT an Audit-Only File!

**PolicyParameters-Production.json** is a **MIXED ENFORCEMENT** parameter file designed for production environments with the following effect distribution:

### Effect Breakdown (46 Total Policies)

| Effect Type | Count | Behavior | Production Impact |
|-------------|-------|----------|-------------------|
| **Deny** | 18 policies | ❌ **BLOCKS** new/modified non-compliant resources | **HIGH - Prevents creation** |
| **Audit** | 16 policies | ✅ **MONITORS** only, no blocking | **ZERO - Read-only** |
| **DeployIfNotExists** | 8 policies | 🔧 **AUTO-REMEDIATES** existing resources | **MEDIUM - Makes changes** |
| **Modify** | 2 policies | ⚙️ **AUTO-CHANGES** existing resources | **MEDIUM - Makes changes** |
| **AuditIfNotExists** | 2 policies | ✅ **MONITORS** only | **ZERO - Read-only** |

---

## 🔴 DENY Policies (18) - WILL BLOCK Resources

**These policies PREVENT creation/modification of non-compliant resources:**

### Vault-Level Security (4 Deny Policies)
1. **Key vaults should have deletion protection enabled** (Deny)
   - Prevents creating Key Vaults without purge protection
   - ❌ **BLOCKS**: `New-AzKeyVault` without `-EnablePurgeProtection`

2. **Azure Key Vault should use RBAC permission model** (Deny)
   - Prevents creating Key Vaults with legacy access policies
   - ❌ **BLOCKS**: `New-AzKeyVault` with `-DisableRbacAuthorization`

3. **Azure Key Vault should disable public network access** (Deny)
   - Prevents creating publicly accessible Key Vaults
   - ❌ **BLOCKS**: `New-AzKeyVault` with `-PublicNetworkAccess 'Enabled'`

4. **Azure Key Vault Managed HSM should have purge protection enabled** (Deny)
   - Prevents creating Managed HSMs without purge protection

### Certificate Policies (5 Deny Policies)
5. **Certificates should use allowed key types** (Deny)
   - Only allows RSA or EC certificates
   - ❌ **BLOCKS**: Other key types

6. **Certificates using elliptic curve cryptography should have allowed curve names** (Deny)
   - Only allows P-256, P-256K, P-384, P-521 curves
   - ❌ **BLOCKS**: Weak EC curves

7. **Certificates using RSA cryptography should have the specified minimum key size** (Deny)
   - Requires minimum 2048-bit RSA keys
   - ❌ **BLOCKS**: `Add-AzKeyVaultCertificate` with RSA-1024

8. **Certificates should have the specified maximum validity period** (Deny)
   - Maximum 12 months validity (CA/B Forum compliance)
   - ❌ **BLOCKS**: Certificates > 397 days

9. **Certificates should have the specified lifetime action triggers** (Deny)
   - Requires renewal at 80% lifetime OR 90 days before expiry
   - ❌ **BLOCKS**: Certificates without auto-renewal

### Key Policies (5 Deny Policies)
10. **Keys should be the specified cryptographic type RSA or EC** (Deny)
    - Only allows RSA or EC keys
    - ❌ **BLOCKS**: Other key types

11. **Keys should have the specified maximum validity period** (Deny)
    - Maximum 365 days validity
    - ❌ **BLOCKS**: `Add-AzKeyVaultKey -Expires (Get-Date).AddDays(366)`

12. **Key Vault keys should have an expiration date** (Deny)
    - ALL keys must have expiration
    - ❌ **BLOCKS**: `Add-AzKeyVaultKey` without `-Expires`

13. **Keys using RSA cryptography should have a specified minimum key size** (Deny)
    - Requires minimum 4096-bit RSA keys (stricter than certs!)
    - ❌ **BLOCKS**: RSA-2048 keys

14. **Keys using elliptic curve cryptography should have the specified curve names** (Deny)
    - Only allows P-256, P-256K, P-384, P-521 curves
    - ❌ **BLOCKS**: Weak EC curves

### Secret Policies (2 Deny Policies)
15. **Secrets should have the specified maximum validity period** (Deny)
    - Maximum 365 days validity
    - ❌ **BLOCKS**: `Set-AzKeyVaultSecret -Expires (Get-Date).AddDays(366)`

16. **Key Vault secrets should have an expiration date** (Deny)
    - ALL secrets must have expiration
    - ❌ **BLOCKS**: `Set-AzKeyVaultSecret` without `-Expires`

### Managed HSM Policies (2 Deny Policies)
17. **[Preview]: Azure Key Vault Managed HSM keys should have an expiration date** (Deny)
    - ALL Managed HSM keys must have expiration

18. **[Preview]: Azure Key Vault Managed HSM keys using RSA cryptography should have a specified minimum key size** (Deny)
    - Requires minimum 4096-bit RSA keys for Managed HSM

---

## 🟢 AUDIT Policies (16) - Monitoring Only

**These policies DO NOT block, only report compliance:**

### Vault Monitoring (4 Audit Policies)
1. **Key vaults should have soft delete enabled** (Audit)
   - Reports vaults without soft delete
   - ✅ **NO BLOCKING** - only compliance reporting

2. **Azure Key Vault should have firewall enabled or public network access disabled** (Audit)
   - Monitors firewall status
   - ✅ **NO BLOCKING**

3. **[Preview]: Azure Key Vault Managed HSM should disable public network access** (Audit)
   - Monitors Managed HSM public access
   - ✅ **NO BLOCKING**

4. **Azure Key Vaults should use private link** (Audit)
   - Reports vaults without private endpoints
   - ✅ **NO BLOCKING**

### Certificate Monitoring (3 Audit Policies)
5. **Certificates should be issued by the specified integrated certificate authority** (Audit)
   - Reports non-DigiCert/GlobalSign certs
   - ✅ **NO BLOCKING**

6. **Certificates should be issued by the specified non-integrated certificate authority** (Audit)
   - Reports certs not from ContosoCA
   - ✅ **NO BLOCKING**

7. **Certificates should be issued by one of the specified non-integrated certificate authorities** (Audit)
   - Reports certs not from ContosoCA/FabrikamCA
   - ✅ **NO BLOCKING**

8. **Certificates should not expire within the specified number of days** (Audit)
   - Reports certs expiring in < 90 days
   - ✅ **NO BLOCKING**

### Key/Secret Monitoring (5 Audit Policies)
9. **Keys should have more than the specified number of days before expiration** (Audit)
   - Reports keys expiring in < 90 days
   - ✅ **NO BLOCKING**

10. **Secrets should have more than the specified number of days before expiration** (Audit)
    - Reports secrets expiring in < 90 days
    - ✅ **NO BLOCKING**

11. **Keys should not be active for longer than the specified number of days** (Audit)
    - Reports keys older than 365 days
    - ✅ **NO BLOCKING**

12. **Secrets should not be active for longer than the specified number of days** (Audit)
    - Reports secrets older than 365 days
    - ✅ **NO BLOCKING**

13. **Keys should have a rotation policy ensuring that their rotation is scheduled within the specified number of days after creation.** (Audit)
    - Reports keys without 90-day rotation policy
    - ✅ **NO BLOCKING**

### Other Monitoring (4 Audit Policies)
14. **[Preview]: Azure Key Vault Managed HSM Keys should have more than the specified number of days before expiration** (Audit)
    - Reports Managed HSM keys expiring in < 30 days
    - ✅ **NO BLOCKING**

15. **[Preview]: Azure Key Vault Managed HSM keys using elliptic curve cryptography should have the specified curve names** (Audit)
    - Reports non-compliant Managed HSM EC keys
    - ✅ **NO BLOCKING**

16. **[Preview]: Azure Key Vault Managed HSM keys using RSA cryptography should have a specified minimum key size** (Audit)
    - Reports Managed HSM keys < 4096-bit
    - ✅ **NO BLOCKING**

17. **Keys should be backed by a hardware security module (HSM)** (Audit)
    - Reports software-backed keys
    - ✅ **NO BLOCKING**

18. **Secrets should have content type set** (Audit)
    - Reports secrets without content type metadata
    - ✅ **NO BLOCKING**

---

## 🟡 DeployIfNotExists Policies (8) - AUTO-REMEDIATION

**These policies AUTOMATICALLY DEPLOY resources to fix non-compliance:**

1. **Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace** (DINE)
   - **AUTO-DEPLOYS**: Diagnostic settings to send logs to Log Analytics
   - ⚠️ **Requires**: Managed identity with permissions
   - **Target**: `/subscriptions/.../providers/Microsoft.OperationalInsights/workspaces/law-policy-test-6874`

2. **Configure Azure Key Vaults with private endpoints** (DINE)
   - **AUTO-DEPLOYS**: Private endpoints for Key Vaults without them
   - ⚠️ **Requires**: Managed identity, VNet permissions
   - **Target**: `/subscriptions/.../providers/Microsoft.Network/virtualNetworks/vnet-policy-test/subnets/subnet-keyvault`

3. **Deploy - Configure diagnostic settings to an Event Hub to be enabled on Azure Key Vault Managed HSM** (DINE)
   - **AUTO-DEPLOYS**: Diagnostic settings to Event Hub for Managed HSM
   - **Target**: Event Hub namespace `eh-policy-test-3464`

4. **Configure Azure Key Vaults to use private DNS zones** (DINE)
   - **AUTO-DEPLOYS**: Private DNS zone configuration
   - **Target**: `/subscriptions/.../providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net`

5. **[Preview]: Configure Azure Key Vault Managed HSM with private endpoints** (DINE)
   - **AUTO-DEPLOYS**: Private endpoints for Managed HSMs

6. **Deploy Diagnostic Settings for Key Vault to Event Hub** (DINE)
   - **AUTO-DEPLOYS**: Diagnostic settings to Event Hub

7. **Resource logs in Key Vault should be enabled** (AuditIfNotExists)
   - **AUDITS**: Logging enabled status (365-day retention requirement)
   - ✅ **NO AUTO-FIX** - This is AuditIfNotExists, not DINE

8. **Resource logs in Azure Key Vault Managed HSM should be enabled** (AuditIfNotExists)
   - **AUDITS**: Managed HSM logging
   - ✅ **NO AUTO-FIX**

---

## 🟠 MODIFY Policies (2) - AUTO-CHANGE Resources

**These policies AUTOMATICALLY MODIFY existing resources:**

1. **[Preview]: Configure Azure Key Vault Managed HSM to disable public network access** (Modify)
   - **AUTO-CHANGES**: `publicNetworkAccess = 'Disabled'` on Managed HSMs
   - ⚠️ **BREAKS PUBLIC ACCESS** immediately
   - **Requires**: Managed identity with `Microsoft.KeyVault/managedHSMs/write` permission

2. **Configure key vaults to enable firewall** (Modify)
   - **AUTO-CHANGES**: Enables firewall on Key Vaults
   - ⚠️ **MAY BREAK ACCESS** if no network rules configured
   - **Requires**: Managed identity

---

## 📊 Summary: Why This is NOT Audit-Only

| Risk Level | Policy Count | Behavior | Production Impact |
|------------|--------------|----------|-------------------|
| **HIGH RISK** | 18 Deny policies | Blocks new resources | Breaks deployments immediately |
| **MEDIUM RISK** | 10 DINE/Modify policies | Auto-changes resources | May break access, requires managed identity |
| **ZERO RISK** | 18 Audit policies | Monitoring only | Safe for production |

**Total Blocking/Changing Policies**: **28 out of 46** (61%)  
**Total Safe Monitoring Policies**: **18 out of 46** (39%)

---

## 🔧 How to Create a TRUE Audit-Only Parameter File

If you want **100% audit-only** (zero production risk), you need to change all `Deny`, `DeployIfNotExists`, and `Modify` effects to `Audit`:

```json
{
  "_comment": "AUDIT-ONLY - Production environment - All 46 policies for monitoring compliance only",
  
  "Key vaults should have deletion protection enabled": {
    "effect": "Audit"  // Changed from Deny
  },
  "Azure Key Vault should use RBAC permission model": {
    "effect": "Audit"  // Changed from Deny
  },
  "Azure Key Vault should disable public network access": {
    "effect": "Audit"  // Changed from Deny
  },
  // ... etc for all 46 policies
}
```

**IMPORTANT UPDATE**: You do NOT need to create a new audit-only JSON file! 

The `-PolicyMode Audit` parameter **OVERRIDES** all effect values in PolicyParameters-Production.json. Simply use:

```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Audit  # ← This overrides all Deny/DINE/Modify to Audit!
```

See [POLICYMODE-OVERRIDE-EXPLANATION.md](POLICYMODE-OVERRIDE-EXPLANATION.md) for technical details.

---

## 📁 Existing Parameter Files Comparison

Based on file searches, here are the parameter files you have:

### Active Files (Root Directory)
1. **PolicyParameters-Production.json** (THIS FILE)
   - 46 policies
   - **MIXED**: 18 Deny + 16 Audit + 10 DINE/Modify
   - **Use Case**: Production enforcement (blocks non-compliant resources)

2. **PolicyParameters-DevTest-Full.json**
   - Likely 46 policies in Audit mode
   - **Use Case**: Dev/Test full testing
   - ⚠️ *Need to verify effect distribution*

3. **PolicyParameters-DevTest.json**
   - Likely 30 policies (S/C/K only)
   - **Use Case**: Dev/Test lifecycle testing
   - ⚠️ *Need to verify effect distribution*

### Archived Files (No Longer Active)
- PolicyParameters-Tier1-Audit.json (archived)
- PolicyParameters-Tier2-Audit.json (archived)
- PolicyParameters-Tier3-Audit.json (archived)

---

## ✅ Recommended Deployment Approach (All Phases Use Same File!)

### For Stakeholder Meeting (TODAY) - Audit Mode
**Use**: `PolicyParameters-Production.json` with `-PolicyMode Audit`

```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Audit `
    -IdentityResourceId $identityId `
    -ScopeType Subscription
```

**Why**: 
- Zero production impact (all effects overridden to Audit)
- Immediate compliance visibility
- No rollback needed (monitoring only)
- Same file works for all phases

### For Production Pilot (If Approved) - Auto-Remediation
**Use**: `PolicyParameters-Production.json` with `-PolicyMode Enforce`

```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Enforce `
    -IdentityResourceId $identityId
```

**Result**: Uses JSON effects as-is (Deny blocks, DINE/Modify execute)

### For Production Enforcement (After Remediation) - Full Enforcement
**Use**: `PolicyParameters-Production.json` with `-PolicyMode Deny` or `-PolicyMode Enforce`

**Result**: Full enforcement as designed in JSON file

---

## 🎯 Action Items

### Immediate (Before Meeting)
1. ✅ Use `PolicyParameters-Production.json` with `-PolicyMode Audit`
2. ✅ Explain to stakeholders: "-PolicyMode Audit overrides all effects to monitoring only"
3. ✅ Emphasize: "Same file supports all three phases - we just change -PolicyMode parameter"

### Short-Term (If Approved)
1. Deploy using audit-only parameter file
2. Generate compliance baseline report
3. Plan remediation for non-compliant resources
4. Schedule upgrade to Deny mode (3-6 months out)

### Long-Term (Production Enforcement)
1. Remediate all non-compliant resources
2. Test Deny mode in pilot subscription
3. Deploy `PolicyParameters-Production.json` to all subscriptions
4. Monitor for blocked deployments, add exemptions as needed

---

**Document Version**: 1.0  
**Prepared**: January 30, 2026  
**Next Review**: After stakeholder meeting approval
