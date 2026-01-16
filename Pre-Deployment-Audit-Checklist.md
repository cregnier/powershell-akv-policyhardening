# Pre-Deployment Audit Checklist
# Azure Key Vault Policy Enforcement - Production Readiness

**Version**: 1.0  
**Date**: January 14, 2026  
**Purpose**: Validate environment readiness before each deployment phase  
**Audience**: Cloud Operations, Security Teams, Policy Administrators

---

## Overview

This checklist ensures that pre-deployment audits are completed before enabling Deny mode policies in production. Each phase has specific audit requirements to identify non-compliant resources and minimize deployment disruption.

**Critical Success Factor**: Complete all audit steps and remediate or exempt non-compliant resources BEFORE switching to Deny mode.

---

## Phase 1: LOW RISK - Certificate/Key/Secret Validity (Week 1)

### Pre-Deployment Audit (3 days before deployment)

**Impact Assessment**: ✅ LOW - Affects NEW resources only

#### ☐ 1.1 Environment Validation
```powershell
# Verify subscription context
Get-AzContext | Select-Object Name, Account, Subscription, Tenant

# Confirm no active deployments
Get-AzDeployment -SubscriptionId <sub-id> | Where-Object { $_.ProvisioningState -eq 'Running' }
# Expected: Zero running deployments (schedule maintenance window)
```

#### ☐ 1.2 Stakeholder Notification
- [ ] Email sent to all Key Vault users (3 days prior)
- [ ] Change management ticket created
- [ ] Support team briefed on Phase 1 policies
- [ ] Exemption process documented and published

#### ☐ 1.3 Baseline Compliance Check
```powershell
# Check current compliance (should already be in Audit mode)
Get-AzPolicyState -SubscriptionId <sub-id> -Filter "PolicySetDefinitionCategory eq 'Key Vault'" | 
    Group-Object ComplianceState | 
    Select-Object Name, Count

# Expected: Compliance data available from Audit mode deployment
```

#### ☐ 1.4 Policy Parameter Validation
- [ ] Certificate validity: Max 12 months ✓
- [ ] Key/Secret expiration warning: 30 days ✓
- [ ] Diagnostic logging enabled ✓
- [ ] Parameters file reviewed: `PolicyParameters.json`

#### ☐ 1.5 Go/No-Go Criteria
- [ ] **GO**: >95% of NEW resources will be compliant (based on Audit data)
- [ ] **GO**: <5 exemption requests submitted
- [ ] **GO**: Zero critical deployments scheduled during rollout window
- [ ] **NO-GO**: >10% non-compliance rate in Audit data
- [ ] **NO-GO**: Active incidents or outages

---

## Phase 2: MEDIUM RISK - Firewall/RBAC/Crypto Standards (Week 2)

### Pre-Deployment Audit (5 days before deployment)

**Impact Assessment**: ⚠️ MEDIUM - Auto-remediation for most, but some vaults may be affected

#### ☐ 2.1 Firewall Configuration Audit
```powershell
# Audit: Identify vaults with public network access (no firewall)
$firewallAudit = Get-AzKeyVault | ForEach-Object {
    $vault = Get-AzKeyVault -VaultName $_.VaultName -ResourceGroupName $_.ResourceGroupName
    [PSCustomObject]@{
        VaultName = $vault.VaultName
        ResourceGroup = $vault.ResourceGroupName
        PublicNetworkAccess = $vault.PublicNetworkAccess
        DefaultAction = $vault.NetworkAcls.DefaultAction
        IPRules = $vault.NetworkAcls.IpAddressRanges.Count
        VNetRules = $vault.NetworkAcls.VirtualNetworkResourceIds.Count
        RiskLevel = if ($vault.NetworkAcls.DefaultAction -eq 'Allow') { 
            'HIGH - Public access without firewall' 
        } elseif ($vault.NetworkAcls.DefaultAction -eq 'Deny' -and 
                  $vault.NetworkAcls.IpAddressRanges.Count -eq 0 -and 
                  $vault.NetworkAcls.VirtualNetworkResourceIds.Count -eq 0) {
            'MEDIUM - Firewall enabled but no rules (may block legitimate access)'
        } else { 
            'LOW - Compliant' 
        }
        AutoRemediation = 'YES - DefaultAction will be set to Deny automatically'
    }
}

$firewallAudit | Export-Csv "Phase2-FirewallAudit-$(Get-Date -Format yyyyMMdd).csv" -NoTypeInformation

# Summary
$firewallAudit | Group-Object RiskLevel | Select-Object Name, Count | Format-Table
```

**Expected Results**:
- **HIGH RISK vaults**: Will have `DefaultAction` auto-set to `Deny` (auto-remediation)
- **Action Required**: Contact vault owners to whitelist IPs BEFORE deployment

#### ☐ 2.2 RBAC Permission Model Audit
```powershell
# Audit: Identify vaults using Access Policies (not RBAC)
$rbacAudit = Get-AzKeyVault | ForEach-Object {
    $vault = Get-AzKeyVault -VaultName $_.VaultName -ResourceGroupName $_.ResourceGroupName
    
    # Check for existing access policies
    $accessPolicyCount = if ($vault.AccessPolicies) { $vault.AccessPolicies.Count } else { 0 }
    
    [PSCustomObject]@{
        VaultName = $vault.VaultName
        ResourceGroup = $vault.ResourceGroupName
        EnableRbacAuthorization = $vault.EnableRbacAuthorization
        AccessPolicyCount = $accessPolicyCount
        AccessPolicyUsers = ($vault.AccessPolicies | Select-Object -ExpandProperty DisplayName) -join ', '
        RiskLevel = if ($vault.EnableRbacAuthorization -eq $false -and $accessPolicyCount -gt 0) { 
            'HIGH - Using Access Policies (will be migrated to RBAC)' 
        } elseif ($vault.EnableRbacAuthorization -eq $false -and $accessPolicyCount -eq 0) {
            'MEDIUM - No RBAC, no Access Policies (needs configuration)'
        } else { 
            'LOW - RBAC already enabled' 
        }
        AutoRemediation = 'YES - EnableRbacAuthorization will be set to True'
        ActionRequired = if ($accessPolicyCount -gt 0) { 
            'CRITICAL: Assign RBAC roles to users/SPs before deployment' 
        } else { 
            'None' 
        }
    }
}

$rbacAudit | Export-Csv "Phase2-RBACPermissionModelAudit-$(Get-Date -Format yyyyMMdd).csv" -NoTypeInformation

# Summary
$rbacAudit | Group-Object RiskLevel | Select-Object Name, Count | Format-Table

# HIGH RISK vaults (Access Policies in use)
Write-Host "`n⚠️ CRITICAL: Vaults with Access Policies (require RBAC migration):" -ForegroundColor Red
$rbacAudit | Where-Object { $_.RiskLevel -like '*HIGH*' } | Format-Table VaultName, AccessPolicyCount, AccessPolicyUsers
```

**Expected Results**:
- **HIGH RISK vaults**: Access Policies will be converted to RBAC
- **Action Required**: 
  1. Document current Access Policy permissions
  2. Map to equivalent RBAC roles
  3. Assign roles BEFORE deployment (5-day window)
  4. Test access after role assignment

**RBAC Role Mapping Reference**:
| Access Policy Permission | RBAC Role |
|--------------------------|-----------|
| Get/List secrets | Key Vault Secrets User |
| Set secrets | Key Vault Secrets Officer |
| Get/List keys | Key Vault Crypto User |
| Create keys | Key Vault Crypto Officer |
| Get/List certificates | Key Vault Certificates User |
| Create certificates | Key Vault Certificates Officer |
| All permissions | Key Vault Administrator |

#### ☐ 2.3 Crypto Algorithm Audit
```powershell
# Audit: Check for weak crypto (keys <2048 bits, non-approved curves)
# Note: This requires querying individual keys (time-intensive)

$cryptoAudit = @()
$vaults = Get-AzKeyVault

foreach ($vault in $vaults) {
    try {
        $keys = Get-AzKeyVaultKey -VaultName $vault.VaultName -ErrorAction SilentlyContinue
        
        foreach ($key in $keys) {
            $keyDetails = Get-AzKeyVaultKey -VaultName $vault.VaultName -Name $key.Name
            
            $isCompliant = $true
            $issue = 'Compliant'
            
            # Check RSA key size
            if ($keyDetails.Key.Kty -eq 'RSA' -and $keyDetails.Key.N.Length * 8 -lt 2048) {
                $isCompliant = $false
                $issue = "RSA key size < 2048 bits ($($keyDetails.Key.N.Length * 8) bits)"
            }
            
            # Check EC curves (approved: P-256, P-384, P-521)
            if ($keyDetails.Key.Kty -eq 'EC' -and 
                $keyDetails.Key.CurveName -notin @('P-256', 'P-384', 'P-521', 'P-256K')) {
                $isCompliant = $false
                $issue = "Non-approved EC curve: $($keyDetails.Key.CurveName)"
            }
            
            if (-not $isCompliant) {
                $cryptoAudit += [PSCustomObject]@{
                    VaultName = $vault.VaultName
                    KeyName = $key.Name
                    KeyType = $keyDetails.Key.Kty
                    Issue = $issue
                    ActionRequired = 'NEW keys with weak crypto will be blocked. Existing keys grandfathered.'
                }
            }
        }
    } catch {
        Write-Host "⚠️ Could not audit keys in $($vault.VaultName): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

$cryptoAudit | Export-Csv "Phase2-CryptoAlgorithmAudit-$(Get-Date -Format yyyyMMdd).csv" -NoTypeInformation

# Summary
Write-Host "`n📊 Crypto Audit Summary:" -ForegroundColor Cyan
Write-Host "  Total vaults audited: $($vaults.Count)" -ForegroundColor White
Write-Host "  Non-compliant keys found: $($cryptoAudit.Count)" -ForegroundColor $(if ($cryptoAudit.Count -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "`nNote: Existing keys are grandfathered. Only NEW keys will be blocked." -ForegroundColor Gray
```

#### ☐ 2.4 Stakeholder Communication
- [ ] Email notification sent (5 days prior) with:
  - Firewall audit results
  - RBAC migration requirements
  - Remediation deadline (3 days before deployment)
  - Exemption request process
- [ ] Remediation workshops scheduled (for HIGH RISK vaults)
- [ ] Support team escalation path documented

#### ☐ 2.5 Go/No-Go Criteria
- [ ] **GO**: All HIGH RISK vaults have RBAC roles assigned
- [ ] **GO**: Firewall IP whitelisting complete for affected vaults
- [ ] **GO**: <20% exemption requests (manageable)
- [ ] **GO**: Zero critical business applications blocked in testing
- [ ] **NO-GO**: >50% of vaults require exemptions
- [ ] **NO-GO**: RBAC migration incomplete (access will break)

---

## Phase 3: HIGH RISK - Purge Protection/Required Expirations (Week 3)

### Pre-Deployment Audit (10 days before deployment)

**Impact Assessment**: 🔴 HIGH - Many vaults likely non-compliant, CRITICAL for NEW vault creation

#### ☐ 3.1 Purge Protection Audit (CRITICAL)
```powershell
# Audit: Identify vaults WITHOUT purge protection
$purgeProtectionAudit = Get-AzKeyVault | ForEach-Object {
    $vault = Get-AzKeyVault -VaultName $_.VaultName -ResourceGroupName $_.ResourceGroupName
    
    [PSCustomObject]@{
        VaultName = $vault.VaultName
        ResourceGroup = $vault.ResourceGroupName
        Location = $vault.Location
        EnablePurgeProtection = $vault.EnablePurgeProtection
        EnableSoftDelete = $vault.EnableSoftDelete
        CreatedDate = $vault.VaultProperties.CreatedDate
        RiskLevel = if ($vault.EnablePurgeProtection -ne $true) { 
            'CRITICAL - No purge protection (CANNOT be added post-creation!)' 
        } else { 
            'LOW - Compliant' 
        }
        Impact = if ($vault.EnablePurgeProtection -ne $true) {
            'EXISTING VAULT: Exemption required. NEW VAULTS: MUST enable during creation or blocked.'
        } else {
            'None'
        }
        CanRemediate = if ($vault.EnablePurgeProtection -ne $true) { 'NO - Must request exemption' } else { 'N/A' }
    }
}

$purgeProtectionAudit | Export-Csv "Phase3-PurgeProtectionAudit-$(Get-Date -Format yyyyMMdd).csv" -NoTypeInformation

# Summary
$purgeProtectionAudit | Group-Object RiskLevel | Select-Object Name, Count | Format-Table

# CRITICAL vaults (no purge protection)
Write-Host "`n🔴 CRITICAL: Vaults WITHOUT purge protection:" -ForegroundColor Red
$criticalVaults = $purgeProtectionAudit | Where-Object { $_.RiskLevel -like '*CRITICAL*' }
$criticalVaults | Format-Table VaultName, ResourceGroup, CreatedDate

Write-Host "`n⚠️ IMPORTANT:" -ForegroundColor Yellow
Write-Host "  - Purge protection CANNOT be added to existing vaults" -ForegroundColor Yellow
Write-Host "  - Exemptions required for $($criticalVaults.Count) vaults" -ForegroundColor Yellow
Write-Host "  - NEW vaults MUST include -EnablePurgeProtection during creation" -ForegroundColor Yellow
Write-Host "  - Update deployment templates/scripts IMMEDIATELY`n" -ForegroundColor Yellow
```

**Expected Results**:
- **CRITICAL vaults**: Cannot comply, require exemptions
- **Action Required**:
  1. Submit exemption requests for all non-compliant vaults (10-day window)
  2. Update ALL vault creation templates to include `-EnablePurgeProtection`
  3. Notify development teams to update deployment scripts
  4. Test vault creation in dev/test with updated templates

#### ☐ 3.2 Required Expiration Audit
```powershell
# Audit: Check keys/secrets/certificates without expiration dates
# Note: Affects NEW resources only, but good to understand current state

$expirationAudit = @()
$vaults = Get-AzKeyVault

foreach ($vault in $vaults) {
    try {
        # Check Keys
        $keys = Get-AzKeyVaultKey -VaultName $vault.VaultName -ErrorAction SilentlyContinue
        foreach ($key in $keys) {
            if (-not $key.Expires) {
                $expirationAudit += [PSCustomObject]@{
                    VaultName = $vault.VaultName
                    ResourceType = 'Key'
                    ResourceName = $key.Name
                    Expires = $key.Expires
                    Impact = 'Existing keys grandfathered. NEW keys will require expiration date.'
                }
            }
        }
        
        # Check Secrets
        $secrets = Get-AzKeyVaultSecret -VaultName $vault.VaultName -ErrorAction SilentlyContinue
        foreach ($secret in $secrets) {
            if (-not $secret.Expires) {
                $expirationAudit += [PSCustomObject]@{
                    VaultName = $vault.VaultName
                    ResourceType = 'Secret'
                    ResourceName = $secret.Name
                    Expires = $secret.Expires
                    Impact = 'Existing secrets grandfathered. NEW secrets will require expiration date.'
                }
            }
        }
        
        # Check Certificates
        $certs = Get-AzKeyVaultCertificate -VaultName $vault.VaultName -ErrorAction SilentlyContinue
        foreach ($cert in $certs) {
            if (-not $cert.Expires) {
                $expirationAudit += [PSCustomObject]@{
                    VaultName = $vault.VaultName
                    ResourceType = 'Certificate'
                    ResourceName = $cert.Name
                    Expires = $cert.Expires
                    Impact = 'Existing certs grandfathered. NEW certs will require expiration date.'
                }
            }
        }
    } catch {
        Write-Host "⚠️ Could not audit $($vault.VaultName): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

$expirationAudit | Export-Csv "Phase3-RequiredExpirationAudit-$(Get-Date -Format yyyyMMdd).csv" -NoTypeInformation

# Summary
Write-Host "`n📊 Expiration Audit Summary:" -ForegroundColor Cyan
$expirationAudit | Group-Object ResourceType | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count) without expiration dates" -ForegroundColor White
}
Write-Host "`nNote: Existing resources grandfathered. Policy affects NEW resources only." -ForegroundColor Gray
```

#### ☐ 3.3 Deployment Template Review
- [ ] Audit all IaC templates (ARM, Bicep, Terraform)
- [ ] Verify `-EnablePurgeProtection` included in vault creation
- [ ] Verify expiration dates set for NEW keys/secrets/certificates
- [ ] Update documentation with new requirements
- [ ] Test templates in dev/test environment

**Example Compliant Template**:
```powershell
# Compliant vault creation (Phase 3)
New-AzKeyVault -Name "vault-production" `
    -ResourceGroupName "rg-production" `
    -Location "eastus" `
    -EnablePurgeProtection `              # REQUIRED (Phase 3)
    -EnableRbacAuthorization `            # REQUIRED (Phase 2)
    -EnableSoftDelete `                   # Platform-enforced (always enabled)
    -SoftDeleteRetentionInDays 90

# Compliant key creation
$policy = New-AzKeyVaultKeyRotationPolicy -KeyName "key1" -ExpiresIn (New-TimeSpan -Days 365)
Add-AzKeyVaultKey -VaultName "vault-production" `
    -Name "key1" `
    -Destination Software `
    -KeyType RSA `
    -Size 2048 `
    -Expires (Get-Date).AddDays(365) `   # REQUIRED (Phase 3)
    -RotationPolicy $policy
```

#### ☐ 3.4 Stakeholder Communication (CRITICAL)
- [ ] **CRITICAL notification** sent (10 days prior) including:
  - Purge protection audit results (vault-by-vault list)
  - Exemption request deadline (7 days before deployment)
  - Template update requirements
  - Remediation workshops scheduled
  - Impact on NEW vault creation (must include purge protection)
- [ ] Executive briefing (if >25% vaults non-compliant)
- [ ] DevOps team training on updated templates
- [ ] Support team prepared for increased ticket volume

#### ☐ 3.5 Go/No-Go Criteria
- [ ] **GO**: All exemption requests processed (approved or rejected)
- [ ] **GO**: <10% exemption rate (<5 vaults need waivers)
- [ ] **GO**: All deployment templates updated and tested
- [ ] **GO**: Zero vault creation failures in dev/test
- [ ] **GO**: Stakeholder approval received
- [ ] **NO-GO**: >25% vaults require exemptions (policy too strict)
- [ ] **NO-GO**: Deployment templates not updated (will break NEW vaults)
- [ ] **NO-GO**: Critical business applications cannot comply

---

## Phase 4: SPECIAL CASE - Soft-Delete Audit Mode (Week 4)

### Pre-Deployment Audit (3 days before deployment)

**Impact Assessment**: ℹ️ INFORMATIONAL - Audit mode only (no blocking)

#### ☐ 4.1 Soft-Delete Status Verification
```powershell
# Verify soft-delete enabled on all vaults (platform-enforced)
$softDeleteAudit = Get-AzKeyVault | ForEach-Object {
    $vault = Get-AzKeyVault -VaultName $_.VaultName -ResourceGroupName $_.ResourceGroupName
    
    [PSCustomObject]@{
        VaultName = $vault.VaultName
        EnableSoftDelete = $vault.EnableSoftDelete
        SoftDeleteRetentionInDays = $vault.SoftDeleteRetentionInDays
        Status = if ($vault.EnableSoftDelete -eq $true) { 
            'Compliant (Platform-enforced)' 
        } else { 
            'ERROR - Soft-delete should be enabled automatically!' 
        }
    }
}

$softDeleteAudit | Export-Csv "Phase4-SoftDeleteAudit-$(Get-Date -Format yyyyMMdd).csv" -NoTypeInformation

# Summary
Write-Host "`n✅ Soft-Delete Status:" -ForegroundColor Green
$compliantCount = ($softDeleteAudit | Where-Object { $_.Status -like '*Compliant*' }).Count
Write-Host "  Compliant vaults: $compliantCount / $($softDeleteAudit.Count)" -ForegroundColor Green

# Any non-compliant vaults (should be zero)
$nonCompliant = $softDeleteAudit | Where-Object { $_.Status -like '*ERROR*' }
if ($nonCompliant.Count -gt 0) {
    Write-Host "`n⚠️ WARNING: Non-compliant vaults found (unexpected):" -ForegroundColor Red
    $nonCompliant | Format-Table VaultName, EnableSoftDelete
}
```

#### ☐ 4.2 Policy Assignment Verification
- [ ] Confirm soft-delete policy deployed in **Audit mode** (not Deny)
- [ ] Verify no blocking of vault creation
- [ ] Confirm compliance tracking active

#### ☐ 4.3 Stakeholder Communication
- [ ] Informational email sent (3 days prior)
- [ ] Explain ARM timing bug and Audit mode workaround
- [ ] Confirm no impact to vault operations
- [ ] No action required from users

#### ☐ 4.4 Go/No-Go Criteria
- [ ] **GO**: Soft-delete policy in Audit mode
- [ ] **GO**: 100% of vaults have soft-delete enabled (platform-enforced)
- [ ] **GO**: Zero vault creation failures
- [ ] **NO-GO**: Policy accidentally set to Deny mode (will block ALL vaults)

---

## Post-Deployment Validation (All Phases)

### ☐ Immediate Validation (Day 0 - Deployment Day)

**Within 1 hour of deployment**:

```powershell
# 1. Verify policy assignments active
Get-AzPolicyAssignment -Scope "/subscriptions/<sub-id>" | 
    Where-Object { $_.Properties.DisplayName -like "*Key Vault*" } |
    Select-Object Name, @{N='EnforcementMode';E={$_.Properties.EnforcementMode}}, 
                  @{N='Effect';E={$_.Properties.Parameters.effect.value}} |
    Format-Table

# 2. Test vault creation (should succeed if compliant)
New-AzKeyVault -Name "test-phase-validation-$(Get-Random)" `
    -ResourceGroupName "rg-policy-test" `
    -Location "eastus" `
    -EnablePurgeProtection `
    -EnableRbacAuthorization
# Expected: Success

# 3. Test non-compliant vault (should be blocked in Deny mode)
New-AzKeyVault -Name "test-noncompliant-$(Get-Random)" `
    -ResourceGroupName "rg-policy-test" `
    -Location "eastus"
# Expected: Error "Resource disallowed by policy" (if Phase 3 deployed)
```

### ☐ 24-Hour Review (Day +1)

**Monitor for issues**:
- [ ] Check support ticket volume (should be <20 tickets)
- [ ] Review policy compliance dashboard
- [ ] Identify any unexpected blocks or access issues
- [ ] Process emergency exemption requests (if any)

**Metrics to track**:
```powershell
# Compliance rate
Get-AzPolicyState -SubscriptionId <sub-id> -Filter "PolicySetDefinitionCategory eq 'Key Vault'" |
    Group-Object ComplianceState |
    Select-Object Name, Count, @{N='Percentage';E={($_.Count / $total * 100).ToString('F2') + '%'}}

# Expected: >85% compliant within 24 hours
```

### ☐ Weekly Review (Day +7)

**Assess deployment success**:
- [ ] Compliance trend analysis (should be improving)
- [ ] Exemption rate <10% (sustainable)
- [ ] No production outages related to policy enforcement
- [ ] User feedback collected and documented
- [ ] Lessons learned documented for next phase

---

## Emergency Rollback Procedures

### If Critical Issues Detected

**Immediate Actions**:

1. **Disable Enforcement** (5-30 minutes):
```powershell
# Disable all Key Vault policy enforcement (emergency only)
Get-AzPolicyAssignment | Where-Object { $_.Properties.DisplayName -like "*Key Vault*" } |
    ForEach-Object {
        Set-AzPolicyAssignment -Id $_.ResourceId -EnforcementMode DoNotEnforce
    }
# Policies remain, compliance tracked, but no blocking
```

2. **Notify Stakeholders**:
- [ ] Incident communication sent (incident #, root cause, ETA)
- [ ] Executive escalation (if business-critical impact)
- [ ] Support team alerted

3. **Root Cause Analysis**:
- [ ] Identify which policy causing issue
- [ ] Review exemption requests
- [ ] Check for unexpected non-compliance

4. **Remediation**:
- [ ] Fix policy parameters (if incorrect configuration)
- [ ] Grant targeted exemptions
- [ ] Update documentation
- [ ] Re-enable enforcement after validation

5. **Full Rollback** (if necessary):
```powershell
# Complete removal (last resort)
Get-AzPolicyAssignment | Where-Object { $_.Properties.DisplayName -like "*Key Vault*" } |
    ForEach-Object {
        Remove-AzPolicyAssignment -Id $_.ResourceId
    }
```

---

## Appendix: Audit Scripts Summary

### Quick Reference

| Phase | Audit Script | Purpose | Critical Findings |
|-------|--------------|---------|-------------------|
| 1 | Baseline Compliance | Verify Audit mode compliance | >95% compliance expected |
| 2 | Firewall Audit | Identify public vaults | Auto-remediation (no blocking) |
| 2 | RBAC Audit | Identify Access Policy vaults | CRITICAL: Assign RBAC roles |
| 2 | Crypto Audit | Check weak algorithms | NEW resources only |
| 3 | Purge Protection | Identify non-compliant vaults | CRITICAL: Cannot remediate, need exemptions |
| 3 | Expiration Audit | Check resources without expiration | NEW resources only |
| 4 | Soft-Delete | Verify platform enforcement | Should be 100% compliant |

### Complete Audit Execution

**Run all audits in sequence**:
```powershell
# Set subscription context
Set-AzContext -SubscriptionId "<sub-id>"

# Phase 2 Audits
.\Phase2-FirewallAudit.ps1
.\Phase2-RBACPermissionModelAudit.ps1
.\Phase2-CryptoAlgorithmAudit.ps1

# Phase 3 Audits (CRITICAL)
.\Phase3-PurgeProtectionAudit.ps1
.\Phase3-RequiredExpirationAudit.ps1

# Phase 4 Audit
.\Phase4-SoftDeleteAudit.ps1

# Consolidate results
$auditResults = @{
    FirewallAudit = Import-Csv "Phase2-FirewallAudit-*.csv"
    RBACAccountAudit = Import-Csv "Phase2-RBACPermissionModelAudit-*.csv"
    PurgeProtectionAudit = Import-Csv "Phase3-PurgeProtectionAudit-*.csv"
}

# Generate executive summary
$auditResults | ConvertTo-Json -Depth 10 | Out-File "ExecutiveAuditSummary-$(Get-Date -Format yyyyMMdd).json"
```

---

**Document Version**: 1.0  
**Last Updated**: January 14, 2026  
**Owner**: Cloud Governance Team  
**Next Review**: After Phase 3 deployment
