# Azure Key Vault Policy Governance - Release Package Manifest

**Version**: 1.0  
**Release Date**: 2026-01-22  
**Package Type**: Corporate AAD Deployment  
**Target Environment**: Windows PowerShell 7.0+ on Corporate PC

---

## 📦 Package Contents Overview

**Total Files**: 17 core files  
**Package Size**: ~500 KB (excluding test artifacts)  
**Deployment Time**: 10 minutes setup + 5 minutes deployment  
**Prerequisites**: PowerShell 7.0+, Azure PowerShell modules, Contributor + Resource Policy Contributor roles

---

## 🔧 Core Deployment Scripts (2 files)

### 1. AzPolicyImplScript.ps1
- **Size**: ~250 KB (5,423 lines)
- **Purpose**: Main orchestration script for policy deployment, testing, compliance checking, and remediation
- **Required**: ✅ CRITICAL - Cannot deploy without this
- **Usage**: All deployment scenarios
- **Dependencies**: Azure PowerShell modules (Az.Accounts, Az.Resources, Az.PolicyInsights)

### 2. Setup-AzureKeyVaultPolicyEnvironment.ps1
- **Size**: ~30 KB
- **Purpose**: Infrastructure bootstrapping (VNet, Log Analytics, Event Hub, Managed Identity, Test Key Vaults)
- **Required**: ⚠️ OPTIONAL - Only needed for DevTest environment setup
- **Usage**: First-time DevTest infrastructure deployment
- **Dependencies**: Azure PowerShell modules

---

## 📋 Parameter Configuration Files (6 files)

### DevTest Environment (3 files)

#### 3. PolicyParameters-DevTest.json
- **Size**: ~15 KB
- **Purpose**: 30 policies in Audit mode (safe first deployment)
- **Policies**: 30 baseline policies
- **Mode**: Audit only (no blocking)
- **Use Case**: Initial testing, proof-of-concept
- **Command**: `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -SkipRBACCheck`

#### 4. PolicyParameters-DevTest-Full.json
- **Size**: ~25 KB
- **Purpose**: All 46 policies in Audit mode (comprehensive testing)
- **Policies**: 46 policies (certificates, keys, secrets, vaults)
- **Mode**: Audit only
- **Use Case**: Full governance testing before production
- **Command**: `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -SkipRBACCheck`

#### 5. PolicyParameters-DevTest-Full-Remediation.json
- **Size**: ~12 KB
- **Purpose**: 8 auto-remediation policies (DeployIfNotExists/Modify effects)
- **Policies**: 8 policies (diagnostic settings, private endpoints, soft delete, purge protection)
- **Mode**: Audit with auto-remediation
- **Use Case**: Testing automatic compliance fixes
- **Command**: 
  ```powershell
  .\AzPolicyImplScript.ps1 `
      -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
      -IdentityResourceId "/subscriptions/<subscription-id>/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation" `
      -SkipRBACCheck
  ```

### Production Environment (3 files)

#### 6. PolicyParameters-Production.json
- **Size**: ~25 KB
- **Purpose**: All 46 policies in Audit mode (production monitoring)
- **Policies**: 46 policies
- **Mode**: Audit only
- **Use Case**: Production baseline without blocking operations
- **Command**: `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -SkipRBACCheck`

#### 7. PolicyParameters-Production-Deny.json
- **Size**: ~26 KB
- **Purpose**: All 46 policies in Deny mode (maximum enforcement)
- **Policies**: 46 policies
- **Mode**: **Deny** (blocks non-compliant operations)
- **Use Case**: Production enforcement after Audit phase validation
- **Command**: `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Deny.json -SkipRBACCheck`

#### 8. PolicyParameters-Production-Remediation.json
- **Size**: ~12 KB
- **Purpose**: 8 auto-remediation policies for production
- **Policies**: 8 policies
- **Mode**: Audit with auto-remediation
- **Use Case**: Production automatic compliance fixes
- **Command**: 
  ```powershell
  .\AzPolicyImplScript.ps1 `
      -ParameterFile .\PolicyParameters-Production-Remediation.json `
      -IdentityResourceId "/subscriptions/<subscription-id>/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation" `
      -SkipRBACCheck
  ```

---

## 📊 Supporting Data Files (3 files)

### 9. PolicyNameMapping.json
- **Size**: ~180 KB (3,745 policy definitions)
- **Purpose**: Maps policy display names to Azure policy definition IDs
- **Required**: ✅ CRITICAL - Script cannot resolve policy IDs without this
- **Content**: 3,745 Azure Policy definitions with display names, IDs, and categories
- **Update Frequency**: Monthly (as Azure adds new policies)

### 10. DefinitionListExport.csv
- **Size**: ~15 KB (46 policies)
- **Purpose**: Catalog of 46 deployed policies with display names, definition IDs, and effects
- **Required**: ⚠️ OPTIONAL - Used for reference and validation
- **Content**: Policy name, definition ID, effect (Audit/Deny/DeployIfNotExists)
- **Usage**: Policy documentation, troubleshooting, compliance reporting

### 11. PolicyImplementationConfig.json
- **Size**: ~2 KB
- **Purpose**: Runtime configuration (scope, mode, identity)
- **Required**: ⚠️ OPTIONAL - Script has fallback defaults
- **Content**: Subscription ID, resource group scope, enforcement mode, managed identity ID
- **Usage**: Override default script behavior

---

## 📚 Documentation Files (6 files)

### Quick Start Guide

#### 12. QUICKSTART.md
- **Size**: ~12 KB (262 lines)
- **Purpose**: 5-minute deployment guide for first-time users
- **Required**: ✅ RECOMMENDED - Start here
- **Content**: Prerequisites, 3 deployment options with commands, expected results
- **Target Audience**: Azure administrators deploying for the first time

### Comprehensive Guides

#### 13. README.md
- **Size**: ~15 KB (325 lines)
- **Purpose**: Project overview with 5 Ws+H, features, structure
- **Required**: ✅ RECOMMENDED - Project introduction
- **Content**: What/Who/When/Where/Why/How, testing status, deployment timeline
- **Target Audience**: Stakeholders, project managers, new team members

#### 14. DEPLOYMENT-PREREQUISITES.md
- **Size**: ~18 KB
- **Purpose**: Prerequisites checklist, RBAC requirements, managed identity setup
- **Required**: ✅ RECOMMENDED - Pre-deployment validation
- **Content**: PowerShell version, Azure modules, RBAC roles, managed identity configuration
- **Target Audience**: Azure administrators preparing environment

#### 15. DEPLOYMENT-WORKFLOW-GUIDE.md
- **Size**: ~22 KB
- **Purpose**: Deployment workflows, scope selection, parameter file guide
- **Required**: ⚠️ OPTIONAL - Advanced deployment scenarios
- **Content**: Subscription/resource group/management group deployments, tier-based rollout
- **Target Audience**: Experienced Azure administrators

#### 16. PolicyParameters-QuickReference.md
- **Size**: ~10 KB
- **Purpose**: Parameter file selection guide (which JSON to use when)
- **Required**: ✅ RECOMMENDED - Prevents wrong parameter file usage
- **Content**: Decision tree for parameter file selection, use case matrix
- **Target Audience**: All users deploying policies

#### 17. WORKFLOW-TESTING-GUIDE.md
- **Size**: ~21 KB
- **Purpose**: Testing procedures for all 9 deployment scenarios
- **Required**: ⚠️ OPTIONAL - Validation and quality assurance
- **Content**: Test commands, expected results, troubleshooting
- **Target Audience**: QA teams, pre-production validation

---

## 🔍 Optional Files (Not Required for Deployment)

### Testing Scripts (Use for validation only)
- `Run-All-Workflow-Tests.ps1` - Automated testing of all 9 scenarios
- `Test-AllWorkflowNextSteps.ps1` - Validates next steps guidance
- `Test-AllScenariosWithHTMLValidation.ps1` - Comprehensive scenario testing with HTML report validation

### Additional Documentation (Reference only)
- `PRE-DEPLOYMENT-CHECKLIST.md` - Pre-deployment validation checklist
- `EMAIL-ALERT-CONFIGURATION.md` - Azure Monitor alert setup
- `EXEMPTION_PROCESS.md` - Policy exemption procedures
- `KEYVAULT_POLICY_REFERENCE.md` - Policy details and rationale

### Test Artifacts (Ignore for deployment)
- `workflow-test-*.txt` files (9 files) - Test output from validation runs
- `ComplianceReport-*.html` files - Sample compliance reports
- `KeyVaultPolicyImplementationReport-*.md/json/html` - Deployment reports
- All files in `backups/`, `archive/`, `.history/` directories

---

## 📦 Minimum Deployment Package (17 Core Files)

For corporate deployment on another PC, include **ONLY** these files:

```
powershell-akv-policyhardening/
├── AzPolicyImplScript.ps1                              # CRITICAL
├── Setup-AzureKeyVaultPolicyEnvironment.ps1            # Optional (DevTest only)
├── PolicyParameters-DevTest.json                       # DevTest 30 policies
├── PolicyParameters-DevTest-Full.json                  # DevTest 46 policies
├── PolicyParameters-DevTest-Full-Remediation.json      # DevTest auto-remediation
├── PolicyParameters-Production.json                    # Production Audit
├── PolicyParameters-Production-Deny.json               # Production Deny
├── PolicyParameters-Production-Remediation.json        # Production auto-remediation
├── PolicyNameMapping.json                              # CRITICAL - Policy ID resolver
├── DefinitionListExport.csv                            # Optional - Policy catalog
├── PolicyImplementationConfig.json                     # Optional - Runtime config
├── QUICKSTART.md                                       # RECOMMENDED
├── README.md                                           # RECOMMENDED
├── DEPLOYMENT-PREREQUISITES.md                         # RECOMMENDED
├── DEPLOYMENT-WORKFLOW-GUIDE.md                        # Optional
├── PolicyParameters-QuickReference.md                  # RECOMMENDED
└── WORKFLOW-TESTING-GUIDE.md                           # Optional
```

**Total Package Size**: ~500 KB (compressed: ~150 KB)

---

## 🚀 Deployment Preparation Steps

### For Package Creator (Current PC)

1. Run `.\Create-ReleasePackage.ps1` to generate ZIP package
2. Verify package contents (17 core files)
3. Transfer ZIP to target corporate PC (email, network share, USB)

### For Package User (Target Corporate PC)

1. Extract ZIP to `C:\Deploy\powershell-akv-policyhardening\`
2. Open PowerShell 7.0+ as Administrator
3. Navigate: `cd C:\Deploy\powershell-akv-policyhardening`
4. Follow **CORPORATE-DEPLOYMENT-CHECKLIST.md** step-by-step

---

## 🔐 Security Considerations

### Files Containing Sensitive Data (DO NOT COMMIT)
- Any `PolicyImplementationConfig.json` with real subscription IDs
- Test artifacts with resource IDs or subscription details
- HTML/JSON reports with actual Azure resource names

### Files Safe to Distribute
- All scripts (`.ps1`)
- All documentation (`.md`)
- All parameter files (`.json`) - contain only policy display names, no secrets
- `PolicyNameMapping.json` - contains only Azure built-in policy IDs (public)
- `DefinitionListExport.csv` - contains only policy metadata (public)

---

## 📝 Version Control Recommendations

### Include in Repository
```
✅ *.ps1 (scripts)
✅ PolicyParameters-*.json (parameter files)
✅ PolicyNameMapping.json (policy ID mappings)
✅ DefinitionListExport.csv (policy catalog)
✅ *.md (documentation)
✅ .gitignore (prevents committing sensitive data)
```

### Exclude from Repository (via .gitignore)
```
❌ ComplianceReport-*.html (contains Azure resource details)
❌ KeyVaultPolicyImplementationReport-* (deployment artifacts)
❌ workflow-test-*.txt (test output with subscription IDs)
❌ PolicyImplementationConfig.json (if contains real subscription IDs)
❌ test-all-workflows-*.txt (test logs)
❌ backups/ (backup files)
❌ archive/ (archived files)
❌ .history/ (VS Code local history)
```

---

## 🆘 Support & Troubleshooting

### If Files Are Missing After Extraction
1. Check ZIP integrity: `Get-FileHash AzureKeyVaultPolicyGovernance-v1.0.zip -Algorithm SHA256`
2. Re-extract to new directory
3. Verify 17 core files are present: `Get-ChildItem | Measure-Object`

### If Scripts Fail to Run
1. Check PowerShell version: `$PSVersionTable.PSVersion` (requires 7.0+)
2. Install Azure modules: See DEPLOYMENT-PREREQUISITES.md
3. Verify execution policy: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### If Policy Assignments Fail
1. Verify RBAC: `Get-AzRoleAssignment -SignInName <your-email>`
2. Check subscription context: `Get-AzContext`
3. Review logs in script output for specific error messages

---

## 📞 Contact & Support

- **Issues**: Create issue in GitHub repository
- **Questions**: Review README.md FAQ section
- **Enterprise Support**: Contact Azure Support (if subscription includes support plan)

---

## 🔄 Update Process

### When to Update Package

- **Monthly**: Update `PolicyNameMapping.json` if new Azure policies released
- **Quarterly**: Review parameter files for new policy requirements
- **As Needed**: Update scripts when bugs are fixed or features added

### How to Update Package

1. Pull latest changes from repository
2. Run `.\Create-ReleasePackage.ps1` to generate new ZIP
3. Update version number in this manifest
4. Distribute new package to users

---

**Last Updated**: 2026-01-22  
**Manifest Version**: 1.0  
**Package Maintained By**: Azure Governance Team
