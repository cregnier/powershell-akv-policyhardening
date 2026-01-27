# Complete Cleanup Guide - Azure Key Vault Policy Project

**Version**: 1.0  
**Date**: 2026-01-27  
**Purpose**: Complete removal of all project resources (infrastructure + policy assignments)

---

## 🎯 Quick Reference

### What Gets Cleaned Up

| Category | Items | Cost Impact | Command |
|----------|-------|-------------|---------|
| **Test Infrastructure** | Event Hub, Log Analytics, VNet, Test Vaults | 🔴 **$27-160/month** | Setup script `-CleanupFirst` |
| **Policy Assignments** | 46 KV-* policy assignments | 🟢 **FREE** | Main script `-Rollback` |
| **Remediation Tasks** | Auto-remediation tasks | 🟢 **FREE** (auto-expire 7 days) | Auto-cleanup by Azure |
| **Local Reports** | HTML/JSON/CSV/MD files | 🟢 **FREE** (local disk only) | Manual deletion or Cleanup-Workspace.ps1 |
| **Managed Identity** | id-policy-remediation | 🟢 **FREE** | **KEEP for production** |

### Tonight's Recommendation

```powershell
# OPTION 1: Keep everything overnight (SAFE - policies are FREE)
# - Policy assignments: FREE
# - Local reports: FREE
# - Infrastructure: ~$0.10/night (Event Hub + Log Analytics minimal overnight cost)
# - Resume tomorrow with all context intact

# OPTION 2: Remove ONLY expensive infrastructure (reduces cost to $0)
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst
# Keeps: Policy assignments, managed identity, local reports
# Removes: Event Hub, Log Analytics, VNet, Test Vaults
# Tomorrow: Re-run setup script to recreate test environment
```

**RECOMMENDATION**: **Keep everything overnight** - infrastructure cost is minimal (~$0.10) and you preserve all test context.

---

## 🔍 What Artifacts Exist & Their Scope

### 1. Policy Assignments (Created by AzPolicyImplScript.ps1)

**Scope**: **SUBSCRIPTION-WIDE** ⚠️  
**Target**: ALL Key Vaults in subscription (not just test vaults)  
**Impact**: Policies enforce on ALL resources (test + production if any)

```powershell
# Check current policy assignments
Get-AzPolicyAssignment -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb" | 
    Where-Object { $_.Name -match '^KV-' } | 
    Select-Object Name, DisplayName, EnforcementMode, @{N='Effect';E={$_.Properties.Parameters.effect.value}}
```

**Current Deployment** (Scenario 7):
- **46 policies** assigned at **subscription scope**
- **8 policies** in **Enforce mode** (auto-remediation via DINE/Modify)
- **38 policies** in **Audit mode** (monitoring only)
- **Affects**: ALL Key Vaults in subscription (kv-compliant-test, kv-non-compliant-test, kv-partial-test, and ANY production vaults)

### 2. Remediation Tasks (Created by Azure Policy automatically)

**Scope**: Subscription-wide  
**Target**: All non-compliant resources matching DINE/Modify policies  
**Lifecycle**: Auto-expire after 7 days

```powershell
# Check active remediation tasks
Get-AzPolicyRemediation -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb" |
    Where-Object { $_.CreatedOn -gt (Get-Date).AddDays(-1) } |
    Select-Object Name, ProvisioningState, @{N='ResourcesFixed';E={$_.DeploymentSummary.SuccessfulDeployments}}
```

**Expected Tomorrow**:
- **8 remediation tasks** (one per DINE/Modify policy)
- Will auto-configure ALL non-compliant Key Vaults in subscription
- Auto-cleanup after 7 days (no manual action needed)

### 3. Test Infrastructure (Created by Setup-AzureKeyVaultPolicyEnvironment.ps1)

**Resource Groups**:
- `rg-policy-keyvault-test` - Test vaults and data
- `rg-policy-remediation` - Managed identity and infrastructure

**Resources with Costs**:
- Event Hub Namespace: `eh-policy-test-*` (🔴 **$25-150/month**)
- Log Analytics: `law-policy-test-*` (🟡 **$2-10/month**)
- 3 Test Key Vaults (🟢 **$0.10/month**)
- VNet, Private DNS, Subnets (🟢 **$0-1/month**)

**Resources FREE**:
- Managed Identity: `id-policy-remediation` (required for production)

### 4. Local Files (Created by both scripts)

**Reports**: `ComplianceReport-*.html`, `PolicyImplementationReport-*.json/csv/md`  
**Test Results**: `DenyBlockingTestResults-*.json`, `All46PoliciesBlockingValidation-*.json`  
**Configuration**: `PolicyImplementationConfig.json`, parameter files  
**Cost**: FREE (local disk storage only)

---

## 🧹 Cleanup Methods

### Method 1: Complete Teardown (Fresh Start Tomorrow)

**Use Case**: Want to start completely fresh tomorrow  
**Impact**: Removes EVERYTHING (infrastructure + policy assignments)  
**Tomorrow**: Re-run setup script + redeploy policies (30-45 min setup time)

```powershell
# Step 1: Remove all policy assignments
Write-Host "Removing policy assignments..." -ForegroundColor Yellow
.\AzPolicyImplScript.ps1 -Rollback -SkipRBACCheck

# Step 2: Remove test infrastructure (Event Hub, Log Analytics, Test Vaults)
Write-Host "Removing test infrastructure..." -ForegroundColor Yellow
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst -SkipMonitoring

# Step 3: OPTIONAL - Remove managed identity (if no production use)
Write-Host "Removing managed identity (optional)..." -ForegroundColor Red
# Remove-AzResourceGroup -Name "rg-policy-remediation" -Force
# ⚠️ WARNING: Only if you don't need identity for production!

# Step 4: OPTIONAL - Clean up local reports
Write-Host "Archiving old reports..." -ForegroundColor Yellow
.\Cleanup-Workspace.ps1

# Result: $0/month cost, complete fresh start tomorrow
```

**Cost After Cleanup**: $0/month  
**Tomorrow Setup Time**: 30-45 minutes (re-run setup + deploy policies)

---

### Method 2: Keep Policies, Remove Infrastructure (Recommended for Tonight)

**Use Case**: Preserve policy assignments and test context, reduce overnight costs  
**Impact**: Removes infrastructure only (Event Hub, Log Analytics, Test Vaults)  
**Tomorrow**: Quick restart (5-10 min setup, policies still active)

```powershell
# Remove only test infrastructure (keeps policy assignments)
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst -SkipMonitoring

# Result: Policy assignments still active, infrastructure removed
# Tomorrow: Re-run setup script ONLY (policies remain assigned)
```

**Cost After Cleanup**: $0/month  
**Tomorrow Setup Time**: 5-10 minutes (re-run setup only)  
**Policy Status**: ACTIVE (still enforcing, but no test vaults to validate against)

---

### Method 3: Keep Everything (Minimal Overnight Cost)

**Use Case**: Resume tomorrow exactly where you left off  
**Impact**: None - everything preserved  
**Tomorrow**: Continue immediately from monitoring checkpoint

```powershell
# NO CLEANUP NEEDED
# All resources remain active
# Resume tomorrow with status check from todos.md
```

**Cost Tonight**: ~$0.10-0.50 (Event Hub + Log Analytics minimal overnight usage)  
**Tomorrow Setup Time**: 0 minutes (continue immediately)  
**Policy Status**: ACTIVE (remediation completes overnight)

---

## 🏭 Production Scoping Strategy (Your Question)

### Current Testing Scope vs Production Recommendations

**Current Testing (Scenario 7)**:
```powershell
# ⚠️ SUBSCRIPTION SCOPE - Affects ALL Key Vaults in subscription
-ScopeType Subscription
-Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb"

# Policies apply to:
# - kv-compliant-test ✅
# - kv-non-compliant-test ✅
# - kv-partial-test ✅
# - ANY OTHER VAULTS in subscription ⚠️
```

### Production Deployment Strategy

**Recommended Approach**: Hierarchical scoping with exemptions

```powershell
# ═══════════════════════════════════════════════════════════════════
# PRODUCTION STRATEGY: Start Broad, Refine with Exemptions
# ═══════════════════════════════════════════════════════════════════

# PHASE 1: Subscription-Level Assignment (Audit mode)
# Deploy all 46 policies in AUDIT mode first
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Audit `
    -IdentityResourceId "/subscriptions/.../id-policy-remediation" `
    -ScopeType Subscription `
    -SkipRBACCheck

# Wait 24-48 hours, analyze compliance reports
# Identify vaults that need exemptions (legacy, third-party, etc.)

# PHASE 2: Create Exemptions for Special Cases
# Exempt specific resource groups or vaults from policies
New-AzPolicyExemption `
    -Name "legacy-vaults-exemption" `
    -DisplayName "Legacy Key Vaults - Exempted from Auto-Remediation" `
    -Scope "/subscriptions/abc123/resourceGroups/rg-legacy-apps" `
    -PolicyAssignment (Get-AzPolicyAssignment -Name "KV-Configure-Private-Endpoints") `
    -ExemptionCategory Waiver `
    -Description "Legacy vaults require manual migration - exempt for 90 days"

# PHASE 3: Enable Deny Mode (Subscription-Level)
# Switch to Deny mode for new resources (blocks non-compliant creations)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Deny.json `
    -PolicyMode Deny `
    -IdentityResourceId "/subscriptions/.../id-policy-remediation" `
    -ScopeType Subscription `
    -SkipRBACCheck

# PHASE 4: Enable Auto-Remediation (Subscription-Level with Exemptions)
# Turn on DINE/Modify policies for non-exempt vaults
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -PolicyMode Enforce `
    -IdentityResourceId "/subscriptions/.../id-policy-remediation" `
    -ScopeType Subscription `
    -SkipRBACCheck

# Result: Subscription-wide enforcement with granular exemptions
```

### Alternative: Resource Group Scoping (NOT Recommended)

```powershell
# ⚠️ LESS COMMON: Resource Group Scope
# Only use if you have clear RG boundaries for vault governance
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Audit `
    -IdentityResourceId "/subscriptions/.../id-policy-remediation" `
    -ScopeType ResourceGroup `
    -ResourceGroupName "rg-production-vaults" `
    -SkipRBACCheck

# Limitations:
# - Must redeploy for each RG (maintenance overhead)
# - New RGs not covered automatically
# - Harder to enforce organization-wide standards
```

### Exemption Best Practices

```powershell
# Exemption Categories:
# - Waiver: Permanent exemption (e.g., third-party managed vaults)
# - Mitigated: Risk accepted via compensating controls

# Example exemptions for common scenarios:
# 1. Legacy vaults (time-limited exemption for migration)
New-AzPolicyExemption -ExemptionCategory Waiver -ExpiresOn (Get-Date).AddDays(90)

# 2. Third-party managed vaults (permanent)
New-AzPolicyExemption -ExemptionCategory Waiver -Description "Managed by vendor XYZ"

# 3. Break-glass vaults (excluded from auto-remediation)
New-AzPolicyExemption -PolicyDefinitionReferenceIds @("DINE-Private-Endpoints", "Modify-Firewall")
```

---

## 📋 Cleanup Command Reference

### Setup Script Cleanup

```powershell
# Full cleanup with confirmation prompts
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst

# What it does:
# 1. Prompts for confirmation (type 'DELETE')
# 2. Removes test resource group: rg-policy-keyvault-test
#    - Deletes: Event Hub, Log Analytics, VNet, 3 Test Vaults
# 3. KEEPS: rg-policy-remediation (managed identity for production)
# 4. KEEPS: Policy assignments (managed by main script)

# Skip monitoring setup on recreate
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst -SkipMonitoring
```

### Main Script Rollback

```powershell
# Remove ALL policy assignments (KV-* pattern)
.\AzPolicyImplScript.ps1 -Rollback -SkipRBACCheck

# What it does:
# 1. Finds all assignments starting with 'KV-'
# 2. Removes each assignment from subscription scope
# 3. Displays removal summary
# 4. KEEPS: Infrastructure, remediation tasks auto-expire
```

### Manual Cleanup

```powershell
# Remove specific policy assignment
Remove-AzPolicyAssignment -Name "KV-Require-Private-Endpoints-12345"

# Remove all remediation tasks (if needed)
Get-AzPolicyRemediation -Scope "/subscriptions/abc123" | Remove-AzPolicyRemediation

# Remove resource groups
Remove-AzResourceGroup -Name "rg-policy-keyvault-test" -Force
Remove-AzResourceGroup -Name "rg-policy-remediation" -Force  # ⚠️ Only if no production use!

# Clean local files
.\Cleanup-Workspace.ps1
# OR manually:
# Remove-Item ComplianceReport-*.html, *TestResults-*.json, All46Policies*.json
```

---

## ⚠️ Important Notes

### Policy Assignment Scope Impact

1. **Current Testing**: Policies deployed at **subscription scope**
   - Affects ALL Key Vaults in subscription (test + production)
   - Auto-remediation will modify ALL non-compliant vaults
   - No resource-level targeting currently implemented

2. **Production Recommendation**: 
   - Deploy at subscription scope (broad coverage)
   - Use exemptions for specific vaults/RGs that need exclusions
   - Start with Audit mode, progress to Deny, then Enforce

3. **Resource Group Scope** (alternative):
   - Requires separate deployment per RG
   - More maintenance overhead
   - Less common in enterprise scenarios

### Cost Breakdown (Overnight)

| Resource | Overnight Cost | Monthly Cost | Cleanup Impact |
|----------|----------------|--------------|----------------|
| Event Hub | ~$0.05-0.30 | $25-150 | 🔴 Remove to save |
| Log Analytics | ~$0.05-0.20 | $2-10 | 🟡 Remove to save |
| Key Vaults | ~$0.00 | $0.10 | 🟢 Negligible |
| Policy Assignments | $0.00 | $0.00 | 🟢 FREE - keep |
| Managed Identity | $0.00 | $0.00 | 🟢 FREE - keep for prod |
| Local Reports | $0.00 | $0.00 | 🟢 FREE - archive if desired |
| **TOTAL OVERNIGHT** | **~$0.10-0.50** | **$27-160** | **Keep all: $0.50** |

### Tomorrow's Fresh Start Options

**Option A: Full Teardown (30-45 min setup)**
```powershell
# Tonight: Complete cleanup
.\AzPolicyImplScript.ps1 -Rollback
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst

# Tomorrow: Complete rebuild
.\Setup-AzureKeyVaultPolicyEnvironment.ps1
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Remediation.json -PolicyMode Enforce -IdentityResourceId "..." -ScopeType Subscription
```

**Option B: Infrastructure-Only Cleanup (5-10 min setup)**
```powershell
# Tonight: Remove infrastructure only
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst

# Tomorrow: Quick restart
.\Setup-AzureKeyVaultPolicyEnvironment.ps1
# Policies still active, just recreate test environment
```

**Option C: Keep Everything (0 min setup)**
```powershell
# Tonight: No cleanup
# Cost: ~$0.10-0.50 overnight

# Tomorrow: Resume immediately
# Run status check from todos.md
```

---

## 🎯 Recommended Action for Tonight

```powershell
# ═══════════════════════════════════════════════════════════════════
# RECOMMENDED: Keep Everything Overnight
# ═══════════════════════════════════════════════════════════════════
# 
# COST: ~$0.10-0.50 (minimal overnight Event Hub + Log Analytics usage)
# BENEFIT: Zero setup time tomorrow, preserve all test context
# REASON: Remediation cycle completes overnight, check results in AM
# 
# NO ACTION NEEDED TONIGHT!
# ═══════════════════════════════════════════════════════════════════

# Tomorrow morning: Run status check from todos.md (lines 43-94)
```

---

## 📚 Related Documentation

- **QUICKSTART.md**: Quick deployment guide  
- **DEPLOYMENT-WORKFLOW-GUIDE.md**: Complete workflow reference  
- **todos.md**: Tomorrow's monitoring checkpoint  
- **CLEANUP-GUIDE.md**: Original cleanup guide (infrastructure only)

---

**Document Version**: 1.0  
**Last Updated**: 2026-01-27 17:15  
**Author**: Azure Key Vault Policy Governance Project
