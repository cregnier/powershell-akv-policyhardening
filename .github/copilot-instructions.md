# Azure Key Vault Policy Governance - AI Agent Instructions

## Project Architecture

This is an **Azure Policy automation framework** for deploying and managing 46 Azure Key Vault governance policies across dev/test and production environments. The project uses PowerShell for Azure Resource Manager policy assignments with comprehensive testing, compliance reporting, and auto-remediation capabilities.

### Core Components

1. **AzPolicyImplScript.ps1** (4,277 lines): Monolithic orchestration script
   - Policy deployment engine with retry logic and managed identity support
   - 5 testing modes: Infrastructure validation, Production enforcement, Auto-remediation, Deny blocking, Compliance checking
   - Exemption management (Create/List/Remove/Export)
   - HTML/JSON/CSV report generation
   - Interactive menu system for first-time users

2. **Setup-AzureKeyVaultPolicyEnvironment.ps1**: Infrastructure bootstrapping
   - Deploys VNet, Log Analytics, Event Hub, Private DNS, Managed Identity
   - Creates 3 test Key Vaults with different compliance states (dev/test only)
   - Configures Azure Monitor alerts and action groups

3. **6-Parameter File Strategy** (critical - always use correct file):
   - **DevTest (30)**: `PolicyParameters-DevTest.json`, `PolicyParameters-DevTest-Remediation.json`
   - **DevTest-Full (46)**: `PolicyParameters-DevTest-Full.json`, `PolicyParameters-DevTest-Full-Remediation.json`
   - **Production (46)**: `PolicyParameters-Production.json`, `PolicyParameters-Production-Remediation.json`

### Policy Enforcement Modes

- **Audit**: Monitor compliance without blocking (safe default)
- **Deny**: Block new non-compliant resources (production enforcement)
- **DeployIfNotExists/Modify**: Auto-remediate existing non-compliant resources (8 policies)

## PowerShell Az.KeyVault Module - Critical Syntax Changes

**BREAKING CHANGES** as of Az.KeyVault 6.3.2+ (January 2026):

### RBAC Authorization Parameter
- **OLD (deprecated)**: `-EnableRbacAuthorization` (does not exist)
- **NEW (correct)**: 
  - To **ENABLE** RBAC: Omit the `-DisableRbacAuthorization` switch (RBAC enabled by default)
  - To **DISABLE** RBAC: Use `-DisableRbacAuthorization` switch

```powershell
# CORRECT - Enable RBAC (default behavior)
New-AzKeyVault -Name "vault" -ResourceGroupName "rg" -Location "eastus" -EnablePurgeProtection
# RBAC is enabled by default - no parameter needed!

# CORRECT - Disable RBAC (use Access Policies)
New-AzKeyVault -Name "vault" -ResourceGroupName "rg" -Location "eastus" -DisableRbacAuthorization

# WRONG - This parameter does not exist
New-AzKeyVault -EnableRbacAuthorization  # ❌ ERROR
```

### Public Network Access Parameter
- **Parameter**: `-PublicNetworkAccess <String>`
- **Values**: `'Enabled'` or `'Disabled'` (string, not boolean)
- **Default**: Enabled if omitted

```powershell
# CORRECT - Disable public access
New-AzKeyVault -Name "vault" -ResourceGroupName "rg" -Location "eastus" -PublicNetworkAccess 'Disabled'

# WRONG - Boolean not accepted
New-AzKeyVault -PublicNetworkAccess $false  # ❌ ERROR
```

### Testing Impact
When writing comprehensive tests, ensure:
1. ✅ Omit `-DisableRbacAuthorization` for RBAC-enabled vaults (default)
2. ✅ Use `-PublicNetworkAccess 'Disabled'` for private vaults (string value)
3. ✅ ARM templates use `"enableRbacAuthorization": true` (still valid in JSON)

## Critical Workflows

### Policy Deployment (ALWAYS use managed identity + proper parameters)

**CRITICAL**: All deployments now require these parameters for complete policy coverage:
- `-ParameterFile`: Which policy set to deploy
- `-PolicyMode`: Audit or Deny (prevents interactive menu prompts)
- `-IdentityResourceId`: Managed identity for DINE/Modify policies (ALL scenarios need this)
- `-ScopeType Subscription`: Always use subscription scope (production-ready)
- `-SkipRBACCheck`: Skip permission validation (speeds up testing)

```powershell
# Get managed identity (created by Setup-AzureKeyVaultPolicyEnvironment.ps1)
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# DevTest safe deployment (30/30 policies, Audit mode, Subscription scope)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest.json `
    -PolicyMode Audit `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck

# DevTest full testing (46/46 policies, Audit mode, Subscription scope)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full.json `
    -PolicyMode Audit `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck

# Production deployment (46/46 policies, Audit mode, Subscription scope)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Audit `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck

# Production deployment (34 Deny policies, Subscription scope)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Deny.json `
    -PolicyMode Deny `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck

# Auto-remediation (8/8 DeployIfNotExists/Modify policies)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck
```

### Testing Commands (script has built-in test functions)

```powershell
# Comprehensive infrastructure validation (11 checks)
.\AzPolicyImplScript.ps1 -TestInfrastructure -Detailed

# Production enforcement validation (4 Deny mode tests)
.\AzPolicyImplScript.ps1 -TestProductionEnforcement

# Auto-remediation testing (30-60 min - creates test vault, waits for Azure Policy evaluation)
.\AzPolicyImplScript.ps1 -TestAutoRemediation

# Compliance reporting (HTML/JSON/CSV output)
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan
```

## Project-Specific Conventions

### Parameter File Loading
**CRITICAL**: Script uses `-ParameterOverridesPath` (not `-ParameterFile`). The argument parser at line ~4030 converts both.

```powershell
# Correct parameter name in function signature
param([string]$ParameterOverridesPath = './PolicyParameters.json')

# Argument parsing handles both -ParameterFile and -ParameterOverridesPath
'^-ParameterOverridesPath$' { if ($i+1 -lt $args.Count) { $callParams['ParameterOverridesPath'] = $args[$i+1]; $i++ } }
```

### Managed Identity Pattern (for DeployIfNotExists/Modify policies)
Always pass full ARM resource ID, not just name:
```powershell
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

### Retry Logic Pattern (exponential backoff)
```powershell
# Standard retry pattern used throughout (lines ~1800-2000)
for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
    try {
        # Azure operation
        break
    } catch {
        $delay = [Math]::Pow(2, $attempt)
        Write-Log "Attempt $attempt failed: $($_.Exception.Message). Retrying in $delay seconds..." -Level 'WARN'
        Start-Sleep -Seconds $delay
    }
}
```

### Policy Assignment Naming Convention
Assignments automatically generated from policy display names, truncated to 64 chars with numeric suffix:
```powershell
# Example: "Certificates should have the specified maximum validity period" 
# becomes "Certificatesshouldhavethespecifiedmaximumvalidityperi-1606864759"
```

## Azure Policy Timing Constraints

**CRITICAL**: Azure Policy has mandatory wait periods that cannot be bypassed:

1. **Policy Assignment Propagation**: 30-90 minutes across Azure regions
2. **Compliance Evaluation**: 15-30 minutes for resource scanning
3. **Auto-Remediation**: 10-15 minutes for DeployIfNotExists task creation
4. **Total Testing Time**: 30-60 minutes minimum for auto-remediation tests

**Do not attempt to speed up policy evaluation** - Azure controls this backend process.

## Common Pitfalls

### 1. Wrong Parameter File Loaded
**Problem**: Script defaults to `PolicyParameters.json` if parameter file not found
**Solution**: Always verify correct file with `-ParameterOverridesPath` parameter
```powershell
# Check loaded file in logs
[INFO] Loading policy parameter overrides from .\PolicyParameters-DevTest-Full-Remediation.json
```

### 2. Missing Parameters for Deny Mode
**Problem**: Switching from Audit to Deny requires all parameter values
**Solution**: Use parameter file designed for Deny mode (Production.json), not Audit (DevTest.json)

### 3. Managed Identity Required for ALL Deployments
**Problem**: DeployIfNotExists/Modify policies skipped without managed identity, missing 8 policies
**Solution**: ALWAYS provide `-IdentityResourceId` for ALL scenarios (not just remediation)
```powershell
# Managed identity created by Setup-AzureKeyVaultPolicyEnvironment.ps1 at line 369
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# ALL scenarios need this parameter
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest.json `
    -PolicyMode Audit `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck
```

**8 Policies That Require Identity** (present in DevTest/Production parameter files):
1. Configure Azure Key Vault Managed HSM with private endpoints (DINE)
2. Deploy - Configure diagnostic settings to Event Hub for Managed HSM (DINE)
3. Configure Azure Key Vaults to use private DNS zones (DINE)
4. Deploy Diagnostic Settings for Key Vault to Event Hub (DINE)
5. Deploy - Configure diagnostic settings for Key Vault to Log Analytics (DINE)
6. Configure Azure Key Vaults with private endpoints (DINE)
7. Configure Azure Key Vault Managed HSM to disable public network access (Modify)
8. Configure key vaults to enable firewall (Modify)

### 4. PolicyMode Parameter Missing
**Problem**: Script prompts "Choose mode (Audit/Deny/Enforce) [Audit]:" interactively (breaks automation)
**Solution**: Always provide `-PolicyMode Audit` or `-PolicyMode Deny` explicitly
```powershell
# Script does NOT auto-read mode from parameter file's "effect" values
# Must explicitly provide -PolicyMode parameter
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest.json `
    -PolicyMode Audit `  # REQUIRED - prevents interactive prompt
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck
```

### 5. Scope Strategy (Updated Jan 2026)
**Problem**: DevTest scenarios originally used ResourceGroup scope (limited)
**Solution**: ALL scenarios now use Subscription scope (production-ready)
```powershell
# Script hardcoded to use Subscription at line 5773
# But explicit parameter ensures clarity
-ScopeType Subscription
```
### 6. Testing Auto-Remediation Without Waiting
**Solution**: Wait 30-60 minutes for Azure Policy evaluation cycle (enforced by Azure backend)

## Code Navigation Tips

- **Main entry point**: Line ~4216 (`if ($PSCommandPath -eq $MyInvocation.MyCommand.Path)`)
- **Argument parsing**: Lines ~4030-4045 (switch statement)
- **Test functions**: Lines ~600-1400 (Test-InfrastructureValidation, Test-ProductionEnforcement, Test-AutoRemediation)
- **Policy assignment logic**: Lines ~1800-2500 (Main function, retry handling)
- **Report generation**: Lines ~1300-1600 (New-ComplianceHtmlReport)
- **Managed identity handling**: Lines ~2200-2300 (identity assignment for DeployIfNotExists policies)

## Key Files Reference

- **DefinitionListExport.csv**: 46 Azure policy definitions with display names, IDs, effects
- **PolicyNameMapping.json**: 3,745 policy display name → definition ID mappings
- **PolicyImplementationConfig.json**: Runtime configuration (scope, mode, identity)
- **DEPLOYMENT-PREREQUISITES.md**: Complete setup requirements
- **QUICKSTART.md**: Step-by-step deployment guide
- **PolicyParameters-QuickReference.md**: Parameter file selection guide

## Environment-Specific Resource Requirements

### DevTest Environment
- Resource Group: `rg-policy-keyvault-test`
- Test Key Vaults: `kv-compliant-test`, `kv-non-compliant-test`, `kv-partial-test`
- Managed Identity: `id-policy-remediation` (for auto-remediation testing)
- Log Analytics: `law-policy-test-*` (random suffix)
- Event Hub: `eh-policy-test-*` (random suffix)

### Production Environment
- Infrastructure-only (no test vaults)
- Same managed identity, Log Analytics, Event Hub patterns
- Private DNS: `privatelink.vaultcore.azure.net`

## Testing Coverage Status

See `todos.md` for current test status. As of last update:
- Infrastructure: ✅ Complete
- DevTest (30 policies): ✅ Complete  
- Production (46 policies): ✅ Complete
- Auto-Remediation: ⏳ In Progress (requires 30-60 min Azure evaluation)
- Key Policies: ⏳ Pending (14 policies)

## When Modifying Code

1. **Test Parameters**: Use `-WhatIf` or `-DryRun` before deploying
2. **Compliance Checks**: Always run `-CheckCompliance` after deployment changes
3. **Rollback Available**: `.\AzPolicyImplScript.ps1 -Rollback` removes all KV-* assignments
4. **Logging**: All operations logged with timestamps `[2026-01-15 14:03:05Z] [INFO]`
5. **Error Handling**: Retry logic with exponential backoff standard across all Azure operations
