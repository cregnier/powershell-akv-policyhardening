# Prerequisites and Permissions Guide
## Sprint 1, Story 1.1 - Environment Discovery

This document details exact requirements for running the discovery scripts in different scenarios.

---

## Supported Scenarios

### Scenario 1: MSDN Subscription with Guest MSA Account
**Use Case**: Personal MSDN subscription where you are the Owner (e.g., Visual Studio subscription benefit)

**Account Type**: Microsoft Account (MSA) added as guest to subscription tenant

**Typical Setup**:
- You have an MSA (e.g., `yourname@outlook.com`, `yourname@gmail.com`)
- Your account appears as `yourname_outlook.com#EXT#@sometenant.onmicrosoft.com`
- You are the Owner of the MSDN subscription

### Scenario 2: Corporate AAD Environment
**Use Case**: Enterprise Azure tenant managed by IT/Cloud team (Intel Azure)

**Account Type**: Azure Active Directory (AAD) corporate account

**Typical Setup**:
- You have a corporate AAD account (e.g., `yourname@company.com`)
- Multiple subscriptions managed by Cloud Brokers
- RBAC permissions vary by subscription
- May need to request access

---

## Prerequisites by Scenario

### Scenario 1: MSDN Subscription (Guest MSA)

#### PowerShell Requirements
```powershell
# Minimum PowerShell version
PowerShell 7.0 or higher

# Check your version
$PSVersionTable.PSVersion
# If < 7.0, install from: https://aka.ms/powershell-release
```

#### Azure PowerShell Modules
```powershell
# Required modules (install if missing)
Install-Module -Name Az.Accounts -MinimumVersion 2.0.0 -Scope CurrentUser -Force
Install-Module -Name Az.Resources -MinimumVersion 6.0.0 -Scope CurrentUser -Force
Install-Module -Name Az.KeyVault -MinimumVersion 4.0.0 -Scope CurrentUser -Force

# Optional (for diagnostic settings check)
Install-Module -Name Az.Monitor -MinimumVersion 4.0.0 -Scope CurrentUser -Force

# Verify installation
Get-Module -ListAvailable -Name Az.Accounts, Az.Resources, Az.KeyVault
```

#### Azure Connectivity
```powershell
# Connect to Azure (browser-based login)
Connect-AzAccount

# If you have multiple tenants, specify tenant ID
Connect-AzAccount -TenantId '<your-tenant-id>'

# Verify connection
Get-AzContext

# Expected output shows:
# Account: yourname_outlook.com#EXT#@sometenant.onmicrosoft.com
# Subscription: Your MSDN subscription name
```

#### RBAC Permissions
**You already have Owner role on your MSDN subscription - no additional permissions needed!**

**Permissions Breakdown**:
- ✅ **Reader**: List subscriptions, resources, Key Vaults (inherited from Owner)
- ✅ **Contributor**: Manage resources (inherited from Owner)
- ✅ **Owner**: Full access including RBAC management (you have this)
- ✅ **User Access Administrator**: View/manage role assignments (inherited from Owner)

**What You Can Do**:
- ✅ Run ALL discovery scripts without limitations
- ✅ View all subscription details
- ✅ View all RBAC assignments (owners, contributors)
- ✅ View all Key Vaults and configurations
- ✅ View all policy assignments
- ✅ Deploy policies (Story 1.2)

**Special Considerations for Guest Accounts**:
- Some Azure APIs may behave differently for guest accounts
- If you encounter "access denied" errors, ensure you're in the correct tenant context
- Use `-TenantId` parameter when connecting if you have multiple tenants

---

### Scenario 2: Corporate AAD Environment (Intel Azure)

#### PowerShell Requirements
```powershell
# Same as Scenario 1
PowerShell 7.0 or higher

# Check your version
$PSVersionTable.PSVersion
```

#### Azure PowerShell Modules
```powershell
# Same modules as Scenario 1
Install-Module -Name Az.Accounts -MinimumVersion 2.0.0 -Scope CurrentUser -Force
Install-Module -Name Az.Resources -MinimumVersion 6.0.0 -Scope CurrentUser -Force
Install-Module -Name Az.KeyVault -MinimumVersion 4.0.0 -Scope CurrentUser -Force
Install-Module -Name Az.Monitor -MinimumVersion 4.0.0 -Scope CurrentUser -Force
```

#### Azure Connectivity
```powershell
# Connect to corporate Azure tenant
Connect-AzAccount -TenantId '<intel-tenant-id>'

# Or just
Connect-AzAccount
# (will prompt for tenant if you have multiple)

# Verify connection and accessible subscriptions
Get-AzSubscription

# If you see "No subscriptions found", you need access granted
```

#### RBAC Permissions (Minimum Required)

##### For Discovery Scripts (Story 1.1)
**Minimum**: **Reader** role at subscription scope

```powershell
# Required permissions:
# - Reader role on each subscription you want to inventory

# To check your current permissions on a subscription:
$subId = '<subscription-id>'
Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id -Scope "/subscriptions/$subId"

# Expected output should include "Reader", "Contributor", or "Owner" role
```

**What You Can Do with Reader Role**:
- ✅ List subscriptions
- ✅ View subscription details and tags
- ✅ View all Key Vaults and configurations
- ✅ View policy assignments
- ✅ View resource counts
- ⚠️ Limited: Cannot view RBAC assignments (owners/contributors) without User Access Administrator
- ❌ Cannot deploy policies (need Contributor + Resource Policy Contributor for Story 1.2)

**Optional Permissions for Enhanced Discovery**:
- **User Access Administrator**: View RBAC role assignments (owners, contributors)
  - Enables `-IncludeRBAC` parameter in subscription inventory
  - Not required for basic discovery

##### For Policy Deployment (Story 1.2 - Future)
**Minimum**: **Contributor** + **Resource Policy Contributor** roles at subscription scope

```powershell
# Required roles for policy deployment:
# - Contributor (to manage resources)
# - Resource Policy Contributor (to create policy assignments)
# OR
# - Owner (includes both)

# Request these roles from Cloud Brokers or subscription owners before Story 1.2
```

#### How to Request Access (Corporate Environment)

If you don't have access to subscriptions:

1. **Identify Target Subscriptions**
   - Work with Cloud Brokers team to identify subscriptions in scope
   - Get subscription IDs and names

2. **Request Reader Access**
   - Contact subscription owners or Cloud Brokers
   - Request: "Reader role at subscription scope for environment discovery"
   - Provide business justification: "Sprint 1 - Azure Key Vault policy deployment planning"

3. **Sample Access Request Email**:
   ```
   Subject: Access Request - Reader Role for Azure Policy Discovery

   Hi [Cloud Brokers / Subscription Owner],

   I need Reader access to the following Azure subscriptions for environment 
   discovery as part of the Azure Key Vault policy deployment project (Sprint 1):

   Subscriptions:
   - [Subscription Name] ([Subscription ID])
   - [Subscription Name] ([Subscription ID])

   Required Role: Reader (at subscription scope)
   Duration: Temporary (2-4 weeks for discovery phase)
   
   Purpose: Inventory Key Vaults and existing policy assignments to prepare 
   for pilot deployment of 46 Azure Key Vault governance policies.

   Please let me know if you need additional information.

   Thanks,
   [Your Name]
   ```

4. **Verify Access After Grant**:
   ```powershell
   # Reconnect to Azure
   Connect-AzAccount
   
   # Verify you can see the subscription
   Get-AzSubscription -SubscriptionId '<subscription-id>'
   
   # Verify you have Reader role
   Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id -Scope "/subscriptions/<subscription-id>"
   ```

---

## Azure CLI Alternative (Not Recommended but Supported)

If you prefer Azure CLI over PowerShell Az modules:

### Required CLI Tools
```bash
# Azure CLI version 2.40.0 or higher
az --version

# Install from: https://docs.microsoft.com/cli/azure/install-azure-cli

# Install PowerShell Az modules anyway (scripts require them)
# Cannot use pure Azure CLI for these discovery scripts
```

**Note**: The discovery scripts are written in PowerShell and require Az modules. Azure CLI alone is **NOT sufficient**.

---

## Resource Provider Registration

Some subscriptions may not have required Resource Providers registered. This is usually handled by subscription owners.

### Check Resource Provider Status
```powershell
# Set context to target subscription
Set-AzContext -SubscriptionId '<subscription-id>'

# Check required providers
Get-AzResourceProvider -ProviderNamespace 'Microsoft.KeyVault'
Get-AzResourceProvider -ProviderNamespace 'Microsoft.PolicyInsights'
Get-AzResourceProvider -ProviderNamespace 'Microsoft.Authorization'

# Look for RegistrationState: "Registered"
```

### Register Resource Providers (if needed)
```powershell
# Requires Contributor or Owner role
# Usually already registered in most subscriptions

Register-AzResourceProvider -ProviderNamespace 'Microsoft.KeyVault'
Register-AzResourceProvider -ProviderNamespace 'Microsoft.PolicyInsights'
Register-AzResourceProvider -ProviderNamespace 'Microsoft.Authorization'

# Wait for registration to complete (can take 5-10 minutes)
Get-AzResourceProvider -ProviderNamespace 'Microsoft.KeyVault' -ListAvailable
```

**Note**: If providers are not registered and you don't have Contributor role, contact subscription owner.

---

## Network and Firewall Requirements

### Corporate Networks
If running from corporate network with proxy or firewall:

```powershell
# You may need to configure proxy settings
$env:HTTPS_PROXY = "http://proxy.company.com:8080"
$env:HTTP_PROXY = "http://proxy.company.com:8080"

# Or configure in PowerShell profile
Set-Content -Path $PROFILE -Value @"
`$env:HTTPS_PROXY = 'http://proxy.company.com:8080'
`$env:HTTP_PROXY = 'http://proxy.company.com:8080'
"@
```

### Required Endpoints
Ensure firewall allows access to:
- `login.microsoftonline.com` (authentication)
- `management.azure.com` (ARM API)
- `*.vault.azure.net` (Key Vault)
- `*.azconfig.io` (App Configuration - if used)

---

## Validating Prerequisites

### Automated Validation
```powershell
# Run the prerequisites check script
.\Test-DiscoveryPrerequisites.ps1

# With detailed output
.\Test-DiscoveryPrerequisites.ps1 -Detailed

# Auto-fix missing modules
.\Test-DiscoveryPrerequisites.ps1 -FixIssues
```

### Manual Validation Checklist

- [ ] PowerShell 7.0+ installed
- [ ] Az.Accounts module installed (version 2.0.0+)
- [ ] Az.Resources module installed (version 6.0.0+)
- [ ] Az.KeyVault module installed (version 4.0.0+)
- [ ] Connected to Azure (`Get-AzContext` shows valid context)
- [ ] Can list subscriptions (`Get-AzSubscription` returns results)
- [ ] Have Reader role on target subscriptions (at minimum)
- [ ] Required Resource Providers registered
- [ ] Network allows access to Azure endpoints

---

## Troubleshooting

### Error: "Connect-AzAccount: The term 'Connect-AzAccount' is not recognized"
**Cause**: Az.Accounts module not installed

**Solution**:
```powershell
Install-Module -Name Az.Accounts -Scope CurrentUser -Force
Import-Module Az.Accounts
```

### Error: "No subscriptions found"
**Cause**: Account has no access to any subscriptions

**Solution**:
- Verify you're logged in: `Get-AzContext`
- Request Reader access from subscription owner
- Ensure you're in the correct tenant: `Connect-AzAccount -TenantId '<tenant-id>'`

### Error: "Insufficient privileges to complete the operation" when viewing RBAC
**Cause**: Don't have User Access Administrator role

**Solution**:
- Expected for basic Reader role
- Skip `-IncludeRBAC` parameter
- Script will log warning but continue

### Error: "The client '...' with object id '...' does not have authorization"
**Cause**: Don't have Reader role on the subscription

**Solution**:
- Request Reader role from subscription owner
- Verify subscription ID is correct
- Ensure you're in the correct tenant

### Guest Account Issues
**Cause**: Guest accounts sometimes have additional restrictions

**Solution**:
- Ensure you're using the correct tenant ID when connecting
- Some AAD policies may block guest accounts - contact tenant admin
- Verify guest account has been granted explicit permission

---

## Summary: Required Modules and Permissions

### PowerShell Modules (Both Scenarios)
| Module | Minimum Version | Purpose |
|--------|----------------|---------|
| Az.Accounts | 2.0.0 | Authentication, context management |
| Az.Resources | 6.0.0 | Resource and policy management |
| Az.KeyVault | 4.0.0 | Key Vault inventory |
| Az.Monitor | 4.0.0 | (Optional) Diagnostic settings |

### RBAC Roles (Corporate AAD - Minimum)
| Role | Scope | Purpose | Required for Story |
|------|-------|---------|---------------------|
| Reader | Subscription | View resources, configurations | 1.1 (Discovery) |
| User Access Administrator | Subscription | View RBAC assignments | 1.1 (Optional for detailed RBAC) |
| Contributor | Subscription | Manage resources | 1.2 (Policy Deployment) |
| Resource Policy Contributor | Subscription | Create policy assignments | 1.2 (Policy Deployment) |

### RBAC Roles (MSDN Subscription)
| Role | Scope | Status |
|------|-------|--------|
| Owner | Subscription | ✅ You already have this |

---

## Next Steps

1. **Validate Prerequisites**:
   ```powershell
   .\Test-DiscoveryPrerequisites.ps1 -Detailed
   ```

2. **If Prerequisites Pass**:
   ```powershell
   # Run unified discovery tool
   .\Start-EnvironmentDiscovery.ps1
   ```

3. **If Prerequisites Fail**:
   - Review error messages
   - Install missing modules
   - Request required access
   - Re-run validation

4. **For Corporate AAD Users Needing Access**:
   - Use the sample email template above
   - Contact Cloud Brokers or subscription owners
   - Wait for access grant (can take 1-3 business days)
   - Re-run validation after access granted
