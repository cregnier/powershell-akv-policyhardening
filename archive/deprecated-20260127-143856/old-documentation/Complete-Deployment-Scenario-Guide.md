# Complete Deployment Scenario Guide - All 9 Workflows

**Last Updated**: January 22, 2026  
**Purpose**: Comprehensive reference for Azure Key Vault Policy deployment scenarios  
**Audience**: DevOps engineers, Security teams, Azure administrators

---

## 📋 Quick Reference

| # | Scenario | Policies | Effect | Identity | Duration | Risk Level |
|---|----------|----------|--------|----------|----------|------------|
| 1 | DevTest Baseline | 30 | Audit | Optional | 5 min | 🟢 Low |
| 2 | DevTest Full | 46 | Audit | Optional | 5 min | 🟢 Low |
| 3 | DevTest Auto-Remediation | 46 | Audit+DINE | **Required** | 60-90 min | 🟡 Medium |
| 4 | Production Audit | 46 | Audit | Optional | 5 min | 🟢 Low |
| 5 | Production Deny | 35 | Deny | No | 5 min | 🔴 High |
| 6 | Production Auto-Remediation | 46 | Audit+DINE | **Required** | 60-90 min | 🟡 Medium |
| 7 | Resource Group Scope | 30 | Audit | Optional | 5 min | 🟢 Low |
| 8 | Management Group Scope | 46 | Audit | Optional | 5 min | 🟡 Medium |
| 9 | Rollback | All | N/A | No | 3 min | 🟢 Low |

---

## Scenario 1: DevTest Baseline

### Overview
Safe initial deployment for infrastructure validation and core governance testing.

### Configuration
- **Parameter File**: `PolicyParameters-DevTest.json`
- **Policy Count**: 30 policies
- **Effect**: Audit only
- **Managed Identity**: Optional (8 policies skipped without it)
- **Scope**: Subscription
- **Risk Level**: 🟢 Low (no blocking)

### Purpose & Use Cases
1. **First Deployment**: Validate Azure Policy infrastructure setup
2. **Syntax Testing**: Verify parameter file structure
3. **Baseline Metrics**: Establish initial compliance baseline
4. **Safe Testing**: No operational impact on existing resources

### Strategy
- Core security policies only (30 of 46)
- Audit mode prevents resource blocking
- Immediate deployment (no wait time)
- Suitable for any environment

### Policy Categories Included
- **Configuration** (8): Soft delete, purge protection, RBAC, network security
- **Certificates** (9): Validity, CA, key types, expiration
- **Keys** (7): Expiration, types, sizes, HSM backing
- **Secrets** (4): Expiration, content type, validity
- **Diagnostics** (2): Logging (Audit only without identity)

### Deployment Command
```powershell
# Preview mode (safe validation)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -Preview -SkipRBACCheck

# Actual deployment
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -SkipRBACCheck
```

### Expected Outcomes
- ✅ 30 policy assignments created successfully
- ✅ Compliance data available in 30-90 minutes
- ✅ No resource creation blocked
- ✅ HTML report generated with policy status
- 📊 Typical compliance: 30-40% (baseline before remediation)

### Success Criteria
1. All 30 policies assigned without errors
2. Azure Portal shows 30 assignments
3. Compliance report accessible
4. No [ERROR] messages in deployment log

---

## Scenario 2: DevTest Full Testing

### Overview
Comprehensive testing of all 46 Azure Key Vault policies in non-production environment.

### Configuration
- **Parameter File**: `PolicyParameters-DevTest-Full.json`
- **Policy Count**: 46 policies (all available)
- **Effect**: Audit only
- **Managed Identity**: Optional (8 policies limited without it)
- **Scope**: Subscription
- **Risk Level**: 🟢 Low (monitoring only)

### Purpose & Use Cases
1. **Complete Coverage**: Test all available governance policies
2. **Gap Analysis**: Identify compliance gaps before production
3. **Policy Understanding**: Learn requirements for all policy categories
4. **Production Readiness**: Prepare for comprehensive governance

### Strategy
- All 46 policies in Audit mode
- Includes preview Managed HSM policies
- More stringent requirements than Scenario 1
- Expected lower compliance percentage

### Additional Policies vs Scenario 1 (+16)
- **Managed HSM** (8): Preview policies for Managed HSM governance
- **Network Security** (3): Additional firewall and private link policies
- **Diagnostics** (3): Event Hub and Log Analytics integration
- **Advanced Certificate/Key Policies** (2): Additional validation rules

### Deployment Command
```powershell
# Preview mode
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -Preview -SkipRBACCheck

# Actual deployment
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -SkipRBACCheck
```

### Expected Outcomes
- ✅ 46 policy assignments created
- ✅ Comprehensive compliance visibility
- ⚠️ Lower compliance % than Scenario 1 (stricter requirements)
- ✅ Identifies all governance gaps
- 📊 Typical compliance: 25-35% (more policies, tighter rules)

### Comparison to Scenario 1
| Aspect | Scenario 1 (30) | Scenario 2 (46) |
|--------|----------------|----------------|
| Policies | 30 core | 46 comprehensive |
| Managed HSM | ❌ Not included | ✅ 8 policies |
| Diagnostics | 2 basic | 5 advanced |
| Compliance | 30-40% | 25-35% |
| Deployment Time | 5 min | 5 min |

---

## Scenario 3: DevTest Auto-Remediation

### Overview
Test automated compliance remediation with DeployIfNotExists/Modify policies.

### Configuration
- **Parameter File**: `PolicyParameters-DevTest-Full-Remediation.json`
- **Policy Count**: 46 (38 Audit + 8 DeployIfNotExists/Modify)
- **Effect**: Mixed (Audit + auto-remediation)
- **Managed Identity**: **REQUIRED** ⚠️
- **Scope**: Subscription
- **Risk Level**: 🟡 Medium (auto-modifies resources)
- **Duration**: 60-90 minutes (Azure evaluation cycle)

### Purpose & Use Cases
1. **Remediation Testing**: Validate auto-fix policies work correctly
2. **RBAC Validation**: Test managed identity permissions
3. **Timing Understanding**: Learn Azure Policy evaluation cycles
4. **Production Prep**: Test before enabling in production

### Strategy
- 38 policies monitor compliance (Audit)
- 8 policies automatically fix issues (DeployIfNotExists/Modify)
- Requires 30-90 minute wait for Azure evaluation
- Tests managed identity permissions end-to-end

### Auto-Remediation Policies (8)

| # | Policy | Effect | Action |
|---|--------|--------|--------|
| 1 | Resource logs in Key Vault should be enabled | DeployIfNotExists | Creates diagnostic settings |
| 2 | Resource logs in Azure Key Vault Managed HSM should be enabled | DeployIfNotExists | Creates HSM diagnostic settings |
| 3 | Deploy Diagnostic Settings for Key Vault to Event Hub | DeployIfNotExists | Configures Event Hub logging |
| 4 | Deploy diagnostic settings to Event Hub for Managed HSM | DeployIfNotExists | Configures HSM Event Hub logging |
| 5 | Deploy diagnostic settings for Azure Key Vault to Log Analytics | DeployIfNotExists | Configures Log Analytics workspace |
| 6 | Configure Azure Key Vaults with private endpoints | DeployIfNotExists | Creates private endpoints |
| 7 | Configure Azure Key Vaults to use private DNS zones | DeployIfNotExists | Links private DNS zones |
| 8 | Configure key vaults to enable firewall | Modify | Enables firewall on existing vaults |

### Prerequisites
**Infrastructure** (deployed by Setup-AzureKeyVaultPolicyEnvironment.ps1):
- ✅ Managed Identity: `id-policy-remediation`
- ✅ Resource Group: `rg-policy-remediation`
- ✅ Log Analytics Workspace: `law-policy-*`
- ✅ Event Hub Namespace: `eh-policy-*`
- ✅ Private DNS Zone: `privatelink.vaultcore.azure.net`
- ✅ Virtual Network: `vnet-policy-test`

**RBAC Assignments** (on managed identity):
- ✅ Contributor (subscription scope)
- ✅ Key Vault Contributor (subscription scope)
- ✅ Network Contributor (for private endpoints)

### Deployment Command
```powershell
# Preview mode (shows what would happen)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation" `
    -Preview `
    -SkipRBACCheck

# Actual deployment
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation" `
    -SkipRBACCheck
```

### Testing Timeline
1. **Deploy Policies**: 5 minutes
2. **Azure Evaluation Cycle**: 30-90 minutes ⏱️
3. **Remediation Task Creation**: Automatic
4. **Remediation Execution**: 10-15 minutes
5. **Verify Compliance**: 5 minutes

**Total Expected Time**: 60-90 minutes minimum (cannot be accelerated)

### Verification Steps
1. Check remediation task status:
   ```powershell
   Get-AzPolicyRemediation -Scope "/subscriptions/<sub-id>"
   ```
2. Verify diagnostic settings created on Key Vaults
3. Check private endpoints deployed
4. Confirm firewall enabled on non-compliant vaults
5. Review compliance report for improvement

### Expected Outcomes
- ✅ 46 policy assignments created
- ⏱️ Remediation tasks created automatically (after 30-90 min)
- ✅ Non-compliant resources automatically fixed
- 📈 Compliance improves from ~25% to ~35%+
- ✅ 8 remediation tasks visible in Azure Portal

---

## Scenario 4: Production Audit Monitoring

### Overview
Production-ready monitoring deployment without blocking resources.

### Configuration
- **Parameter File**: `PolicyParameters-Production.json`
- **Policy Count**: 46 policies (all available)
- **Effect**: Audit only
- **Managed Identity**: Optional
- **Scope**: Subscription
- **Risk Level**: 🟢 Low (no blocking)

### Purpose & Use Cases
1. **Production Monitoring**: Track compliance without operational impact
2. **Change Detection**: Alert on non-compliant configurations
3. **Gradual Adoption**: Monitor before enforcement
4. **Compliance Reporting**: Executive dashboards and reports

### Strategy
- All 46 policies in Audit mode
- Production parameter values (stricter than DevTest)
- No resource blocking
- Continuous compliance monitoring

### Key Differences from DevTest Full
| Aspect | DevTest Full | Production Audit |
|--------|-------------|------------------|
| Parameter Values | Relaxed | Strict |
| Certificate Validity | 12-24 months | 12 months |
| Key Size | 2048+ | 4096+ |
| Expiration Warning | 30 days | 90 days |
| CA Authorities | Test CAs | Production CAs |
| Environment | Dev/Test | Production |

### Deployment Command
```powershell
# Preview mode
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -Preview -SkipRBACCheck

# Actual deployment
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -SkipRBACCheck
```

### Expected Outcomes
- ✅ 46 policy assignments with production parameters
- 📊 Compliance baseline established
- 🔔 Alerts configured for violations
- ✅ No operational disruption
- 📈 Prepare for Deny mode transition

### Transition Path
1. **Week 1-2**: Deploy Audit mode, establish baseline
2. **Week 3-4**: Review compliance, identify gaps
3. **Week 5-6**: Remediate high-priority violations
4. **Week 7**: Deploy auto-remediation (Scenario 6)
5. **Week 8+**: Consider Deny mode (Scenario 5) for critical policies

---

## Scenario 5: Production Deny Mode (Maximum Enforcement)

### Overview
Maximum enforcement deployment - blocks creation of non-compliant resources.

### Configuration
- **Parameter File**: `PolicyParameters-Production-Deny.json`
- **Policy Count**: 35 policies (11 excluded)
- **Effect**: Deny mode
- **Managed Identity**: Not used
- **Scope**: Subscription
- **Risk Level**: 🔴 High (blocks resources)

### ⚠️ WARNING
**This scenario BLOCKS resource creation/updates that violate policies. Deploy in Audit mode first!**

### Purpose & Use Cases
1. **Maximum Security**: Prevent non-compliant resource deployment
2. **Compliance Enforcement**: Ensure all new resources meet standards
3. **Policy-Based Governance**: Shift-left security controls
4. **Zero Trust**: Block non-compliant configurations at creation time

### Strategy
- 35 policies using Deny effect
- 11 policies excluded (don't support Deny)
- Blocks non-compliant resource operations
- Requires user training and documentation

### Excluded Policies (11 - cannot use Deny)

**DeployIfNotExists/Modify Policies (8)**:
1. Resource logs in Key Vault should be enabled
2. Resource logs in Azure Key Vault Managed HSM should be enabled
3. Deploy Diagnostic Settings for Key Vault to Event Hub
4. Deploy diagnostic settings to Event Hub for Managed HSM
5. Deploy diagnostic settings for Azure Key Vault to Log Analytics
6. Configure Azure Key Vaults with private endpoints
7. Configure Azure Key Vaults to use private DNS zones
8. Configure key vaults to enable firewall

**Audit-Only Policies (3)**:
9. [Preview]: Configure Azure Key Vault Managed HSM to disable public network access (Modify only)
10. [Preview]: Azure Key Vault Managed HSM should use private link (Audit only)
11. Keys should have a rotation policy ensuring rotation is scheduled (Audit only)

### Pre-Deployment Checklist
- [ ] Scenario 4 (Production Audit) deployed for at least 2 weeks
- [ ] Compliance baseline established and reviewed
- [ ] High-priority violations remediated
- [ ] User documentation updated with new requirements
- [ ] Support team trained on policy requirements
- [ ] Exemption process documented
- [ ] Testing completed in dev/test environment
- [ ] Change management approval obtained

### Deployment Command
```powershell
# ALWAYS preview first!
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Deny.json -Preview -SkipRBACCheck

# Actual deployment (requires confirmation)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Deny.json -SkipRBACCheck
```

### Testing Blocked Operations
**Test creating non-compliant Key Vault**:
```powershell
# This should be BLOCKED by policy
New-AzKeyVault `
    -Name "kv-test-no-soft-delete" `
    -ResourceGroupName "rg-test" `
    -Location "eastus" `
    -EnableSoftDelete $false  # ❌ BLOCKED by policy
```

**Expected Error**:
```
Resource creation denied by policy 'Key vaults should have soft delete enabled'
```

### Expected Outcomes
- ✅ 35 policy assignments in Deny mode
- 🚫 Non-compliant resource creation blocked
- 📝 Policy violation errors returned to users
- ⚠️ Increased support tickets initially
- 📈 Improved long-term compliance

### Rollback Plan
If blocking causes issues:
```powershell
# Remove Deny assignments
.\AzPolicyImplScript.ps1 -Rollback

# Re-deploy Audit mode
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -SkipRBACCheck
```

---

## Scenario 6: Production Auto-Remediation

### Overview
Production automated compliance with DeployIfNotExists/Modify policies.

### Configuration
- **Parameter File**: `PolicyParameters-Production-Remediation.json`
- **Policy Count**: 46 (38 Audit + 8 auto-remediation)
- **Effect**: Mixed (Audit + DeployIfNotExists/Modify)
- **Managed Identity**: **REQUIRED** ⚠️
- **Scope**: Subscription
- **Risk Level**: 🟡 Medium (auto-modifies resources)
- **Duration**: 60-90 minutes (Azure evaluation)

### Purpose & Use Cases
1. **Production Auto-Fix**: Automatically remediate compliance issues
2. **Reduced Manual Work**: Auto-configure diagnostics and security
3. **Continuous Compliance**: Maintain compliance as resources deploy
4. **Operational Efficiency**: Reduce compliance backlog

### Strategy
- Same 8 auto-remediation policies as Scenario 3
- Production parameter values
- Requires managed identity with production RBAC
- 30-90 minute evaluation cycle

### Production vs DevTest Remediation

| Aspect | DevTest (Scenario 3) | Production (Scenario 6) |
|--------|---------------------|------------------------|
| Parameter Values | Relaxed | Strict |
| Log Retention | 30 days | 90-365 days |
| Event Hub | Test namespace | Production namespace |
| Log Analytics | Test workspace | Production workspace |
| Private Endpoints | Optional | Recommended |
| Managed Identity | Test identity | Production identity |

### Deployment Command
```powershell
# Preview mode
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -IdentityResourceId "/subscriptions/<sub-id>/resourceGroups/rg-policy-remediation-prod/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation-prod" `
    -Preview `
    -SkipRBACCheck

# Actual deployment
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -IdentityResourceId "/subscriptions/<sub-id>/resourceGroups/rg-policy-remediation-prod/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation-prod" `
    -SkipRBACCheck
```

### Monitoring Remediation Tasks
```powershell
# Check active remediation tasks
Get-AzPolicyRemediation -Scope "/subscriptions/<sub-id>" | 
    Where-Object { $_.ProvisioningState -eq 'Running' }

# View remediation history
Get-AzPolicyRemediation -Scope "/subscriptions/<sub-id>" | 
    Select-Object Name, PolicyDefinitionReferenceId, ProvisioningState, CreatedOn
```

### Expected Outcomes
- ✅ 46 policy assignments (38 monitor, 8 remediate)
- ⏱️ Remediation tasks start 30-90 minutes post-deployment
- ✅ Diagnostic settings auto-created on non-compliant vaults
- ✅ Firewalls auto-enabled where disabled
- 📈 Compliance improves continuously as resources deploy

---

## Scenario 7: Resource Group Scope Testing

### Overview
Limited scope deployment for specific resource group testing.

### Configuration
- **Parameter File**: `PolicyParameters-DevTest.json`
- **Policy Count**: 30 policies
- **Effect**: Audit only
- **Managed Identity**: Optional
- **Scope**: Resource Group (rg-policy-keyvault-test)
- **Risk Level**: 🟢 Low

### Purpose & Use Cases
1. **Isolated Testing**: Test policies on specific resource group
2. **Limited Blast Radius**: Reduce testing scope
3. **Proof of Concept**: Demonstrate to specific team/project
4. **Gradual Rollout**: Deploy to one RG before subscription-wide

### Strategy
- Same 30 policies as Scenario 1
- Scoped to single resource group
- No subscription-wide impact
- Ideal for pilot deployments

### Deployment Command
```powershell
# Preview mode
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest.json `
    -ScopeType ResourceGroup `
    -ResourceGroupName "rg-policy-keyvault-test" `
    -Preview `
    -SkipRBACCheck

# Actual deployment
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest.json `
    -ScopeType ResourceGroup `
    -ResourceGroupName "rg-policy-keyvault-test" `
    -SkipRBACCheck
```

### Scope Comparison

| Scope Type | Resource Coverage | Use Case |
|------------|------------------|----------|
| Subscription | All Key Vaults in subscription | Standard deployment |
| Resource Group | Only vaults in specified RG | Limited testing |
| Management Group | All subscriptions in MG | Enterprise governance |

### Expected Outcomes
- ✅ 30 policy assignments (RG scope)
- ✅ Only affects Key Vaults in target resource group
- ✅ Other resource groups unaffected
- ✅ Test results isolated to one RG

---

## Scenario 8: Management Group Scope

### Overview
Organization-wide governance deployment across multiple subscriptions.

### Configuration
- **Parameter File**: `PolicyParameters-Production.json`
- **Policy Count**: 46 policies
- **Effect**: Audit only
- **Managed Identity**: Optional
- **Scope**: Management Group
- **Risk Level**: 🟡 Medium (org-wide impact)

### Purpose & Use Cases
1. **Enterprise Governance**: Apply policies across all subscriptions
2. **Centralized Management**: Single deployment point
3. **Consistent Standards**: Ensure all subs follow same rules
4. **Scalability**: Manage hundreds of subscriptions

### Strategy
- All 46 policies at management group level
- Inherited by all child subscriptions
- Production parameter values
- Requires management group permissions

### Prerequisites
- ✅ Management group structure created
- ✅ Policy Contributor role at management group
- ✅ Management Group ID obtained
- ✅ Stakeholder approval for org-wide deployment

### Deployment Command
```powershell
# Preview mode
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -ScopeType ManagementGroup `
    -ManagementGroupId "<YOUR-MG-ID>" `
    -Preview `
    -SkipRBACCheck

# Actual deployment
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -ScopeType ManagementGroup `
    -ManagementGroupId "<YOUR-MG-ID>" `
    -SkipRBACCheck
```

### Expected Outcomes
- ✅ 46 policy assignments at MG level
- ✅ Policies inherited by all child subscriptions
- 📊 Compliance visible across organization
- ⚠️ Longer evaluation time (more resources)

---

## Scenario 9: Rollback (Remove All Policies)

### Overview
Remove all Azure Policy assignments with "KV-" prefix.

### Configuration
- **Parameter File**: None
- **Policy Count**: All existing assignments
- **Effect**: Removal
- **Managed Identity**: Not used
- **Scope**: User-selected (Subscription/ResourceGroup/ManagementGroup)
- **Risk Level**: 🟢 Low (removes monitoring, not resources)

### Purpose & Use Cases
1. **Clean Up**: Remove test deployments
2. **Redeploy**: Clear before fresh deployment
3. **Troubleshooting**: Reset to clean state
4. **Environment Teardown**: Remove policies when decommissioning

### Strategy
- Identifies all assignments with "KV-" prefix
- Removes assignments in batches
- Does NOT delete resources
- Only removes policy monitoring

### Deployment Command
```powershell
# Preview mode (safe - shows what would be removed)
.\AzPolicyImplScript.ps1 -Rollback -Preview

# Actual rollback
.\AzPolicyImplScript.ps1 -Rollback
```

### Scope Selection
When prompted, choose scope:
- **Subscription**: Remove all KV-* assignments in current subscription
- **ResourceGroup**: Remove only from specific resource group
- **ManagementGroup**: Remove from management group (requires MG ID)

### Expected Outcomes
- ✅ All "KV-*" policy assignments removed
- ✅ Compliance data retained (historical)
- ✅ Resources unaffected
- ✅ Clean state for re-deployment

### Recovery
To re-deploy after rollback, run desired scenario again.

---

## Deployment Best Practices

### 1. Always Preview First
```powershell
# Add -Preview to any command for safe validation
.\AzPolicyImplScript.ps1 -ParameterFile <file> -Preview -SkipRBACCheck
```

### 2. Recommended Deployment Sequence

**For New Environments**:
1. Scenario 1 (DevTest Baseline) - validate infrastructure
2. Scenario 2 (DevTest Full) - understand all requirements
3. Scenario 3 (DevTest Auto-Remediation) - test managed identity
4. Scenario 4 (Production Audit) - establish baseline
5. Scenario 6 (Production Auto-Remediation) - enable auto-fix
6. Scenario 5 (Production Deny) - enforce compliance (optional)

**For Existing Environments**:
1. Scenario 4 (Production Audit) - 2-4 weeks monitoring
2. Scenario 6 (Production Auto-Remediation) - gradual enablement
3. Scenario 5 (Production Deny) - selective enforcement

### 3. Testing Matrix

| Scenario | Dev/Test | Staging | Production |
|----------|----------|---------|------------|
| 1-3 | ✅ Recommended | Optional | ❌ Skip |
| 4, 6 | Optional | ✅ Recommended | ✅ Recommended |
| 5 | ⚠️ Test only | ✅ Validate | ⚠️ Selective |
| 7 | ✅ PoC | ✅ Pilot | ❌ Skip |
| 8 | ❌ Skip | ❌ Skip | ✅ Enterprise only |

### 4. Monitoring & Validation

After each deployment:
```powershell
# Check compliance
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan

# Review HTML report
Get-ChildItem -Filter "ComplianceReport-*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
```

---

## Troubleshooting Guide

### Common Issues

**Issue**: Policy assignments created but no compliance data  
**Solution**: Wait 30-90 minutes for Azure evaluation cycle

**Issue**: Remediation tasks not created  
**Solution**: Verify managed identity has required RBAC roles

**Issue**: Deny mode blocking legitimate resources  
**Solution**: Create policy exemptions or adjust parameter values

**Issue**: Preview mode shows user input prompts  
**Solution**: Current known issue - provide input as requested

---

## Quick Command Reference

```powershell
# Scenario 1: DevTest Baseline
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -SkipRBACCheck

# Scenario 2: DevTest Full
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -SkipRBACCheck

# Scenario 3: DevTest Remediation
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json -IdentityResourceId "/subscriptions/<id>/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation" -SkipRBACCheck

# Scenario 4: Production Audit
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -SkipRBACCheck

# Scenario 5: Production Deny
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Deny.json -SkipRBACCheck

# Scenario 6: Production Remediation
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Remediation.json -IdentityResourceId "/subscriptions/<id>/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation" -SkipRBACCheck

# Scenario 7: Resource Group
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -ScopeType ResourceGroup -ResourceGroupName "rg-test" -SkipRBACCheck

# Scenario 8: Management Group
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -ScopeType ManagementGroup -ManagementGroupId "<mg-id>" -SkipRBACCheck

# Scenario 9: Rollback
.\AzPolicyImplScript.ps1 -Rollback
```

---

## Related Documentation

- [Policy Effect Compatibility Matrix](Policy-Effect-Compatibility-Matrix.md) - Which policies support Audit/Deny/DINE
- [PolicyParameters Quick Reference](PolicyParameters-QuickReference.md) - Parameter file selection
- [Azure KeyVault Policy Supported Effects](Azure-KeyVault-Policy-Supported-Effects.md) - Official effect reference
- [Deployment Prerequisites](DEPLOYMENT-PREREQUISITES.md) - Infrastructure setup
- [Test Validation Guide](Test-Validation-Fixes-Summary.md) - Testing framework
