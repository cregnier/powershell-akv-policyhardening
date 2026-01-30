# Azure Key Vault Policy Troubleshooting Guide
**Version**: 1.2.0  
**Last Updated**: January 30, 2026  

---

## Quick Reference: Common Issues & Solutions

| Issue | Quick Fix | Details Section |
|-------|-----------|----------------|
| Policy deployment fails | Verify managed identity permissions | [Deployment Errors](#deployment-errors) |
| WhatIf mode shows errors | Check RBAC permissions | [Permission Issues](#permission-issues) |
| Compliance scan returns no data | Trigger manual scan | [Compliance Issues](#compliance-issues) |
| Rollback doesn't remove all policies | Use wildcard pattern | [Rollback Issues](#rollback-issues) |
| Multi-subscription mode hangs | Reduce subscription count | [Performance Issues](#performance-issues) |

---

## Emergency Procedures

### Quick Rollback (Remove All Policies)
```powershell
# Option 1: Use built-in rollback
.\AzPolicyImplScript.ps1 -Rollback
# Removes all KV-* policy assignments
# Execution time: 3-5 minutes

# Option 2: Manual removal (specific policy)
Remove-AzPolicyAssignment -Name "KV-Secrets-Expiration-*" -Scope "/subscriptions/{sub-id}"

# Option 3: Disable without removing
Set-AzPolicyAssignment -Name "KV-*" -EnforcementMode DoNotEnforce
# Policies remain but don't evaluate (temporary pause)
```

### Emergency Exemption (Break-Glass)
```powershell
# Create 24-hour exemption for emergency Key Vault
.\AzPolicyImplScript.ps1 -CreateExemption `
    -ResourceId "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{vault}" `
    -PolicyAssignmentName "ALL" `
    -Reason "P1 incident: Critical app deployment" `
    -ExpiryDate (Get-Date).AddHours(24) `
    -TicketNumber "INC-12345"
```

---

## Deployment Errors

### Error: "Managed identity not found"
**Symptoms**:
```
ERROR: The managed identity '/subscriptions/.../id-policy-remediation' does not exist
```

**Cause**: Managed identity hasn't been created or incorrect resource ID

**Solution**:
```powershell
# Step 1: Verify managed identity exists
Get-AzUserAssignedIdentity -Name "id-policy-remediation" -ResourceGroupName "rg-policy-remediation"

# Step 2: If missing, create it
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 `
    -SubscriptionId "YOUR-SUB-ID" `
    -ResourceGroupName "rg-policy-remediation" `
    -Location "eastus"

# Step 3: Get correct resource ID
$identity = Get-AzUserAssignedIdentity -Name "id-policy-remediation" -ResourceGroupName "rg-policy-remediation"
$identityId = $identity.Id
Write-Host "Use this ID: $identityId"
```

---

### Error: "Policy assignment already exists"
**Symptoms**:
```
ERROR: Policy assignment 'KV-Secrets-Expiration-123456' already exists
```

**Cause**: Previous deployment wasn't fully removed

**Solution**:
```powershell
# Option 1: Remove existing assignment
Remove-AzPolicyAssignment -Name "KV-Secrets-Expiration-*"

# Option 2: Use -Force parameter (overwrites)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Audit `
    -Force

# Option 3: Full cleanup before redeployment
.\AzPolicyImplScript.ps1 -Rollback
Start-Sleep -Seconds 30  # Wait for Azure propagation
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -PolicyMode Audit
```

---

### Error: "Parameter file not found"
**Symptoms**:
```
ERROR: Cannot find path 'PolicyParameters.json'
```

**Cause**: Wrong parameter file name or path

**Solution**:
```powershell
# Verify file exists
Test-Path .\PolicyParameters-Production.json

# Use absolute path if relative doesn't work
.\AzPolicyImplScript.ps1 `
    -ParameterFile "C:\Source\powershell-akv-policyhardening\PolicyParameters-Production.json" `
    -PolicyMode Audit

# Check available parameter files
Get-ChildItem -Filter "PolicyParameters-*.json" | Select-Object Name
```

**Available Parameter Files**:
- `PolicyParameters-DevTest.json` - 12 basic policies
- `PolicyParameters-DevTest-Full.json` - 30 S/C/K policies (dev/test)
- `PolicyParameters-Production.json` - 30 S/C/K policies (Audit mode)
- `PolicyParameters-Production-Deny.json` - 22 Deny-capable policies
- `PolicyParameters-DevTest-Full-Remediation.json` - 8 DINE/Modify policies
- `PolicyParameters-Production-Remediation.json` - 8 DINE/Modify policies

---

### Error: "Effect parameter is invalid"
**Symptoms**:
```
ERROR: The effect 'Enforce' is not valid. Allowed values: Audit, Deny, Disabled
```

**Cause**: Trying to use "Enforce" instead of "DeployIfNotExists" or "Modify"

**Solution**:
```powershell
# For DeployIfNotExists/Modify policies, use remediation parameter file
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -IdentityResourceId $identityId

# For Audit/Deny policies, specify mode explicitly
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Audit  # or Deny
```

---

## Permission Issues

### Error: "Insufficient permissions to assign policies"
**Symptoms**:
```
ERROR: Authorization failed. User does not have permission to create policy assignments
```

**Cause**: Missing RBAC role assignment

**Solution**:
```powershell
# Check current permissions
Get-AzRoleAssignment -SignInName (Get-AzContext).Account

# Required roles (minimum):
# - Owner (at subscription scope)
# - Contributor + Resource Policy Contributor
# - User Access Administrator + Resource Policy Contributor

# Request role assignment from subscription owner:
# Role: "Resource Policy Contributor" or "Owner"
# Scope: Subscription level
```

**Workaround (temporary)**:
```powershell
# Use -SkipRBACCheck to bypass permission validation
# (Still requires actual permissions, just skips pre-flight check)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Audit `
    -SkipRBACCheck
```

---

### Error: "Managed identity lacks permissions"
**Symptoms**:
```
ERROR: Managed identity does not have Contributor permissions on subscription
```

**Cause**: Identity not assigned required RBAC roles for DINE/Modify policies

**Solution**:
```powershell
# Step 1: Get managed identity
$identity = Get-AzUserAssignedIdentity -Name "id-policy-remediation" -ResourceGroupName "rg-policy-remediation"

# Step 2: Assign Key Vault Contributor role at subscription scope
New-AzRoleAssignment `
    -ObjectId $identity.PrincipalId `
    -RoleDefinitionName "Key Vault Contributor" `
    -Scope "/subscriptions/YOUR-SUB-ID"

# Step 3: Wait 5 minutes for RBAC propagation
Start-Sleep -Seconds 300

# Step 4: Retry deployment
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -IdentityResourceId $identity.Id
```

---

## Compliance Issues

### Issue: Compliance scan returns no data
**Symptoms**: Compliance dashboard shows "No data" or 0% compliance

**Cause**: Policy evaluation hasn't run yet (takes 15-30 minutes)

**Solution**:
```powershell
# Option 1: Trigger on-demand scan
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan
# Wait 15-30 minutes for Azure to complete evaluation

# Option 2: Manual trigger via Azure CLI
az policy state trigger-scan --subscription YOUR-SUB-ID

# Option 3: Wait for automatic scan (every 24 hours)
# Check last evaluation time in Azure Portal
```

**Verification**:
```powershell
# Check if policies are assigned
Get-AzPolicyAssignment | Where-Object {$_.Name -like "KV-*"}

# Check compliance state
Get-AzPolicyState -SubscriptionId "YOUR-SUB-ID" -Top 10
```

---

### Issue: Compliance report shows "Compliant" for non-compliant resources
**Symptoms**: Report shows 100% compliant but you know resources are non-compliant

**Cause**: Policy scope doesn't include the resources

**Solution**:
```powershell
# Verify policy scope
Get-AzPolicyAssignment -Name "KV-Secrets-Expiration-*" | Select-Object Name, Scope

# Ensure policies deployed at subscription scope (not resource group)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Audit `
    -ScopeType Subscription  # NOT ResourceGroup
```

---

### Issue: HTML report generation fails
**Symptoms**:
```
ERROR: Unable to generate compliance report
```

**Cause**: Missing compliance data or template issues

**Solution**:
```powershell
# Step 1: Verify compliance data exists
$state = Get-AzPolicyState -SubscriptionId "YOUR-SUB-ID" -Top 1
if ($state) { Write-Host "Compliance data available" }

# Step 2: Regenerate report
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan

# Step 3: Check output directory
Get-ChildItem -Filter "ComplianceReport-*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
```

---

## Rollback Issues

### Issue: Rollback doesn't remove all policies
**Symptoms**: Some policies remain after running `-Rollback`

**Cause**: Policies deployed with different naming pattern or at different scopes

**Solution**:
```powershell
# Option 1: Manual cleanup with wildcard
Get-AzPolicyAssignment | Where-Object {$_.Name -like "*Key*Vault*"} | ForEach-Object {
    Write-Host "Removing: $($_.Name)"
    Remove-AzPolicyAssignment -Id $_.ResourceId
}

# Option 2: Remove by scope
Get-AzPolicyAssignment -Scope "/subscriptions/YOUR-SUB-ID" | 
    Where-Object {$_.Properties.DisplayName -like "*Key Vault*"} |
    Remove-AzPolicyAssignment

# Option 3: Nuclear option (remove ALL policy assignments)
# ⚠️ WARNING: This removes ALL policies, not just Key Vault
# Get-AzPolicyAssignment | Remove-AzPolicyAssignment -Confirm:$false
```

---

### Issue: Rollback fails with "Policy assignment is locked"
**Symptoms**:
```
ERROR: Cannot delete policy assignment. Resource is locked.
```

**Cause**: Azure resource lock preventing deletion

**Solution**:
```powershell
# Step 1: Find locks
Get-AzResourceLock -Scope "/subscriptions/YOUR-SUB-ID"

# Step 2: Remove lock temporarily
Remove-AzResourceLock -LockName "DoNotDelete" -ResourceGroupName "rg-policy-remediation"

# Step 3: Rollback policies
.\AzPolicyImplScript.ps1 -Rollback

# Step 4: Restore lock (if needed)
New-AzResourceLock -LockLevel CanNotDelete -LockName "DoNotDelete" -Scope "/subscriptions/YOUR-SUB-ID"
```

---

## Performance Issues

### Issue: Multi-subscription deployment takes too long
**Symptoms**: Script hangs or takes >2 hours for 838 subscriptions

**Cause**: Sequential deployment across all subscriptions

**Solution**:
```powershell
# Option 1: Deploy to single subscription first
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Audit `
    -ScopeType Subscription `
    -SubscriptionId "SINGLE-SUB-ID"

# Option 2: Use parallel processing (if available in your version)
# Check if script supports -Parallel parameter

# Option 3: Deploy in batches
# Batch 1: Critical subscriptions
# Batch 2: Dev/Test subscriptions
# Batch 3: Remaining subscriptions
```

---

### Issue: Compliance scan timeout
**Symptoms**: Script times out waiting for compliance data

**Cause**: Azure backend slow to evaluate policies

**Solution**:
```powershell
# Don't wait for scan to complete
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -NoWait

# Check status later (manually in Azure Portal)
# Or run compliance check separately:
.\AzPolicyImplScript.ps1 -CheckCompliance
```

---

## Azure-Specific Issues

### Error: "Subscription not found"
**Symptoms**:
```
ERROR: The subscription 'xxx' could not be found
```

**Cause**: Not connected to Azure or wrong subscription context

**Solution**:
```powershell
# Step 1: Verify Azure connection
Get-AzContext

# Step 2: If not connected, login
Connect-AzAccount

# Step 3: Set correct subscription
Set-AzContext -SubscriptionId "YOUR-SUB-ID"

# Step 4: Verify access to 838 subscriptions
Get-AzSubscription | Measure-Object
# Expected: Count = 838 (for AAD account)
```

---

### Error: "Policy definition not found"
**Symptoms**:
```
ERROR: Policy definition 'Microsoft.KeyVault/vaults/secrets/expiration' not found
```

**Cause**: Using old policy definition IDs or incorrect namespace

**Solution**:
```powershell
# Verify correct policy definition exists
Get-AzPolicyDefinition -Name "YOUR-POLICY-ID"

# Check DefinitionListExport.csv for correct policy IDs
Import-Csv .\DefinitionListExport.csv | Where-Object {$_.DisplayName -like "*secret*expir*"}

# Use PolicyNameMapping.json for accurate mapping
$mapping = Get-Content .\PolicyNameMapping.json | ConvertFrom-Json
$policyId = $mapping."Secrets should have an expiration date"
```

---

### Error: "Azure Policy quota exceeded"
**Symptoms**:
```
ERROR: Policy assignment quota exceeded. Maximum 100 assignments per subscription.
```

**Cause**: Too many policy assignments at subscription scope

**Solution**:
```powershell
# Check current policy count
(Get-AzPolicyAssignment -Scope "/subscriptions/YOUR-SUB-ID").Count

# Option 1: Remove unused policies
Get-AzPolicyAssignment | Where-Object {$_.Properties.EnforcementMode -eq 'DoNotEnforce'} | Remove-AzPolicyAssignment

# Option 2: Use policy initiatives (bundles multiple policies into one assignment)
# This is a design change - contact Azure support for guidance

# Option 3: Deploy at management group level (if available)
# Reduces per-subscription assignment count
```

---

## WhatIf Mode Issues

### Issue: WhatIf shows "0 policies would be deployed"
**Symptoms**: WhatIf mode reports no changes

**Cause**: Policies already deployed or parameter file mismatch

**Solution**:
```powershell
# Step 1: Check if policies already exist
Get-AzPolicyAssignment | Where-Object {$_.Name -like "KV-*"}

# Step 2: Verify parameter file
Test-Path .\PolicyParameters-Production.json
Get-Content .\PolicyParameters-Production.json | Select-String "effect"

# Step 3: Run WhatIf with verbose output
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Audit `
    -WhatIf `
    -Verbose
```

---

### Issue: WhatIf CSV report shows placeholder data
**Symptoms**: WhatIfReport.csv contains "SAMPLE DATA" instead of actual policies

**Cause**: Known v1.2.0 cosmetic issue (doesn't affect actual deployment)

**Solution**:
```powershell
# This is cosmetic only - actual deployment works fine
# Verify deployment plan from console output instead of CSV

# Or generate report after deployment (not during WhatIf)
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan
# Output: ComplianceReport-YYYYMMDD-HHMMSS.html (actual data)
```

---

## Multi-Subscription Mode Issues

### Issue: Multi-sub mode shows wrong subscription count
**Symptoms**: Script shows "2 subscriptions" instead of 838

**Cause**: Known v1.2.0 cosmetic display issue (doesn't affect deployment)

**Solution**:
```powershell
# This is display-only issue - actual deployment covers all subscriptions
# Verify subscription coverage after deployment:
Get-AzPolicyAssignment -Scope "/subscriptions/YOUR-SUB-ID" | 
    Where-Object {$_.Name -like "KV-*"} |
    Select-Object Name, Scope
```

---

## Testing & Validation Issues

### Issue: Test infrastructure validation fails
**Symptoms**:
```
❌ FAILED: Log Analytics workspace not found
```

**Cause**: Prerequisites not deployed

**Solution**:
```powershell
# Run infrastructure setup first
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 `
    -SubscriptionId "YOUR-SUB-ID" `
    -ResourceGroupName "rg-policy-remediation" `
    -Location "eastus"

# Wait 2-3 minutes for resources to provision

# Retry validation
.\AzPolicyImplScript.ps1 -TestInfrastructure -Detailed
```

---

### Issue: Auto-remediation test times out
**Symptoms**: Test waits 60+ minutes with no results

**Cause**: Azure Policy evaluation takes 30-60 minutes (cannot be accelerated)

**Solution**:
```powershell
# This is expected - Azure backend controls evaluation timing
# Options:
# 1. Wait (30-60 minutes required)
# 2. Skip auto-remediation test for now:
.\AzPolicyImplScript.ps1 -TestProductionEnforcement
# 3. Run test overnight (long-running)
```

---

## Logging & Diagnostics

### Enable Verbose Logging
```powershell
# Maximum verbosity for troubleshooting
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Audit `
    -Verbose `
    -Debug `
    -ErrorAction Continue

# Redirect output to file
.\AzPolicyImplScript.ps1 ... 2>&1 | Tee-Object -FilePath "deployment-log.txt"
```

### Check Azure Activity Log
```powershell
# View recent policy operations
Get-AzLog -StartTime (Get-Date).AddHours(-2) | 
    Where-Object {$_.ResourceType -like "*policy*"} |
    Select-Object EventTimestamp, OperationName, Status, SubStatus

# Export to CSV for analysis
Get-AzLog -StartTime (Get-Date).AddHours(-2) | 
    Export-Csv "azure-activity-log.csv" -NoTypeInformation
```

---

## Getting Help

### Internal Support
- **Cloud Brokers Team**: [Your team contact]
- **Azure Policy SME**: [SME name/contact]
- **On-Call Support**: [24/7 contact if deployed]

### Microsoft Support
- Azure Policy Documentation: https://learn.microsoft.com/azure/governance/policy/
- Azure Support Ticket: Portal → Help + Support → New support request
- Category: "Governance" → "Azure Policy"

### Community Resources
- Azure Policy GitHub: https://github.com/Azure/azure-policy
- Q&A Forum: https://learn.microsoft.com/answers/tags/33/azure-policy

---

## Known Issues (v1.2.0)

### Cosmetic Issues (No Impact on Functionality)
1. **Multi-subscription display**: Shows "2 subscriptions" instead of actual count
   - **Impact**: Display only - all subscriptions are deployed correctly
   - **Workaround**: Ignore display, verify post-deployment

2. **WhatIf CSV placeholder data**: WhatIfReport.csv contains sample data
   - **Impact**: CSV report inaccurate in WhatIf mode only
   - **Workaround**: Use console output instead of CSV

3. **Progress bar inaccurate**: May show 100% before completion
   - **Impact**: Visual only - deployment completes correctly
   - **Workaround**: Monitor console log messages

### Pending Fixes (v1.2.1)
- Multi-subscription mode display (cosmetic)
- WhatIf CSV report generation (cosmetic)
- MSA account RBAC workaround documentation

---

## Diagnostic Checklist

Before opening support ticket, collect:
- [ ] PowerShell version: `$PSVersionTable.PSVersion`
- [ ] Azure PowerShell version: `Get-Module Az -ListAvailable | Select-Object Version`
- [ ] Script version: `v1.2.0` (from script header)
- [ ] Parameter file used: `PolicyParameters-Production.json`
- [ ] Error message (full text)
- [ ] Screenshot of error (if applicable)
- [ ] Azure subscription ID
- [ ] Deployment timestamp
- [ ] Console output (last 50 lines)

**Collect Script Output**:
```powershell
# Run with full logging
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -PolicyMode Audit `
    -Verbose 2>&1 | Tee-Object -FilePath "troubleshooting-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
```

---

**Document Version**: 1.0  
**Last Updated**: January 30, 2026  
**Applies to**: AzPolicyImplScript.ps1 v1.2.0
