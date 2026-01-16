# Parameter File Usage Guide - Complete Reference

**Version**: 2.0  
**Last Updated**: 2026-01-16  
**Status**: Complete infrastructure values configured

---

## 🎯 The 5 Ws and H

| Question | Answer |
|----------|--------|
| **WHO** | Azure administrators deploying policies across different environments |
| **WHAT** | Guide to selecting the correct parameter file for your deployment scenario |
| **WHEN** | Reference this before each deployment to choose the right parameter file |
| **WHERE** | All parameter files located in repository root directory |
| **WHY** | Different scenarios require different policy modes (Audit vs Deny) and parameter values |
| **HOW** | Match your scenario to the table below, use the specified command |

---

## 🎯 WHICH FILE FOR WHICH SCENARIO?

### Testing Scenarios (Use These!)

| Scenario | Parameter File | Policies | Mode | Command |
|----------|---------------|----------|------|---------|
| **Step 2: DevTest Safe** | `PolicyParameters-DevTest.json` | 30 | Audit | `.\AzPolicyImplScript.ps1 -DeployDevTest -SkipRBACCheck` |
| **Step 3: DevTest Full** | `PolicyParameters-DevTest-Full.json` | 46 | Audit | `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -SkipRBACCheck` |
| **Step 4: Production Deny** | `PolicyParameters-Production.json` | 46 | Deny | `.\AzPolicyImplScript.ps1 -DeployProduction -SkipRBACCheck` |
| **Auto-Remediation Testing** | `PolicyParameters-DevTest-Full-Remediation.json` | 46 (9 remediation) | DeployIfNotExists/Modify | `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json -IdentityResourceId "/subscriptions/.../id-policy-remediation" -SkipRBACCheck` |

### Corporate Tier Deployment (Production Use)

| Tier | Parameter File | Policies | Timeline | Command |
|------|---------------|----------|----------|---------|
| **Tier 1 Audit** | `PolicyParameters-Tier1-Audit.json` | 9 | Month 1 | `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Tier1-Audit.json -SkipRBACCheck` |
| **Tier 1 Deny** | `PolicyParameters-Tier1-Deny.json` | 9 | Month 2 | `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Tier1-Deny.json -SkipRBACCheck` |
| **Tier 2 Audit** | `PolicyParameters-Tier2-Audit.json` | 25 | Months 4-5 | `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Tier2-Audit.json -SkipRBACCheck` |
| **Tier 2 Deny** | `PolicyParameters-Tier2-Deny.json` | 25 | Months 6-7 | `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Tier2-Deny.json -SkipRBACCheck` |
| **Tier 3 Audit** | `PolicyParameters-Tier3-Audit.json` | 3 | Months 10+ | `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Tier3-Audit.json -SkipRBACCheck` |
| **Tier 3 Deny** | `PolicyParameters-Tier3-Deny.json` | 3 | TBD | `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Tier3-Deny.json -SkipRBACCheck` |
| **Tier 4 Remediation** | `PolicyParameters-Tier4-Remediation.json` | 9 | Months 1-6 | Requires managed identity - see below |

---

## 🔧 Current Infrastructure Values (January 15, 2026)

**Subscription**: `ab1336c7-687d-4107-b0f6-9649a0458adb`  
**Resource Group (Test)**: `rg-policy-keyvault-test`  
**Resource Group (Infrastructure)**: `rg-policy-remediation`

### Required Resource IDs

```powershell
# Log Analytics Workspace
/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.OperationalInsights/workspaces/law-policy-test-6827

# Event Hub Authorization Rule
/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.EventHub/namespaces/eh-policy-test-6513/authorizationrules/RootManageSharedAccessKey

# Private Endpoint Subnet
/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.Network/virtualNetworks/vnet-policy-test/subnets/snet-privateendpoints

# Private DNS Zone
/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net

# Managed Identity (for auto-remediation)
/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation
```

---

## ✅ 6-Step Testing Workflow (Use These Files In Order)

### Step 1: Infrastructure ✅ COMPLETE
- Already recreated with correct values

### Step 2: DevTest Safe (30 policies) - USE THIS NEXT
**File**: `PolicyParameters-DevTest.json`  
**Command**: `.\AzPolicyImplScript.ps1 -DeployDevTest -SkipRBACCheck`  
**Wait**: 60 minutes for Azure Policy evaluation  
**Report**: `.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck`

### Step 3: DevTest Full (46 policies)
**Cleanup First**: Remove 30 policy assignments from Step 2  
**File**: `PolicyParameters-DevTest-Full.json`  
**Command**: `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -SkipRBACCheck`  
**Wait**: 60 minutes  
**Report**: `.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck`

### Step 4: Production Deny (46 policies)
**Cleanup First**: Remove 46 policy assignments from Step 3  
**File**: `PolicyParameters-Production.json`  
**Command**: `.\AzPolicyImplScript.ps1 -DeployProduction -SkipRBACCheck` (Type 'PROCEED')  
**Test**: `.\AzPolicyImplScript.ps1 -TestProductionEnforcement -SkipRBACCheck`  
**Wait**: 60 minutes  
**Report**: `.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck`

### Step 5: Validate Reports
**Command**: `.\AzPolicyImplScript.ps1 -ValidateReport -SkipRBACCheck`  
**Checks**: 7 validation tests (structure, policy count, data completeness)

### Step 6: Documentation
- Update todos.md with results
- Mark testing complete

---

## 📊 Policy Count Verification

All files updated with correct infrastructure values (January 15, 2026):

| File | Policies | Status |
|------|----------|--------|
| PolicyParameters-DevTest.json | 30 | ✅ Updated |
| PolicyParameters-DevTest-Full.json | 46 | ✅ Updated |
| PolicyParameters-DevTest-Full-Remediation.json | 46 | ✅ Updated |
| PolicyParameters-Production.json | 46 | ✅ Updated |
| PolicyParameters-Production-Remediation.json | 46 | ✅ Updated |
| PolicyParameters-Tier1-Audit.json | 9 | ✅ Updated |
| PolicyParameters-Tier1-Deny.json | 9 | ✅ Updated |
| PolicyParameters-Tier2-Audit.json | 25 | ✅ Updated |
| PolicyParameters-Tier2-Deny.json | 25 | ✅ Updated |
| PolicyParameters-Tier3-Audit.json | 3 | ✅ Updated |
| PolicyParameters-Tier3-Deny.json | 3 | ✅ Updated |
| PolicyParameters-Tier4-Remediation.json | 9 | ✅ Updated |

**Total**: 9 + 25 + 3 + 9 = 46 policies across all tiers ✅

---

## ⚠️ CRITICAL: Do NOT Use These Files

- ❌ `PolicyParameters.json` (generic template - missing values)
- ❌ Any file without infrastructure resource IDs

---

## 🔍 How to Verify Parameter File Correctness

```powershell
# Check policy count
$json = Get-Content .\PolicyParameters-DevTest-Full.json | ConvertFrom-Json
$policyCount = ($json.PSObject.Properties | Where-Object { $_.Name -ne 'metadata' -and $_.Name -notlike '_*' }).Count
Write-Host "Policy count: $policyCount"

# Check for placeholder values (should return 0)
$content = Get-Content .\PolicyParameters-DevTest-Full.json -Raw
$placeholders = [regex]::Matches($content, 'placeholder').Count
Write-Host "Placeholders found: $placeholders (should be 0)"

# Verify infrastructure values are present
$hasLogAnalytics = $content -match 'law-policy-test-6827'
$hasEventHub = $content -match 'eh-policy-test-6513'
$hasSubnet = $content -match 'snet-privateendpoints'
Write-Host "Has correct Log Analytics: $hasLogAnalytics"
Write-Host "Has correct Event Hub: $hasEventHub"
Write-Host "Has correct Subnet: $hasSubnet"
```

---

## 📝 Notes

- All parameter files updated with actual infrastructure resource IDs (January 15, 2026)
- No more "placeholder" values - all references point to real resources
- Auto-remediation files require `-IdentityResourceId` parameter
- DevTest files use ResourceGroup scope, Production uses Subscription scope
- Always use `-SkipRBACCheck` for testing environment
