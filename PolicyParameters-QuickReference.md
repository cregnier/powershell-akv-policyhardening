# Azure Key Vault Policy Parameters - Quick Reference Guide

**Last Updated**: January 22, 2026  
**Purpose**: Guide for selecting and using policy parameter files  
**Audience**: DevOps engineers, Cloud admins, Security teams

---

## 📋 Quick Selection Guide

### Which Parameter File Should I Use?

```
┌─ Need to test/validate in dev/test environment?
│  ├─ Testing 30 baseline policies? → PolicyParameters-DevTest.json
│  ├─ Testing all 46 policies? → PolicyParameters-DevTest-Full.json
│  └─ Testing auto-remediation? → PolicyParameters-DevTest-Full-Remediation.json
│
└─ Ready for production deployment?
   ├─ Monitoring only (Audit mode)? → PolicyParameters-Production.json
   ├─ Blocking non-compliant (Deny mode)? → PolicyParameters-Production-Deny.json
   └─ Auto-fix existing resources? → PolicyParameters-Production-Remediation.json
```

---

## 📂 Available Parameter Files

| File | Policies | Mode | Environment | -IdentityResourceId Required? |
|------|----------|------|-------------|-------------------------------|
| **PolicyParameters-DevTest.json** | 30 | Audit | Dev/Test | ⚠️ Optional (8 policies skipped without it) |
| **PolicyParameters-DevTest-Full.json** | 46 | Audit | Dev/Test | ⚠️ Optional (8 policies skipped without it) |
| **PolicyParameters-DevTest-Full-Remediation.json** | 46 | Mixed (8 DeployIfNotExists/Modify) | Dev/Test | ✅ **REQUIRED** |
| **PolicyParameters-Production.json** | 46 | Audit | Production | ⚠️ Optional (8 policies skipped without it) |
| **PolicyParameters-Production-Deny.json** | 46 | Deny | Production | ❌ Not needed (Deny doesn't auto-fix) |
| **PolicyParameters-Production-Remediation.json** | 46 | Mixed (8 DeployIfNotExists/Modify) | Production | ✅ **REQUIRED** |

---

## 🔑 When Do I Need -IdentityResourceId?

### Decision Tree

```
Do any policies have DeployIfNotExists or Modify effects?
│
├─ YES → ✅ REQUIRED: Add -IdentityResourceId parameter
│   └─ Which files? DevTest-Full-Remediation.json, Production-Remediation.json
│
└─ NO → ❌ NOT NEEDED: Audit/Deny modes don't auto-fix
    └─ Which files? All other parameter files
```

### Required Parameter Format

```powershell
-IdentityResourceId "/subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<identity-name>"
```

### Example: Working Installation

```powershell
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# DevTest Remediation (REQUIRES identity)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -IdentityResourceId $identityId `
    -SkipRBACCheck

# Production Remediation (REQUIRES identity)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -IdentityResourceId $identityId `
    -SkipRBACCheck
```

### What Happens Without -IdentityResourceId?

If you use a remediation parameter file WITHOUT the identity parameter:

```
[WARN] Policy default effect 'DeployIfNotExists' requires managed identity. 
       Skipping assignment - provide -IdentityResourceId to enable.
```

**Result**: 8 critical policies will be skipped:
1. Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace
2. Deploy Diagnostic Settings for Key Vault to Event Hub
3. Deploy - Configure diagnostic settings to an Event Hub (Managed HSM)
4. Configure Azure Key Vaults with private endpoints
5. [Preview]: Configure Azure Key Vault Managed HSM with private endpoints
6. Configure Azure Key Vaults to use private DNS zones
7. [Preview]: Configure Azure Key Vault Managed HSM to disable public network access
8. Configure key vaults to enable firewall

---

## 🎯 Common Workflow Commands

### Development/Testing Workflows

#### 1. DevTest Baseline (30 Policies - Audit Only)
```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest.json `
    -DryRun `
    -SkipRBACCheck
```

**Use When**: First-time testing, validating 30 core policies  
**Identity Needed**: No (but 8 policies will be skipped)

#### 2. DevTest Full (46 Policies - Audit Only)
```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full.json `
    -DryRun `
    -SkipRBACCheck
```

**Use When**: Testing complete policy suite in Audit mode  
**Identity Needed**: No (but 8 policies will be skipped)

#### 3. DevTest Remediation (46 Policies - Auto-Fix)
```powershell
$identityId = "/subscriptions/.../id-policy-remediation"

.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -IdentityResourceId $identityId `
    -DryRun `
    -SkipRBACCheck
```

**Use When**: Testing auto-remediation capabilities  
**Identity Needed**: ✅ **YES - REQUIRED**

### Production Workflows

#### 4. Production Audit (46 Policies - Monitoring Only)
```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -SkipRBACCheck
```

**Use When**: Initial production deployment, compliance monitoring  
**Identity Needed**: No (but 8 policies will be skipped)

#### 5. Production Deny (46 Policies - Blocking)
```powershell
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Deny.json `
    -SkipRBACCheck
```

**Use When**: Maximum enforcement, prevent non-compliant resource creation  
**Identity Needed**: No (Deny mode doesn't auto-fix)  
**⚠️ WARNING**: Blocks all non-compliant operations - test thoroughly first!

#### 6. Production Remediation (46 Policies - Auto-Fix)
```powershell
$identityId = "/subscriptions/.../id-policy-remediation"

.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -IdentityResourceId $identityId `
    -SkipRBACCheck
```

**Use When**: Fixing existing non-compliant resources automatically  
**Identity Needed**: ✅ **YES - REQUIRED**  
**⚠️ WARNING**: Modifies existing Key Vaults - test in dev/test first!

---

## 📊 Parameter File Comparison

### DevTest vs Production Differences

| Aspect | DevTest Files | Production Files |
|--------|---------------|------------------|
| **Purpose** | Testing, validation, experimentation | Live enforcement, compliance monitoring |
| **Risk Tolerance** | High (aggressive testing) | Low (careful phased rollout) |
| **Resource Group** | `rg-policy-keyvault-test` | Subscription-wide |
| **Rollback** | Easy (delete test RG) | Complex (exemptions, rollback script) |
| **Policy Count** | 30 or 46 (flexible) | Always 46 (complete suite) |
| **Enforcement Modes** | Audit (default), Remediation (optional) | Audit → Deny → Remediation (phased) |

### 30 vs 46 Policy Files

**30-Policy Files** (`PolicyParameters-DevTest.json`):
- Core baseline policies only
- Faster testing cycles
- Good for initial validation
- Missing 16 advanced policies

**46-Policy Files** (all others):
- Complete governance suite
- Covers all Azure Key Vault features
- Matches production configuration
- Recommended for production parity

---

## ⚙️ Setup Prerequisites

### Before Using Remediation Parameter Files

You MUST create the managed identity first:

```powershell
# Run the infrastructure setup script
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -EnvironmentType DevTest

# This creates:
# - Managed Identity: id-policy-remediation
# - Resource Group: rg-policy-remediation
# - Log Analytics workspace
# - Event Hub namespace
# - Private DNS zone
# - VNet with subnets
```

### Verify Managed Identity Exists

```powershell
# Get the managed identity resource ID
$identity = Get-AzUserAssignedIdentity -ResourceGroupName "rg-policy-remediation" -Name "id-policy-remediation"
$identityId = $identity.Id

# Should output something like:
# /subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation
```

---

## 🔍 Troubleshooting

### "Skipping assignment - provide -IdentityResourceId"

**Problem**: Using remediation parameter file without managed identity  
**Solution**: Add `-IdentityResourceId` parameter with full ARM resource ID

```powershell
# Wrong (identity missing)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json

# Right (identity provided)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json -IdentityResourceId "/subscriptions/.../id-policy-remediation"
```

### "Cannot find path PolicyParameters-Production-Deny.json"

**Problem**: File doesn't exist yet (created on 2026-01-22)  
**Solution**: File is now available - update your Git repository

```powershell
# Verify file exists
Test-Path ".\PolicyParameters-Production-Deny.json"  # Should return: True

# If False, pull latest changes
git pull origin master
```

### "Parameter 'cryptographicType' not defined in policy"

**Problem**: Parameter file includes parameter not recognized by policy definition  
**Solution**: This is EXPECTED - script automatically skips invalid parameters

**Log Message (EXPECTED)**:
```
[WARN] Parameter 'cryptographicType' not defined in policy. Skipping to avoid UndefinedPolicyParameter error.
```

**Action**: No action needed - this is the parameter filter working correctly

---

## 📚 Related Documentation

- **QUICKSTART.md** - Complete deployment walkthrough
- **DEPLOYMENT-WORKFLOW-GUIDE.md** - Step-by-step workflow instructions
- **DEPLOYMENT-PREREQUISITES.md** - Infrastructure setup requirements
- **Workflow-Testing-Analysis.md** - Test execution results
- **WORKFLOW-TESTING-GUIDE.md** - Comprehensive testing guide

---

## 📝 Quick Command Reference

```powershell
# Variables (set these first)
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# DevTest workflows (no identity - audit only)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -DryRun -SkipRBACCheck
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -DryRun -SkipRBACCheck

# DevTest remediation (identity required)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json -IdentityResourceId $identityId -DryRun -SkipRBACCheck

# Production audit (no identity - monitoring only)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -SkipRBACCheck

# Production deny (no identity - blocking mode)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Deny.json -SkipRBACCheck

# Production remediation (identity required)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Remediation.json -IdentityResourceId $identityId -SkipRBACCheck
```

---

**Need Help?** See [DEPLOYMENT-WORKFLOW-GUIDE.md](DEPLOYMENT-WORKFLOW-GUIDE.md) for detailed workflow instructions.
