# Sprint 1, Story 1.1 - Environment Discovery Scripts

## Overview

This package contains PowerShell 7 scripts to complete the acceptance criteria for **Sprint 1, Story 1.1: Environment Discovery & Baseline Assessment**.

**Acceptance Criteria**: Complete inventory of all Azure subscriptions and Key Vault resources delivered in documented format (Excel/CSV with subscription IDs, resource counts, owners, environments).

## Scripts Included

### **NEW: Unified Menu-Driven Script (Recommended)**

**[Start-EnvironmentDiscovery.ps1](Start-EnvironmentDiscovery.ps1)** - Interactive menu combining all three inventories

**Features**:
- Interactive menu system (similar to AzPolicyImplScript.ps1)
- Automatically outputs to **subscriptions-template.csv** compatible format
- Prerequisites validation
- Individual or combined inventories
- Quick mode (basic) or detailed mode
- Filter by existing subscriptions-template.csv
- Support for both MSDN guest and corporate AAD scenarios

**Usage**:
```powershell
# Launch interactive menu (recommended)
.\Start-EnvironmentDiscovery.ps1

# Auto-run full discovery without menu
.\Start-EnvironmentDiscovery.ps1 -AutoRun

# Use existing subscriptions-template.csv to filter subscriptions
.\Start-EnvironmentDiscovery.ps1 -UseExistingTemplate
```

**Menu Options**:
- `0` - Run Prerequisites Check
- `1` - Subscription Inventory (outputs to subscriptions-template.csv format)
- `2` - Key Vault Inventory  
- `3` - Policy Assignment Inventory
- `4` - Run ALL Inventories (Full Discovery - Detailed)
- `5` - Run ALL Inventories (Quick Discovery - Basic)
- `6` - Toggle Filter by Subscriptions Template
- `7` - Toggle Detailed Mode
- `8` - View Current Configuration
- `9` - Change Output Directory
- `Q` - Quit

---

### **NEW: Prerequisites Validation Script**

**[Test-DiscoveryPrerequisites.ps1](Test-DiscoveryPrerequisites.ps1)** - Validates all prerequisites

**Features**:
- Checks PowerShell version (7.0+)
- Validates all required Azure modules
- Tests Azure connectivity
- Verifies subscription access
- Checks RBAC permissions
- Tests Resource Provider registration
- Auto-detects account type (Guest MSA vs Corporate AAD)
- Auto-fix option to install missing modules

**Usage**:
```powershell
# Basic check
.\Test-DiscoveryPrerequisites.ps1

# Detailed check with remediation steps
.\Test-DiscoveryPrerequisites.ps1 -Detailed

# Auto-install missing modules
.\Test-DiscoveryPrerequisites.ps1 -FixIssues
```

---

### Individual Inventory Scripts (Can Still Be Used Standalone)

### 1. **Get-AzureSubscriptionInventory.ps1**
Enumerates all Azure subscriptions in your tenant with detailed metadata.

**Outputs**:
- Subscription name, ID, tenant ID, state
- Subscription policies (quota ID)
- Tags
- Optional: Owners and Contributors (RBAC)
- Optional: Resource counts

**Usage**:
```powershell
# Basic usage
.\Get-AzureSubscriptionInventory.ps1

# With detailed RBAC and resource counts
.\Get-AzureSubscriptionInventory.ps1 -IncludeRBAC -IncludeResourceCounts

# Custom output location
.\Get-AzureSubscriptionInventory.ps1 -OutputPath "C:\Reports\Subscriptions.csv"
```

### 2. **Get-KeyVaultInventory.ps1**
Inventories all Azure Key Vaults across subscriptions with configuration details.

**Outputs**:
- Key Vault name, location, resource group, subscription
- SKU, tenant ID, resource ID, vault URI
- Security settings: Soft delete, purge protection, RBAC, public network access
- Private endpoint connections count
- Tags
- Optional: Network rules summary
- Optional: Access policy counts
- Diagnostic settings status

**Usage**:
```powershell
# Basic usage - scan all subscriptions
.\Get-KeyVaultInventory.ps1

# With detailed network and access policy info
.\Get-KeyVaultInventory.ps1 -IncludeNetworkRules -IncludeAccessPolicies

# Scan specific subscriptions only
.\Get-KeyVaultInventory.ps1 -SubscriptionIds @('sub-id-1', 'sub-id-2')

# Custom output location
.\Get-KeyVaultInventory.ps1 -OutputPath "C:\Reports\KeyVaults.csv"
```

**Compliance Metrics Calculated**:
- Soft delete enabled %
- Purge protection enabled %
- RBAC authorization enabled %
- Public network access disabled %
- Private endpoints configured %

### 3. **Get-PolicyAssignmentInventory.ps1**
Discovers existing Azure Policy assignments to identify potential conflicts.

**Outputs**:
- Assignment name, display name, description
- Subscription, scope, scope type (Subscription/ResourceGroup/ManagementGroup)
- Policy definition ID and name
- Policy type, mode, category
- Enforcement mode (Default/DoNotEnforce)
- Identity (for DINE/Modify policies)
- NotScopes, parameters, metadata
- Resource ID

**Usage**:
```powershell
# Basic usage - all policy assignments
.\Get-PolicyAssignmentInventory.ps1

# Filter to Key Vault-related policies only
.\Get-PolicyAssignmentInventory.ps1 -FilterByKeyVault

# Include detailed parameter values
.\Get-PolicyAssignmentInventory.ps1 -IncludeParameters

# Scan specific subscriptions
.\Get-PolicyAssignmentInventory.ps1 -SubscriptionIds @('sub-id-1')

# Custom output location
.\Get-PolicyAssignmentInventory.ps1 -OutputPath "C:\Reports\Policies.csv"
```

**Key Features**:
- Automatically detects existing Key Vault policies
- Warns about potential conflicts
- Categorizes by scope type and enforcement mode
- Groups by policy category

### 4. **Invoke-EnvironmentDiscovery.ps1** (MAIN ORCHESTRATION SCRIPT)
Runs all three inventory scripts and generates a consolidated report.

**Outputs**:
- SubscriptionInventory.csv
- KeyVaultInventory.csv
- PolicyAssignmentInventory.csv
- DiscoveryReport.txt (consolidated summary)

**Usage**:
```powershell
# Run full discovery with default settings
.\Invoke-EnvironmentDiscovery.ps1

# Run with detailed information (RBAC, network rules, parameters)
# WARNING: Takes significantly longer
.\Invoke-EnvironmentDiscovery.ps1 -DetailedInventory

# Custom output directory
.\Invoke-EnvironmentDiscovery.ps1 -OutputDirectory "C:\Reports\Sprint1-Discovery"

# Scan specific subscriptions only
.\Invoke-EnvironmentDiscovery.ps1 -SubscriptionIds @('sub-id-1', 'sub-id-2')

# Skip certain inventories (if already completed)
.\Invoke-EnvironmentDiscovery.ps1 -SkipSubscriptionInventory
.\Invoke-EnvironmentDiscovery.ps1 -SkipKeyVaultInventory
.\Invoke-EnvironmentDiscovery.ps1 -SkipPolicyInventory
```

**Report Includes**:
- Executive summary with key statistics
- Subscription count and state breakdown
- Key Vault compliance snapshot
- Existing policy assignment summary
- Warnings about Key Vault policy conflicts
- Next steps and action items

## Templates Included

### 5. **Stakeholder-Contact-Template.csv**
Track stakeholder contacts across teams:
- Cloud Brokers
- Cyber Defense
- Subscription Owners
- Change Management
- Documentation Team
- Leadership

**Fields**: Team, Contact Name, Role, Email, Phone, Availability, Authority Level, Notes

### 6. **Gap-Analysis-Template.csv**
Document what you HAVE vs what you NEED. **Pre-populated with 28 requirements** across categories:
- Technical Prerequisites
- Process Requirements
- Documentation
- Data Availability
- Stakeholder Engagement
- Testing

**Fields**: Category, Requirement, Status (HAVE/NEED), Current State, Gap Description, Impact, Mitigation Plan, Owner, Target Date, Notes

### 7. **Risk-Register-Template.csv**
Document what you HAVE vs what you NEED across categories:
- Technical Prerequisites
- Process Requirements
- Documentation
- Data Availability
- Stakeholder Engagement
- Testing

**Fields**: Category, Requirement, Status (HAVE/NEED), Current State, Gap Description, Impact, Mitigation Plan, Owner, Target Date, Notes

### 3. **Risk-Register-Template.csv**
Track and mitigate risks throughout the project.

**Includes 20 Pre-Populated Risks**:
- R001: Stakeholder approval process unclear
- R003: Existing Key Vault policies conflict
- R004: Managed identity lacks permissions
- R007: Azure Policy evaluation delays
- R010: Cyber Defense team blocks deployment
- ... and 15 more

**Fields**: Risk ID, Description, Category, Impact, Likelihood, Risk Score, Mitigation Strategy, Owner, Status, Target Resolution Date, Notes

## Prerequisites

### ⚠️ IMPORTANT: Read Prerequisites Guide First

**Two deployment scenarios are supported:**
1. **MSDN Subscription** with guest MSA account (Owner role)
2. **Corporate AAD Environment** (Intel Azure) with AAD user (Reader+ role)

📖 **[Complete Prerequisites Guide](PREREQUISITES-GUIDE.md)** - Detailed requirements, permissions, and troubleshooting for both scenarios

### Quick Prerequisites Check
```powershell
# Automated validation (recommended)
.\Test-DiscoveryPrerequisites.ps1 -Detailed

# Auto-install missing modules
.\Test-DiscoveryPrerequisites.ps1 -FixIssues
```

### PowerShell Modules Required
```powershell
# Install required modules
Install-Module -Name Az.Accounts -MinimumVersion 2.0.0 -Scope CurrentUser -Force
Install-Module -Name Az.Resources -MinimumVersion 6.0.0 -Scope CurrentUser -Force
Install-Module -Name Az.KeyVault -MinimumVersion 4.0.0 -Scope CurrentUser -Force

# Optional: For diagnostic settings check in Key Vault inventory
Install-Module -Name Az.Monitor -MinimumVersion 4.0.0 -Scope CurrentUser -Force
```

### Azure Permissions Required

**Scenario 1 - MSDN Subscription (Guest MSA)**:
- ✅ Owner role (you already have this on your MSDN subscription)
- ✅ No additional permissions needed

**Scenario 2 - Corporate AAD (Intel Azure)**:
- **Minimum for Discovery**: Reader role at subscription scope
- **Optional for RBAC details**: User Access Administrator role
- **For Policy Deployment (Story 1.2)**: Contributor + Resource Policy Contributor roles

### Connect to Azure
```powershell
# Scenario 1 - MSDN with guest MSA account
Connect-AzAccount
# Or specify tenant: Connect-AzAccount -TenantId 'your-tenant-id'

# Scenario 2 - Corporate AAD
Connect-AzAccount -TenantId '<intel-tenant-id>'

# Verify connection
Get-AzContext
```

## Quick Start - Complete Story 1.1

### Option 1: Unified Menu-Driven Script (Recommended - Especially for Corporate)
```powershell
# 1. Validate prerequisites
.\Test-DiscoveryPrerequisites.ps1 -Detailed

# 2. If prerequisites pass, launch unified discovery tool
.\Start-EnvironmentDiscovery.ps1

# 3. Select option 4 (Full Discovery) or 5 (Quick Discovery) from menu

# 4. Review the output
cd .\Discovery-<timestamp>
notepad DiscoveryReport.txt

# 5. Open subscriptions-template.csv in Excel (compatible format!)
explorer .
```

**Outputs**:
- `subscriptions-template.csv` - Compatible with existing template format (SubscriptionId, SubscriptionName, Environment, Notes)
- `SubscriptionInventory.csv` - Full subscription details
- `KeyVaultInventory.csv` - Key Vault configurations
- `PolicyAssignmentInventory.csv` - Policy assignments
- `DiscoveryReport.txt` - Executive summary

### Option 2: Automated Full Discovery (No Menu)
```powershell
# 1. Connect to Azure
Connect-AzAccount

# 2. Run auto-discovery
.\Start-EnvironmentDiscovery.ps1 -AutoRun

# 3. Review output
cd .\Discovery-<timestamp>
explorer .
```

### Option 3: Run Everything at Once with Orchestration Script
```powershell
# 1. Connect to Azure
Connect-AzAccount

# 2. Run full discovery
.\Invoke-EnvironmentDiscovery.ps1

# 3. Review the output
cd .\Discovery-<timestamp>
notepad DiscoveryReport.txt

# 4. Open CSV files in Excel for detailed analysis
explorer .
```

### Option 2: Run Scripts Individually
```powershell
# 1. Connect to Azure
Connect-AzAccount

# 2. Run subscription inventory
.\Get-AzureSubscriptionInventory.ps1 -IncludeRBAC

# 3. Run Key Vault inventory
.\Get-KeyVaultInventory.ps1 -IncludeNetworkRules -IncludeAccessPolicies

# 4. Run policy assignment inventory
.\Get-PolicyAssignmentInventory.ps1 -FilterByKeyVault

# 5. Review CSV files
explorer .
```

## Expected Execution Times

| Script | Basic Mode | Detailed Mode | Notes |
|--------|-----------|---------------|-------|
| Subscription Inventory | 1-5 min | 5-15 min | Depends on subscription count |
| Key Vault Inventory | 2-10 min | 10-30 min | Depends on Key Vault count |
| Policy Inventory | 1-5 min | 5-15 min | Depends on policy count |
| **Full Discovery** | **5-20 min** | **20-60 min** | Total for all inventories |

**Factors Affecting Time**:
- Number of subscriptions
- Number of Key Vaults
- Number of policy assignments
- Azure API response times
- Network latency
- Detailed mode options enabled

## Output Files Structure

```
Discovery-yyyyMMdd-HHmmss/
├── SubscriptionInventory.csv          # Subscription details
├── KeyVaultInventory.csv              # Key Vault configurations
├── PolicyAssignmentInventory.csv      # Policy assignments
└── DiscoveryReport.txt                # Executive summary
```

## Common Scenarios

### Scenario 1: First-Time Discovery Across Entire Tenant
```powershell
# Run full discovery with detailed information
.\Invoke-EnvironmentDiscovery.ps1 -DetailedInventory

# Expected: 20-60 minutes depending on tenant size
```

### Scenario 2: Quick Discovery for Pilot Selection
```powershell
# Run basic discovery (faster)
.\Invoke-EnvironmentDiscovery.ps1

# Expected: 5-20 minutes
```

### Scenario 3: Focus on Specific Subscriptions
```powershell
# Get subscription IDs first
$pilotSubs = @(
    'ab1336c7-687d-4107-b0f6-9649a0458adb',
    'another-sub-id-here'
)

# Run discovery on pilot subscriptions only
.\Invoke-EnvironmentDiscovery.ps1 -SubscriptionIds $pilotSubs

# Expected: 2-10 minutes
```

### Scenario 4: Check for Key Vault Policy Conflicts Only
```powershell
# Run only policy inventory, filtered to Key Vault
.\Get-PolicyAssignmentInventory.ps1 -FilterByKeyVault

# Review output for conflicts
Import-Csv .\PolicyAssignmentInventory-*.csv | Format-Table DisplayName, ScopeType, EnforcementMode
```

### Scenario 5: Re-run Discovery After Initial Pass
```powershell
# Skip subscription inventory (already have it)
# Re-scan Key Vaults and policies for updates
.\Invoke-EnvironmentDiscovery.ps1 -SkipSubscriptionInventory
```

## Troubleshooting

### Error: "Not connected to Azure"
```powershell
# Solution: Connect to Azure first
Connect-AzAccount
```

### Error: "Az.KeyVault module not found"
```powershell
# Solution: Install required modules
Install-Module -Name Az.KeyVault -Scope CurrentUser -Force
```

### Error: "Access denied" or "Insufficient permissions"
```powershell
# Solution: Verify you have Reader role on subscriptions
Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id

# Contact subscription owner to grant Reader role
```

### Warning: "Unable to retrieve RBAC assignments"
```powershell
# This is expected if you don't have User Access Administrator role
# Script will continue, but RBAC data will show "Error retrieving owners"
# You can safely ignore this if you don't need owner information
```

### Slow Execution
```powershell
# If discovery is taking too long:
# 1. Run without detailed options first
.\Invoke-EnvironmentDiscovery.ps1

# 2. Or scan specific subscriptions only
.\Invoke-EnvironmentDiscovery.ps1 -SubscriptionIds @('sub-id')

# 3. Or skip sections you already have
.\Invoke-EnvironmentDiscovery.ps1 -SkipSubscriptionInventory
```

## Next Steps After Discovery

1. **Review DiscoveryReport.txt**
   - Understand scope: Total subscriptions, Key Vaults, policies
   - Identify compliance gaps
   - Note any Key Vault policy conflicts

2. **Analyze CSV Files in Excel**
   - SubscriptionInventory.csv: Identify pilot subscription candidates
   - KeyVaultInventory.csv: Find non-compliant Key Vaults
   - PolicyAssignmentInventory.csv: Review existing governance

3. **Fill Out Templates**
   - Stakeholder-Contact-Template.csv: Identify contacts
   - Gap-Analysis-Template.csv: Document what you're missing
   - Risk-Register-Template.csv: Update risk status and owners

4. **Select Pilot Subscriptions**
   - Choose 2-3 diverse subscriptions (Dev, Test, Production-like)
   - Verify you have access (Contributor + Policy Contributor roles)
   - Confirm with subscription owners

5. **Engage Stakeholders**
   - Schedule meetings with Cloud Brokers, Cyber Defense
   - Present discovery findings
   - Gather requirements and concerns

6. **Proceed to Sprint 1, Story 1.2**
   - Pilot Environment Setup & Initial Deployment
   - Deploy 46 Key Vault policies to pilot subscriptions

## Support and Feedback

For issues or questions about these scripts:
1. Review troubleshooting section above
2. Check script comments and help documentation: `Get-Help .\scriptname.ps1 -Full`
3. Review error messages in console output
4. Check [Sprint-Requirements-Gap-Analysis.md](Sprint-Requirements-Gap-Analysis.md) for known limitations

## Version History

- **v1.0** (January 29, 2026): Initial release
  - Subscription inventory script
  - Key Vault inventory script
  - Policy assignment inventory script
  - Orchestration script with consolidated reporting
  - CSV templates for stakeholder tracking, gap analysis, and risk management
