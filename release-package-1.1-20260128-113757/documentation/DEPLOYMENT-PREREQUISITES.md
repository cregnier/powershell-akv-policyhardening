# Azure Policy Implementation - Deployment Prerequisites

**Version**: 2.1  
**Last Updated**: 2026-01-27  
**Audience**: Azure Administrators deploying Key Vault governance policies  
**Test Results**: 25/34 Deny Policies Validated (74% in MSDN) | 46/46 Total Policies Deployed

---

## 🎯 The 5 Ws and H

| Question | Answer |
|----------|--------|
| **WHO** | Azure administrators with Policy Contributor or Owner role |
| **WHAT** | Prerequisites and requirements for deploying 46 Azure Key Vault policies |
| **WHEN** | Review this before your first deployment or when troubleshooting |
| **WHERE** | Azure subscriptions/resource groups with Key Vault resources |
| **WHY** | Ensure successful policy deployment without errors or missing dependencies |
| **HOW** | Install modules, configure RBAC, prepare infrastructure, select parameter files |

---

## Quick Reference

**To run AzPolicyImplScript.ps1 successfully, you need:**

✅ PowerShell 7.0+ with Azure Az modules  
✅ Azure subscription access with Policy Contributor or Owner role  
✅ **6 parameter files** for all testing scenarios (included in repository)  
✅ **Mandatory**: Managed Identity for ALL deployments (8 DINE/Modify policies skip without it)  
✅ Optional: Infrastructure resources for diagnostic policies (Log Analytics, Event Hub)

**💰 VALUE-ADD**: $60K/year savings | 135 hrs/year time saved | 100% security prevention | 98.2% deployment speed

**📖 Parameter File Guide**: See [PARAMETER-FILE-USAGE-GUIDE.md](PARAMETER-FILE-USAGE-GUIDE.md) for complete guide.

---

## Parameter Files Structure (6 Files)

### DevTest Environment - Safety Option (30 policies)
- `PolicyParameters-DevTest.json` - Audit mode, safe default
- `PolicyParameters-DevTest-Remediation.json` - 6 auto-remediation policies

### DevTest Environment - Full Testing (46 policies)
- `PolicyParameters-DevTest-Full.json` - Audit mode, comprehensive testing
- `PolicyParameters-DevTest-Full-Remediation.json` - 8 auto-remediation policies

### Production Environment (46 policies)
- `PolicyParameters-Production.json` - Deny mode enforcement
- `PolicyParameters-Production-Remediation.json` - 8 auto-remediation policies

**Quick Deploy Commands:**
```powershell
# Get managed identity (created by Setup-AzureKeyVaultPolicyEnvironment.ps1)
$identity = Get-AzUserAssignedIdentity -ResourceGroupName "rg-policy-remediation" -Name "id-policy-remediation"
$identityId = $identity.Id

# DevTest (30 policies) - Subscription scope
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest.json `
    -PolicyMode Audit `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck

# DevTest Full (46 policies) - Subscription scope
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full.json `
    -PolicyMode Audit `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck

# Production (46 policies, Deny mode) - Subscription scope
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Deny.json `
    -PolicyMode Deny `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck

# Auto-Remediation Testing (8 DINE/Modify policies)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck
    
.\AzPolicyImplScript.ps1 -TestAutoRemediation -SkipRBACCheck
```

---

## 1. PowerShell Modules

### Required Modules (Auto-Installed)

The script automatically installs missing modules, but you can pre-install them:

```powershell
# Install all required Azure PowerShell modules
Install-Module -Name Az.Accounts -Scope CurrentUser -Force -AllowClobber
Install-Module -Name Az.Resources -Scope CurrentUser -Force -AllowClobber
Install-Module -Name Az.PolicyInsights -Scope CurrentUser -Force -AllowClobber
Install-Module -Name Az.Monitor -Scope CurrentUser -Force -AllowClobber
Install-Module -Name Az.KeyVault -Scope CurrentUser -Force -AllowClobber
```

### Module Purpose

| Module | Purpose |
|--------|---------|
| **Az.Accounts** | Azure authentication and subscription management |
| **Az.Resources** | Policy assignment, resource group management, managed identities |
| **Az.PolicyInsights** | Policy compliance data, policy state queries |
| **Az.Monitor** | Diagnostic settings, activity log alerts |
| **Az.KeyVault** | Key Vault operations for testing deny blocking |

### Version Requirements

- **PowerShell**: 5.1 or PowerShell Core 7.x
- **Az Modules**: Latest versions recommended (auto-updated by script)

---

## 2. Azure Subscription & Authentication

### Subscription Access

You need access to an Azure subscription where you'll deploy policies.

**Get your subscription ID:**
```powershell
Connect-AzAccount
Get-AzSubscription | Format-Table Name, Id, State
```

### Authentication

The script supports:
- ✅ **Interactive login** (default): `Connect-AzAccount`
- ✅ **Service Principal**: Pre-authenticate before running script
- ✅ **Managed Identity**: For automated/CI-CD scenarios

**First-time setup:**
```powershell
# Connect to Azure (prompts for credentials)
Connect-AzAccount

# Select subscription (if you have multiple)
Set-AzContext -SubscriptionId "YOUR-SUBSCRIPTION-ID"
```

---

## 3. Required RBAC Permissions

### Minimum Required Roles

You need **ONE** of these roles at the deployment scope:

| Role | Permissions | Recommended For |
|------|-------------|-----------------|
| **Owner** | Full control including RBAC | Production deployments |
| **Contributor** + **Resource Policy Contributor** | Deploy policies + manage policy assignments | Most common |
| **Policy Contributor** | Manage policy assignments only | Policy-focused deployments |

### Scope Levels

Policies can be assigned at different scopes:

| Scope | Example | RBAC Required At | Recommended |
|-------|---------|------------------|-------------|
| **Subscription** | `/subscriptions/{sub-id}` | Subscription level | ✅ **YES** (production-ready) |
| **Management Group** | `/providers/Microsoft.Management/managementGroups/{mg-id}` | Management Group level | ✅ Best (multi-subscription) |
| **Resource Group** | `/subscriptions/{sub-id}/resourceGroups/rg-name` | Resource Group level | ❌ Limited testing only |

**💡 Best Practice**: Always use **Subscription scope** (or Management Group if available) for production deployments. This ensures policies apply to all current and future Key Vaults.

**Updated Strategy** (as of Jan 2026):
- All test scenarios now use **Subscription scope** by default
- Resource Group scope deprecated for production use
- Script hardcoded to use Subscription (line 5773 in AzPolicyImplScript.ps1)

### Check Your Permissions

```powershell
# Check your role assignments
$subscriptionId = "YOUR-SUBSCRIPTION-ID"
$scope = "/subscriptions/$subscriptionId"

Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id -Scope $scope | 
    Select-Object RoleDefinitionName, Scope | 
    Format-Table

# Required roles to see:
# - Owner (best)
# - Contributor + Resource Policy Contributor (good)
# - Policy Contributor (minimum)
```

### Missing Permissions?

If you don't have required roles, you can skip the RBAC check using the `-SkipRBACCheck` parameter.

#### ✅ When to Use `-SkipRBACCheck`

Use this parameter in these scenarios:

1. **Automated CI/CD Pipelines**  
   Service principal/managed identity permissions are pre-verified in pipeline configuration
   ```powershell
   .\AzPolicyImplScript.ps1 -DeployDevTest -SkipRBACCheck
   ```

2. **Testing Environments**  
   You've confirmed RBAC assignments separately and want to speed up repeated testing
   ```powershell
   .\AzPolicyImplScript.ps1 -TestInfrastructure -SkipRBACCheck
   ```

3. **Repeated Deployments**  
   You've already validated permissions on first run and don't need to check again
   ```powershell
   .\AzPolicyImplScript.ps1 -CheckCompliance -SkipRBACCheck
   ```

4. **Non-Interactive Execution**  
   Running in scripts, automation runbooks, or scheduled tasks where interactive permission prompts would fail
   ```powershell
   # In Azure Automation Runbook
   .\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -SkipRBACCheck
   ```

#### ⚠️ When NOT to Use `-SkipRBACCheck`

Avoid this parameter in these scenarios:

1. **First-Time Deployment**  
   Always verify RBAC on new subscriptions/resource groups to ensure proper permissions
   ```powershell
   # DON'T skip on first run - let script verify permissions
   .\AzPolicyImplScript.ps1 -DeployProduction  # ✅ Correct (checks RBAC)
   ```

2. **Production Environments with Strict Governance**  
   Validate permissions to avoid audit issues and ensure compliance
   ```powershell
   # Production deployment - verify RBAC for audit trail
   .\AzPolicyImplScript.ps1 -DeployProduction  # ✅ Correct
   ```

3. **Uncertain About Role Assignments**  
   Let the script check and show helpful error messages if permissions are missing
   ```powershell
   # If unsure, let script check:
   .\AzPolicyImplScript.ps1 -DeployDevTest
   # Script will show RBAC request template if permissions missing
   ```

#### Impact of Skipping RBAC Check

When `-SkipRBACCheck` is used:
- **No permission validation** before policy deployment
- **Deployment may fail** with cryptic Azure API errors if permissions missing
- **No helpful RBAC request template** generated (script normally shows this)
- **Faster execution** (~5-10 seconds saved per run)

**Best Practice**: Use `-SkipRBACCheck` only after successful initial deployment with RBAC validation complete.

---
## 4. Required Files

### Core Script Files

| File | Required? | Purpose |
|------|-----------|---------|
| **AzPolicyImplScript.ps1** | ✅ Yes | Main deployment script |
| **PolicyParameters-DevTest.json** | ✅ Yes (for DevTest) | DevTest environment parameters |
| **PolicyParameters-Production.json** | ✅ Yes (for Production) | Production environment parameters |

### Optional Configuration Files

| File | Required? | Purpose |
|------|-----------|---------|
| **PolicyImplementationConfig.json** | ⚪ Optional | Pre-configured settings (subscription ID, managed identity, etc.) |
| **DefinitionListExport.csv** | ⚪ Optional | Policy definition reference (auto-generated) |
| **Comprehensive-Test-Plan.md** | ⚪ Optional | Testing strategy and phases |

### Minimal File Set

**For a new deployment, the minimum files needed:**

```
📁 azure-keyvault-policy-governance-1.2.0/
├── 📁 scripts/
│   ├── AzPolicyImplScript.ps1
│   └── Setup-AzureKeyVaultPolicyEnvironment.ps1
├── 📁 parameters/
│   ├── PolicyParameters-DevTest.json
│   ├── PolicyParameters-DevTest-Full.json
│   ├── PolicyParameters-Production.json
│   └── PolicyParameters-Production-Deny.json
├── 📁 reference-data/
│   ├── DefinitionListExport.csv
│   ├── PolicyNameMapping.json
│   └── PolicyImplementationConfig.json
└── 📁 documentation/
    ├── QUICKSTART.md
    └── DEPLOYMENT-PREREQUISITES.md
```

**Note**: The actual release package structure matches this layout. All scripts auto-generate additional files as needed (logs, reports, etc.).

---

## 5. Azure Resources (For Specific Policies)

### Optional: Managed Identity

**Required for:** DeployIfNotExists and Modify policies

**When deploying these policy types, you need a Managed Identity with:**
- User-assigned managed identity created in Azure
- Appropriate role assignments (e.g., Contributor, Key Vault Contributor)

**Create managed identity:**
```powershell
# Create resource group for policy infrastructure
New-AzResourceGroup -Name "rg-policy-remediation" -Location "eastus"

# Create user-assigned managed identity
$identity = New-AzUserAssignedIdentity `
    -ResourceGroupName "rg-policy-remediation" `
    -Name "id-policy-remediation" `
    -Location "eastus"

# Assign Contributor role at subscription scope
$subscriptionId = "YOUR-SUBSCRIPTION-ID"
New-AzRoleAssignment `
    -ObjectId $identity.PrincipalId `
    -RoleDefinitionName "Contributor" `
    -Scope "/subscriptions/$subscriptionId"

# Get the full resource ID for use with -IdentityResourceId parameter
$identityResourceId = $identity.Id
Write-Host "Managed Identity Resource ID: $identityResourceId" -ForegroundColor Green
# Example output: /subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation
```

#### Using `-IdentityResourceId` Parameter

**When deploying auto-remediation policies**, you **MUST** provide the full ARM resource ID:

```powershell
# ✅ CORRECT: Full ARM resource ID
.\.AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation" `
    -SkipRBACCheck

# ❌ INCORRECT: Just the identity name (will fail)
.\.AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -IdentityResourceId "id-policy-remediation" `
    -SkipRBACCheck
```

**Get Your Identity Resource ID**:
```powershell
# Method 1: Query Azure
$identity = Get-AzUserAssignedIdentity -ResourceGroupName "rg-policy-remediation" -Name "id-policy-remediation"
$identity.Id

# Method 2: Construct manually
$subscriptionId = (Get-AzContext).Subscription.Id
$identityResourceId = "/subscriptions/$subscriptionId/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Which Policies Require Managed Identity?**

Only **8 policies** with `DeployIfNotExists` or `Modify` effects:

1. Azure Key Vault should have firewall enabled (DeployIfNotExists)
2. Configure Azure Key Vaults to use private DNS zones (DeployIfNotExists)
3. Configure Key vaults to enable firewall (Modify)
4. Enable logging by category group for Key Vault to Event Hub (DeployIfNotExists)
5. Enable logging by category group for Key Vault to Log Analytics (DeployIfNotExists)
6. Enable logging by category group for Key Vault to Storage (DeployIfNotExists)
7. Resource logs in Key Vault should be enabled (DeployIfNotExists)
8. Configure diagnostic settings for Key Vault to Log Analytics workspace (DeployIfNotExists)

**📖 Complete Parameter Guide**: See [PolicyParameters-QuickReference.md](PolicyParameters-QuickReference.md) for decision tree

**Policies that need managed identity:**
- Configure diagnostic settings (DeployIfNotExists)
- Configure private endpoints (DeployIfNotExists)
- Configure firewall (Modify)
- Configure public network access (Modify)

### Optional: Infrastructure Resources

Some policies reference Azure infrastructure that may not exist in new environments:

| Policy Type | Required Resource | Example |
|-------------|-------------------|---------|
| **Diagnostic Settings** | Log Analytics workspace OR Event Hub | `/subscriptions/{id}/resourceGroups/rg-policy-remediation/providers/Microsoft.OperationalInsights/workspaces/law-keyvault` |
| **Private Endpoints** | Virtual Network + Subnet | `/subscriptions/{id}/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-main/subnets/subnet-privatelink` |
| **Private DNS Zones** | Private DNS Zone | `/subscriptions/{id}/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net` |

**For DevTest**: The parameter files include placeholder resource IDs - policies will show "Not Applicable" status (this is normal).

**For Production**: Replace placeholder IDs with real infrastructure resource IDs before deployment.

---

## 6. Environment-Specific Setup

### DevTest Environment

**Minimum requirements:**
- ✅ Azure subscription with Contributor access
- ✅ AzPolicyImplScript.ps1
- ✅ PolicyParameters-DevTest.json
- ⚪ Optional: Test resource group (auto-created if missing)

**Command:**
```powershell
.\AzPolicyImplScript.ps1 -Environment DevTest -Phase Test
```

### Production Environment

**Minimum requirements:**
- ✅ Azure subscription with Owner OR (Contributor + Resource Policy Contributor)
- ✅ AzPolicyImplScript.ps1
- ✅ PolicyParameters-Production.json
- ✅ Managed identity for DeployIfNotExists/Modify policies (if using these)
- ⚪ Infrastructure resources (Log Analytics, Event Hub, Private Link) if enforcing those policies

**Command:**
```powershell
.\AzPolicyImplScript.ps1 -Environment Production -Phase Audit
```

---

## 7. Network Requirements

### Internet Connectivity

The script requires internet access to:
- ✅ Download PowerShell modules from PSGallery
- ✅ Connect to Azure Resource Manager (management.azure.com)
- ✅ Query Azure Policy APIs
- ✅ Authenticate with Azure AD

### Firewall/Proxy Considerations

If behind a corporate firewall/proxy:

```powershell
# Configure PowerShell to use proxy
$proxy = [System.Net.WebProxy]::new("http://proxy.company.com:8080")
[System.Net.WebRequest]::DefaultWebProxy = $proxy

# Or set environment variable
$env:HTTP_PROXY = "http://proxy.company.com:8080"
$env:HTTPS_PROXY = "http://proxy.company.com:8080"
```

### Azure Endpoints

Must be able to reach:
- `management.azure.com` (Azure Resource Manager)
- `login.microsoftonline.com` (Azure AD authentication)
- `psgallery.powershellgallery.com` (PowerShell Gallery)

---

## 8. Step-by-Step Setup on New Computer

### Step 1: Install PowerShell (if needed)

**Windows:**
- PowerShell 5.1 is pre-installed
- Or install [PowerShell 7](https://github.com/PowerShell/PowerShell/releases)

**macOS/Linux:**
- Install [PowerShell Core 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)

### Step 2: Copy Files

Copy to new computer:
```
C:\PolicyDeployment\
├── AzPolicyImplScript.ps1
├── PolicyParameters-DevTest.json
└── PolicyParameters-Production.json
```

### Step 3: Install Azure Modules

```powershell
# The script auto-installs, but you can pre-install:
Install-Module -Name Az.Accounts, Az.Resources, Az.PolicyInsights, Az.Monitor, Az.KeyVault `
    -Scope CurrentUser -Force -AllowClobber
```

### Step 4: Connect to Azure

```powershell
# Authenticate
Connect-AzAccount

# Verify connection
Get-AzContext

# Select subscription (if needed)
Set-AzContext -SubscriptionId "YOUR-SUBSCRIPTION-ID"
```

### Step 5: Verify RBAC Permissions

```powershell
# Check your roles
Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id | 
    Where-Object { $_.Scope -like "*/subscriptions/*" } |
    Select-Object RoleDefinitionName, Scope
```

Expected to see:
- Owner (best)
- Contributor + Resource Policy Contributor (good)
- Policy Contributor (minimum)

### Step 6: Run Deployment

```powershell
# Navigate to script directory
cd C:\PolicyDeployment

# Run DevTest deployment
.\AzPolicyImplScript.ps1 -Environment DevTest -Phase Test

# Or skip RBAC check if pre-verified
.\AzPolicyImplScript.ps1 -Environment DevTest -Phase Test -SkipRBACCheck
```

---

## 9. CI/CD Pipeline Setup

### Azure DevOps Pipeline

**Prerequisites:**
- ✅ Service Connection to Azure subscription
- ✅ Service Principal with Contributor + Resource Policy Contributor roles

**azure-pipelines.yml:**
```yaml
trigger:
  branches:
    include:
      - main

pool:
  vmImage: 'windows-latest'

steps:
- task: AzurePowerShell@5
  inputs:
    azureSubscription: 'YOUR-SERVICE-CONNECTION'
    ScriptType: 'FilePath'
    ScriptPath: '$(Build.SourcesDirectory)/AzPolicyImplScript.ps1'
    ScriptArguments: '-Environment DevTest -Phase Test -SkipRBACCheck'
    azurePowerShellVersion: 'LatestVersion'
  displayName: 'Deploy Azure Policies'
```

### GitHub Actions

**Prerequisites:**
- ✅ Azure credentials stored in GitHub Secrets
- ✅ Service Principal with Contributor + Resource Policy Contributor roles

**.github/workflows/deploy-policies.yml:**
```yaml
name: Deploy Azure Policies

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy Policies
        shell: pwsh
        run: |
          .\AzPolicyImplScript.ps1 -Environment DevTest -Phase Test -SkipRBACCheck
```

---

## 10. Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| **"Module not found"** | Run: `Install-Module Az.* -Scope CurrentUser -Force` |
| **"Insufficient permissions"** | Verify RBAC roles with `Get-AzRoleAssignment` |
| **"Policy definition not found"** | Ensure using built-in Azure policies (not custom) |
| **"Parameter file not found"** | Check file path and name match exactly |
| **"Managed identity not found"** | Create managed identity or remove DeployIfNotExists policies |

### Enable Debug Logging

```powershell
# Run with verbose output
.\AzPolicyImplScript.ps1 -Environment DevTest -Phase Test -Verbose

# Or enable PowerShell transcript
Start-Transcript -Path "C:\Logs\policy-deployment.log"
.\AzPolicyImplScript.ps1 -Environment DevTest -Phase Test
Stop-Transcript
```

### Test Connection

```powershell
# Test Azure connectivity
Test-NetConnection -ComputerName management.azure.com -Port 443

# Verify authentication
Get-AzContext
Get-AzSubscription

# Test policy permissions
Get-AzPolicyDefinition -Top 1
```

---

## 11. Offline/Disconnected Scenarios

### Air-Gapped Environments

**Challenge**: No internet access for module downloads or Azure connectivity.

**Solution**:
1. Download modules on internet-connected machine:
   ```powershell
   Save-Module -Name Az.Accounts, Az.Resources, Az.PolicyInsights, Az.Monitor, Az.KeyVault `
       -Path "C:\AzModules"
   ```

2. Copy `C:\AzModules` to air-gapped machine

3. Install modules offline:
   ```powershell
   Import-Module C:\AzModules\Az.Accounts\*\Az.Accounts.psd1 -Force
   Import-Module C:\AzModules\Az.Resources\*\Az.Resources.psd1 -Force
   # ... repeat for other modules
   ```

4. Use Azure Stack or Azure Government endpoints if available

---

## 12. Summary Checklist

Before running on a new computer, ensure you have:

### Required ✅
- [ ] **PowerShell 5.1 or 7.x** installed
- [ ] **Internet connectivity** (or offline modules prepared)
- [ ] **AzPolicyImplScript.ps1** file
- [ ] **PolicyParameters-DevTest.json** OR **PolicyParameters-Production.json**
- [ ] **Azure subscription** access
- [ ] **RBAC permissions**: Owner OR (Contributor + Resource Policy Contributor)
- [ ] **Azure authentication**: `Connect-AzAccount` works

### Optional (depending on policies) ⚪
- [ ] **Managed Identity** (for DeployIfNotExists/Modify policies)
- [ ] **Log Analytics workspace** (for diagnostic settings policies)
- [ ] **Event Hub** (for event hub diagnostic policies)
- [ ] **Virtual Network** (for private endpoint policies)
- [ ] **Private DNS Zones** (for private DNS policies)

### Quick Start Command

```powershell
# 1. Connect to Azure
Connect-AzAccount
Set-AzContext -SubscriptionId "YOUR-SUBSCRIPTION-ID"

# 2. Navigate to script directory
cd C:\Path\To\PolicyDeployment

# 3. Run deployment
.\AzPolicyImplScript.ps1 -Environment DevTest -Phase Test
```

---

## 13. Additional Resources

- [Azure Policy Documentation](https://learn.microsoft.com/azure/governance/policy/)
- [Azure PowerShell Documentation](https://learn.microsoft.com/powershell/azure/)
- [Key Vault Policy Integration](https://learn.microsoft.com/azure/key-vault/general/azure-policy)
- [Azure RBAC Documentation](https://learn.microsoft.com/azure/role-based-access-control/)

---

**Last Updated**: 2026-01-14  
**Script Version**: 0.1.0  
**Compatibility**: Windows, macOS, Linux (PowerShell Core 7+)
