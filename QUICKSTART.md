# Quick Start Guide - Azure Key Vault Policy Governance

**Version**: 2.0  
**Last Updated**: 2026-01-16  
**Prerequisites Time**: 10 minutes  
**Deployment Time**: 5 minutes

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
# Deploy policies
.\AzPolicyImplScript.ps1 -DeployDevTest -SkipRBACCheck

# Check compliance (wait 15-30 min for Azure Policy evaluation)
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck

# View HTML report
Get-Item ComplianceReport-*.html | Select-Object -First 1 | ForEach-Object { Start-Process $_.FullName }
```

**Expected Result**:
- ✅ 30 policies assigned in Audit mode
- ✅ HTML compliance report generated
- ✅ No blocking of existing operations

---

### Option 2: Full Testing Environment (After DevTest Success)

**What**: All 46 policies in Audit mode  
**Why**: Complete governance testing before production  
**Timeline**: 5 minutes deployment + 30 minutes evaluation

```powershell
# Deploy all 46 policies
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -SkipRBACCheck

# Run comprehensive tests
.\AzPolicyImplScript.ps1 -TestInfrastructure -Detailed -SkipRBACCheck
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**Expected Result**:
- ✅ 46 policies assigned successfully
- ✅ All infrastructure tests pass
- ✅ Complete compliance baseline established

---

### Option 3: Production Enforcement (After Testing Complete)

**What**: 9 Tier 1 policies in Deny mode (blocks non-compliant operations)  
**Why**: Critical security policies enforced in production  
**Timeline**: 5 minutes deployment + monitoring

```powershell
# Deploy Tier 1 enforcement policies
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Tier1-Deny.json -SkipRBACCheck

# Test enforcement (validates blocking)
.\AzPolicyImplScript.ps1 -TestProductionEnforcement -SkipRBACCheck

# Monitor compliance
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**Expected Result**:
- ✅ 9 critical policies in Deny mode
- ✅ Non-compliant operations blocked
- ✅ Enforcement validation tests pass (9/9)

---

## 📊 Quick Verification


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

**Last Updated**: 2026-01-16  
**Version**: 2.0  
**Testing Status**: ✅ 100% Pass Rate (46/46 policies validated)
