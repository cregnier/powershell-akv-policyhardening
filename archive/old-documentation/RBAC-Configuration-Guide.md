# RBAC Configuration Guide for Azure Policy Implementation

## Overview

This guide explains the RBAC (Role-Based Access Control) requirements for deploying and managing Azure Policies using `AzPolicyImplScript.ps1`, including when and how to use the `-SkipRBACCheck` parameter.

---

## Required RBAC Roles

To deploy, manage, and remediate Azure Policies, you need **one of the following roles** at the target scope:

| Role | Capabilities | Recommended For |
|------|-------------|-----------------|
| **Owner** | Full access to all resources, including policy assignment and role assignments | Production environments, initial setup |
| **Policy Contributor** | Manage policy definitions and assignments | Policy governance teams |
| **Contributor** | Manage all resources except role assignments | Limited policy deployments (cannot assign managed identities for auto-remediation) |

### Scope Hierarchy

Roles can be assigned at different scopes (inherited from parent to child):

```
Management Group
  └── Subscription
        └── Resource Group
              └── Individual Resources
```

**Best Practice**: Assign Policy Contributor role at the **subscription level** for centralized policy governance.

---

## RBAC Check Behavior

### Default Behavior (RBAC Check Enabled)

By default, `AzPolicyImplScript.ps1` **validates your permissions** before deploying policies:

```powershell
# Default: RBAC check is performed
.\AzPolicyImplScript.ps1 -PolicyMode Audit -ScopeType Subscription
```

**What happens:**
1. ✅ Script queries your role assignments at the target scope
2. ✅ Verifies you have Owner, Policy Contributor, or Contributor role
3. ✅ If missing permissions, displays a **role request template** and exits
4. ✅ If permissions are valid, proceeds with deployment

**Output if missing permissions:**
```
[ERROR] Insufficient RBAC to continue. Resolve RBAC and re-run.
----- ROLE REQUEST TEMPLATE START -----
Please grant the following RBAC role to user@contoso.com on scope /subscriptions/abc123:
 - Role: Policy Contributor (or Owner)
Reason: Needed to assign and manage Azure Policy for Key Vault governance and compliance evaluations.
Requested-by: user@contoso.com
Contact: security-team@contoso.com
----- ROLE REQUEST TEMPLATE END -----
```

### Skip RBAC Check (`-SkipRBACCheck`)

Use this switch to **bypass pre-deployment permission validation**:

```powershell
# Skip RBAC check (use only when permissions are pre-verified)
.\AzPolicyImplScript.ps1 -PolicyMode Audit -ScopeType Subscription -SkipRBACCheck
```

**What happens:**
1. ⚠️ Script does NOT query role assignments
2. ⚠️ Proceeds directly to policy deployment
3. ⚠️ If permissions are actually missing, Azure API calls will fail with RBAC errors

---

## When to Use `-SkipRBACCheck`

### ✅ **Recommended Scenarios**

| Scenario | Why It's Safe | Example |
|----------|---------------|---------|
| **CI/CD Pipelines** | Service principal/managed identity permissions are pre-configured and tested | `az account show` confirms correct identity before deployment |
| **Automated Testing** | Test environment with known RBAC configuration | Dedicated test subscription with Owner role on automation account |
| **Repeated Runs** | You've already confirmed permissions in a previous run | Running compliance checks hourly on the same subscription |
| **Non-Interactive Execution** | Scheduled tasks, Azure Automation runbooks | Azure DevOps pipeline job with managed identity |
| **Performance Optimization** | Large-scale deployments where RBAC checks add overhead | Deploying to 50+ subscriptions via PowerShell loop |

### ❌ **NOT Recommended Scenarios**

| Scenario | Risk | Better Approach |
|----------|------|-----------------|
| **First-Time Deployment** | May waste time debugging RBAC errors instead of getting clear guidance | Run with default RBAC check to validate permissions upfront |
| **Production Environments** | Skipping checks bypasses audit trail for governance | Always validate permissions explicitly for compliance |
| **Unknown RBAC Status** | Unclear if you have correct roles assigned | Let script verify and show role request template if needed |
| **Multi-Tenant/Multi-Subscription** | Easy to accidentally target wrong scope with wrong identity | RBAC check confirms correct identity and permissions |

---

## Automation Examples

### Example 1: Azure DevOps Pipeline (Recommended)

```yaml
steps:
- task: AzurePowerShell@5
  inputs:
    azureSubscription: 'MyServiceConnection'
    ScriptType: 'FilePath'
    ScriptPath: './AzPolicyImplScript.ps1'
    ScriptArguments: '-PolicyMode Audit -ScopeType Subscription -SkipRBACCheck -IdentityResourceId "/subscriptions/abc123/resourceGroups/rg-policy/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy"'
    azurePowerShellVersion: 'LatestVersion'
```

**Why `-SkipRBACCheck` is safe:**
- Service connection has pre-configured Contributor role at subscription scope
- Pipeline validates identity before running script
- Reduces execution time by ~5-10 seconds (no RBAC API calls)

### Example 2: GitHub Actions (Recommended)

```yaml
- name: Deploy Azure Policies
  uses: azure/powershell@v1
  with:
    inlineScript: |
      ./AzPolicyImplScript.ps1 `
        -PolicyMode Audit `
        -ScopeType Subscription `
        -SkipRBACCheck `
        -IdentityResourceId "${{ secrets.MANAGED_IDENTITY_ID }}"
    azPSVersion: "latest"
```

**Why `-SkipRBACCheck` is safe:**
- GitHub OIDC authentication with pre-configured federated identity
- Managed identity has Policy Contributor role (verified in previous workflow step)
- Non-interactive execution (no human to review RBAC prompt)

### Example 3: Azure Automation Runbook (Recommended)

```powershell
# Azure Automation Runbook
param()

# Connect using system-assigned managed identity
Connect-AzAccount -Identity

# Deploy policies (skip RBAC check - managed identity has pre-configured Policy Contributor role)
./AzPolicyImplScript.ps1 `
    -PolicyMode Audit `
    -ScopeType Subscription `
    -SkipRBACCheck `
    -IdentityResourceId "/subscriptions/abc123/resourceGroups/rg-policy/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"
```

**Why `-SkipRBACCheck` is safe:**
- System-assigned managed identity has been granted Policy Contributor role via ARM template
- Runbook runs on schedule (weekly compliance scans)
- RBAC check adds unnecessary overhead for scheduled automation

### Example 4: Local Testing (Safe After Initial Verification)

```powershell
# First run: Validate permissions
.\AzPolicyImplScript.ps1 -PolicyMode Audit -ScopeType ResourceGroup

# Output:
# [INFO] Found role Policy Contributor for user@contoso.com
# ✅ Permissions validated

# Subsequent runs: Skip RBAC check for faster execution
.\AzPolicyImplScript.ps1 -PolicyMode Audit -ScopeType ResourceGroup -SkipRBACCheck
```

---

## Granting RBAC Permissions

### Option 1: Azure Portal (GUI)

1. Navigate to **Subscriptions** → Select subscription → **Access control (IAM)**
2. Click **+ Add** → **Add role assignment**
3. Select **Policy Contributor** role
4. Click **Next** → Select user/group/service principal
5. Click **Review + assign**

### Option 2: Azure CLI

```bash
# Grant Policy Contributor at subscription scope
az role assignment create \
  --assignee user@contoso.com \
  --role "Policy Contributor" \
  --scope "/subscriptions/abc123-def456-789"

# Grant Owner at resource group scope
az role assignment create \
  --assignee user@contoso.com \
  --role "Owner" \
  --scope "/subscriptions/abc123-def456-789/resourceGroups/rg-policy-test"
```

### Option 3: Azure PowerShell

```powershell
# Grant Policy Contributor at subscription scope
$subId = "abc123-def456-789"
$scope = "/subscriptions/$subId"
New-AzRoleAssignment `
    -SignInName "user@contoso.com" `
    -RoleDefinitionName "Policy Contributor" `
    -Scope $scope

# Grant Owner at management group scope (for enterprise-wide governance)
$mgScope = "/providers/Microsoft.Management/managementGroups/mg-prod"
New-AzRoleAssignment `
    -SignInName "user@contoso.com" `
    -RoleDefinitionName "Owner" `
    -Scope $mgScope
```

### Option 4: Managed Identity (For Auto-Remediation)

```powershell
# Create managed identity
$identity = New-AzUserAssignedIdentity `
    -ResourceGroupName "rg-policy-infra" `
    -Name "id-policy-remediation" `
    -Location "eastus"

# Grant Contributor role for auto-remediation (required for DeployIfNotExists/Modify policies)
New-AzRoleAssignment `
    -ObjectId $identity.PrincipalId `
    -RoleDefinitionName "Contributor" `
    -Scope "/subscriptions/$subId"

# Use in script
.\AzPolicyImplScript.ps1 `
    -PolicyMode Enforce `
    -ScopeType Subscription `
    -IdentityResourceId $identity.Id `
    -SkipRBACCheck  # Safe: Pipeline pre-validates managed identity permissions
```

---

## Troubleshooting RBAC Issues

### Error: "Insufficient RBAC to continue"

**Symptom:**
```
[ERROR] Insufficient RBAC to continue. Resolve RBAC and re-run.
```

**Solution:**
1. Run without `-SkipRBACCheck` to see role request template
2. Request Policy Contributor or Owner role from Azure admin
3. Verify role assignment:
   ```powershell
   Get-AzRoleAssignment -SignInName "user@contoso.com" -Scope "/subscriptions/$subId"
   ```

### Error: "AuthorizationFailed" (when using `-SkipRBACCheck`)

**Symptom:**
```
New-AzPolicyAssignment: The client 'user@contoso.com' with object id 'xyz' does not have authorization to perform action 'Microsoft.Authorization/policyAssignments/write'
```

**Solution:**
1. **Remove** `-SkipRBACCheck` from command
2. Let script validate permissions and show role request template
3. Grant required role (Owner or Policy Contributor)
4. Re-run script

### Error: "Role assignment exists but script still fails"

**Symptom:**
```
Get-AzRoleAssignment shows "Policy Contributor" but script fails with authorization error
```

**Solution:**
Role assignments can take **5-10 minutes** to propagate. Wait and retry.

---

## Security Best Practices

### 1. Principle of Least Privilege

Grant **minimum required role** at **narrowest scope**:

| Deployment Scope | Recommended Role | Why |
|------------------|------------------|-----|
| **Testing/Dev** | Policy Contributor at Resource Group | Limits blast radius, prevents accidental production changes |
| **Production** | Policy Contributor at Subscription | Centralized governance, audit trail |
| **Enterprise** | Policy Contributor at Management Group | Inherited to all child subscriptions |

### 2. Use Managed Identities for Automation

❌ **Bad**: Store service principal credentials in pipeline variables
```yaml
# AVOID THIS
- script: |
    az login --service-principal -u $APP_ID -p $PASSWORD --tenant $TENANT
    ./AzPolicyImplScript.ps1 -SkipRBACCheck
```

✅ **Good**: Use Azure DevOps service connection with managed identity
```yaml
# RECOMMENDED
- task: AzurePowerShell@5
  inputs:
    azureSubscription: 'MyServiceConnection'  # Federated credential, no secrets
    ScriptPath: './AzPolicyImplScript.ps1'
    ScriptArguments: '-SkipRBACCheck'
```

### 3. Audit RBAC Changes

Enable Azure Activity Log alerts for role assignments:

```powershell
# Create alert rule for role assignment changes
$actionGroup = Get-AzActionGroup -ResourceGroupName "rg-monitoring" -Name "SecurityTeam"
$condition = New-AzActivityLogAlertCondition -Field "category" -Equals "Administrative"
New-AzActivityLogAlert `
    -ResourceGroupName "rg-monitoring" `
    -Name "RoleAssignmentChanges" `
    -Condition $condition `
    -ActionGroup $actionGroup.Id
```

---

## Summary

### ✅ Use `-SkipRBACCheck` When:
- Running in **CI/CD pipelines** with pre-configured service principals/managed identities
- **Automated/scheduled tasks** where RBAC is validated separately
- **Repeated runs** where permissions were already verified
- **Performance** is critical (large-scale deployments)

### ❌ Do NOT Use `-SkipRBACCheck` When:
- **First-time deployment** on new subscription/scope
- **Production environments** requiring governance audit trail
- **Uncertain about RBAC** assignments
- **Interactive deployments** where human can review role request template

### Default Recommendation:
**Always start without `-SkipRBACCheck`**. Only add it after confirming permissions are valid, especially for automation scenarios.

---

## Related Documentation

- [Pre-Deployment-Audit-Checklist.md](./Pre-Deployment-Audit-Checklist.md) - Comprehensive audit procedures before deployment
- [KeyVault-Policy-Enforcement-FAQ.md](./KeyVault-Policy-Enforcement-FAQ.md) - Common questions about policy enforcement
- [README.md](./README.md) - Main documentation and usage examples

---

**Last Updated**: January 14, 2026  
**Script Version**: 0.1.0
