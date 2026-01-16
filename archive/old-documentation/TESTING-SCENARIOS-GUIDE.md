# Testing Scenarios Guide - Azure Key Vault Policy Framework

**Last Updated**: January 15, 2026  
**Current Status**: Scenario 1 in progress (DevTest 30 policies)  
**Infrastructure**: ✅ Ready (VNet, Log Analytics, Event Hub, 3 test Key Vaults)

---

## 📋 Complete Testing Matrix

### Phase 1: Core Testing Scenarios (DevTest → Production)

| Scenario | Parameter File | Policies | Mode | Managed Identity Required | Command |
|----------|---------------|----------|------|---------------------------|---------|
| **1. DevTest Safe** | `PolicyParameters-DevTest.json` | **30** | Audit | ❌ No | `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -SkipRBACCheck` |
| **2. DevTest Full** | `PolicyParameters-DevTest-Full.json` | **46** | Audit | ❌ No | `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -SkipRBACCheck` |
| **3. DevTest Remediation** | `PolicyParameters-DevTest-Full-Remediation.json` | **46** (9 remediate) | Audit + DINE/Modify | ✅ Yes | `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json -IdentityResourceId '/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation' -SkipRBACCheck` |
| **4. Production Deny** | `PolicyParameters-Production.json` | **46** | **Deny** | ❌ No | `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -SkipRBACCheck` (Type 'PROCEED') |
| **5. Production Remediation** | `PolicyParameters-Production-Remediation.json` | **46** (9 remediate) | **Deny** + DINE/Modify | ✅ Yes | `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Remediation.json -IdentityResourceId '/subscriptions/.../id-policy-remediation' -SkipRBACCheck` |

---

### Phase 2: Corporate Tier Deployment Testing

| Tier | Parameter Files | Policies | Purpose | Timeline | Command |
|------|----------------|----------|---------|----------|---------|
| **Tier 1** | `PolicyParameters-Tier1-Audit.json`<br>`PolicyParameters-Tier1-Deny.json` | **9** each | Baseline security (low impact) | Corporate Months 1-3 | `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Tier1-Audit.json -SkipRBACCheck` |
| **Tier 2** | `PolicyParameters-Tier2-Audit.json`<br>`PolicyParameters-Tier2-Deny.json` | **25** each | Lifecycle management (moderate impact) | Corporate Months 4-9 | `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Tier2-Audit.json -SkipRBACCheck` |
| **Tier 3** | `PolicyParameters-Tier3-Audit.json`<br>`PolicyParameters-Tier3-Deny.json` | **3** each | Infrastructure (high impact, high cost) | Corporate Months 10-12+ | `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Tier3-Audit.json -SkipRBACCheck` |
| **Tier 4** | `PolicyParameters-Tier4-Remediation.json` | **9** | Auto-remediation (parallel deployment) | Corporate Months 1-6 | `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Tier4-Remediation.json -IdentityResourceId '/subscriptions/.../id-policy-remediation' -SkipRBACCheck` |

**Tier Coverage Validation**: 9 + 25 + 3 + 9 = **46 total policies** ✅

---

## 🎯 Current Testing Status

### ✅ Completed
- Infrastructure setup (VNet, Log Analytics, Event Hub, DNS, Managed Identity, 3 test Key Vaults)
- 41 old policy assignments removed
- Environment clean and ready

### 🔄 In Progress
- **Scenario 1: DevTest Safe (30 policies)**
  - Status: Deployment completed with warnings
  - Issue: Script processed all 46 policies from CSV, but parameter file only has 30
  - 25 policies successfully assigned, 14 warnings (expected - those policies not in DevTest.json)
  - 7 policies skipped (require managed identity, not provided)
  - Next: Wait 60 minutes for Azure Policy evaluation

### ⏹️ Pending
- Scenarios 2-5 (DevTest Full → Production)
- Tier scenarios (7 corporate deployment files)
- Report validation
- Documentation update

---

## 📊 Policy Distribution Breakdown

### Scenario 1: DevTest Safe (30 Policies)
**Focus**: Low-risk baseline policies for safe initial testing

✅ **Successfully Assigned (25 policies)**:
- Soft delete enabled
- Deletion protection enabled
- Public network access disabled
- Firewall enabled
- Certificate/Key/Secret validity periods
- Expiration dates
- Rotation policies
- RSA key size minimums
- Certificate authority restrictions
- Elliptic curve restrictions
- Resource logs enabled (2 policies - AuditIfNotExists)
- RBAC permission model
- Managed HSM purge protection
- Managed HSM key standards

⚠️ **Skipped - Require Managed Identity (7 policies)**:
- Configure Managed HSM public network access (Modify)
- Deploy diagnostics to Log Analytics (DeployIfNotExists)
- Configure Key Vaults with private endpoints (DeployIfNotExists)
- Deploy diagnostics to Event Hub (Managed HSM) (DeployIfNotExists)
- Configure Key Vaults with private DNS zones (DeployIfNotExists)
- Configure Key Vaults firewall (Modify)
- Configure Managed HSM with private endpoints (DeployIfNotExists)
- Deploy diagnostics to Event Hub (Key Vault) (DeployIfNotExists)

❌ **Not in DevTest.json (14 policies)** - Expected, these are in DevTest-Full.json:
- Certificates lifetime action triggers (missing params)
- Secrets maximum validity period (missing params)
- Keys maximum validity period (missing params)
- Keys minimum days before expiration (missing params)
- Keys using RSA cryptography minimum key size (missing params)
- Certificates non-integrated CA (missing params)
- Certificates non-integrated CAs list (missing params)
- Certificates RSA key size (missing params)
- Keys rotation policy (missing params)
- Keys not active longer than specified days (missing params)
- Secrets not active longer than specified days (missing params)
- Certificates not expire within specified days (missing params)
- Managed HSM Keys minimum days before expiration
- Managed HSM Keys using elliptic curve

---

## 🔧 How to Use This Guide

### Step-by-Step Testing Process

1. **Before Each Scenario**:
   ```powershell
   # Check current policy assignments
   Get-AzPolicyAssignment | Where-Object { $_.Name -like '*keyvault*' } | Measure-Object
   
   # If > 0, clean up previous test
   Get-AzPolicyAssignment | Where-Object { $_.Name -like '*keyvault*' } | ForEach-Object { Remove-AzPolicyAssignment -Id $_.Id }
   ```

2. **Deploy Policies**:
   - Copy the exact command from the table above for your scenario
   - Paste into PowerShell terminal
   - For Production scenarios, type `PROCEED` when prompted

3. **Wait for Azure Policy Evaluation**:
   ```powershell
   # Azure Policy evaluation takes 60 minutes minimum
   # - Assignment propagation: 30-90 minutes across regions
   # - Resource scanning: 15-30 minutes
   # - Compliance calculation: 10-15 minutes
   
   Write-Host "Waiting 60 minutes for Azure Policy evaluation..."
   Start-Sleep -Seconds 3600  # Or just wait manually
   ```

4. **Generate Compliance Report**:
   ```powershell
   .\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
   ```

5. **Validate Report**:
   ```powershell
   .\AzPolicyImplScript.ps1 -ValidateReport -SkipRBACCheck
   ```

6. **Review Results**:
   - Open the generated HTML report: `PolicyImplementationReport-<timestamp>.html`
   - Check compliance percentage (expect 60-80% for DevTest, higher for Production)
   - Verify all policies are reporting data (no 0 evaluations)

---

## 🚨 Common Issues & Solutions

### Issue 1: "Missing parameter(s)" Warnings
**Cause**: Script processes all 46 policies from DefinitionListExport.csv, but parameter file doesn't have all 46  
**Expected**: DevTest.json has 30 policies, so 16 policies will show warnings  
**Solution**: This is NORMAL - warnings are expected when using subset parameter files

### Issue 2: "Requires managed identity" Warnings
**Cause**: DeployIfNotExists/Modify policies need `-IdentityResourceId` parameter  
**Expected**: 7-9 policies will be skipped in Audit-only scenarios  
**Solution**: Use Remediation parameter files with `-IdentityResourceId` to enable these policies

### Issue 3: Compliance Shows 0% After Deployment
**Cause**: Azure Policy hasn't finished evaluating resources yet  
**Expected**: Initial compliance reports show partial/no data for 30-90 minutes  
**Solution**: Wait 60 minutes, then regenerate report with `-TriggerScan`

### Issue 4: Policy Assignment Already Exists
**Cause**: Previous test wasn't cleaned up  
**Expected**: Assignments from previous scenarios remain  
**Solution**: Run cleanup command before each new scenario (see Step-by-Step above)

---

## 📝 Parameter File Quick Reference

| File | Count | Use When | Notes |
|------|-------|----------|-------|
| `DevTest.json` | 30 | Initial safe testing | No managed identity needed, all parameters complete |
| `DevTest-Full.json` | 46 | Comprehensive Audit testing | All 46 policies, Audit mode |
| `DevTest-Full-Remediation.json` | 46 | Testing auto-remediation | Requires managed identity |
| `Production.json` | 46 | Production enforcement | **Deny mode** - blocks non-compliant resources |
| `Production-Remediation.json` | 46 | Production + auto-fix | Deny mode + auto-remediation |
| `Tier1-Audit.json` | 9 | Corporate Month 1 | Baseline security |
| `Tier1-Deny.json` | 9 | Corporate Month 2-3 | Baseline enforcement |
| `Tier2-Audit.json` | 25 | Corporate Months 4-5 | Lifecycle policies |
| `Tier2-Deny.json` | 25 | Corporate Months 6-9 | Lifecycle enforcement |
| `Tier3-Audit.json` | 3 | Corporate Months 10+ | High-cost infrastructure |
| `Tier3-Deny.json` | 3 | Corporate Months 12+ | Infrastructure enforcement |
| `Tier4-Remediation.json` | 9 | Corporate Months 1-6 | Auto-remediation (parallel) |

---

## 🎯 Success Criteria

### Scenario 1: DevTest Safe (30 policies)
- ✅ 25-30 policies successfully assigned
- ✅ Compliance: 60-75% (initial DevTest environment)
- ✅ No blocking errors (Audit mode doesn't block)
- ✅ HTML report generated with valid data

### Scenarios 2-3: DevTest Full (46 policies)
- ✅ 40-46 policies successfully assigned
- ✅ Compliance: 65-80%
- ✅ Auto-remediation policies working (Scenario 3)

### Scenarios 4-5: Production (46 policies Deny)
- ✅ All 46 policies assigned
- ✅ Blocking validation passes (non-compliant resources blocked)
- ✅ Compliance: 80-95%
- ✅ No critical automation broken

### Tier Scenarios
- ✅ Tier totals: 9 + 25 + 3 + 9 = 46 policies
- ✅ No overlap (each policy in exactly one tier)
- ✅ Compliance increases with each tier deployment

---

## 🔍 Where We Are Now

**Current Scenario**: Scenario 1 - DevTest Safe (30 policies)  
**Command Used**: `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -SkipRBACCheck`  
**Status**: Deployment complete, 25 policies assigned  
**Next Action**: Wait 60 minutes, then run compliance check  

**Next Command to Run**:
```powershell
# Wait 60 minutes from deployment time (16:34 UTC + 60 min = 17:34 UTC)
# Then run:
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**After Compliance Check**:
```powershell
# Validate the HTML report
.\AzPolicyImplScript.ps1 -ValidateReport -SkipRBACCheck

# Review report (open in browser)
ii .\PolicyImplementationReport-*.html | Select-Object -Last 1
```

---

## 📅 Estimated Timeline

| Phase | Duration | Details |
|-------|----------|---------|
| Scenario 1 (DevTest 30) | 90 min | Deploy 5 min + Wait 60 min + Report 5 min + Validate 5 min + Cleanup 5 min |
| Scenario 2 (DevTest Full 46) | 90 min | Same timing |
| Scenario 3 (Remediation 46) | 90 min | Same timing |
| Scenario 4 (Production Deny 46) | 90 min | Same timing + blocking tests |
| Scenario 5 (Prod Remediation 46) | 90 min | Same timing |
| Tier Scenarios (7 files) | 90 min each | Can batch some together |
| **Total Estimated Time** | **8-10 hours** | Mostly waiting for Azure Policy evaluation |

---

**Remember**: Azure Policy evaluation cannot be rushed. The 60-minute wait is mandatory for Azure's backend evaluation process. Use this time to review reports, update documentation, or work on other tasks.
