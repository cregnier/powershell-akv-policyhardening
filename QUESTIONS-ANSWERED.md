# Answers to Your Questions - Sprint 1 Story 1.1 Scripts

## Question 1: Do scripts handle MSDN subscription with guest MSA account (Owner)?

**Answer: YES** ✅

The scripts now fully support MSDN subscriptions with guest MSA accounts:

### What Was Added:
1. **[Test-DiscoveryPrerequisites.ps1](Test-DiscoveryPrerequisites.ps1)** - Auto-detects account type
   - Identifies guest accounts (`*#EXT#*` pattern in username)
   - Validates Owner role exists
   - Provides specific guidance for guest account issues

2. **Enhanced Error Handling** in all scripts:
   - Gracefully handles guest account API differences
   - Falls back to alternative methods when direct queries fail
   - Continues execution even if RBAC enumeration fails

3. **[PREREQUISITES-GUIDE.md](PREREQUISITES-GUIDE.md)** - Complete section on MSDN scenario
   - Connection instructions: `Connect-AzAccount -TenantId '<tenant-id>'`
   - Troubleshooting for guest-specific issues
   - Clarifies that Owner role = all permissions needed

### How Guest MSA Accounts Work:
```powershell
# Your account appears as:
yourname_outlook.com#EXT#@sometenant.onmicrosoft.com

# Scripts detect this and:
# 1. Skip RBAC checks that fail for guests (fallback to alternative methods)
# 2. Use context-based subscription enumeration instead of direct queries
# 3. Log warnings instead of errors for permission limitations
```

### What You Can Do with Owner on MSDN:
- ✅ Run ALL discovery scripts without limitations
- ✅ View all subscription details, Key Vaults, policies
- ✅ View RBAC assignments (inherited from Owner role)
- ✅ Deploy policies in Story 1.2

---

## Question 2: Do scripts handle corporate AAD with unknown permissions?

**Answer: YES** ✅

The scripts now handle corporate AAD with varying/unknown permissions:

### What Was Added:

1. **[Test-DiscoveryPrerequisites.ps1](Test-DiscoveryPrerequisites.ps1)** - Comprehensive permission checks
   - Tests subscription access
   - Validates RBAC roles (Reader, Contributor, Owner)
   - Checks Resource Provider registration
   - Provides remediation steps for missing permissions
   - Shows exactly what roles you have and what's needed

2. **[PREREQUISITES-GUIDE.md](PREREQUISITES-GUIDE.md)** - Complete permission documentation
   - Lists exact Azure PowerShell modules needed (with minimum versions)
   - Documents required RBAC roles by task
   - Includes sample access request email template
   - Troubleshooting for "access denied" errors

3. **Graceful Degradation** in all scripts:
   - Scripts attempt operations and log warnings if permissions insufficient
   - Continue with available data instead of failing completely
   - Clearly document what wasn't accessible and why

### Exact Modules Required:

| Module | Minimum Version | Purpose | Install Command |
|--------|----------------|---------|-----------------|
| Az.Accounts | 2.0.0 | Authentication | `Install-Module Az.Accounts -MinimumVersion 2.0.0 -Scope CurrentUser -Force` |
| Az.Resources | 6.0.0 | Policy/Resource mgmt | `Install-Module Az.Resources -MinimumVersion 6.0.0 -Scope CurrentUser -Force` |
| Az.KeyVault | 4.0.0 | Key Vault inventory | `Install-Module Az.KeyVault -MinimumVersion 4.0.0 -Scope CurrentUser -Force` |
| Az.Monitor | 4.0.0 | Diagnostic settings (optional) | `Install-Module Az.Monitor -MinimumVersion 4.0.0 -Scope CurrentUser -Force` |

### Exact RBAC Roles Needed:

#### For Discovery (Story 1.1):
**Minimum**: **Reader** role at subscription scope

```powershell
# Check if you have Reader role:
$subId = '<subscription-id>'
Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id -Scope "/subscriptions/$subId"

# If no roles shown, request:
# "Reader role on subscription /subscriptions/<sub-id>"
```

**What Reader Allows**:
- ✅ List subscriptions
- ✅ View subscription details and tags
- ✅ View all Key Vaults and configurations
- ✅ View policy assignments
- ✅ View resource counts
- ⚠️ Limited RBAC viewing (can't see who owns resources)

**Optional (Enhanced Discovery)**: **User Access Administrator** role
- Enables viewing owners/contributors on resources
- Not required for basic acceptance criteria

#### For Policy Deployment (Story 1.2 - Future):
**Required**: **Contributor** + **Resource Policy Contributor** roles
- OR just **Owner** role (includes both)

### Sample Access Request Email:
```
Subject: Access Request - Reader Role for Azure Policy Discovery

Hi [Cloud Brokers / Subscription Owner],

I need Reader access to the following Azure subscriptions for environment 
discovery as part of the Azure Key Vault policy deployment project (Sprint 1):

Subscriptions:
- [Subscription Name] ([Subscription ID])

Required Role: Reader (at subscription scope)
Duration: Temporary (2-4 weeks for discovery phase)

Purpose: Inventory Key Vaults and existing policy assignments to prepare 
for pilot deployment of 46 Azure Key Vault governance policies.

Please let me know if you need additional information.

Thanks,
[Your Name]
```

### Validation Process:
```powershell
# Step 1: Run prerequisites check
.\Test-DiscoveryPrerequisites.ps1 -Detailed

# Step 2: If fails, review output for exact missing permissions
# Step 3: Request access using email template
# Step 4: After access granted, re-run validation
.\Test-DiscoveryPrerequisites.ps1 -Detailed

# Step 5: When all checks pass, run discovery
.\Start-EnvironmentDiscovery.ps1
```

---

## Question 3: Using subscriptions-template.csv format?

**Answer: YES** ✅

The new **[Start-EnvironmentDiscovery.ps1](Start-EnvironmentDiscovery.ps1)** outputs to subscriptions-template.csv format!

### What Was Changed:

1. **Subscriptions-Template.csv Format** is now the default output:
   ```csv
   SubscriptionId,SubscriptionName,Environment,Notes
   <subscription-id>,Production-Sub-1,Production,Primary production subscription
   ```

2. **Dual Output Approach**:
   - `subscriptions-template.csv` - Simple format compatible with existing template
   - `SubscriptionInventory.csv` - Full details (tags, state, policies, RBAC if available)

3. **Environment Auto-Detection**:
   Scripts attempt to populate the "Environment" column by:
   - Reading `Environment` tag from subscription
   - Inferring from subscription name (e.g., "prod", "dev", "test")
   - Leaving blank if unknown (you fill in manually)

### How It Works:

```powershell
# Run unified discovery
.\Start-EnvironmentDiscovery.ps1

# Select option 1 (Subscription Inventory) or 4 (Full Discovery)

# Output includes BOTH:
# 1. subscriptions-template.csv (simple format)
SubscriptionId,SubscriptionName,Environment,Notes
ab1336c7-...,MSDN-Subscription,Development,Personal dev subscription

# 2. SubscriptionInventory.csv (detailed format)
SubscriptionId,SubscriptionName,TenantId,State,Environment,SubscriptionPolicies,Tags,Notes
ab1336c7-...,MSDN-Subscription,<tenant>,Enabled,Development,<quota>,Environment=Dev,Personal dev
```

### Using Existing subscriptions-template.csv as Filter:

If you already have `subscriptions-template.csv` with specific subscriptions, use it as a filter:

```powershell
# Option 1: Command-line parameter
.\Start-EnvironmentDiscovery.ps1 -UseExistingTemplate

# Option 2: Menu option
.\Start-EnvironmentDiscovery.ps1
# Select option 6 to toggle template filter
# Then run inventory (it will only scan subscriptions in template)
```

**How Filter Works**:
1. Script reads `subscriptions-template.csv`
2. Extracts SubscriptionId column
3. Only inventories those specific subscriptions
4. Ignores placeholder IDs (e.g., `12345678-1234-...`)
5. Updates template with discovered information

---

## Question 4: Can the 3 scripts be merged into one with a menu?

**Answer: YES** ✅

**[Start-EnvironmentDiscovery.ps1](Start-EnvironmentDiscovery.ps1)** is the unified menu-driven script!

### Menu System Features:

```
====================================================================
 MAIN MENU
====================================================================

 Prerequisites & Validation
   0. Run Prerequisites Check

 Individual Inventories
   1. Subscription Inventory (with subscriptions-template.csv output)
   2. Key Vault Inventory
   3. Policy Assignment Inventory

 Combined Operations
   4. Run ALL Inventories (Full Discovery)
   5. Run ALL Inventories (Quick Discovery - Basic Mode)

 Advanced Options
   6. Filter by Subscriptions Template (use existing subscriptions-template.csv)
   7. Toggle Detailed Mode (Currently: False)

 Utilities
   8. View Current Configuration
   9. Change Output Directory

   Q. Quit
====================================================================
```

### How It Works:

1. **Interactive Menu** (like AzPolicyImplScript.ps1):
   ```powershell
   .\Start-EnvironmentDiscovery.ps1
   # Shows banner with current Azure context
   # Displays menu
   # Accepts input (0-9, Q)
   # Executes selected task
   # Returns to menu
   ```

2. **Auto-Run Mode** (no menu):
   ```powershell
   .\Start-EnvironmentDiscovery.ps1 -AutoRun
   # Runs full discovery immediately
   # No prompts, no menu
   # Perfect for automation/scripts
   ```

3. **Individual Scripts Still Available**:
   - Original 3 scripts (`Get-AzureSubscriptionInventory.ps1`, etc.) still exist
   - Can be called standalone if needed
   - Unified script calls them internally

### Architecture:

```
Start-EnvironmentDiscovery.ps1 (Unified Menu Script)
├── Calls: Test-DiscoveryPrerequisites.ps1 (Menu option 0)
├── Calls: Invoke-SubscriptionInventory (Menu option 1)
│   └── Runs inline subscription inventory code
│   └── Outputs: subscriptions-template.csv + SubscriptionInventory.csv
├── Calls: Get-KeyVaultInventory.ps1 (Menu option 2)
│   └── Outputs: KeyVaultInventory.csv
├── Calls: Get-PolicyAssignmentInventory.ps1 (Menu option 3)
│   └── Outputs: PolicyAssignmentInventory.csv
└── Calls: All 3 combined (Menu options 4/5)
    └── Outputs: All CSVs + DiscoveryReport.txt
```

### Benefits of Unified Script:

✅ **Single entry point** - easier for corporate users
✅ **Prerequisites check integrated** - validates before running
✅ **No need to remember 3 different scripts**
✅ **Consistent output directory** - all files in one place
✅ **Interactive configuration** - toggle options without re-running
✅ **Shows Azure context** - confirms you're connected to right tenant
✅ **Auto-detects account type** - shows if guest or corporate AAD
✅ **Template-compatible output** - works with subscriptions-template.csv

---

## Summary: All 4 Questions Answered

| Question | Answer | Key Files |
|----------|--------|-----------|
| **1. MSDN guest MSA support?** | ✅ YES | `Test-DiscoveryPrerequisites.ps1`, `PREREQUISITES-GUIDE.md` |
| **2. Corporate AAD unknown perms?** | ✅ YES | `Test-DiscoveryPrerequisites.ps1`, `PREREQUISITES-GUIDE.md` |
| **3. Using subscriptions-template.csv?** | ✅ YES | `Start-EnvironmentDiscovery.ps1` (auto-outputs to template format) |
| **4. Merge scripts with menu?** | ✅ YES | `Start-EnvironmentDiscovery.ps1` (unified interactive menu) |

---

## Recommended Workflow

### For MSDN Guest MSA Users:
```powershell
# 1. Connect (specify tenant if multiple)
Connect-AzAccount -TenantId '<your-tenant-id>'

# 2. Validate (should all pass with Owner role)
.\Test-DiscoveryPrerequisites.ps1 -Detailed

# 3. Run unified discovery
.\Start-EnvironmentDiscovery.ps1

# 4. Select option 4 (Full Discovery)

# 5. Review outputs
cd .\Discovery-<timestamp>
explorer .
```

### For Corporate AAD Users:
```powershell
# 1. Connect to corporate tenant
Connect-AzAccount -TenantId '<intel-tenant-id>'

# 2. Validate prerequisites
.\Test-DiscoveryPrerequisites.ps1 -Detailed

# 3a. If prerequisites PASS:
.\Start-EnvironmentDiscovery.ps1
# Select option 4 or 5

# 3b. If prerequisites FAIL (no access):
# - Review output for missing permissions
# - Use email template in PREREQUISITES-GUIDE.md
# - Request Reader role from subscription owner
# - Wait for access grant
# - Re-run validation: .\Test-DiscoveryPrerequisites.ps1 -Detailed
# - When pass, proceed with .\Start-EnvironmentDiscovery.ps1

# 4. Review outputs
cd .\Discovery-<timestamp>
notepad DiscoveryReport.txt
# Open subscriptions-template.csv in Excel
```

---

## Files Created/Updated

### New Files:
1. ✅ **Test-DiscoveryPrerequisites.ps1** - Prerequisites validation
2. ✅ **Start-EnvironmentDiscovery.ps1** - Unified menu-driven discovery
3. ✅ **PREREQUISITES-GUIDE.md** - Complete permissions documentation
4. ✅ **QUESTIONS-ANSWERED.md** - This file

### Updated Files:
5. ✅ **SPRINT1-STORY1.1-README.md** - Updated with new scripts and workflows

### Existing Files (Unchanged but Still Available):
6. ✅ **Get-AzureSubscriptionInventory.ps1** - Original subscription script
7. ✅ **Get-KeyVaultInventory.ps1** - Original Key Vault script
8. ✅ **Get-PolicyAssignmentInventory.ps1** - Original policy script
9. ✅ **Invoke-EnvironmentDiscovery.ps1** - Original orchestration script
10. ✅ **Stakeholder-Contact-Template.csv** - Stakeholder tracking
11. ✅ **Gap-Analysis-Template.csv** - Gap tracking
12. ✅ **Risk-Register-Template.csv** - Risk tracking

---

## Next Steps

1. **Review Prerequisites Guide**: [PREREQUISITES-GUIDE.md](PREREQUISITES-GUIDE.md)
2. **Validate Prerequisites**: `.\Test-DiscoveryPrerequisites.ps1 -Detailed`
3. **Run Unified Discovery**: `.\Start-EnvironmentDiscovery.ps1`
4. **Review Outputs**: Check `subscriptions-template.csv` and other CSVs
5. **Fill Templates**: Complete stakeholder contacts, gap analysis, risks
6. **Proceed to Story 1.2**: Pilot Environment Setup
