# Policy Parameter Files - Quick Reference

## Overview
6 parameter files for comprehensive testing across all enforcement modes.

## File Structure

### DevTest Environment (Safety Option - 30 Policies)
1. **PolicyParameters-DevTest.json**
   - Policies: 30
   - Mode: Audit (all policies)
   - Use Case: Safe default for dev/test, relaxed parameters
   - Deploy: `.\AzPolicyImplScript.ps1 -DeployDevTest -SkipRBACCheck`

2. **PolicyParameters-DevTest-Remediation.json**
   - Policies: 30
   - Mode: 6 DeployIfNotExists/Modify + rest Audit
   - Use Case: Test auto-remediation in dev/test
   - Deploy: `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Remediation.json -SkipRBACCheck`
   - Remediation Policies:
     - Managed HSM public network access (Modify)
     - Deploy diagnostic settings - Log Analytics (DeployIfNotExists)
     - Deploy private endpoints (DeployIfNotExists)
     - Deploy diagnostic settings - Event Hub (DeployIfNotExists)
     - Deploy private DNS zones (DeployIfNotExists)
     - Enable firewall (Modify)
     - Deploy Managed HSM private endpoints (DeployIfNotExists)
     - Deploy Event Hub diagnostic settings (DeployIfNotExists)

### DevTest Environment (Full Testing - 46 Policies)
3. **PolicyParameters-DevTest-Full.json**
   - Policies: 46 (all production policies)
   - Mode: Audit (all policies)
   - Use Case: Comprehensive testing in dev/test with all 46 policies
   - Deploy: `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -SkipRBACCheck`

4. **PolicyParameters-DevTest-Full-Remediation.json**
   - Policies: 46
   - Mode: 8 DeployIfNotExists/Modify + rest Audit
   - Use Case: Full auto-remediation testing with all 46 policies
   - Deploy: `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json -SkipRBACCheck`
   - Remediation Policies: (same 8 as #2 above)

### Production Environment (46 Policies)
5. **PolicyParameters-Production.json**
   - Policies: 46
   - Mode: Deny (enforcement on critical policies)
   - Use Case: Production enforcement, blocks non-compliant operations
   - Deploy: `.\AzPolicyImplScript.ps1 -DeployProduction -SkipRBACCheck`

6. **PolicyParameters-Production-Remediation.json**
   - Policies: 46
   - Mode: 8 DeployIfNotExists/Modify + rest Audit
   - Use Case: Production auto-remediation (fixes non-compliant resources)
   - Deploy: `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Remediation.json -SkipRBACCheck`
   - Remediation Policies: (same 8 as #2 above)

## Policy Count by Environment

| Environment | Policies | Safety Level | Key Differences |
|-------------|----------|--------------|-----------------|
| DevTest (30) | 30 | High | Excludes production-critical key policies (expiration, rotation, HSM) |
| DevTest-Full (46) | 46 | Medium | Includes all policies for comprehensive testing |
| Production (46) | 46 | Low | Strict parameters, Deny enforcement |

## Remediation Policies (8 Total)

All remediation parameter files enable these 8 policies with DeployIfNotExists/Modify effects:

1. **Modify**: Configure Azure Key Vault Managed HSM to disable public network access
2. **DeployIfNotExists**: Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace
3. **DeployIfNotExists**: Configure Azure Key Vaults with private endpoints
4. **DeployIfNotExists**: Deploy - Configure diagnostic settings to an Event Hub to be enabled on Azure Key Vault Managed HSM
5. **DeployIfNotExists**: Configure Azure Key Vaults to use private DNS zones
6. **Modify**: Configure key vaults to enable firewall
7. **DeployIfNotExists**: Configure Azure Key Vault Managed HSM with private endpoints
8. **DeployIfNotExists**: Deploy Diagnostic Settings for Key Vault to Event Hub

## Testing Workflows

### Scenario 1: Safe DevTest Testing (30 policies)
```powershell
# Audit mode
.\AzPolicyImplScript.ps1 -DeployDevTest -SkipRBACCheck

# Auto-remediation mode
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Remediation.json -SkipRBACCheck
.\AzPolicyImplScript.ps1 -TestAutoRemediation -SkipRBACCheck
```

### Scenario 2: Comprehensive DevTest Testing (46 policies)
```powershell
# Audit mode - all 46 policies
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -SkipRBACCheck

# Auto-remediation mode - all 46 policies
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json -SkipRBACCheck
.\AzPolicyImplScript.ps1 -TestAutoRemediation -SkipRBACCheck
```

### Scenario 3: Production Enforcement (46 policies)
```powershell
# Deny mode - blocks non-compliant operations
.\AzPolicyImplScript.ps1 -DeployProduction -SkipRBACCheck
.\AzPolicyImplScript.ps1 -TestProductionEnforcement -SkipRBACCheck

# Auto-remediation mode - fixes existing violations
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Remediation.json -SkipRBACCheck
.\AzPolicyImplScript.ps1 -TestAutoRemediation -SkipRBACCheck
```

## Parameter Differences

### DevTest vs Production Parameters

| Policy | DevTest | Production | Reason |
|--------|---------|------------|--------|
| Key max validity | 1095 days (3 years) | 365 days (1 year) | Production requires frequent rotation |
| Secret max validity | 1095 days | 365 days | Production security requirement |
| Key rotation | 365 days | 90 days | Production requires frequent rotation |
| RSA key size | 2048 bits | 4096 bits | Production security requirement |
| Log retention | 30 days | 365 days | Production compliance requirement |
| Certificate validity | 36 months | 12 months | Production security requirement |
| Days before expiration | 30 days | 90 days | Production early warning |

## Next Steps for Testing

**Current Position:** 10/13 tests complete (77%)

**Remaining Tests:**
1. Auto-remediation testing (Step B) - Use remediation parameter files
2. Key policies testing (Step C) - Use Full parameter files
3. Final validation

**Recommended Sequence:**
```powershell
# 1. Deploy DevTest-Full-Remediation (all 46 policies with auto-remediation)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json -SkipRBACCheck

# 2. Run auto-remediation test
.\AzPolicyImplScript.ps1 -TestAutoRemediation -SkipRBACCheck

# 3. Generate compliance report
.\AzPolicyImplScript.ps1 -CheckCompliance -SkipRBACCheck

# 4. Test Key policies (create test keys with various configurations)
# Manual testing - create keys with expiration, rotation, size variations
```

## File Locations
All parameter files in: `C:\Temp\`
