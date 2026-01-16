# Comprehensive Testing Plan - Azure Key Vault Policy Governance

**Date**: January 16, 2026  
**Environment**: MSDN Platforms Subscription (Test)  
**Status**: Fresh Environment - Ready for Testing

---

## ✅ Step 1 & 2: Environment Cleanup - COMPLETE

**Completed**: All resources cleaned and recreated

**Infrastructure Created**:
- ✅ Managed Identity: `id-policy-remediation`
- ✅ VNet: `vnet-policy-test` with subnet `snet-privateendpoints`
- ✅ Private DNS Zone: `privatelink.vaultcore.azure.net`
- ✅ Log Analytics: `law-policy-test-1911`
- ✅ Event Hub: `eh-policy-test-3856`

**Test Vaults Created**:
- ✅ `kv-compliant-2674` - Fully compliant (soft delete, purge protection, RBAC, firewall disabled)
- ✅ `kv-partial-4991` - Partially compliant (some features missing)
- ✅ `kv-noncompliant-3526` - Non-compliant (minimal compliance)

**Test Data Seeded**:
- ✅ 12 Secrets (various expiration states)
- ✅ 15 Keys (various types, sizes, expiration states)
- ✅ 9 Certificates (various validity periods, issuers)

---

## 📋 Step 3: DevTest Testing (CRITICAL 30 + FULL 46)

### Scenario 3.1: DevTest Critical (30 Policies - Audit Mode)

**Parameter File**: `PolicyParameters-DevTest.json`  
**Expected Policies**: 30 (critical/essential policies only)  
**Mode**: Audit  
**Purpose**: Baseline testing with essential policies

**Command**:
```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest.json `
    -IdentityResourceId '/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation' `
    -SkipRBACCheck
```

**Expected Results**:
- ✅ 30/30 policy assignments successful
- ✅ Deployment time: ~60-90 seconds
- ✅ All in Audit mode (no blocking)
- ⏳ Wait 5 minutes for compliance data

**Validation**:
```powershell
# Check compliance after 5 minutes
.\AzPolicyImplScript.ps1 -CheckCompliance -SkipRBACCheck

# Verify 30 assignments created
Get-AzPolicyAssignment | Where-Object { $_.Name -like '*vault*' } | Measure-Object
```

---

### Scenario 3.2: DevTest Full (46 Policies - Audit Mode)

**Parameter File**: `PolicyParameters-DevTest-Full.json`  
**Expected Policies**: 46 (all available Azure Key Vault policies)  
**Mode**: Audit  
**Purpose**: Comprehensive testing with full policy coverage

**Cleanup First**:
```powershell
# Remove Scenario 3.1 assignments
.\AzPolicyImplScript.ps1 -Rollback -SkipRBACCheck
```

**Command**:
```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full.json `
    -IdentityResourceId '/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation' `
    -SkipRBACCheck
```

**Expected Results**:
- ✅ 46/46 policy assignments successful
- ✅ Deployment time: ~80-120 seconds
- ✅ All in Audit mode
- ⏳ Wait 5 minutes for compliance data

---

### Scenario 3.3: DevTest Auto-Remediation (46 Policies with 9 DeployIfNotExists/Modify)

**Parameter File**: `PolicyParameters-DevTest-Full-Remediation.json`  
**Expected Policies**: 46 (9 with auto-remediation via managed identity)  
**Mode**: Mixed (Audit + DeployIfNotExists/Modify)  
**Purpose**: Test automatic compliance remediation

**Cleanup First**:
```powershell
.\AzPolicyImplScript.ps1 -Rollback -SkipRBACCheck
```

**Command**:
```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -IdentityResourceId '/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation' `
    -SkipRBACCheck
```

**Expected Results**:
- ✅ 46/46 policy assignments successful
- ✅ 9 policies with managed identity (auto-remediation)
- ✅ 37 policies in Audit mode
- ⏳ Wait 30-60 minutes for remediation tasks

**9 Auto-Remediation Policies**:
1. Deploy diagnostic settings to Log Analytics
2. Deploy diagnostic settings to Event Hub (Key Vault)
3. Deploy diagnostic settings to Event Hub (Managed HSM)
4. Configure private endpoints (Key Vault)
5. Configure private endpoints (Managed HSM)
6. Configure private DNS zones
7. Configure firewall
8. Configure Managed HSM to disable public network access
9. Configure Managed HSM firewall

---

## 📋 Step 4: Production Testing (46 Policies - Phased Approach)

### ⚠️ IMPORTANT: Corporate AAD-Based Subscription Guidance

**Phase 1: Audit Mode (30-90 days)**
- Deploy all 46 policies in **Audit** mode
- Monitor compliance without blocking operations
- Identify non-compliant resources and remediation needs
- Communicate findings to stakeholders

**Phase 2: Deny Mode (60-90 days)**
- Switch to **Deny** mode gradually (by policy category)
- Prevents NEW non-compliant resources
- Existing resources remain functional
- Validate no critical automation is broken

**Phase 3: Enforce Mode (Production)**
- Enable **DeployIfNotExists/Modify** for automatic remediation
- Schedule maintenance window
- Monitor remediation tasks
- Have rollback plan ready

---

### Scenario 4.1: Production Audit (46 Policies - MSDN Test)

**Parameter File**: `PolicyParameters-Production.json`  
**Expected Policies**: 46  
**Mode**: Audit (SAFE for MSDN test - will use Deny in corporate)  
**Purpose**: Test production configuration without blocking

**Cleanup First**:
```powershell
.\AzPolicyImplScript.ps1 -Rollback -SkipRBACCheck
```

**Command**:
```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Audit `
    -IdentityResourceId '/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation' `
    -SkipRBACCheck
```

**Expected Results**:
- ✅ 46/46 policies deployed
- ✅ All in Audit mode (safe testing)
- ✅ Production-grade parameters (stricter than DevTest)

---

### Scenario 4.2: Production Deny Mode (46 Policies - MSDN Test)

**Parameter File**: `PolicyParameters-Production.json`  
**Expected Policies**: 46  
**Mode**: Deny (blocks non-compliant operations)  
**Purpose**: Test enforcement blocking

**Cleanup First**:
```powershell
.\AzPolicyImplScript.ps1 -Rollback -SkipRBACCheck
```

**Command**:
```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Deny `
    -IdentityResourceId '/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation' `
    -SkipRBACCheck
```

**⚠️ WARNING**: This will require typing **PROCEED** to confirm!

**Expected Results**:
- ✅ 46/46 policies deployed in Deny mode
- ✅ Blocks creation of non-compliant vaults
- ✅ Run enforcement tests: `.\AzPolicyImplScript.ps1 -TestProductionEnforcement`

---

### Scenario 4.3: Production Auto-Remediation (46 Policies)

**Parameter File**: `PolicyParameters-Production-Remediation.json`  
**Expected Policies**: 46 (9 with DeployIfNotExists/Modify)  
**Mode**: Mixed (Deny + Auto-Remediation)  
**Purpose**: Full production enforcement with automatic compliance

**Cleanup First**:
```powershell
.\AzPolicyImplScript.ps1 -Rollback -SkipRBACCheck
```

**Command**:
```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -IdentityResourceId '/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation' `
    -SkipRBACCheck
```

**Expected Results**:
- ✅ 46/46 policies deployed
- ✅ 37 policies in Deny mode (blocking)
- ✅ 9 policies with auto-remediation
- ⏳ Wait 30-60 minutes for remediation tasks

---

## 📋 Step 5: Policy Mode Coverage & Best Practices

### Mode Distribution Across All Scenarios

| Scenario | Total Policies | Audit | Deny | Audit-IfNotExists | DeployIfNotExists | Modify |
|----------|----------------|-------|------|-------------------|-------------------|--------|
| 3.1 DevTest (30) | 30 | 30 | 0 | 0 | 0 | 0 |
| 3.2 DevTest Full (46) | 46 | 46 | 0 | 0 | 0 | 0 |
| 3.3 DevTest Remediation | 46 | 37 | 0 | 2 | 6 | 1 |
| 4.1 Production Audit | 46 | 46 | 0 | 0 | 0 | 0 |
| 4.2 Production Deny | 46 | 0 | 46 | 0 | 0 | 0 |
| 4.3 Production Remediation | 46 | 0 | 37 | 2 | 6 | 1 |

### Best Practices Applied

✅ **Audit Mode** (Discovery Phase)
- Monitor compliance without blocking
- Identify non-compliant resources
- Build business case for enforcement
- Used in: Scenarios 3.1, 3.2, 4.1

✅ **Deny Mode** (Prevention Phase)
- Prevents NEW non-compliant resources
- No impact on existing resources
- Safe incremental enforcement
- Used in: Scenario 4.2

✅ **DeployIfNotExists/Modify** (Automation Phase)
- Automatic compliance remediation
- Requires managed identity with permissions
- Scheduled during maintenance windows
- Used in: Scenarios 3.3, 4.3

✅ **AuditIfNotExists** (Compliance Verification)
- Validates existence of configurations
- Non-blocking validation
- Used for: Diagnostic logs, private endpoints

---

## 📋 Step 6: HTML Report Data Integrity Validation

### Report Validation Checklist

After EACH scenario deployment, verify:

**1. Deployment Metadata**
```powershell
# Open HTML report
.\PolicyImplementationReport-YYYYMMDD-HHMMSS.html
```

✅ Check:
- [ ] Scenario name displayed correctly
- [ ] Parameter file path shown
- [ ] Deployment timestamp accurate
- [ ] Subscription ID correct
- [ ] Scope type (Subscription) shown

**2. Policy Assignment Summary**
✅ Check:
- [ ] Total policies deployed matches expected count
- [ ] Success count = expected policies
- [ ] Failed count = 0
- [ ] Skipped count = 0
- [ ] Deployment duration shown

**3. Policy Details Table**
✅ Check:
- [ ] All policies listed with display names
- [ ] Policy definition IDs present
- [ ] Effect modes correct (Audit/Deny/DeployIfNotExists)
- [ ] Parameter values shown
- [ ] Assignment IDs populated

**4. Compliance Data** (after 5-minute wait)
```powershell
# Re-run compliance check
.\AzPolicyImplScript.ps1 -CheckCompliance -SkipRBACCheck
```

✅ Check:
- [ ] Overall compliance % calculated
- [ ] Policies reporting count > 0
- [ ] Compliant resource count
- [ ] Non-compliant resource count
- [ ] Resource details table populated

**5. Operational Metrics**
✅ Check:
- [ ] Key Vault count = 3 (test vaults)
- [ ] Policy evaluation states shown
- [ ] Compliance trends (if multiple runs)
- [ ] Phase 2.3 enforcement tests (Deny mode scenarios)

---

## 📋 Phased Corporate Deployment Guide

### Timeline for Corporate AAD-Based Subscriptions

**Referenced in**: DEPLOYMENT-WORKFLOW-GUIDE.md

**Month 1-3: Audit Phase**
```powershell
# Deploy all 46 policies in Audit mode
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Audit `
    -ScopeType Subscription

# Generate weekly compliance reports
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan
```

**Activities**:
- Weekly compliance reviews
- Identify non-compliant resources
- Remediate violations manually
- Communicate to stakeholders
- Create exemptions for exceptions
- Update deployment templates

**Month 4-6: Deny Phase (Gradual Rollout)**
```powershell
# Switch to Deny mode (tier by tier)
# Start with Tier 1 (9 critical policies)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Tier1-Deny.json `
    -PolicyMode Deny `
    -ScopeType Subscription
```

**Activities**:
- Monitor for blocked operations
- Validate no critical automation broken
- Adjust exemptions as needed
- Gradually add Tier 2, 3, 4

**Month 7+: Enforce Phase (Auto-Remediation)**
```powershell
# Enable auto-remediation
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -ScopeType Subscription
```

**Activities**:
- Schedule maintenance window
- Monitor remediation tasks
- Verify compliance improvements
- Maintain exemptions

---

## 📋 Testing Execution Checklist

### Pre-Testing
- [x] Environment cleaned completely
- [x] Infrastructure resources created
- [x] Test vaults created with data
- [x] Managed identity configured with RBAC
- [x] Parameter files reviewed and correct

### Testing Sequence

**Day 1: DevTest Scenarios**
- [ ] Scenario 3.1: DevTest Critical (30 policies)
  - [ ] Deploy
  - [ ] Wait 5 minutes
  - [ ] Check compliance
  - [ ] Validate HTML report
  - [ ] Cleanup

- [ ] Scenario 3.2: DevTest Full (46 policies)
  - [ ] Deploy
  - [ ] Wait 5 minutes
  - [ ] Check compliance
  - [ ] Validate HTML report
  - [ ] Cleanup

- [ ] Scenario 3.3: DevTest Auto-Remediation
  - [ ] Deploy
  - [ ] Wait 30-60 minutes
  - [ ] Check compliance
  - [ ] Verify remediation tasks
  - [ ] Validate HTML report
  - [ ] Cleanup

**Day 2: Production Scenarios**
- [ ] Scenario 4.1: Production Audit (46 policies)
  - [ ] Deploy
  - [ ] Wait 5 minutes
  - [ ] Check compliance
  - [ ] Validate HTML report
  - [ ] Cleanup

- [ ] Scenario 4.2: Production Deny (46 policies)
  - [ ] Deploy (confirm PROCEED)
  - [ ] Wait 5 minutes
  - [ ] Run enforcement tests
  - [ ] Check compliance
  - [ ] Validate HTML report
  - [ ] Cleanup

- [ ] Scenario 4.3: Production Auto-Remediation
  - [ ] Deploy (confirm PROCEED)
  - [ ] Wait 30-60 minutes
  - [ ] Check compliance
  - [ ] Verify remediation tasks
  - [ ] Validate HTML report
  - [ ] Final cleanup

---

## 📊 Success Criteria

### Deployment Success
- ✅ All scenarios deploy expected policy count
- ✅ 100% success rate (0 failures)
- ✅ Deployment times under 2 minutes (except remediation waits)
- ✅ All parameter files load correct policy count
- ✅ Metadata fields (_comment, _description) filtered out

### Compliance Reporting
- ✅ Compliance data available within 5 minutes
- ✅ HTML reports generated successfully
- ✅ All data fields populated
- ✅ Compliance % calculated correctly
- ✅ Resource details accurate

### Enforcement Testing
- ✅ Deny mode blocks non-compliant operations
- ✅ Enforcement tests pass 100%
- ✅ Auto-remediation creates tasks
- ✅ Remediation completes within 60 minutes

### Documentation
- ✅ All scenarios documented with commands
- ✅ Corporate deployment guide complete
- ✅ Best practices applied throughout
- ✅ Rollback procedures validated

---

## 🔧 Troubleshooting

### Common Issues

**Issue**: Policy deployment attempts 46 policies when only subset expected  
**Solution**: ✅ FIXED - JSON now determines which policies to deploy

**Issue**: Compliance data shows 0% after deployment  
**Solution**: Wait 5-10 minutes for Azure Policy evaluation cycle

**Issue**: Auto-remediation policies skip deployment  
**Solution**: Ensure `-IdentityResourceId` parameter provided with full ARM resource ID

**Issue**: Production Deny deployment blocks immediately  
**Solution**: Expected behavior - type PROCEED to confirm enforcement

**Issue**: HTML report missing compliance data  
**Solution**: Run `-CheckCompliance` separately after 5-minute wait

---

## 📚 Reference Documents

1. **DEPLOYMENT-WORKFLOW-GUIDE.md** - Corporate phased deployment
2. **PolicyParameters-QuickReference.md** - Parameter file selection guide
3. **DEPLOYMENT-PREREQUISITES.md** - Infrastructure requirements
4. **Comprehensive-Test-Plan.md** - Original 8-scenario testing plan (superseded by this document)

---

**Last Updated**: January 16, 2026  
**Status**: Ready for execution
