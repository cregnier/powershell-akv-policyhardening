# Environment Configuration Guide

## Overview

This guide explains how to use the dev/test and production environment configurations to safely manage Azure Key Vault policy deployments across different environments.

## Configuration Files

### 1. **PolicyParameters-DevTest.json** (Development/Testing)

**Purpose**: Relaxed parameters for rapid iteration, testing, and validation without blocking resource creation.

**Characteristics**:
- ✅ **All Audit mode** - No resource blocking
- 📅 **Longer validity periods** - 36 months for certs, 1095 days (3 years) for keys/secrets
- 🔍 **Lower retention requirements** - 30 days for diagnostic logs
- 🔑 **Relaxed key sizes** - 2048-bit RSA minimum
- ⚠️ **Shorter expiration warnings** - 30 days notice

**Use Cases**:
- Initial policy testing and validation
- Learning policy behavior
- Proof-of-concept deployments
- CI/CD pipeline testing
- Development subscriptions
- Non-production resource groups

---

### 2. **PolicyParameters-Production.json** (Production)

**Purpose**: Strict security parameters with enforcement for critical policies to maintain production security standards.

**Characteristics**:
- 🛑 **Deny mode for critical policies** - Blocks non-compliant resource creation/modification
- 📅 **Shorter validity periods** - 12 months for certs, 365 days (1 year) for keys/secrets
- 📊 **Longer retention requirements** - 365 days for diagnostic logs
- 🔑 **Stricter key sizes** - 4096-bit RSA minimum
- ⚠️ **Longer expiration warnings** - 90 days notice

**Critical Policies with Deny Effect**:
1. ❌ Key vaults should have soft delete enabled
2. ❌ Key vaults should have deletion protection enabled
3. ❌ Azure Key Vault should disable public network access
4. ❌ Azure Key Vault should have firewall enabled
5. ❌ Azure Key Vault Managed HSM should have purge protection enabled
6. ❌ Key Vault secrets should have an expiration date
7. ❌ Key Vault keys should have an expiration date
8. ❌ Keys/Certs using RSA cryptography should have minimum key size (4096)
9. ❌ Resource logs in Key Vault should be enabled

**Use Cases**:
- Production subscriptions
- Compliance-sensitive environments
- Security-hardened deployments
- Post-validation enforcement

---

### 3. **PolicyParameters.json** (Custom/Legacy)

**Purpose**: Custom configuration with full control over all parameters.

**Use Cases**:
- Advanced users with specific requirements
- Hybrid configurations (some Audit, some Deny)
- Organization-specific parameter values
- Backwards compatibility with existing scripts

---

## Environment Detection

The script automatically detects the environment based on the parameter file name:

```powershell
EnvironmentPreset = if ($ParameterOverridesPath -like '*DevTest*') { 
    'Development/Test' 
} elseif ($ParameterOverridesPath -like '*Production*') { 
    'Production' 
} else { 
    'Custom' 
}
```

This metadata is included in compliance reports and execution logs.

---

## Usage Examples

### Interactive Menu Selection

When running the script interactively, you'll be prompted to choose an environment:

```powershell
.\AzPolicyImplScript.ps1
```

**Menu Output**:
```
Choose environment preset:
  1) Dev/Test  - Relaxed parameters, all Audit mode, longer validity periods
  2) Production - Strict parameters, critical policies Deny, shorter validity periods
  3) Custom    - Use existing PolicyParameters.json

Select environment [1-3]: 
```

---

### Non-Interactive Execution

#### Dev/Test Deployment

```powershell
# Test in dev/test resource group (recommended first step)
.\AzPolicyImplScript.ps1 `
    -PolicyMode Audit `
    -ScopeType ResourceGroup `
    -ResourceGroupName "rg-policy-keyvault-test" `
    -ParameterOverridesPath "./PolicyParameters-DevTest.json" `
    -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# Test at subscription scope (Audit mode only)
.\AzPolicyImplScript.ps1 `
    -PolicyMode Audit `
    -ScopeType Subscription `
    -ParameterOverridesPath "./PolicyParameters-DevTest.json" `
    -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

#### Production Deployment (Phased Approach)

**Phase 1: Audit Mode First**
```powershell
# Deploy production parameters in Audit mode first
.\AzPolicyImplScript.ps1 `
    -PolicyMode Audit `
    -ScopeType Subscription `
    -ParameterOverridesPath "./PolicyParameters-Production.json" `
    -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# Wait 24-48 hours, review compliance reports
# Remediate non-compliant resources
```

**Phase 2: Deny Mode (After Validation)**
```powershell
# Enable Deny enforcement for production
.\AzPolicyImplScript.ps1 `
    -PolicyMode Deny `
    -ScopeType Subscription `
    -ParameterOverridesPath "./PolicyParameters-Production.json" `
    -IdentityResourceId "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation" `
    -Confirm:$true
```

---

## Production Safeguards

### Built-in Safeguards

The script includes these safeguards when using production configurations:

1. **Environment Detection**: Automatically identifies Production preset
2. **Metadata Tracking**: Records environment preset in compliance reports
3. **Audit-First Approach**: Recommends Audit mode before Deny enforcement
4. **Manual Confirmation**: PowerShell `-Confirm` parameter for Deny deployments

### Recommended Additional Safeguards

#### 1. **WhatIf Validation** (Not yet implemented)

Test deployment without making changes:

```powershell
# Proposed enhancement
.\AzPolicyImplScript.ps1 `
    -PolicyMode Deny `
    -ParameterOverridesPath "./PolicyParameters-Production.json" `
    -WhatIf
```

#### 2. **Approval Workflow** (For CI/CD)

Require manual approval gates in Azure DevOps/GitHub Actions:

```yaml
# Azure DevOps YAML example
stages:
- stage: DeployProduction
  jobs:
  - deployment: DeployPolicies
    environment: 'Production'  # Requires manual approval
    strategy:
      runOnce:
        deploy:
          steps:
          - task: AzurePowerShell@5
            inputs:
              ScriptPath: './AzPolicyImplScript.ps1'
              ScriptArguments: '-PolicyMode Deny -ParameterOverridesPath "./PolicyParameters-Production.json"'
```

#### 3. **Subscription Lock Check**

Verify target subscription before deployment:

```powershell
# Check subscription before running script
$currentSub = (Get-AzContext).Subscription.Id
$productionSub = "ab1336c7-687d-4107-b0f6-9649a0458adb"

if ($currentSub -eq $productionSub) {
    Write-Host "⚠️ WARNING: Deploying to PRODUCTION subscription" -ForegroundColor Red
    $confirm = Read-Host "Type 'CONFIRM' to proceed"
    if ($confirm -ne 'CONFIRM') {
        Write-Host "❌ Deployment cancelled" -ForegroundColor Red
        exit
    }
}

.\AzPolicyImplScript.ps1 -ParameterOverridesPath "./PolicyParameters-Production.json"
```

#### 4. **Parameter File Validation**

Validate parameter file before deployment:

```powershell
# Verify production parameters are loaded correctly
$params = Get-Content "./PolicyParameters-Production.json" | ConvertFrom-Json
$denyCount = ($params.PSObject.Properties | Where-Object { $_.Value.effect -eq 'Deny' }).Count
Write-Host "Production configuration will enforce $denyCount policies with Deny effect" -ForegroundColor Yellow
```

---

## Configuration Comparison

| Aspect | Dev/Test | Production | Custom |
|--------|----------|------------|--------|
| **Primary Effect** | Audit | Deny (critical)<br>Audit (informational) | User-defined |
| **Cert Validity** | 36 months | 12 months | User-defined |
| **Key/Secret Validity** | 1095 days (3 years) | 365 days (1 year) | User-defined |
| **Expiration Warning** | 30 days | 90 days | User-defined |
| **RSA Key Size** | 2048-bit | 4096-bit | User-defined |
| **Log Retention** | 30 days | 365 days | User-defined |
| **Rotation Policy** | 180 days | 90 days | User-defined |
| **Resource Blocking** | ❌ None | ✅ 9 critical policies | User-defined |
| **Recommended Scope** | Resource Group<br>Non-prod Subscription | Production Subscription<br>(after Audit phase) | Any |

---

## Migration Path: Dev/Test → Production

### Phase 1: Test in Dev/Test Environment (Week 1)

```powershell
# Step 1: Deploy to test resource group
.\AzPolicyImplScript.ps1 `
    -PolicyMode Audit `
    -ScopeType ResourceGroup `
    -ResourceGroupName "rg-policy-keyvault-test" `
    -ParameterOverridesPath "./PolicyParameters-DevTest.json"

# Step 2: Review compliance, test remediation
# Step 3: Validate HTML reports, exemption process
```

### Phase 2: Production Audit Mode (Week 2-3)

```powershell
# Step 1: Deploy production parameters in Audit mode
.\AzPolicyImplScript.ps1 `
    -PolicyMode Audit `
    -ScopeType Subscription `
    -ParameterOverridesPath "./PolicyParameters-Production.json"

# Step 2: Wait 24-48 hours for initial compliance scan
# Step 3: Review compliance reports
# Step 4: Remediate non-compliant resources
# Step 5: Communicate with stakeholders
```

### Phase 3: Production Deny Mode (Week 4+)

```powershell
# Step 1: Final validation of compliance percentages
# Step 2: Get stakeholder sign-off
# Step 3: Enable Deny enforcement
.\AzPolicyImplScript.ps1 `
    -PolicyMode Deny `
    -ScopeType Subscription `
    -ParameterOverridesPath "./PolicyParameters-Production.json"

# Step 4: Monitor Azure Activity Log for policy denials
# Step 5: Process exemption requests
```

---

## Troubleshooting

### Issue: Accidentally deployed production config to dev/test subscription

**Solution**: Update assignments back to Audit mode

```powershell
# Redeploy with Audit mode
.\AzPolicyImplScript.ps1 `
    -PolicyMode Audit `
    -ScopeType Subscription `
    -ParameterOverridesPath "./PolicyParameters-DevTest.json"
```

### Issue: Production parameters too strict for current environment

**Solution**: Create intermediate configuration

1. Copy `PolicyParameters-Production.json` to `PolicyParameters-Staging.json`
2. Adjust specific parameters (e.g., change some Deny → Audit)
3. Update menu in script to include "Staging" option

### Issue: Need to test specific Deny policy behavior without full production config

**Solution**: Use custom parameter file with selective Deny

```json
{
  "_comment": "Test specific Deny policy",
  "Key vaults should have soft delete enabled": {
    "effect": "Deny"
  }
  // All other policies remain Audit
}
```

---

## Best Practices

### ✅ DO:

- **Start with Dev/Test** parameters in non-production environments
- **Test in Audit mode first**, even with production parameters
- **Review compliance reports** before enabling Deny enforcement
- **Communicate changes** to stakeholders before production Deny deployment
- **Document exemptions** using the exemption process (see EXEMPTION_PROCESS.md)
- **Use version control** for parameter file changes
- **Create backups** before modifying parameter files

### ❌ DON'T:

- **Don't deploy Deny mode** to production without prior Audit phase
- **Don't skip compliance review** between Audit and Deny phases
- **Don't modify parameter files** without testing changes first
- **Don't deploy production config** to dev/test subscriptions (creates unnecessary restrictions)
- **Don't bypass manual confirmation** for production Deny deployments

---

## Security Considerations

### Parameter File Protection

Parameter files should be:
- ✅ Stored in version control (Git)
- ✅ Reviewed through pull request process
- ✅ Protected with branch policies (require approvals)
- ❌ Not modified directly on production systems

### Least Privilege

When using production configurations:
- Use managed identities with minimum required permissions
- Separate read-only compliance scanning from policy deployment
- Audit changes to policy assignments using Azure Activity Log

### Change Management

For production deployments:
1. Document change in change management system
2. Get approval from security team
3. Schedule during maintenance window
4. Have rollback plan ready
5. Monitor for 24 hours post-deployment

---

## Related Documentation

- [RBAC-Configuration-Guide.md](RBAC-Configuration-Guide.md) - RBAC permissions and automation
- [Pre-Deployment-Audit-Checklist.md](Pre-Deployment-Audit-Checklist.md) - Pre-deployment validation
- [ProductionRolloutPlan.md](ProductionRolloutPlan.md) - Phased production rollout strategy
- [EXEMPTION_PROCESS.md](EXEMPTION_PROCESS.md) - Policy exemption procedures
- [Policy-Validation-Matrix.md](Policy-Validation-Matrix.md) - Complete policy validation

---

## Summary

The environment configuration framework provides:

- **Safety**: Prevents accidental production enforcement through phased approach
- **Flexibility**: Three configuration options (Dev/Test, Production, Custom)
- **Traceability**: Automatic environment detection and metadata tracking
- **Best Practices**: Built-in safeguards and recommended workflows

**Recommended Workflow**: Dev/Test (Audit) → Production (Audit) → Production (Deny)

This ensures policies are validated at each stage before enforcement.
