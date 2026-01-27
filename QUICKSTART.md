# Quick Start Guide - Azure Key Vault Policy Governance

**Version**: 2.1  
**Last Updated**: 2026-01-27  
**Prerequisites Time**: 10 minutes  
**Deployment Time**: 5 minutes  
**Test Results**: 25/34 Deny Policies Validated (74% in MSDN) | 46/46 Total Policies Deployed

---

## 🎯 The 5 Ws and H

| Question | Answer |
|----------|--------|
| **WHO** | Azure administrators deploying Key Vault governance policies |
| **WHAT** | Step-by-step guide to deploy 46 Azure Key Vault policies |
| **WHEN** | Follow this guide for your first deployment (DevTest → Production) |
| **WHERE** | Azure subscription/resource group with Key Vault resources |
| **WHY** | Quickly establish secure, compliant Key Vault governance |
| **HOW** | PowerShell automation with pre-configured parameter files |

---

## ⚡ 5-Minute Deployment

### Prerequisites (One-Time Setup)

```powershell
# 1. Verify PowerShell version (requires 7.0+)
$PSVersionTable.PSVersion

# 2. Install required Azure modules (~5 minutes first time)
Install-Module -Name Az.Accounts, Az.Resources, Az.PolicyInsights, Az.KeyVault -Force -Scope CurrentUser

# 3. Connect to your Azure subscription
Connect-AzAccount
Set-AzContext -Subscription "<your-subscription-id>"

# 4. Clone repository and navigate
git clone https://github.com/cregnier/powershell-akv-policyhardening.git
cd powershell-akv-policyhardening
```

---

### Option 1: DevTest Safe Start (Recommended First Deployment)

**What**: 30 policies in Audit mode - monitors but doesn't block  
**Why**: Safe testing without impacting existing resources  
**Timeline**: 5 minutes deployment + 15-30 minutes Azure evaluation

```powershell
# Get managed identity created during infrastructure setup
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# Deploy policies with managed identity (ensures all 30 policies deploy)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest.json `
    -PolicyMode Audit `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck

# Check compliance (wait 15-30 min for Azure Policy evaluation)
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck

# View HTML report
Get-Item ComplianceReport-*.html | Select-Object -First 1 | ForEach-Object { Start-Process $_.FullName }
```

**Expected Result**:
- ✅ 30/30 policies assigned in Audit mode (includes 8 DINE/Modify policies)
- ✅ HTML compliance report generated with VALUE-ADD metrics ($60K/yr, 135 hrs/yr)
- ✅ No blocking of existing operations
- ✅ Auto-remediation policies ready (will fix non-compliance automatically)

**📊 See Also**: [MasterTestReport-20260127-143212.html](MasterTestReport-20260127-143212.html) for comprehensive stakeholder summary

---

### Option 2: Full Testing Environment (After DevTest Success)

**What**: All 46 policies in Audit mode  
**Why**: Complete governance testing before production  
**Timeline**: 5 minutes deployment + 30 minutes evaluation

```powershell
# Get managed identity
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# Deploy all 46 policies with managed identity
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full.json `
    -PolicyMode Audit `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck

# Run comprehensive tests
.\AzPolicyImplScript.ps1 -TestInfrastructure -Detailed -SkipRBACCheck
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**Expected Result**:
- ✅ 46/46 policies assigned successfully (complete coverage)
- ✅ All infrastructure tests pass
- ✅ Complete compliance baseline established

---

### Option 2.5: Auto-Remediation Testing (Optional - Advanced)

**What**: 8 auto-remediation policies (DeployIfNotExists/Modify effects)  
**Why**: Automatically fix non-compliant resources instead of just monitoring  
**Requires**: Managed Identity with Contributor role (created by setup script)  
**Timeline**: 5 minutes deployment + 30-60 minutes Azure auto-remediation

**💡 Note**: If you used `-IdentityResourceId` in Options 1 & 2, you already deployed these policies! This section tests them in isolation.

```powershell
# Get managed identity (created by Setup-AzureKeyVaultPolicyEnvironment.ps1)
$identity = Get-AzUserAssignedIdentity -ResourceGroupName "rg-policy-remediation" -Name "id-policy-remediation"
$identityId = $identity.Id

# Deploy ONLY the 8 auto-remediation policies
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck

# Test auto-remediation (creates test vault, waits for Azure to fix compliance)
.\AzPolicyImplScript.ps1 -TestAutoRemediation -SkipRBACCheck
```

**What Auto-Remediation Policies Do**:
- Enable diagnostic logging automatically
- Configure private DNS zones
- Deploy network security settings
- Modify resource configurations to meet compliance

**Expected Result**:
- ✅ 8 remediation policies deployed with managed identity
- ✅ Non-compliant resources automatically fixed by Azure
- ✅ Remediation tasks visible in Azure Portal (Policy → Remediation)

**📖 See Also**: [PolicyParameters-QuickReference.md](PolicyParameters-QuickReference.md) for complete parameter file guide

---

### Option 3: Production Enforcement (After Testing Complete)

**What**: Production policies in Deny mode (blocks non-compliant operations)  
**Why**: Critical security policies enforced in production  
**Timeline**: 5 minutes deployment + monitoring

```powershell
# Get managed identity
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# Deploy production Deny policies
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Deny.json `
    -PolicyMode Deny `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck

# Test enforcement (validates blocking with 34 comprehensive tests)
.\AzPolicyImplScript.ps1 -TestAllDenyPolicies -SkipRBACCheck

# Monitor compliance
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**Expected Result**:
- ✅ 34 Deny policies deployed
- ✅ Non-compliant operations blocked
- ✅ Comprehensive enforcement validation (34/34 tests pass)

---

### Option 4: Production Auto-Remediation (Advanced - Scenario 7)

**What**: 46 policies with 8 auto-remediation policies in Enforce mode  
**Why**: Automatically fix non-compliant resources without manual intervention  
**Timeline**: 5 minutes deployment + **90 minutes remediation cycle**  
**⚠️ CRITICAL**: Must use `-PolicyMode Enforce` for auto-remediation to work

```powershell
# Get managed identity (REQUIRED for auto-remediation)
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# Deploy with ENFORCE mode (NOT Audit - common mistake!)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -PolicyMode Enforce `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck `
    -Force

# Wait 60-90 minutes for Azure Policy remediation cycle
Write-Host "Waiting for remediation cycle... Check status at ~75 minutes" -ForegroundColor Yellow
Start-Sleep -Seconds 4500  # 75 minutes

# Check remediation tasks (should show 8 tasks)
Get-AzPolicyRemediation -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb" |
    Select-Object Name, ProvisioningState, @{N='ResourcesRemediated';E={$_.DeploymentSummary.TotalDeployments}}

# Regenerate compliance report
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**Expected Result**:
- ✅ 46/46 policies deployed (8 Enforce + 38 Audit)
- ✅ 8 remediation tasks created and executed
- ✅ Compliance improved from ~30% to 60-80%
- ✅ Resources automatically fixed: private endpoints, diagnostics, firewall, network access

**Common Mistakes**:
- ❌ Using `-PolicyMode Audit` - auto-remediation won't trigger
- ❌ Omitting `-IdentityResourceId` - policies deploy but can't remediate
- ❌ Not waiting 90 minutes - remediation tasks take time to execute

---

## � Important Notes

### MSDN Subscription Limitations

**8 Managed HSM policies cannot be tested in MSDN subscriptions** due to quota limitations:
- Quota: MSDN_2014-09-01 (no Managed HSM support)
- Blocked policies: All Managed HSM policies (17.4% of total 46)
- Test coverage: 38/46 (82.6%) in MSDN, 46/46 (100%) in Enterprise
- Workaround: Test in Enterprise or Pay-As-You-Go subscription ($730/month or ~$1 for 1-hour test)

### Recent Parameter Fixes (2026-01-27)

✅ **Fixed**: `cryptographicType` → `allowedKeyTypes` parameter  
- **Policy**: "Keys should be the specified cryptographic type RSA or EC"  
- **Impact**: Parameter was being skipped during deployment  
- **Files updated**: 4 parameter files (Production-Remediation, DevTest-Full-Remediation, Tier2-Audit, Tier2-Deny)  
- **Status**: All parameter files now use correct Azure Policy parameter names

### New Documentation

📖 **[SCENARIO-COMMANDS-REFERENCE.md](SCENARIO-COMMANDS-REFERENCE.md)**: Complete command reference for all 7 scenarios  
📊 **[POLICY-COVERAGE-MATRIX.md](POLICY-COVERAGE-MATRIX.md)**: 46 policies × 7 scenarios comprehensive matrix  
🎯 **[MasterTestReport-20260127-143212.html](MasterTestReport-20260127-143212.html)**: Comprehensive stakeholder summary

---

## �📊 Quick Verification


## 📊 Quick Verification

### Check Policy Assignments
```powershell
# List all Key Vault policy assignments
Get-AzPolicyAssignment | Where-Object { $_.Properties.DisplayName -like "*Key Vault*" -or $_.Properties.DisplayName -like "*key*" } | Select-Object -Property Name, @{Name='DisplayName';Expression={$_.Properties.DisplayName}}, @{Name='Effect';Expression={$_.Properties.Parameters.effect.value}}
```

### Check Compliance Status
```powershell
# Get compliance summary
Get-AzPolicyStateSummary -ManagementGroupName "YourMgmtGroup" | Select-Object -ExpandProperty PolicyAssignments | Where-Object { $_.PolicyAssignmentName -like "KV-*" }
```

### View Latest Report
```powershell
# Open most recent HTML report
Get-ChildItem ComplianceReport-*.html | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | ForEach-Object { Start-Process $_.FullName }
```

---

## 🛠️ Common Issues & Solutions

### Issue: "Module Az.* not found"
**Solution**:
```powershell
Install-Module -Name Az.Accounts, Az.Resources, Az.PolicyInsights -Force -Scope CurrentUser
```

### Issue: "Not connected to Azure"
**Solution**:
```powershell
Connect-AzAccount
Set-AzContext -Subscription "<your-subscription-id>"
```

### Issue: "No compliance data available"
**Solution**: Wait 15-30 minutes for Azure Policy evaluation, then run:
```powershell
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

### Issue: "Policy assignment failed - insufficient permissions"
**Solution**: Ensure you have **Policy Contributor** or **Owner** role:
```powershell
Get-AzRoleAssignment -SignInName "<your-email>" | Select-Object RoleDefinitionName, Scope
```

---

## 📁 Key Files Reference

| File | Purpose |
|------|---------|
| **AzPolicyImplScript.ps1** | Main deployment and testing script (4900+ lines) |
| **PolicyParameters-DevTest.json** | DevTest: 30 policies, Audit mode |
| **PolicyParameters-DevTest-Full.json** | DevTest: 46 policies, Audit mode |
| **PolicyParameters-Tier1-Deny.json** | Production: 9 policies, Deny mode |
| **DEPLOYMENT-PREREQUISITES.md** | Complete setup requirements |
| **TESTING-MAPPING.md** | Testing framework guide |
| **PARAMETER-FILE-USAGE-GUIDE.md** | Parameter file selection guide |

---

## 🎯 Next Steps

### After Successful DevTest Deployment:
1. ✅ Review compliance report - identify non-compliant resources
2. ✅ Run infrastructure tests - validate environment setup
3. ✅ Plan remediation - fix non-compliant resources before Deny mode
4. ✅ Deploy to production - start with Tier 1 Audit, then Deny

### Recommended Timeline:
- **Week 1**: DevTest deployment + testing
- **Week 2-3**: Compliance analysis + remediation planning
- **Month 2**: Production Audit deployment (30-day monitoring)
- **Month 3**: Tier 1 Deny enforcement

---

## 📚 Additional Resources

- **[README.md](README.md)**: Complete project overview
- **[SCENARIO-COMMANDS-REFERENCE.md](SCENARIO-COMMANDS-REFERENCE.md)**: All 7 scenarios with validated commands
- **[POLICY-COVERAGE-MATRIX.md](POLICY-COVERAGE-MATRIX.md)**: 46 policies × 7 scenarios matrix with VALUE-ADD metrics
- **[TESTING-MAPPING.md](TESTING-MAPPING.md)**: Testing framework and workflow
- **[FINAL-TEST-SUMMARY.md](FINAL-TEST-SUMMARY.md)**: Complete test results
- **[DEPLOYMENT-PREREQUISITES.md](DEPLOYMENT-PREREQUISITES.md)**: Requirements and permissions

---

## ✅ Success Checklist

After completing this guide, you should have:

- [ ] PowerShell 7.0+ installed and configured
- [ ] Azure PowerShell Az modules installed
- [ ] Connected to Azure subscription
- [ ] Deployed policies to DevTest (30 or 46 policies)
- [ ] Generated compliance report (HTML)
- [ ] Verified policy assignments in Azure Portal
- [ ] Reviewed compliance baseline

**Ready for production?** See [DEPLOYMENT-PREREQUISITES.md](DEPLOYMENT-PREREQUISITES.md) for production deployment checklist.

---

**Last Updated**: 2026-01-27  
**Version**: 2.2  
**Testing Status**: ✅ 82.6% Coverage in MSDN (38/46), 100% in Enterprise (46/46)  
**Latest Achievement**: Scenario 7 auto-remediation deployed successfully
