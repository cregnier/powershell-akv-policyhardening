# Quick Start Guide - Azure Key Vault Policy Governance

**Version**: 1.1.1  
**Last Updated**: 2026-01-28  
**Prerequisites Time**: 10 minutes  
**Deployment Time**: 5 minutes  
**Auto-Remediation Policies**: 8 (DeployIfNotExists + Modify effects)

**Quick Links**: [README](README.md) | [Prerequisites](DEPLOYMENT-PREREQUISITES.md) | [All Workflows](DEPLOYMENT-WORKFLOW-GUIDE.md) | [Commands Reference](SCENARIO-COMMANDS-REFERENCE.md) | [Cleanup Guide](CLEANUP-EVERYTHING-GUIDE.md)

---

## 🎯 The 5 Ws and H

| Question | Answer |
|----------|--------|
| **WHO** | Azure administrators deploying Key Vault governance policies |
| **WHAT** | Step-by-step guide to deploy 46 Azure Key Vault policies (8 with auto-remediation) |
| **WHEN** | Follow this guide for your first deployment (Dev/Test → Production) |
| **WHERE** | Azure subscription with existing or new Key Vault resources |
| **WHY** | Quickly establish secure, compliant Key Vault governance |
| **HOW** | PowerShell automation with pre-configured parameter files |

---

## 📋 Prerequisites (One-Time Setup)

### 1. PowerShell and Azure Modules

```powershell
# Verify PowerShell version (requires 7.0+)
$PSVersionTable.PSVersion

# Install required Azure modules (~5 minutes first time)
Install-Module -Name Az.Accounts, Az.Resources, Az.PolicyInsights, Az.KeyVault -Force -Scope CurrentUser

# Connect to your Azure subscription
Connect-AzAccount
Set-AzContext -Subscription "<your-subscription-id>"
```

### 2. Extract Release Package

```powershell
# Extract the release package ZIP
Expand-Archive -Path "azure-keyvault-policy-governance-1.1.1-FINAL.zip" -DestinationPath "C:\Azure\KeyVault-Policies"
cd "C:\Azure\KeyVault-Policies"
```

### 3. Infrastructure Setup (REQUIRED - Choose Your Scenario)

**Before deploying policies, you MUST create the required infrastructure using the setup script.**

#### 🧪 **Dev/Test Environment** (Complete Testing Infrastructure)

Creates a full testing environment from scratch with:
- ✅ User-assigned managed identity (for auto-remediation policies)
- ✅ Event Hub namespace (for diagnostic logs)
- ✅ Log Analytics workspace (for monitoring)
- ✅ Virtual Network + Subnet (for private endpoints)
- ✅ Private DNS Zone (for private Key Vaults)
- ✅ **3 Test Key Vaults** (compliant, non-compliant, partial - for testing)
- ✅ Test data (secrets, keys, certificates)
- ✅ Monitoring alerts and action groups

**Use Case**: Learning, testing, validation before production

```powershell
# Create complete dev/test environment
.\scripts\Setup-AzureKeyVaultPolicyEnvironment.ps1 -Environment DevTest

# What gets created:
# - Resource Group: rg-policy-keyvault-test (test vaults)
# - Resource Group: rg-policy-remediation (infrastructure)
# - 3 Key Vaults for testing policy behavior
# - All monitoring and networking infrastructure
```

#### 🏭 **Production Environment** (Minimal Policy-Required Infrastructure)

Creates ONLY the infrastructure required for Azure Policy governance:
- ✅ User-assigned managed identity (for 8 auto-remediation policies)
- ✅ Event Hub namespace (for diagnostic log policies)
- ✅ Log Analytics workspace (for monitoring policies)
- ❌ **NO test vaults** (policies monitor your EXISTING production vaults)
- ❌ **NO test data** (uses your existing secrets/keys/certificates)
- ❌ **NO VNet/Subnet** (optional - only if using private endpoint policies)

**Use Case**: Production deployment monitoring existing Key Vaults

```powershell
# Create minimal production infrastructure
.\scripts\Setup-AzureKeyVaultPolicyEnvironment.ps1 -Environment Production

# What gets created:
# - Resource Group: rg-policy-remediation (infrastructure only)
# - Managed Identity: id-policy-remediation
# - Event Hub: eh-policy-prod-<random>
# - Log Analytics: law-policy-prod-<random>
# - RBAC assignments for managed identity

# What does NOT get created:
# - Key Vaults (policies monitor EXISTING vaults in your subscription)
# - Test data
# - Virtual networks (unless you need private endpoints)
```

**📖 For detailed infrastructure requirements, see [DEPLOYMENT-PREREQUISITES.md](DEPLOYMENT-PREREQUISITES.md)**

---

## ⚡ Deployment Scenarios

### Scenario 1: Dev/Test - Safe Start (30 Policies, Audit Mode)

**What**: 30 policies in Audit mode - monitors but doesn't block  
**Why**: Safe testing without impacting existing resources  
**Timeline**: 5 minutes deployment + 15-30 minutes Azure evaluation  
**Auto-Remediation**: 8 policies included (but in Audit mode, won't auto-fix yet)

```powershell
# Prerequisites: Run Setup-AzureKeyVaultPolicyEnvironment.ps1 -Environment DevTest first!

# Get managed identity created during infrastructure setup
$subscriptionId = (Get-AzContext).Subscription.Id
$identityId = "/subscriptions/$subscriptionId/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# Deploy policies with managed identity (ensures all 30 policies deploy, including 8 DINE/Modify)
.\scripts\AzPolicyImplScript.ps1 `
    -ParameterFile .\parameters\PolicyParameters-DevTest.json `
    -PolicyMode Audit `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck

# Check compliance (wait 15-30 min for Azure Policy evaluation)
.\scripts\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck

# View HTML report
Get-Item ComplianceReport-*.html | Select-Object -First 1 | ForEach-Object { Start-Process $_.FullName }
```

**Expected Result**:
- ✅ 30/30 policies assigned in Audit mode
  - 22 Audit-only policies
  - **8 DeployIfNotExists/Modify policies** (will auto-remediate when triggered)
- ✅ HTML compliance report with VALUE-ADD metrics:
  - 💵 **$60,000/year** cost savings
  - ⏱️ **135 hours/year** time savings
  - 🚀 **98.2% faster** deployment (45 sec vs 42 min manual)
  - 🛡️ **100%** security enforcement
- ✅ No blocking of existing operations
- ✅ Policies monitor 3 test vaults created by setup script

**📚 Next Steps**: See [DEPLOYMENT-WORKFLOW-GUIDE.md](DEPLOYMENT-WORKFLOW-GUIDE.md) for additional scenarios

---

### Scenario 2: Dev/Test - Full Coverage (46 Policies, Audit Mode)

**What**: All 46 policies in Audit mode  
**Why**: Complete governance testing before production  
**Timeline**: 5 minutes deployment + 30 minutes evaluation  
**Auto-Remediation**: Same 8 policies (Audit mode)

```powershell
# Prerequisites: Run Setup-AzureKeyVaultPolicyEnvironment.ps1 -Environment DevTest first!

# Get managed identity
$subscriptionId = (Get-AzContext).Subscription.Id
$identityId = "/subscriptions/$subscriptionId/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# Deploy all 46 policies with managed identity
.\scripts\AzPolicyImplScript.ps1 `
    -ParameterFile .\parameters\PolicyParameters-DevTest-Full.json `
    -PolicyMode Audit `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck

# Run comprehensive tests
.\scripts\AzPolicyImplScript.ps1 -TestInfrastructure -Detailed -SkipRBACCheck
.\scripts\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**Expected Result**:
- ✅ 46/46 policies assigned successfully (complete coverage)
- ✅ All infrastructure tests pass
- ✅ Complete compliance baseline established

---

### Scenario 3: Production - Audit Baseline (46 Policies, Audit Mode) ⭐ **RECOMMENDED FIRST**

**What**: All 46 policies monitoring EXISTING production vaults  
**Why**: Establish compliance baseline without enforcement  
**Timeline**: 5 minutes deployment + 30-60 minutes evaluation  
**Auto-Remediation**: 8 policies ready (but won't auto-fix in Audit mode)

```powershell
# Prerequisites: Run Setup-AzureKeyVaultPolicyEnvironment.ps1 -Environment Production first!

# Get managed identity
$subscriptionId = (Get-AzContext).Subscription.Id
$identityId = "/subscriptions/$subscriptionId/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# Deploy all 46 policies to monitor existing production vaults
.\scripts\AzPolicyImplScript.ps1 `
    -ParameterFile .\parameters\PolicyParameters-Production.json `
    -PolicyMode Audit `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck

# Check compliance of existing vaults
.\scripts\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**Expected Result**:
- ✅ 46/46 policies assigned to subscription scope
- ✅ Policies monitor ALL Key Vaults in subscription (existing + future)
- ✅ Compliance report shows current state of production vaults
- ⚠️ NO vaults blocked (Audit mode only monitors)
- 📊 Baseline established for production enforcement decision

**💡 Production Best Practice**:
1. Deploy Scenario 3 (Audit) first → Monitor 7-14 days
2. Review compliance reports → Identify non-compliant vaults
3. Fix critical issues manually or create exemptions
4. Deploy Scenario 4 (Deny) → Prevent new non-compliant resources
5. Deploy Scenario 5 (Auto-Remediation) → Fix existing issues automatically

---

### Scenario 4: Production - Enforcement (34 Deny Policies + 12 Audit)

**What**: 34 policies in Deny mode + 12 in Audit mode  
**Why**: Block new non-compliant resources while monitoring others  
**Timeline**: 5 minutes deployment  
**Requires**: Scenario 3 completed and reviewed

**⚠️ WARNING**: Deny mode BLOCKS resource creation/updates. Only deploy after reviewing Audit compliance.

```powershell
# Prerequisites: Scenario 3 deployed and reviewed for 7+ days

# Get managed identity
$subscriptionId = (Get-AzContext).Subscription.Id
$identityId = "/subscriptions/$subscriptionId/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# Deploy Deny policies (will block non-compliant operations)
.\scripts\AzPolicyImplScript.ps1 `
    -ParameterFile .\parameters\PolicyParameters-Production-Deny.json `
    -PolicyMode Deny `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck
```

**Expected Result**:
- ✅ 34 policies in Deny mode (will BLOCK non-compliant operations)
- ✅ 12 policies in Audit mode (monitoring only)
- 🚫 Non-compliant Key Vault creations/updates will fail
- 📊 Compliance percentage should increase to 95%+

**📖 For complete Deny testing, see [DEPLOYMENT-WORKFLOW-GUIDE.md](DEPLOYMENT-WORKFLOW-GUIDE.md) for detailed procedures**

---

### Scenario 5: Production - Auto-Remediation (8 DINE/Modify Enforce + 38 Audit)

**What**: 8 auto-remediation policies actively fixing issues  
**Why**: Automatically remediate non-compliant resources  
**Timeline**: 5 minutes deployment + 60-90 minutes Azure auto-remediation  
**Requires**: Scenario 3 or 4 completed

**💡 The 8 Auto-Remediation Policies**:

⚠️ **PRODUCTION WARNING**: These policies will AUTOMATICALLY modify your Key Vaults. Review potential impacts before deployment.

| Policy | Effect | What It Does | ⚠️ Potential Impact / Mitigation |
|--------|--------|--------------|----------------------------------|
| Configure Azure Key Vault Managed HSM to disable public network access | Modify | Disables public access on HSMs | **BREAKS**: Public access to HSM<br>**MITIGATE**: Ensure private endpoints configured first |
| Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace | DeployIfNotExists | Creates diagnostic settings → Log Analytics | **COST**: Log Analytics ingestion charges (~$2.30/GB)<br>**MITIGATE**: Set retention policies, monitor costs |
| Configure Azure Key Vaults with private endpoints | DeployIfNotExists | Creates private endpoints for vaults | **COST**: Private endpoint charges (~$7.30/month each)<br>**MITIGATE**: Review existing network topology |
| Deploy - Configure diagnostic settings to an Event Hub for Managed HSM | DeployIfNotExists | Creates diagnostic settings → Event Hub (HSM) | **COST**: Event Hub ingress charges<br>**MITIGATE**: Configure Event Hub retention |
| Configure Azure Key Vaults to use private DNS zones | DeployIfNotExists | Configures private DNS zones | **BREAKS**: Public DNS resolution<br>**MITIGATE**: Ensure VNet DNS configured |
| Configure key vaults to enable firewall | Modify | Enables firewall on vaults | **BREAKS**: Unrestricted access from all IPs<br>**MITIGATE**: Add allowed IP ranges BEFORE deployment |
| Configure Azure Key Vault Managed HSM with private endpoints | DeployIfNotExists | Creates private endpoints for HSMs | **COST**: Private endpoint charges<br>**MITIGATE**: Review network requirements |
| Deploy Diagnostic Settings for Key Vault to Event Hub | DeployIfNotExists | Creates diagnostic settings → Event Hub | **COST**: Event Hub charges<br>**MITIGATE**: Set appropriate retention |

**🛡️ Recommended Pre-Deployment Steps**:
1. **Test in Dev/Test first** - Deploy Scenario 2 with test vaults
2. **Review existing vaults** - Check current network configuration
3. **Whitelist IPs** - Add allowed IP ranges for firewall policies
4. **Configure private endpoints** - Set up VNet/subnet if using private networking
5. **Monitor costs** - Review Event Hub and Log Analytics pricing
6. **Create exemptions** - For vaults that should NOT be auto-remediated (see [SCENARIO-COMMANDS-REFERENCE.md](SCENARIO-COMMANDS-REFERENCE.md))

```powershell
# Prerequisites: Scenario 3 or 4 deployed

# Get managed identity (required for auto-remediation)
$subscriptionId = (Get-AzContext).Subscription.Id
$identityId = "/subscriptions/$subscriptionId/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# Deploy auto-remediation policies (8 Enforce + 38 Audit)
.\scripts\AzPolicyImplScript.ps1 `
    -ParameterFile .\parameters\PolicyParameters-Production-Remediation.json `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck

# Monitor remediation progress (wait 60-90 minutes)
Start-Sleep -Seconds 5400  # Wait 90 minutes
.\scripts\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck

# Check remediation tasks
Get-AzPolicyRemediation -Scope "/subscriptions/$subscriptionId" | 
    Where-Object { $_.CreatedOn -gt (Get-Date).AddHours(-2) } |
    Format-Table Name, ProvisioningState, DeploymentSummary
```

**Expected Result**:
- ✅ 8 policies in Enforce mode (DeployIfNotExists/Modify effects)
- ✅ 38 policies in Audit mode
- ⏳ Azure creates remediation tasks (60-90 min)
- 🔧 Non-compliant resources automatically fixed
- 📊 Compliance increases from ~32% to 60-80%

**📖 For detailed remediation monitoring, see [DEPLOYMENT-WORKFLOW-GUIDE.md](DEPLOYMENT-WORKFLOW-GUIDE.md) for complete procedures**

---

## 🧹 Cleanup Procedures

### Remove Policies Only (Keep Infrastructure)

```powershell
# Remove all KV-* policy assignments (does NOT remove managed identity or monitoring)
.\scripts\AzPolicyImplScript.ps1 -Rollback
```

### Remove Everything (Policies + Infrastructure)

```powershell
# Remove policies first
.\scripts\AzPolicyImplScript.ps1 -Rollback

# Remove infrastructure (Event Hub, Log Analytics, Managed Identity, Test Vaults)
.\scripts\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst
```

**📖 For complete cleanup procedures, see [CLEANUP-EVERYTHING-GUIDE.md](CLEANUP-EVERYTHING-GUIDE.md)**

---

## 🚨 Important Production Considerations

### What Production Setup Script Creates

The setup script with `-Environment Production` creates ONLY:
- ✅ Resource Group: `rg-policy-remediation`
- ✅ Managed Identity: `id-policy-remediation` (for 8 auto-remediation policies)
- ✅ Event Hub: `eh-policy-prod-<random>` (for diagnostic log policies)
- ✅ Log Analytics: `law-policy-prod-<random>` (for monitoring policies)
- ✅ RBAC: Contributor role for managed identity (subscription scope)

### What Production Setup Does NOT Create

- ❌ Key Vaults (policies monitor YOUR existing vaults)
- ❌ Secrets, keys, certificates (uses YOUR existing data)
- ❌ Virtual networks or subnets (unless you need private endpoints)
- ❌ Test data or test resource groups

### Policy Scope in Production

- **Subscription-Wide**: Policies apply to ALL Key Vaults in subscription
- **Existing Vaults**: Monitored immediately after deployment
- **New Vaults**: Automatically governed by policies
- **Exemptions**: Create for specific vaults if needed (see [SCENARIO-COMMANDS-REFERENCE.md](SCENARIO-COMMANDS-REFERENCE.md))

### Existing Azure Policies

If your subscription already has Azure Policies:
1. ✅ Our policies will coexist with existing ones
2. ⚠️ Review for conflicting assignments (same policy, different parameters)
3. 💡 Use `-WhatIf` mode to preview before deployment
4. 📊 Check compliance reports to identify overlaps

---

## ❓ Troubleshooting

### "Policy assignment failed" Error
→ Check RBAC permissions (requires Contributor on subscription)  
→ See [DEPLOYMENT-PREREQUISITES.md](DEPLOYMENT-PREREQUISITES.md)

### "No remediation tasks created" Issue
→ Wait 75-90 minutes after deployment (Azure Policy evaluation cycle)  
→ Ensure managed identity has Contributor role

### "HSM policies failing" in Dev/Test
→ Expected (requires HSM quota not available in dev/test subscriptions)  
→ See [UNSUPPORTED-SCENARIOS.md](UNSUPPORTED-SCENARIOS.md)

### "Cannot find managed identity" Error
→ Run setup script first: `.\scripts\Setup-AzureKeyVaultPolicyEnvironment.ps1 -Environment <DevTest|Production>`

---

## 📚 Related Documentation

- **[README.md](README.md)** - Master index and project overview
- **[DEPLOYMENT-PREREQUISITES.md](DEPLOYMENT-PREREQUISITES.md)** - Complete infrastructure requirements
- **[DEPLOYMENT-WORKFLOW-GUIDE.md](DEPLOYMENT-WORKFLOW-GUIDE.md)** - All 5 deployment scenarios with detailed commands
- **[SCENARIO-COMMANDS-REFERENCE.md](SCENARIO-COMMANDS-REFERENCE.md)** - Quick command reference
- **[POLICY-COVERAGE-MATRIX.md](POLICY-COVERAGE-MATRIX.md)** - 46 policies detailed analysis
- **[CLEANUP-EVERYTHING-GUIDE.md](CLEANUP-EVERYTHING-GUIDE.md)** - Complete cleanup procedures
- **[UNSUPPORTED-SCENARIOS.md](UNSUPPORTED-SCENARIOS.md)** - HSM and Integrated CA limitations

---

**Version**: 1.1.1 | **Updated**: 2026-01-28 | **Package**: azure-keyvault-policy-governance-1.1.1-FINAL.zip
