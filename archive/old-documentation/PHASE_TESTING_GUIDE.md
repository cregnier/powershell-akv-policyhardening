# Phase-Based Testing Quick Reference

## Current Status (2026-01-12 16:00Z)

### ✅ Completed
- **Phase 1**: 100% policy coverage (46/46 assigned in Audit mode)
- **Phase 2.1**: Deny mode assignment complete (awaiting evaluation)

### 📋 Next Steps

---

## OPTION 1: Complete Setup (Recommended for Fresh Start)

Run the comprehensive setup script to create/verify all infrastructure and test vaults:

```powershell
.\Setup-PolicyTestingEnvironment.ps1
```

**What it does:**
- ✅ Creates managed identity with proper RBAC (Contributor, Key Vault Contributor, etc.)
- ✅ Creates Log Analytics workspace, Event Hub, Private DNS, VNet/Subnet
- ✅ **Interactive resource group selection** - shows all available RGs first
- ✅ Creates 3 test Key Vaults (compliant, partially compliant, non-compliant)
- ✅ **Seeds vaults with test data**: secrets, keys, certs (various compliance states)
- ✅ **Assigns Key Vault Administrator RBAC to your MSA account** on all test vaults
- ✅ Updates PolicyParameters.json with real resource IDs
- ✅ Creates PolicyImplementationConfig.json

**Output:**
- Infrastructure ready for testing
- Test vaults ready for compliance validation
- You can immediately access vaults to add/modify secrets/keys/certs

---

## OPTION 2: Phase 2.2 - Enforce Mode Testing

After setup is complete, test auto-remediation:

```powershell
# Load configuration
$config = Get-Content C:\Temp\PolicyImplementationConfig.json | ConvertFrom-Json

# Assign policies in Enforce mode
.\AzPolicyImplScript.ps1 `
    -PolicyMode Enforce `
    -ScopeType ResourceGroup `
    -SkipRBACCheck `
    -IdentityResourceId $config.ManagedIdentityId
```

**What to monitor:**
- DeployIfNotExists policies automatically create diagnostic settings
- Modify policies automatically update non-compliant configurations
- Remediation tasks in Azure Portal (Policy → Remediation)

---

## OPTION 3: Full Subscription Deployment (Production)

For production deployment across entire subscription:

```powershell
# Load configuration
$config = Get-Content C:\Temp\PolicyImplementationConfig.json | ConvertFrom-Json

# Assign policies at subscription level
.\AzPolicyImplScript.ps1 `
    -PolicyMode Audit `
    -ScopeType Subscription `
    -IdentityResourceId $config.ManagedIdentityId
```

---

## Key Improvements Made Today

### 1. Combined Prerequisites Script
- **Before**: Two separate scripts (GatherPrerequisites.ps1 + Phase2.1-DenyModeTest.ps1)
- **Now**: One comprehensive Setup-PolicyTestingEnvironment.ps1

### 2. Interactive Resource Group Selection
- **Before**: Manual entry of resource group name
- **Now**: Shows table of all RGs with resource counts, then prompts for selection

### 3. Automatic RBAC for User
- **Feature**: Assigns Key Vault Administrator role to your MSA account on all test vaults
- **Benefit**: You can immediately seed vaults with secrets/keys/certs for testing

### 4. Test Vault Seeding
- **Compliant vault**: All policies satisfied (soft delete, purge protection, RBAC, firewall)
- **Partial vault**: Some policies satisfied (soft delete, RBAC, but public access)
- **Non-compliant vault**: Access policies instead of RBAC, no purge protection
- **Test data**: 3 secrets + 3 keys per vault with various expiration/content type states

---

## Testing Workflow

```
Phase 1 (✅ Done)
└─ Audit mode → Baseline compliance

Phase 2.1 (✅ Done)
└─ Deny mode → Validate blocking behavior

Phase 2.2 (📋 Next)
└─ Enforce mode → Auto-remediation testing
   ├─ DeployIfNotExists → Diagnostic settings created automatically
   ├─ Modify → Non-compliant configs auto-corrected
   └─ Monitor remediation tasks

Phase 3 (Future)
└─ Real-world validation
   ├─ Create various Key Vault configs
   ├─ Test edge cases (expiring certs, rotating secrets)
   └─ Validate policy effectiveness

Phase 4 (Future)
└─ Environment-specific configs
   ├─ Dev/test parameters (permissive)
   ├─ Production parameters (strict)
   └─ Management Group deployment
```

---

## Files Reference

| File | Purpose |
|------|---------|
| `Setup-PolicyTestingEnvironment.ps1` | **One-stop setup** - infrastructure + test vaults |
| `AzPolicyImplScript.ps1` | Main policy assignment script |
| `Phase2.1-AssignDenyMode.ps1` | Quick Deny mode assignment |
| `PolicyImplementationConfig.json` | Generated config (managed identity, resource IDs) |
| `PolicyParameters.json` | Policy parameter overrides |
| `PolicyNameMapping.json` | 3745 policy definitions mapped to IDs |
| `DefinitionListExport.csv` | 46 Key Vault policies to assign |

---

## Quick Commands

### Check Current Compliance
```powershell
Get-AzPolicyState -ResourceGroupName rg-policy-keyvault-test | 
  Group-Object ComplianceState | 
  Select-Object Name, Count
```

### List Test Vaults
```powershell
Get-AzKeyVault -ResourceGroupName rg-policy-keyvault-test | 
  Select-Object VaultName, Location, EnableSoftDelete, EnablePurgeProtection, EnableRbacAuthorization
```

### View Remediation Tasks
```powershell
Get-AzPolicyRemediation -ResourceGroupName rg-policy-keyvault-test
```

### Add Test Secret (after RBAC assignment)
```powershell
$secret = ConvertTo-SecureString "MyTestValue" -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName <vault-name> -Name "test-secret" -SecretValue $secret -Expires (Get-Date).AddDays(90)
```

---

## Notes for MSA Account Users

Your account has:
- **Subscription Owner** role (can create resources)
- **Key Vault Administrator** role (auto-assigned by setup script on test vaults)

This allows you to:
- Create new Key Vaults
- Seed vaults with secrets, keys, and certificates
- Test compliance policies with real data
- Validate blocking and remediation behaviors

---

## Next Immediate Action

Run the setup script to ensure all prerequisites and test vaults are ready:

```powershell
.\Setup-PolicyTestingEnvironment.ps1
```

This will interactively guide you through:
1. Resource group selection (shows available options)
2. Infrastructure creation/verification
3. Test vault creation with various compliance states
4. RBAC assignment
5. Vault seeding with test data

**Estimated time**: 5-10 minutes

Then proceed to Phase 2.2 (Enforce mode testing).
