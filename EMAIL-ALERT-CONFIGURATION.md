# Azure Key Vault Policy Governance - Email Alert Configuration Guide

**Version**: 1.0  
**Last Updated**: January 20, 2026  
**Purpose**: Configure Azure Monitor email alerts for policy compliance monitoring

---

## 📧 OVERVIEW

This guide explains how to configure email notifications for Azure Key Vault policy compliance alerts using Azure Monitor Action Groups and Alert Rules.

### What You'll Set Up

1. **Azure Monitor Action Group** - Email distribution list for alerts
2. **5 Recommended Alert Rules** - Automated compliance notifications
3. **Email Delivery Testing** - Verify alerts work correctly

### Prerequisites

- Azure subscription with Owner or Contributor + Monitoring Contributor role
- Email address or distribution list for alert delivery
- Setup script already executed (creates Action Group)

---

## ✅ STEP 1: Configure Email Action Group

### Automatic Setup (Recommended)

The infrastructure setup script creates the Action Group automatically:

```powershell
# Run with your alert email address
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -ActionGroupEmail "alerts@company.com"
```

**What This Creates**:
- **Action Group Name**: `ag-keyvault-policy-alerts-<random>`
- **Short Name**: `KVPolicy` (visible in SMS/push notifications)
- **Email Receiver**: Name = "PolicyTeam", Address = your specified email
- **Resource Group**: `rg-policy-keyvault-test` (or production equivalent)

### Manual Setup (Alternative)

If you need to create/update the Action Group manually:

#### Via Azure Portal

1. Navigate to **Azure Monitor** → **Alerts** → **Action groups**
2. Click **+ Create**
3. Configure:
   - **Resource group**: `rg-policy-keyvault-test`
   - **Action group name**: `ag-keyvault-policy-alerts`
   - **Display name**: `KVPolicy`
4. Under **Notifications**:
   - **Notification type**: Email/SMS message/Push/Voice
   - **Name**: PolicyTeam
   - **Email**: alerts@company.com
   - ✅ Check "Enable the common alert schema"
5. Click **Review + create**

#### Via PowerShell

```powershell
# Connect to Azure
Connect-AzAccount
Set-AzContext -SubscriptionId "<your-subscription-id>"

# Create email receiver
$emailReceiver = New-AzActionGroupReceiver `
    -Name "PolicyTeam" `
    -EmailReceiver `
    -EmailAddress "alerts@company.com"

# Create Action Group
Set-AzActionGroup `
    -Name "ag-keyvault-policy-alerts" `
    -ResourceGroupName "rg-policy-keyvault-test" `
    -ShortName "KVPolicy" `
    -Receiver $emailReceiver
```

#### Via Azure CLI

```bash
# Create Action Group with email receiver
az monitor action-group create \
  --resource-group rg-policy-keyvault-test \
  --name ag-keyvault-policy-alerts \
  --short-name KVPolicy \
  --action email PolicyTeam alerts@company.com
```

---

## ✅ STEP 2: Create Alert Rules

### 5 Recommended Alert Rules

Configure these 5 alert rules to monitor policy compliance:

#### 1. Policy Assignment Deleted Alert

**Purpose**: Detect if someone accidentally or maliciously deletes policy assignments

**Configuration**:
```powershell
# Via PowerShell
$actionGroupId = (Get-AzActionGroup -ResourceGroupName "rg-policy-keyvault-test" -Name "ag-keyvault-policy-alerts").Id

$condition = New-AzActivityLogAlertCondition `
    -Field "operationName" `
    -Equal "Microsoft.Authorization/policyAssignments/delete"

New-AzActivityLogAlert `
    -ResourceGroupName "rg-policy-keyvault-test" `
    -Name "alert-policy-assignment-deleted" `
    -Scope "/subscriptions/<subscription-id>" `
    -Condition $condition `
    -ActionGroupId $actionGroupId `
    -Description "Alert when Key Vault policy assignments are deleted"
```

**Via Azure Portal**:
1. Navigate to **Azure Monitor** → **Alerts** → **Create alert rule**
2. **Scope**: Select subscription
3. **Condition**: 
   - Signal type: Activity Log
   - Operation name: Delete Policy Assignment
4. **Action group**: Select `ag-keyvault-policy-alerts`
5. **Alert rule name**: `alert-policy-assignment-deleted`

---

#### 2. Compliance Drop > 10% Alert

**Purpose**: Detect significant compliance percentage drops (indicates new non-compliant resources or policy drift)

**Configuration**:

```powershell
# This requires custom Log Analytics query
# Step 1: Ensure compliance data flows to Log Analytics
# Step 2: Create scheduled query rule

$query = @"
AzurePolicyComplianceEvents
| where ResourceType == "Microsoft.KeyVault/vaults"
| summarize CompliancePercent = avg(todouble(ComplianceState == "Compliant")) * 100 by bin(TimeGenerated, 1h)
| extend PreviousCompliancePercent = prev(CompliancePercent, 1)
| where CompliancePercent < (PreviousCompliancePercent - 10)
| project TimeGenerated, CompliancePercent, PreviousCompliancePercent, ComplianceDrop = PreviousCompliancePercent - CompliancePercent
"@

# Note: This alert requires Azure Policy compliance data exported to Log Analytics
# Current implementation: HTML reports show compliance trends manually
```

**⚠️ Current Limitation**: Azure Policy compliance data is not automatically exported to Log Analytics. This alert requires:
- **Option A**: Configure Azure Policy diagnostic settings to send to Log Analytics (not currently supported by Azure Policy service)
- **Option B**: Use Azure Resource Graph queries in scheduled tasks to track compliance over time
- **Option C**: Manual compliance monitoring via HTML reports (current implementation)

**Recommendation**: Track compliance trends manually using weekly HTML reports until Azure Policy adds Log Analytics export.

---

#### 3. Remediation Task Failures Alert

**Purpose**: Detect when auto-remediation tasks fail (indicates permission issues or configuration problems)

**Configuration**:

```powershell
# Via PowerShell
$actionGroupId = (Get-AzActionGroup -ResourceGroupName "rg-policy-keyvault-test" -Name "ag-keyvault-policy-alerts").Id

$condition = New-AzActivityLogAlertCondition `
    -Field "operationName" `
    -Equal "Microsoft.PolicyInsights/remediations/write" `
    -Field "status" `
    -Equal "Failed"

New-AzActivityLogAlert `
    -ResourceGroupName "rg-policy-keyvault-test" `
    -Name "alert-remediation-task-failed" `
    -Scope "/subscriptions/<subscription-id>" `
    -Condition $condition `
    -ActionGroupId $actionGroupId `
    -Description "Alert when policy remediation tasks fail"
```

**Via Azure Portal**:
1. **Azure Monitor** → **Alerts** → **Create alert rule**
2. **Scope**: Subscription
3. **Condition**: 
   - Signal type: Activity Log
   - Operation name: Write Remediation
   - Event level: Error
4. **Action group**: `ag-keyvault-policy-alerts`

---

#### 4. Deny Block Spike Alert

**Purpose**: Detect unusual spike in policy deny events (indicates application misconfiguration or attack attempt)

**Configuration**:

```powershell
# Via PowerShell
$actionGroupId = (Get-AzActionGroup -ResourceGroupName "rg-policy-keyvault-test" -Name "ag-keyvault-policy-alerts").Id

# Activity Log Alert for Policy Deny events
$condition = New-AzActivityLogAlertCondition `
    -Field "category" `
    -Equal "Policy" `
    -Field "level" `
    -Equal "Error"

New-AzActivityLogAlert `
    -ResourceGroupName "rg-policy-keyvault-test" `
    -Name "alert-policy-deny-spike" `
    -Scope "/subscriptions/<subscription-id>" `
    -Condition $condition `
    -ActionGroupId $actionGroupId `
    -Description "Alert when policy deny events spike"
```

**⚠️ Current Limitation**: Activity Log only shows individual deny events, not aggregated spike detection. For spike detection, consider:
- **Option A**: Use Azure Monitor Metrics (if available for policy denies)
- **Option B**: Create custom Log Analytics query with threshold
- **Option C**: Manual monitoring via Azure Activity Log filtering

---

#### 5. Exemption Expiry Warning Alert

**Purpose**: Warn before policy exemptions expire (30-day advance notice)

**Configuration**:

**⚠️ Current Limitation**: Azure Policy does not have built-in expiration alerts for exemptions. This requires custom implementation:

```powershell
# Custom logic needed - add to scheduled task/automation runbook

# Pseudo-code:
# 1. Query all policy exemptions:
$exemptions = Get-AzPolicyExemption -Scope "/subscriptions/<subscription-id>"

# 2. Filter exemptions expiring in next 30 days:
$expiringExemptions = $exemptions | Where-Object { 
    $_.Properties.ExpiresOn -and 
    $_.Properties.ExpiresOn -le (Get-Date).AddDays(30) -and
    $_.Properties.ExpiresOn -gt (Get-Date)
}

# 3. Send email alert if any found:
if ($expiringExemptions.Count -gt 0) {
    # Send-MailMessage or trigger Action Group
    Write-Host "WARNING: $($expiringExemptions.Count) exemptions expiring soon"
}
```

**Recommendation**: Implement as Azure Automation Runbook scheduled weekly:
1. Create Azure Automation Account
2. Add runbook with exemption expiry check logic
3. Schedule to run every Monday
4. Configure to trigger Action Group when exemptions expiring < 30 days

---

## ✅ STEP 3: Test Email Delivery

### Test Action Group

```powershell
# Test email delivery
Test-AzActionGroup `
    -ActionGroupResourceId "/subscriptions/<subscription-id>/resourceGroups/rg-policy-keyvault-test/providers/Microsoft.Insights/actionGroups/ag-keyvault-policy-alerts" `
    -AlertType "servicehealth"
```

**Expected Result**: Email delivered to `alerts@company.com` within 5 minutes with subject "Test notification from Azure Monitor"

### Verify Email Configuration

```powershell
# Check Action Group configuration
Get-AzActionGroup `
    -ResourceGroupName "rg-policy-keyvault-test" `
    -Name "ag-keyvault-policy-alerts" | 
    Select-Object Name, EmailReceivers, Enabled

# Expected output:
# Name                           EmailReceivers                Enabled
# ----                           --------------                -------
# ag-keyvault-policy-alerts     {PolicyTeam}                   True
```

---

## 📧 EMAIL NOTIFICATION EXAMPLES

### Sample Alert: Policy Assignment Deleted

**Subject**: `[Azure Monitor] Alert: alert-policy-assignment-deleted`

**Body**:
```
Alert Rule: alert-policy-assignment-deleted
Severity: Warning
Status: Fired
Fired Time: 2026-01-20 14:30:00 UTC

Description: Alert when Key Vault policy assignments are deleted

Details:
- Operation Name: Microsoft.Authorization/policyAssignments/delete
- Resource: /subscriptions/.../policyAssignments/KV-soft-delete-1234567890
- Caller: user@company.com
- Time: 2026-01-20 14:30:00 UTC

Action Required:
1. Verify if deletion was intentional
2. Re-deploy policy if accidental: .\AzPolicyImplScript.ps1 -DeployProduction
3. Review RBAC permissions if unauthorized deletion
```

### Sample Alert: Remediation Task Failed

**Subject**: `[Azure Monitor] Alert: alert-remediation-task-failed`

**Body**:
```
Alert Rule: alert-remediation-task-failed
Severity: Error
Status: Fired
Fired Time: 2026-01-20 15:45:00 UTC

Description: Alert when policy remediation tasks fail

Details:
- Operation Name: Microsoft.PolicyInsights/remediations/write
- Resource: kv-production-vault-123
- Status: Failed
- Error: ManagedIdentityPermissionDenied - Managed identity lacks Key Vault Contributor role

Action Required:
1. Check managed identity RBAC: Get-AzRoleAssignment -ObjectId <identity-id>
2. Assign required role: New-AzRoleAssignment -ObjectId <identity-id> -RoleDefinitionName "Key Vault Contributor" -Scope <vault-id>
3. Re-trigger remediation: .\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Remediation.json
```

---

## 🔧 TROUBLESHOOTING

### Email Not Received

**Check 1: Action Group Enabled**
```powershell
Get-AzActionGroup -ResourceGroupName "rg-policy-keyvault-test" -Name "ag-keyvault-policy-alerts" | 
    Select-Object Enabled

# Should show: Enabled = True
```

**Check 2: Email Address Correct**
```powershell
Get-AzActionGroup -ResourceGroupName "rg-policy-keyvault-test" -Name "ag-keyvault-policy-alerts" |
    Select-Object -ExpandProperty EmailReceivers |
    Format-Table Name, EmailAddress, Status

# Verify EmailAddress matches your distribution list
```

**Check 3: Spam Folder**
- Azure Monitor emails may be flagged as spam
- Add `azure-noreply@microsoft.com` to safe sender list
- Check email server logs for delivery

**Check 4: Email Confirmation**
- First-time setup requires email confirmation
- Check inbox for "Azure Monitor - Email confirmation required" message
- Click confirmation link within 48 hours

### Alert Not Triggering

**Check 1: Alert Rule Enabled**
```powershell
# For Activity Log alerts:
Get-AzActivityLogAlert -ResourceGroupName "rg-policy-keyvault-test" |
    Select-Object Name, Enabled

# Should show: Enabled = True
```

**Check 2: Alert Condition Met**
- Activity Log alerts only trigger when exact condition matches
- Review alert condition query in Azure Portal
- Check Azure Activity Log to verify events exist

**Check 3: Action Group Linked**
```powershell
Get-AzActivityLogAlert -ResourceGroupName "rg-policy-keyvault-test" -Name "alert-policy-assignment-deleted" |
    Select-Object -ExpandProperty Actions

# Should show action group resource ID
```

---

## 📊 SMTP CONFIGURATION (NOT REQUIRED)

**Note**: Azure Monitor Action Groups use Azure's email infrastructure. You do NOT need to configure SMTP servers.

**If you require custom SMTP** (for on-premises email systems):
- Azure Monitor Action Groups do not support custom SMTP
- Consider alternatives:
  - **Logic Apps**: Trigger from Action Group → Send email via Logic Apps SMTP connector
  - **Azure Functions**: Trigger from Action Group → Custom function with SMTP library
  - **Azure Automation**: Runbook scheduled task with Send-MailMessage cmdlet

---

## 📚 ADDITIONAL RESOURCES

- [Azure Monitor Action Groups Documentation](https://learn.microsoft.com/azure/azure-monitor/alerts/action-groups)
- [Azure Activity Log Alerts](https://learn.microsoft.com/azure/azure-monitor/alerts/activity-log-alerts)
- [Azure Policy Compliance States](https://learn.microsoft.com/azure/governance/policy/how-to/get-compliance-data)
- [Azure Monitor Common Alert Schema](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-common-schema)

---

## 📝 SUMMARY

✅ **Implemented Features**:
- Action Group creation with email receiver (via Setup script)
- Test email delivery capability
- Alert Rule #1: Policy Assignment Deleted (Activity Log)
- Alert Rule #3: Remediation Task Failures (Activity Log)
- Alert Rule #4: Deny Block Spike (Activity Log - individual events)

⏳ **Partial Implementation** (requires custom logic):
- Alert Rule #2: Compliance Drop >10% (needs Resource Graph scheduled task)
- Alert Rule #5: Exemption Expiry Warning (needs Automation Runbook)

❌ **Not Supported by Azure**:
- Direct Log Analytics export for policy compliance metrics
- Built-in exemption expiration alerts
- Custom SMTP server support in Action Groups

**Recommendation**: Use current email alerting for critical events (policy deletion, remediation failures). Track compliance trends manually via weekly HTML reports until Azure Policy adds advanced monitoring capabilities.

---

**END OF GUIDE**
