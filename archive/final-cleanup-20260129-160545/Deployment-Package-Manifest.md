# Deployment Package Manifest

## Overview

This document identifies all files necessary to deploy Azure Key Vault policy governance in a **new/clean environment** (different subscription, different tenant, fresh start).

**Target Use Case**: Deploy this solution in a new Azure subscription for testing or production use.

**Last Updated**: January 14, 2026

---

## Minimal Required Files

### Category 1: Core Scripts (REQUIRED)

These 2 scripts are essential for deployment:

1. **AzPolicyImplScript.ps1** (176 KB)
   - Main policy deployment and management script
   - All 46 Azure Key Vault policies
   - Compliance checking, exemption management, rollback
   - **REQUIRED**: Core script

2. **Setup-AzureKeyVaultPolicyEnvironment.ps1** (40 KB)
   - Creates Azure infrastructure (managed identity, VNet, Log Analytics)
   - Sets up test Key Vaults (dev/test only)
   - Configures Azure Monitor (optional)
   - **REQUIRED**: For infrastructure setup

### Category 2: Configuration Files (REQUIRED)

These 3 files define policy parameters and definitions:

3. **DefinitionListExport.csv** (92 KB)
   - List of all 46 Azure Key Vault policies
   - Policy names, IDs, categories, effects
   - **REQUIRED**: Policy inventory source

4. **PolicyParameters-DevTest.json** (2.4 KB)
   - Dev/Test environment parameters (relaxed)
   - All Audit mode, longer validity periods
   - **REQUIRED**: For dev/test deployments

5. **PolicyParameters-Production.json** (3.1 KB)
   - Production environment parameters (strict)
   - Deny mode for critical policies, shorter validity periods
   - **REQUIRED**: For production deployments

### Category 3: Helper Scripts (RECOMMENDED)

These scripts simplify deployment and testing:

6. **Environment-SafeDeployment.ps1** (10 KB)
   - Safe deployment helper with phase-based workflow
   - Prevents accidental production enforcement
   - **RECOMMENDED**: Safeguards for production

### Category 4: Documentation (ESSENTIAL)

Critical documentation for successful deployment:

7. **README.md** (7.4 KB)
   - Quick start guide
   - Core script usage
   - **ESSENTIAL**: Main entry point

8. **QUICKSTART.md** (5.2 KB) OR merge into README
   - Step-by-step deployment instructions
   - **ESSENTIAL**: First-time deployment

9. **Environment-Configuration-Guide.md** (22 KB)
   - Dev/Test vs Production configuration
   - Migration workflow
   - **ESSENTIAL**: Environment management

10. **RBAC-Configuration-Guide.md** (15 KB)
    - Required RBAC permissions
    - Automation examples
    - **ESSENTIAL**: Permission setup

11. **Pre-Deployment-Audit-Checklist.md** (24 KB)
    - Pre-deployment validation steps
    - Audit procedures
    - **RECOMMENDED**: Quality assurance

---

## Complete Deployment Package

### MINIMAL Package (15 files, ~400 KB)

**For basic policy deployment in new environment**:

```
deployment-package/
├── scripts/
│   ├── AzPolicyImplScript.ps1                    [REQUIRED - Core]
│   ├── Setup-AzureKeyVaultPolicyEnvironment.ps1  [REQUIRED - Setup]
│   └── Environment-SafeDeployment.ps1            [RECOMMENDED - Safety]
├── config/
│   ├── DefinitionListExport.csv                 [REQUIRED - Policy list]
│   ├── PolicyParameters-DevTest.json            [REQUIRED - Dev config]
│   └── PolicyParameters-Production.json         [REQUIRED - Prod config]
└── docs/
    ├── README.md                                 [ESSENTIAL - Start here]
    ├── QUICKSTART.md                            [ESSENTIAL - How-to]
    ├── Environment-Configuration-Guide.md       [ESSENTIAL - Environments]
    ├── RBAC-Configuration-Guide.md              [ESSENTIAL - Permissions]
    ├── Pre-Deployment-Audit-Checklist.md       [RECOMMENDED - QA]
    ├── EXEMPTION_PROCESS.md                     [RECOMMENDED - Exemptions]
    ├── KeyVault-Policy-Enforcement-FAQ.md       [RECOMMENDED - FAQ]
    ├── KEYVAULT_POLICY_REFERENCE.md            [REFERENCE - Policies]
    └── Policy-Validation-Matrix.md              [REFERENCE - Validation]
```

**Total Size**: ~400 KB  
**Files**: 15  
**Ready to Deploy**: Yes

---

### RECOMMENDED Package (20 files, ~550 KB)

**For complete deployment with all helpers and documentation**:

Add these to the MINIMAL package:

```
deployment-package/
├── scripts/
│   ├── [... minimal scripts ...]
│   ├── DeployAll46PoliciesDenyMode.ps1          [HELPER - Deny deployment]
│   ├── CheckPolicyCompliance.ps1                [HELPER - Compliance]
│   └── GenerateMonthlyReport.ps1                [HELPER - Reporting]
└── docs/
    ├── [... minimal docs ...]
    ├── Production-Deployment-Safeguards.md      [GUIDE - Safety]
    ├── ProductionRolloutPlan.md                 [GUIDE - Rollout]
    └── Email-Alert-Configuration-Analysis.md    [GUIDE - Monitoring]
```

**Total Size**: ~550 KB  
**Files**: 20  
**Ready to Deploy**: Yes with full support

---

## Files NOT Needed for New Deployment

### Historical/Testing Artifacts (EXCLUDE)

**Test Results** (130+ files):
- All `*TestResults*.json` files
- All `All46Policies*.json` files  
- All `DenyBlockingTestResults*.json` files
- All `ComplianceReport-*.html` files
- All `KeyVaultPolicyImplementationReport-*.json` files

**Reason**: Historical test data from development environment

---

**Analysis Documents** (10+ files):
- `Documentation-Consolidation-Analysis.md`
- `Script-Consolidation-Analysis.md`
- `Email-Alert-Configuration-Analysis.md`
- `Production-Deployment-Safeguards.md` (unless doing production deployment)
- `Phase*Completion*.md` files
- `SOFT_DELETE_POLICY_INVESTIGATION.md`

**Reason**: Project documentation, not deployment documentation

---

**Legacy/Deprecated Scripts** (5+ files):
- `QuickTest.ps1` (deprecated)
- `TestParameterBinding.ps1` (deprecated)
- `FixMissing9Policies.ps1` (one-time fix)
- `AnalyzePolicyEffects.ps1` (analysis only)
- `RunPolicyTest.ps1` (wrapper, use main script)
- `RunFullTest.ps1` (wrapper, use main script)

**Reason**: Development artifacts or superseded by main script

---

**Configuration Specific to Dev Subscription** (3 files):
- `PolicyImplementationConfig.json` (subscription-specific)
- `ComplianceDashboard-PowerBI-Config-*.json` (environment-specific)
- `PolicyNameMapping.json` (auto-generated during deployment)

**Reason**: Will be recreated for new environment

---

### Backup Folders (EXCLUDE ENTIRE FOLDERS)

- `.history/` - File history
- `backups/` - Historical backups
- Any timestamped backup folders

**Reason**: Development history, not needed for deployment

---

## Deployment Steps for New Environment

### Step 1: Prepare Package (5 minutes)

```powershell
# Create deployment folder
New-Item -Path "C:\AzureKVPolicy-Deployment" -ItemType Directory

# Copy MINIMAL or RECOMMENDED package files (listed above)
# Exclude all test results, backups, analysis docs
```

---

### Step 2: Prerequisites Check (10 minutes)

**Azure Subscription**:
- ✅ Azure subscription (any tier)
- ✅ Subscription Owner or Policy Contributor + Contributor roles
- ✅ No existing conflicting Key Vault policies

**PowerShell Environment**:
```powershell
# Install required modules
Install-Module Az.Accounts, Az.Resources, Az.PolicyInsights, Az.Monitor, Az.KeyVault -Scope CurrentUser

# Connect to Azure
Connect-AzAccount
Set-AzContext -Subscription "<your-subscription-id>"
```

**Configuration**:
- ✅ Email address for monitoring (optional)
- ✅ Decide on environment: DevTest or Production
- ✅ Choose deployment scope: ResourceGroup or Subscription

---

### Step 3: Infrastructure Setup (15-20 minutes)

```powershell
# Navigate to deployment folder
cd C:\AzureKVPolicy-Deployment

# Dev/Test setup (creates test vaults)
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -ActionGroupEmail "your-email@company.com"

# Production setup (infrastructure only)
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -Environment Production -SkipMonitoring
```

**Creates**:
- Managed identity for policy assignments
- Resource groups (infra + test)
- VNet and subnet (for private endpoint policies)
- Private DNS zone
- Log Analytics workspace
- Event Hub (for diagnostic policies)
- Test Key Vaults (dev/test only)

---

### Step 4: Deploy Policies (10-15 minutes)

**Option A: Safe Deployment Helper (RECOMMENDED)**

```powershell
# Phase 1: Test in dev/test
.\Environment-SafeDeployment.ps1 -Environment DevTest -Phase Test -Scope ResourceGroup

# Phase 2: Production Audit (wait 24-48 hours, review compliance)
.\Environment-SafeDeployment.ps1 -Environment Production -Phase Audit -Scope Subscription

# Phase 3: Production Enforcement (after validation)
.\Environment-SafeDeployment.ps1 -Environment Production -Phase Enforce -Scope Subscription
```

**Option B: Direct Deployment**

```powershell
# Dev/Test Audit mode
.\AzPolicyImplScript.ps1 `
    -PolicyMode Audit `
    -ScopeType Subscription `
    -ParameterOverridesPath "./PolicyParameters-DevTest.json"

# Production Audit mode (REQUIRED FIRST)
.\AzPolicyImplScript.ps1 `
    -PolicyMode Audit `
    -ScopeType Subscription `
    -ParameterOverridesPath "./PolicyParameters-Production.json"

# Production Deny mode (after 24-48 hour validation)
.\AzPolicyImplScript.ps1 `
    -PolicyMode Deny `
    -ScopeType Subscription `
    -ParameterOverridesPath "./PolicyParameters-Production.json"
# Type 'PROCEED' when prompted
```

---

### Step 5: Validate Deployment (10 minutes)

```powershell
# Check compliance
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan

# Review HTML report
$report = Get-ChildItem "ComplianceReport-*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Invoke-Item $report.FullName

# Verify policy assignments in portal
Start-Process "https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyMenuBlade/Compliance"
```

---

## Environment-Specific Customization

### Files to Customize for New Environment

**1. Subscription ID** (auto-detected during setup, or manual in scripts):
- `Setup-AzureKeyVaultPolicyEnvironment.ps1`: `-SubscriptionId` parameter
- `AzPolicyImplScript.ps1`: Auto-detects from `Get-AzContext`

**2. Email Addresses** (optional, for monitoring):
- `Setup-AzureKeyVaultPolicyEnvironment.ps1`: `-ActionGroupEmail` parameter
- Default: 'ops@contoso.com' (change in Setup script line 488)

**3. Location** (optional, default: East US):
- `Setup-AzureKeyVaultPolicyEnvironment.ps1`: `-Location` parameter
- Affects: Resource group, VNet, Log Analytics, Event Hub

**4. Parameter Values** (optional, customize policy parameters):
- `PolicyParameters-DevTest.json`: Edit validity periods, key sizes, retention days
- `PolicyParameters-Production.json`: Edit strict parameters

**NO OTHER CUSTOMIZATION REQUIRED** - Scripts are environment-agnostic.

---

## File Checklist

### Before Packaging for New Environment

**Review Files**:
```powershell
# Create deployment package checklist
$minimalFiles = @(
    # Scripts
    "AzPolicyImplScript.ps1",
    "Setup-AzureKeyVaultPolicyEnvironment.ps1",
    "Environment-SafeDeployment.ps1",
    
    # Config
    "DefinitionListExport.csv",
    "PolicyParameters-DevTest.json",
    "PolicyParameters-Production.json",
    
    # Docs
    "README.md",
    "QUICKSTART.md",
    "Environment-Configuration-Guide.md",
    "RBAC-Configuration-Guide.md",
    "Pre-Deployment-Audit-Checklist.md",
    "EXEMPTION_PROCESS.md",
    "KeyVault-Policy-Enforcement-FAQ.md",
    "KEYVAULT_POLICY_REFERENCE.md",
    "Policy-Validation-Matrix.md"
)

# Verify all files exist
foreach ($file in $minimalFiles) {
    $exists = Test-Path $file
    $status = if ($exists) { "✅" } else { "❌ MISSING" }
    Write-Host "$status $file"
}

# Copy to deployment package
$destination = "C:\AzureKVPolicy-Deployment"
foreach ($file in $minimalFiles) {
    if (Test-Path $file) {
        Copy-Item $file -Destination $destination
    }
}

Write-Host "`n✅ Deployment package ready: $destination" -ForegroundColor Green
```

---

### Exclude Files/Folders

**Exclusion Pattern**:
```powershell
# DO NOT COPY these to deployment package
$excludePatterns = @(
    "*TestResults*.json",
    "All46Policies*.json",
    "DenyBlocking*.json",
    "ComplianceReport-*.html",
    "KeyVaultPolicyImplementationReport-*.json",
    "PolicyImplementationConfig.json",  # Subscription-specific
    "PolicyNameMapping.json",  # Auto-generated
    "*Consolidation*.md",  # Analysis docs
    "*Investigation*.md",  # Research docs
    "Phase*.md",  # Project history
    "QuickTest.ps1",  # Deprecated
    "TestParameterBinding.ps1",  # Deprecated
    "FixMissing9Policies.ps1",  # One-time fix
    "todos.md",  # Project management
    ".history/*",  # History folder
    "backups/*"  # Backup folder
)
```

---

## Summary

### Minimal Deployment Package

**6 Core Files** (MUST HAVE):
1. ✅ AzPolicyImplScript.ps1
2. ✅ Setup-AzureKeyVaultPolicyEnvironment.ps1
3. ✅ DefinitionListExport.csv
4. ✅ PolicyParameters-DevTest.json
5. ✅ PolicyParameters-Production.json
6. ✅ README.md

**9 Documentation Files** (SHOULD HAVE):
7. ✅ QUICKSTART.md
8. ✅ Environment-Configuration-Guide.md
9. ✅ RBAC-Configuration-Guide.md
10. ✅ Pre-Deployment-Audit-Checklist.md
11. ✅ EXEMPTION_PROCESS.md
12. ✅ KeyVault-Policy-Enforcement-FAQ.md
13. ✅ KEYVAULT_POLICY_REFERENCE.md
14. ✅ Policy-Validation-Matrix.md
15. ✅ Environment-SafeDeployment.ps1

**Total**: 15 files, ~400 KB

### Deployment Success Criteria

✅ All required Azure modules installed  
✅ Connected to target Azure subscription  
✅ Infrastructure setup completes without errors  
✅ Policy assignments succeed (46/46)  
✅ Compliance check runs successfully  
✅ HTML report generated  
✅ No RBAC permission errors  

### Estimated Time

- **Package Preparation**: 5 minutes
- **Prerequisites Setup**: 10 minutes
- **Infrastructure Deployment**: 15-20 minutes
- **Policy Deployment**: 10-15 minutes
- **Validation**: 10 minutes

**Total**: 50-60 minutes for complete new environment setup

---

## Support

**For deployment issues**, refer to:
- README.md (quick start)
- QUICKSTART.md (step-by-step)
- RBAC-Configuration-Guide.md (permission errors)
- FAQ.md (common issues)

**For customization**, refer to:
- Environment-Configuration-Guide.md (dev/test vs production)
- PolicyParameters-*.json (parameter customization)
- Pre-Deployment-Audit-Checklist.md (validation)
