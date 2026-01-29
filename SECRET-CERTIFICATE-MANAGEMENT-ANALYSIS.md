# Secret & Certificate Management Analysis
## AAD Test Results - January 29, 2026

---

## Executive Summary

❌ **NO SECRET EXPIRATION POLICIES DEPLOYED** in current environment  
✅ **12 SECRET/CERTIFICATE POLICIES AVAILABLE** in the 46-policy governance framework  
⚠️ **CRITICAL GAP**: Secrets and certificates may be expiring without monitoring

---

## Secret/Certificate Policies in Framework (46 Total)

The Azure Key Vault Policy Governance framework includes **12 policies** specifically for secret, key, and certificate lifecycle management:

### Certificate Policies (5)

1. **Certificates should have the specified maximum validity period** (audit/deny)
   - Policy ID: 0a075868-4646-42ff-acb8-8f1c8e5fc6c4
   - Effect: audit/deny
   - Purpose: Enforce maximum certificate lifetime (e.g., 12 months)

2. **Certificates should use allowed key types** (audit/deny)
   - Policy ID: 1151cede-290b-4ba0-8b38-0ad145ac888f
   - Effect: audit/deny
   - Purpose: Restrict to RSA or EC keys

3. **Certificates should have the specified lifetime action triggers** (audit/deny)
   - Policy ID: 12ef42cb-9903-4e39-9c26-422d29570417
   - Effect: audit/deny
   - Purpose: Ensure auto-renewal triggers set

4. **Certificates should be issued by the specified integrated certificate authority** (audit/deny)
   - Policy ID: 8e826246-c976-48f6-b03e-619bb92b3d82
   - Effect: audit/deny
   - Purpose: Enforce use of DigiCert or GlobalSign

5. **Certificates should be issued by the specified non-integrated certificate authority** (audit/deny)
   - Policy ID: a22f4a40-01d3-4c7d-8071-da157eeff341
   - Effect: audit/deny
   - Purpose: Enforce custom CA usage

### Key Expiration Policies (4)

6. **Key Vault keys should have an expiration date** (audit/deny)
   - Policy ID: 152b15f7-8e1f-4c1f-ab71-8c010ba5dbc0
   - Effect: audit/deny
   - Purpose: Prevent indefinite key lifetime

7. **[Preview] Azure Key Vault Managed HSM keys should have an expiration date** (audit/deny)
   - Policy ID: 1d478a74-21ba-4b9f-9d8f-8e6fced0eec5
   - Effect: audit/deny
   - Purpose: HSM key expiration enforcement

8. **Keys should have the specified maximum validity period** (audit/deny)
   - Policy ID: 49a22571-d204-4c91-a7b6-09b1a586fbc9
   - Effect: audit/deny
   - Purpose: Enforce maximum key lifetime

9. **Keys should have more than the specified number of days before expiration** (audit)
   - Policy ID: 5ff38825-c5d8-47c5-b70e-069a21955146
   - Effect: audit
   - Purpose: Alert on keys expiring soon (e.g., <30 days)

### Secret Expiration Policies (3)

10. **Key Vault secrets should have an expiration date** (audit/deny)
    - Policy ID: 98728c90-32c7-4049-8429-847dc0f4fe37
    - Effect: audit/deny
    - Purpose: Prevent indefinite secret lifetime

11. **Secrets should have the specified maximum validity period** (audit/deny)
    - Policy ID: 342e8053-e12e-4c44-be01-c3c2f318400f
    - Effect: audit/deny
    - Purpose: Enforce maximum secret lifetime (e.g., 90 days)

12. **Secrets should have more than the specified number of days before expiration** (audit)
    - Policy ID: b0eb591a-5e70-4534-a8bf-04b9c489584a
    - Effect: audit
    - Purpose: Alert on secrets expiring soon (e.g., <30 days)

---

## Current Deployment Status

### AAD Environment Findings

**From Policy Assignment Inventory** (34,642 total assignments):
- ❌ **NONE of the 12 secret/certificate policies deployed**
- ✅ Only "Wiz Key Vault access policy" found (3rd-party security scanning)

**Key Vaults Analyzed**: 2,156 vaults  
**Secret/Certificate Compliance**: ❌ **UNKNOWN** (no policies deployed to monitor)

---

## Risk Assessment

### Critical Risks

1. **Expired Secrets in Production** 🔴 **HIGH RISK**
   - Application service principals may have expired secrets
   - Connection strings to databases may be outdated
   - API keys may no longer be valid
   - **Impact**: Production outages, authentication failures

2. **Expired Certificates** 🔴 **HIGH RISK**
   - SSL/TLS certificates may expire without warning
   - Code signing certificates may be invalid
   - **Impact**: Website downtime, browser warnings, unsigned code

3. **Indefinite Key Lifetimes** 🟡 **MEDIUM RISK**
   - Encryption keys never rotated
   - Compromised keys remain valid indefinitely
   - **Impact**: Reduced security posture, compliance violations

4. **No Rotation Monitoring** 🟡 **MEDIUM RISK**
   - No alerts for upcoming expirations
   - Manual rotation processes prone to human error
   - **Impact**: Last-minute emergency rotations

---

## Recommendations

### Immediate Actions (This Week)

1. **Deploy Secret Expiration Audit Policy**
   ```powershell
   # Add to PolicyParameters-Production.json
   {
       "policyDefinitionId": "/providers/Microsoft.Authorization/policyDefinitions/98728c90-32c7-4049-8429-847dc0f4fe37",
       "displayName": "Key Vault secrets should have an expiration date",
       "effect": "audit"
   }
   ```

2. **Deploy Certificate Expiration Audit Policy**
   ```powershell
   # Add to PolicyParameters-Production.json
   {
       "policyDefinitionId": "/providers/Microsoft.Authorization/policyDefinitions/0a075868-4646-42ff-acb8-8f1c8e5fc6c4",
       "displayName": "Certificates should have the specified maximum validity period",
       "effect": "audit",
       "parameters": {
           "maximumValidityInMonths": { "value": 12 }
       }
   }
   ```

3. **Run Immediate Inventory**
   ```powershell
   # Check for secrets without expiration dates
   $vaults = Get-AzKeyVault
   foreach ($vault in $vaults) {
       $secrets = Get-AzKeyVaultSecret -VaultName $vault.VaultName
       $noExpiry = $secrets | Where-Object { $null -eq $_.Expires }
       if ($noExpiry.Count -gt 0) {
           Write-Warning "Vault $($vault.VaultName) has $($noExpiry.Count) secrets without expiration"
       }
   }
   ```

### Short-Term (Next 2 Weeks)

4. **Deploy Deny Mode for New Secrets/Certificates**
   - Prevent creation of secrets without expiration dates
   - Enforce maximum validity periods (90 days for secrets, 12 months for certificates)

5. **Setup Azure Monitor Alerts**
   - Alert when secrets/certificates expire in <30 days
   - Daily compliance reports for Key Vault teams

6. **Create Remediation Runbook**
   - Automated script to set expiration dates on existing secrets
   - Gradual rollout to avoid breaking changes

### Long-Term (Next Month)

7. **Implement Secret Rotation Strategy**
   - Auto-rotation for Azure-managed secrets (e.g., Storage Account keys)
   - Manual rotation process documentation for custom secrets
   - Integration with Azure DevOps/GitHub for automated deployments

8. **Certificate Management Process**
   - Automated Let's Encrypt integration for dev/test
   - DigiCert/GlobalSign integration for production
   - 90-day renewal reminders

---

## Policy Deployment Example

### Add to PolicyParameters-Production.json

```json
{
  "policies": [
    // ... existing 46 policies ...
    
    // Add these 3 critical policies:
    {
      "policyDefinitionId": "/providers/Microsoft.Authorization/policyDefinitions/98728c90-32c7-4049-8429-847dc0f4fe37",
      "displayName": "Key Vault secrets should have an expiration date",
      "description": "Secrets should have a defined expiration date and not be valid indefinitely. This policy audits secrets that do not have an expiration date set.",
      "effect": "audit",
      "parameters": {}
    },
    {
      "policyDefinitionId": "/providers/Microsoft.Authorization/policyDefinitions/b0eb591a-5e70-4534-a8bf-04b9c489584a",
      "displayName": "Secrets should have more than the specified number of days before expiration",
      "description": "Manage your organizational compliance requirements by specifying the minimum number of days that a secret should remain valid.",
      "effect": "audit",
      "parameters": {
        "minimumDaysBeforeExpiration": { "value": 30 }
      }
    },
    {
      "policyDefinitionId": "/providers/Microsoft.Authorization/policyDefinitions/0a075868-4646-42ff-acb8-8f1c8e5fc6c4",
      "displayName": "Certificates should have the specified maximum validity period",
      "description": "Manage your organizational compliance requirements by specifying the maximum amount of time in months that a certificate can be valid.",
      "effect": "audit",
      "parameters": {
        "maximumValidityInMonths": { "value": 12 }
      }
    }
  ]
}
```

### Deployment Command

```powershell
# Deploy with the 3 new secret/certificate policies
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-SecretManagement.json `
    -PolicyMode Audit `
    -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation" `
    -ScopeType Subscription `
    -SkipRBACCheck
```

---

## Current Framework Status

**Policies Available**: 46 total (12 secret/certificate-related)  
**Policies Deployed**: 0 secret/certificate policies  
**Vaults Monitored**: 0 / 2,156 (0%)  

**Action Required**: Deploy at minimum the 3 critical policies listed above this week to begin monitoring secret and certificate expiration.

---

## Related Documentation

- [Azure Key Vault Policy Governance Framework](README.md)
- [Policy Coverage Matrix](POLICY-COVERAGE-MATRIX.md)
- [Deployment Prerequisites](DEPLOYMENT-PREREQUISITES.md)
- [AAD Test Transcript Analysis](AAD-TEST-TRANSCRIPT-ANALYSIS.md)
- [Session Summary](SESSION-SUMMARY-20260129.md)

---

**Last Updated**: January 29, 2026  
**Environment**: AAD Corporate (curtus.regnier@intel.com)  
**Status**: ⚠️ **ACTION REQUIRED** - No secret/certificate policies deployed
