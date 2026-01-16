# Production Enforcement Plan - Phased Rollout Strategy

**Document Version**: 1.0  
**Created**: January 14, 2026  
**Purpose**: Risk-based phased deployment of 46 Key Vault policies to production with Deny mode enforcement  
**Subscription**: ab1336c7-687d-4107-b0f6-9649a0458adb (MSDN Platforms)

---

## Executive Summary

**Testing Status**: ✅ All 46 policies tested (45 in Deny mode, 1 in Audit)  
**Production Approach**: 🎯 **Phased rollout over 4 weeks** based on risk categorization  
**Critical Finding**: Only 1 policy (soft-delete) has ARM timing bug - all others can use Deny mode safely

### Phased Deployment Overview

| Phase | Timeline | Risk Level | Policies | Impact |
|-------|----------|------------|----------|--------|
| **Phase 1** | Week 1 | LOW | 12 policies | Minimal disruption - preventive controls for new resources |
| **Phase 2** | Week 2 | MEDIUM | 18 policies | Moderate impact - common configurations |
| **Phase 3** | Week 3 | HIGH | 15 policies | High impact - requires remediation planning |
| **Phase 4** | Week 4 | SPECIAL | 1 policy | Soft-delete (Audit mode only) |

**Total**: 46 policies deployed over 4 weeks with pre-deployment user notifications

---

## Policy Risk Categorization

### 🟢 PHASE 1: LOW RISK (Week 1) - Safe for Immediate Enforcement

**Deployment Date**: Week 1, Day 1  
**User Notification**: 3 days prior  
**Impact**: Minimal - Affects only NEW resources or non-blocking monitoring

#### Policies (12 total):

| # | Policy Name | Effect | Justification | Breaks What? |
|---|-------------|--------|---------------|--------------|
| 1 | **Certificate Validity Period should not exceed 12 months** | Deny | Only affects NEW certificates | Nothing (only future issuance) |
| 2 | **Certificates should have specified maximum validity period** | Deny | Only affects NEW certificates | Nothing (only future issuance) |
| 3 | **Certificates should be issued by allowed non-integrated CA** | Deny | Only affects NEW certificates | NEW certs from unapproved CAs |
| 4 | **Certificates should be issued by allowed integrated CA** | Deny | Only affects NEW certificates | NEW certs from unapproved CAs |
| 5 | **Certificates should not use disallowed certificate types** | Deny | Only affects NEW certificates | NEW certs with wrong type |
| 6 | **Certificates using elliptic curve crypto should have allowed curve names** | Deny | Only affects NEW EC certificates | NEW EC certs with wrong curve |
| 7 | **Keys should have specified maximum validity period** | Deny | Only affects NEW keys | Nothing (only future creation) |
| 8 | **Keys should be specified crypto type** | Deny | Only affects NEW keys | NEW keys with wrong type (RSA/EC) |
| 9 | **Keys using elliptic curve crypto should have specified curve names** | Deny | Only affects NEW EC keys | NEW EC keys with wrong curve |
| 10 | **Secrets should have specified maximum validity period** | Deny | Only affects NEW secrets | Nothing (only future creation) |
| 11 | **Resource logs in Key Vault should be enabled** | AuditIfNotExists | Monitoring only, doesn't block | Nothing (just logs) |
| 12 | **Keys should have rotation policy** | Audit | Monitoring only | Nothing (just visibility) |

**User Notification Template (Week 1)**:
```
SUBJECT: Azure Key Vault Policy Enforcement - Phase 1 (Low Risk) - Deployment [DATE]

Starting [DEPLOYMENT DATE], the following Key Vault policies will be enforced in Deny mode:
- Certificate validity and issuance controls (12 policies)
- These policies ONLY affect NEW certificates, keys, and secrets
- Existing resources are NOT affected
- No production outages expected

IMPACT: 
✅ No impact to existing Key Vaults or resources
✅ New certificates/keys/secrets must meet security standards
⚠️ Non-compliant NEW resource creation will be blocked

ACTION REQUIRED: None for existing resources
QUESTIONS: Contact [Security Team]
```

---

### 🟡 PHASE 2: MEDIUM RISK (Week 2) - Common Configurations

**Deployment Date**: Week 2, Day 1  
**User Notification**: 5 days prior  
**Impact**: May block some vault operations if not properly configured

#### Policies (18 total):

| # | Policy Name | Effect | Justification | Breaks What? |
|---|-------------|--------|---------------|--------------|
| 13 | **Firewall should be enabled on Key Vault** | Deny | Common security control | PUBLIC vaults without firewall |
| 14 | **Azure Key Vault should disable public network access** | Deny | Zero-trust architecture | PUBLIC vaults (no private endpoint) |
| 15 | **Azure Key Vault should have firewall enabled** | Deny | Network isolation | PUBLIC vaults without firewall |
| 16 | **Key Vault should use private link** | Audit | Monitoring (not blocking) | Nothing (visibility only) |
| 17 | **Private endpoint should be enabled for Key Vault** | Audit | Monitoring (not blocking) | Nothing (visibility only) |
| 18 | **Key vaults should use RBAC permission model** | Deny | Modern access control | Vaults using ACCESS POLICIES |
| 19 | **Azure Key Vault should use private DNS zones** | Audit | Monitoring (not blocking) | Nothing (DNS guidance) |
| 20 | **Azure Key Vault Managed HSM should use private DNS zones** | Audit | Monitoring (not blocking) | Nothing (DNS guidance) |
| 21 | **Certificates should have allowed key types** | Deny | Crypto standards | NEW certs with disallowed key types |
| 22 | **Certificates should use allowed key sizes (RSA)** | Deny | Crypto strength | NEW RSA certs < 2048 bits |
| 23 | **Certificates should use allowed key sizes (EC)** | Deny | Crypto strength | NEW EC certs with wrong size |
| 24 | **Keys should have allowed crypto types** | Deny | Crypto standards | NEW keys with disallowed types |
| 25 | **Keys should be RSA or EC** | Deny | Crypto standards | NEW keys (not RSA/EC) |
| 26 | **Keys should have allowed sizes (RSA)** | Deny | Crypto strength | NEW RSA keys < 2048 bits |
| 27 | **Keys should have allowed sizes (EC)** | Deny | Crypto strength | NEW EC keys with wrong size |
| 28 | **Certificates should not expire within 90 days** | Audit | Certificate lifecycle | Nothing (just alerts) |
| 29 | **Keys should have expiration date** | Audit | Key lifecycle | Nothing (just visibility) |
| 30 | **Secrets should have expiration date** | Audit | Secret lifecycle | Nothing (just visibility) |

**Known Impact Areas**:
- ⚠️ **RBAC Policy (#18)**: Will block vaults using access policies (common in older deployments)
- ⚠️ **Firewall Policies (#13-15)**: Will block public vaults without firewall rules
- ⚠️ **Private Link (#14)**: May block vaults without private endpoints (depends on org network strategy)

**User Notification Template (Week 2)**:
```
SUBJECT: Azure Key Vault Policy Enforcement - Phase 2 (Medium Risk) - Deployment [DATE]

Starting [DEPLOYMENT DATE], the following Key Vault policies will be enforced:
- Network isolation (firewall, private endpoints) - 7 policies
- RBAC vs Access Policy enforcement - 1 policy
- Cryptographic standards (key sizes, algorithms) - 10 policies

IMPACT:
⚠️ CRITICAL: Vaults using ACCESS POLICIES will be blocked (must migrate to RBAC)
⚠️ PUBLIC VAULTS without firewall will be blocked
⚠️ NEW keys/certificates with weak crypto will be blocked
✅ Existing compliant vaults not affected

ACTION REQUIRED:
1. Audit current Key Vaults for:
   - Permission model (Access Policy vs RBAC)
   - Firewall configuration
   - Public network access settings
2. Request exemptions for vaults that cannot be remediated immediately
3. Plan migration for non-compliant vaults

REMEDIATION WINDOW: 5 days before enforcement
EXEMPTION PROCESS: [Link to EXEMPTION_PROCESS.md]
QUESTIONS: Contact [Security Team]
```

---

### 🔴 PHASE 3: HIGH RISK (Week 3) - Requires Pre-Remediation

**Deployment Date**: Week 3, Day 1  
**User Notification**: 10 days prior  
**Impact**: High - Will block vaults without purge protection and specific configurations

#### Policies (15 total):

| # | Policy Name | Effect | Justification | Breaks What? |
|---|-------------|--------|---------------|--------------|
| 31 | **Key vaults should have deletion protection enabled** | Deny | **HIGH IMPACT** | Vaults WITHOUT purge protection |
| 32 | **Azure Key Vault Managed HSM should have purge protection enabled** | Deny | Data loss prevention | HSMs without purge protection |
| 33 | **Key Vault keys should have expiration date** | Deny | Lifecycle management | NEW keys without expiration |
| 34 | **Key Vault secrets should have expiration date** | Deny | Lifecycle management | NEW secrets without expiration |
| 35 | **Certificates should have expiration date** | Deny | Lifecycle management | NEW certs without expiration |
| 36 | **Key Vault keys should not be active for > X days** | Audit | Rotation monitoring | Nothing (just alerts) |
| 37 | **Secrets should not be active for > X days** | Audit | Rotation monitoring | Nothing (just alerts) |
| 38 | **Certificates should not be active for > X days** | Audit | Rotation monitoring | Nothing (just alerts) |
| 39 | **Keys using RSA crypto should have min key size** | Deny | Crypto strength | NEW RSA keys < minimum |
| 40 | **Certificates using RSA should have min key size** | Deny | Crypto strength | NEW RSA certs < minimum |
| 41 | **Azure Key Vault Managed HSM keys should have expiration** | Deny | HSM lifecycle | NEW HSM keys without expiration |
| 42 | **Azure Key Vault Managed HSM keys using RSA should have min size** | Deny | HSM crypto strength | NEW HSM RSA keys < minimum |
| 43 | **Azure Key Vault Managed HSM should disable public network** | Deny | HSM network isolation | PUBLIC HSMs |
| 44 | **Managed HSM should use private link** | Audit | HSM network guidance | Nothing (visibility only) |
| 45 | **Private endpoint should be enabled for Managed HSM** | Audit | HSM network guidance | Nothing (visibility only) |

**CRITICAL IMPACT - Policy #31: Purge Protection**

**Issue**: Many existing vaults DO NOT have purge protection enabled  
**Impact**: Creating NEW vaults without purge protection will be blocked  
**Remediation**: Not possible for existing vaults (purge protection cannot be added post-creation)  
**Solution**: 
- Audit existing vaults for purge protection
- Create exemptions for vaults that cannot be recreated
- Enforce for all NEW vaults going forward

**Pre-Deployment Actions**:
1. **10 days before deployment**:
   ```powershell
   # Audit all vaults for purge protection
   Get-AzKeyVault | Select-Object VaultName, EnablePurgeProtection, ResourceGroupName |
       Where-Object { $_.EnablePurgeProtection -ne $true } |
       Export-Csv "VaultsWithoutPurgeProtection.csv"
   ```

2. **7 days before**: Send report to vault owners
3. **5 days before**: Create exemptions for vaults that cannot be remediated
4. **3 days before**: Final verification

**User Notification Template (Week 3)**:
```
SUBJECT: 🚨 CRITICAL - Azure Key Vault Policy Enforcement - Phase 3 (High Risk) - Deployment [DATE]

Starting [DEPLOYMENT DATE], HIGH-IMPACT policies will be enforced:
- ⚠️ PURGE PROTECTION REQUIRED for all NEW Key Vaults
- ⚠️ EXPIRATION DATES REQUIRED for new keys/secrets/certificates
- ⚠️ CRYPTOGRAPHIC MINIMUMS enforced

CRITICAL IMPACT:
❌ NEW vaults without purge protection will be BLOCKED
❌ NEW keys/secrets/certificates without expiration will be BLOCKED  
❌ Weak cryptographic keys will be BLOCKED

EXISTING VAULTS: 
✅ Not affected (policies only block NEW non-compliant resources)
⚠️ [X] vaults in your subscription lack purge protection (see attached report)
⚠️ These vaults cannot create NEW non-compliant resources after [DATE]

ACTION REQUIRED (HIGH PRIORITY):
1. Review attached report: VaultsWithoutPurgeProtection.csv
2. For vaults without purge protection:
   a. Plan to recreate with purge protection (if feasible)
   b. Request exemption (if cannot recreate) - See exemption process
3. Ensure all NEW resource creation includes expiration dates
4. Test vault creation in lower environments BEFORE [DATE]

REMEDIATION DEADLINE: [DATE - 3 days before enforcement]
EXEMPTION REQUESTS: Due [DATE - 5 days before enforcement]
EXEMPTION PROCESS: [Link]
SUPPORT: [Security Team / Operations Team]

This is a BREAKING CHANGE - Please review immediately.
```

---

### 🟣 PHASE 4: SPECIAL CASE (Week 4) - Soft-Delete (Audit Only)

**Deployment Date**: Week 4, Day 1  
**User Notification**: Informational only (no impact)  
**Impact**: NONE - Audit mode, soft-delete is platform-enforced

#### Policy (1 total):

| # | Policy Name | Effect | Justification | Breaks What? |
|---|-------------|--------|---------------|--------------|
| 46 | **Key vaults should have soft delete enabled** | **Audit** | ARM timing bug workaround | Nothing (monitoring only) |

**Why Audit Mode Only**:
- Policy has ARM timing bug (checks `exists: false` during validation)
- Deny mode blocks ALL vault creation (even compliant)
- Soft-delete is platform-enforced (mandatory since 2019, cannot be disabled)
- Audit mode provides compliance visibility without blocking operations
- See: `SoftDeletePolicyResearch-20260114.md` for full analysis

**User Notification Template (Week 4)**:
```
SUBJECT: Azure Key Vault Policy - Soft-Delete Monitoring Enabled

The "Key vaults should have soft delete enabled" policy is now active in AUDIT mode.

IMPACT: NONE
✅ No operations blocked
✅ Compliance monitoring enabled
ℹ️ Soft-delete is automatically enabled on all vaults (platform-enforced)

This policy monitors compliance only. Deny mode is not used due to a known Azure Policy ARM timing bug.
For technical details, see: SoftDeletePolicyResearch-20260114.md
```

---

## Implementation Checklist

### Pre-Deployment (All Phases)

**2 Weeks Before Phase 1**:
- [ ] Review ProductionRolloutPlan.md (this document)
- [ ] Socialize phased approach with stakeholders
- [ ] Confirm exemption process (EXEMPTION_PROCESS.md)
- [ ] Set up compliance dashboard (ComplianceDashboard-Template.json)
- [ ] Configure Log Analytics for policy logging

**1 Week Before Each Phase**:
- [ ] Send user notification email (use templates above)
- [ ] Publish policy deployment schedule
- [ ] Set up support channels for questions
- [ ] Prepare rollback procedures

### Phase 1 Deployment (Week 1)

**Day -3** (3 days before):
- [ ] Send Phase 1 notification email
- [ ] Publish FAQ document
- [ ] Schedule office hours for questions

**Day 0** (Deployment):
```powershell
# Deploy Phase 1 policies (12 policies - LOW RISK)
.\AzPolicyImplScript.ps1 `
    -PolicyMode Deny `
    -ScopeType Subscription `
    -PolicyFilter "Phase1" `  # Need to add filtering capability
    -IdentityResourceId "/subscriptions/.../id-policy-remediation"
```

**Day +1** (Post-deployment):
- [ ] Monitor compliance dashboard for issues
- [ ] Review policy blocking logs (should be minimal)
- [ ] Address support tickets
- [ ] Daily status email to stakeholders

**Day +3** (72-hour review):
- [ ] Compliance report to leadership
- [ ] Document lessons learned
- [ ] Adjust Phase 2 plan if needed

### Phase 2 Deployment (Week 2)

**Day -5** (5 days before):
- [ ] Send Phase 2 notification email
- [ ] Distribute compliance audit reports
- [ ] Hold Q&A sessions

**Day -3** (3 days before):
- [ ] Publish remediation guides
- [ ] Open exemption request window
- [ ] Test deployment in lower environment

**Day 0** (Deployment):
```powershell
# Deploy Phase 2 policies (18 policies - MEDIUM RISK)
.\AzPolicyImplScript.ps1 `
    -PolicyMode Deny `
    -ScopeType Subscription `
    -PolicyFilter "Phase2" `
    -IdentityResourceId "/subscriptions/.../id-policy-remediation"
```

**Day +1 to +7**:
- [ ] Daily compliance monitoring
- [ ] Process exemption requests (expedited)
- [ ] Support team available 24/7
- [ ] Daily stakeholder updates

### Phase 3 Deployment (Week 3) - HIGH RISK

**Day -10** (10 days before):
- [ ] Send Phase 3 CRITICAL notification
- [ ] Run audit: VaultsWithoutPurgeProtection.csv
- [ ] Distribute non-compliance reports to vault owners

**Day -7** (7 days before):
- [ ] Follow-up emails to owners of non-compliant vaults
- [ ] Hold remediation workshops
- [ ] Publish remediation guides

**Day -5** (5 days before):
- [ ] Exemption request deadline
- [ ] Review and approve exemptions
- [ ] Final compliance audit

**Day -3** (3 days before):
- [ ] Final go/no-go decision
- [ ] Verify exemptions applied
- [ ] Test deployment in lower environment
- [ ] Notify users of final status

**Day 0** (Deployment):
```powershell
# Deploy Phase 3 policies (15 policies - HIGH RISK)
.\AzPolicyImplScript.ps1 `
    -PolicyMode Deny `
    -ScopeType Subscription `
    -PolicyFilter "Phase3" `
    -IdentityResourceId "/subscriptions/.../id-policy-remediation"
```

**Day +1 to +14**:
- [ ] Intensive monitoring (first 48 hours)
- [ ] Support team on standby
- [ ] Daily compliance reports
- [ ] Weekly stakeholder briefings
- [ ] Document incidents and resolutions

### Phase 4 Deployment (Week 4) - SPECIAL CASE

**Day -3** (3 days before):
- [ ] Send informational email (no action required)
- [ ] Publish technical documentation

**Day 0** (Deployment):
```powershell
# Deploy soft-delete policy (AUDIT MODE ONLY)
$assignment = Get-AzPolicyAssignment | Where-Object { 
    $_.PolicyDefinitionId -like "*1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d*" 
}

if ($assignment) {
    # Verify it's in Audit mode
    if ($assignment.PolicyParameterObject.effect -ne 'Audit') {
        Set-AzPolicyAssignment -Id $assignment.ResourceId `
            -PolicyParameterObject @{effect='Audit'}
    }
}
```

**Day +1**:
- [ ] Verify Audit mode active
- [ ] Confirm no blocking
- [ ] Document completion

---

## Risk Mitigation Strategies

### 1. Pre-Deployment Audits

Run these audits BEFORE each phase:

```powershell
# Phase 1 Audit (minimal risk - just verify)
Get-AzKeyVault | Measure-Object  # Just count

# Phase 2 Audit (RBAC vs Access Policy - CRITICAL)
Get-AzKeyVault | ForEach-Object {
    $vault = Get-AzKeyVault -VaultName $_.VaultName -ResourceGroupName $_.ResourceGroupName
    [PSCustomObject]@{
        VaultName = $_.VaultName
        ResourceGroup = $_.ResourceGroupName
        EnableRbacAuthorization = $vault.EnableRbacAuthorization
        NetworkAcls = $vault.NetworkAcls.DefaultAction
        PublicNetworkAccess = $vault.PublicNetworkAccess
        RiskLevel = if ($vault.EnableRbacAuthorization -eq $false) { "HIGH - Uses Access Policies" } 
                   elseif ($vault.NetworkAcls.DefaultAction -eq 'Allow') { "MEDIUM - Public access" }
                   else { "LOW - Compliant" }
    }
} | Export-Csv "Phase2-PreDeploymentAudit.csv"

# Phase 3 Audit (Purge Protection - CRITICAL)
Get-AzKeyVault | ForEach-Object {
    [PSCustomObject]@{
        VaultName = $_.VaultName
        ResourceGroup = $_.ResourceGroupName
        EnablePurgeProtection = $_.EnablePurgeProtection
        EnableSoftDelete = $_.EnableSoftDelete
        RiskLevel = if ($_.EnablePurgeProtection -ne $true) { "HIGH - No purge protection" }
                   else { "LOW - Compliant" }
    }
} | Export-Csv "Phase3-PreDeploymentAudit.csv"
```

### 2. Exemption Management

**Exemption Categories**:
- **Waiver**: Business exception (e.g., third-party integration requires Access Policies)
- **Mitigated**: Compensating controls exist (e.g., vault isolated in different manner)

**Exemption SLA**:
- Phase 1: 48 hours review
- Phase 2: 72 hours review
- Phase 3: 5 business days review (critical impact)

**Exemption Limits**:
- Maximum 10% of vaults per policy
- Exemptions expire after 90 days (review required)
- Document business justification

### 3. Rollback Procedures

**If Phase deployment causes issues**:

```powershell
# Emergency: Disable enforcement (5-30 min propagation)
Get-AzPolicyAssignment | Where-Object { $_.Name -like "*keyvault*" } |
    ForEach-Object {
        Set-AzPolicyAssignment -Id $_.ResourceId -EnforcementMode DoNotEnforce
    }

# Rollback: Remove policy assignments
Get-AzPolicyAssignment | Where-Object { $_.Name -like "*keyvault*" } |
    ForEach-Object {
        Remove-AzPolicyAssignment -Id $_.ResourceId -Confirm:$false
    }
```

### 4. Testing Requirements

**Before Each Phase**:
1. Deploy to LOWER environment first (Dev/Test)
2. Test vault creation (compliant + non-compliant)
3. Test exemption process
4. Verify rollback procedures
5. Train support team

**Test Cases**:
```powershell
# Test compliant vault creation
New-AzKeyVault -Name "test-compliant-$(Get-Random)" `
    -ResourceGroupName "rg-test" `
    -EnablePurgeProtection `
    -EnableRbacAuthorization

# Test non-compliant vault creation (should be blocked in Deny mode)
try {
    New-AzKeyVault -Name "test-noncompliant-$(Get-Random)" `
        -ResourceGroupName "rg-test"
    # Should not reach here in Deny mode
    Write-Host "❌ FAIL: Non-compliant vault created (policy not enforcing)" -ForegroundColor Red
} catch {
    if ($_.Exception.Message -like "*disallowed by policy*") {
        Write-Host "✅ PASS: Non-compliant vault blocked" -ForegroundColor Green
    } else {
        Write-Host "⚠️ WARN: Blocked but not by policy: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
```

---

## Success Criteria

### Phase 1 Success Metrics
- ✅ Zero production outages
- ✅ < 5 support tickets
- ✅ > 95% compliance after 72 hours
- ✅ Zero rollbacks required

### Phase 2 Success Metrics
- ✅ < 10 production incidents
- ✅ < 20 support tickets
- ✅ > 90% compliance after 7 days
- ✅ < 5% exemption rate

### Phase 3 Success Metrics
- ✅ < 20 production incidents
- ✅ All incidents resolved within 4 hours
- ✅ > 85% compliance after 14 days
- ✅ < 10% exemption rate
- ✅ Documented remediation plan for non-compliant vaults

### Phase 4 Success Metrics
- ✅ Audit mode active
- ✅ Zero blocking
- ✅ Compliance visibility established

---

## Communication Templates

### Stakeholder Status Email (Weekly)

```
SUBJECT: Key Vault Policy Enforcement - Week [X] Status Report

DEPLOYMENT STATUS:
✅ Phase [X] deployed [DATE]
📊 Current compliance: [X]%
🎫 Support tickets: [X] (all resolved)
⚠️ Incidents: [X] (details below)

COMPLIANCE METRICS:
- Compliant vaults: [X] ([X]%)
- Non-compliant vaults: [X] ([X]%)
- Exemptions: [X] ([X]%)

NEXT PHASE:
- Phase [X+1] deployment: [DATE]
- User notification: [DATE]
- Preparation activities: [List]

ISSUES & RESOLUTIONS:
[Document any incidents and how they were resolved]

QUESTIONS: Contact [Security Team]
```

---

## Appendix A: Policy-to-Phase Mapping

### Quick Reference Table

| Phase | Risk | Count | Policies |
|-------|------|-------|----------|
| Phase 1 | 🟢 LOW | 12 | Cert validity, Key/Secret expiration settings, Logging |
| Phase 2 | 🟡 MEDIUM | 18 | Firewall, RBAC, Crypto standards, Private Link (Audit) |
| Phase 3 | 🔴 HIGH | 15 | Purge protection, Required expirations, HSM controls |
| Phase 4 | 🟣 SPECIAL | 1 | Soft-delete (Audit only) |

### Detailed Policy-to-Phase CSV

```csv
Phase,RiskLevel,PolicyName,Effect,Impact,BreaksWhat
1,LOW,Certificate Validity <= 12 months,Deny,Minimal,NEW non-compliant certs
1,LOW,Certificates max validity period,Deny,Minimal,NEW non-compliant certs
1,LOW,Certs from allowed non-integrated CA,Deny,Minimal,NEW certs from wrong CA
...
[All 46 policies listed with phase assignments]
```

---

## Appendix B: Compliance Dashboard Configuration

**Dashboard Metrics to Track**:
1. Overall compliance percentage
2. Compliant vs non-compliant vaults
3. Policy denial events (daily count)
4. Exemptions (active count)
5. Top 5 most-violated policies

**Alert Thresholds**:
- Compliance drops below 80%: Warning
- Compliance drops below 70%: Critical
- > 10 denials/hour: Investigate
- > 20% exemption rate: Review policy

---

## Document History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-01-14 | Initial production rollout plan with phased approach | GitHub Copilot |

---

**APPROVAL REQUIRED**:
- [ ] Security Team
- [ ] Operations Team
- [ ] Compliance Team
- [ ] Leadership

**NEXT REVIEW**: Before Phase 1 deployment (Week 1, Day -3)
