# Complete DevTest Policy Testing Plan - All 46 Policies

## Objective
Test the complete policy lifecycle for all 46 Azure Key Vault policies in DevTest environment before Production deployment.

## Test Phases (a → f)

---

### ✅ PHASE A: Deploy All 46 Policies in Audit Mode

**Command:**
```powershell
.\AzPolicyImplScript.ps1 -Environment DevTest -Phase Test -SkipRBACCheck
```

**Expected Outcome:**
- All 46 policies deployed successfully (46/46)
- Mode: Audit (monitoring only, no blocking)
- Coverage: 100%

**Changes Made:**
- Enabled previously disabled policies (11 policies)
- Added placeholder infrastructure parameters:
  - Log Analytics workspace (for diagnostic settings)
  - Event Hub (for diagnostic settings)
  - Private Link subnet (for private endpoints)
  - Private DNS zone (for private DNS)

**Policy Mode Breakdown:**
- **Audit**: 37 policies (evaluate and report)
- **AuditIfNotExists**: 9 policies (check if configurations exist)
- **Total Active**: 46 policies

---

### ✅ PHASE B: Check Compliance - Audit Mode Results

**Command:**
```powershell
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**Wait Time:** 5-10 minutes for Azure Policy evaluation

**Expected Results:**
- **kv-compliant**: High compliance rate (80-90%)
- **kv-partial**: Medium compliance (50-70%)
- **kv-noncompliant**: Low compliance (20-40%)

**Deliverables:**
- HTML Report: `PolicyImplementationReport-[timestamp].html`
- JSON Report: `KeyVaultPolicyImplementationReport-[timestamp].json`
- CSV Report: `KeyVaultPolicyImplementationReport-[timestamp].csv`

**Verification:**
- All 46 policies should appear in report
- No "Not Started" status (all evaluated)
- Compliance percentages calculated

---

### ✅ PHASE C: Switch to Deny Mode & Test Blocking

**Step 1: Create PolicyParameters-DevTest-Deny.json**
```powershell
# Copy current parameters
Copy-Item .\PolicyParameters-DevTest.json .\PolicyParameters-DevTest-Deny.json

# Update all "Audit" → "Deny" (where supported)
# Keep AuditIfNotExists, DeployIfNotExists, Modify as-is
```

**Step 2: Deploy in Deny Mode**
```powershell
# Update script to use Deny mode parameters
.\AzPolicyImplScript.ps1 -Environment DevTest -Phase Test -PolicyMode Deny -SkipRBACCheck
```

**Step 3: Test Blocking Behavior**
```powershell
# Try to create non-compliant resources (should be BLOCKED):

# Test 1: Create secret without expiration date (should DENY)
Set-AzKeyVaultSecret -VaultName "kv-noncompliant" -Name "test-deny-secret" `
  -SecretValue (ConvertTo-SecureString "TestValue" -AsPlainText -Force)

# Test 2: Create key without expiration date (should DENY)
Add-AzKeyVaultKey -VaultName "kv-noncompliant" -Name "test-deny-key" `
  -Destination Software

# Test 3: Create certificate with short validity (should DENY if > 36 months)
# ... additional tests for each blocking policy
```

**Expected Outcome:**
- Non-compliant resource creation attempts are BLOCKED
- Error message references policy assignment
- Compliant resources can still be created

**Verification Checklist:**
- [ ] Secrets without expiration → DENIED ✓
- [ ] Keys without expiration → DENIED ✓
- [ ] Certificates with invalid lifetime → DENIED ✓
- [ ] Keys with small RSA size → DENIED ✓
- [ ] Secrets without content type → DENIED ✓
- [ ] Non-RBAC vault creation → DENIED ✓

---

### ✅ PHASE D: Check Compliance - Deny Mode Results

**Command:**
```powershell
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**Expected Results:**
- Compliance rates should INCREASE (Deny prevents new violations)
- Existing non-compliant resources still reported (not remediated)
- No new non-compliant resources can be created

**Compare to Phase B:**
- Same existing non-compliant resources
- No additional violations (blocked by Deny)
- Verify policy enforcement working

---

### ✅ PHASE E: Optional - Test Enforce Mode (DeployIfNotExists/Modify)

**⚠️ WARNING:** This phase will modify existing resources!

**Step 1: Identify Policies with Remediation**
```powershell
# Policies that auto-remediate:
# - Configure key vaults to enable firewall (Modify)
# - Deploy diagnostic settings (DeployIfNotExists)
# - Configure private endpoints (DeployIfNotExists)
# - etc.
```

**Step 2: Create Remediation Tasks**
```powershell
# For each DeployIfNotExists/Modify policy, create remediation:
Start-AzPolicyRemediation -Name "remediate-kv-firewall" `
  -PolicyAssignmentId "/subscriptions/.../assignments/[policy-name]" `
  -ResourceGroupName "rg-policy-keyvault-test"
```

**Step 3: Monitor Remediation**
```powershell
Get-AzPolicyRemediation -ResourceGroupName "rg-policy-keyvault-test" | 
  Select-Object Name, ProvisioningState, ResourceCount, FailedCount
```

**Expected Outcome:**
- Non-compliant resources are automatically remediated
- Compliance rate increases to near 100%
- Activity logs show policy-triggered modifications

**Note:** Some policies won't remediate due to placeholder infrastructure:
- Log Analytics workspace doesn't exist → diagnostic settings won't deploy
- Private Link subnet doesn't exist → private endpoints won't deploy
- Event Hub doesn't exist → Event Hub diagnostic settings won't deploy

**Operational Policies (will work):**
- 33 Audit policies → Already reporting
- Firewall configuration → Can modify existing vaults
- RBAC enforcement → Can evaluate

---

### ✅ PHASE F: Configure Alerts for Deny/Enforce Actions

**Step 1: Create Activity Log Alert for Policy Deny Events**
```powershell
# Create alert rule for policy deny operations
$condition = New-AzActivityLogAlertCondition -Field 'category' -Equal 'Policy' `
  -Field 'operationName' -Equal 'Microsoft.Authorization/policies/deny/action'

New-AzActivityLogAlert -Name "alert-policy-deny-actions" `
  -ResourceGroupName "rg-policy-remediation" `
  -Condition $condition `
  -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb" `
  -Description "Alert when Azure Policy denies an operation" `
  -Location "global"
```

**Step 2: Create Alert for Policy Remediation Events**
```powershell
# Alert when DeployIfNotExists/Modify policies trigger
$condition = New-AzActivityLogAlertCondition -Field 'category' -Equal 'Policy' `
  -Field 'operationName' -Equal 'Microsoft.Authorization/policies/auditIfNotExists/action'

New-AzActivityLogAlert -Name "alert-policy-remediation" `
  -ResourceGroupName "rg-policy-remediation" `
  -Condition $condition `
  -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb" `
  -Description "Alert when Azure Policy remediates resources" `
  -Location "global"
```

**Step 3: Configure Email Notifications**
```powershell
# Create action group for email alerts
$emailReceiver = New-AzActionGroupReceiver -Name "AdminEmail" `
  -EmailReceiver -EmailAddress "admin@example.com"

Set-AzActionGroup -Name "ag-policy-alerts" `
  -ResourceGroupName "rg-policy-remediation" `
  -ShortName "PolicyAlert" `
  -Receiver $emailReceiver
```

**Step 4: Link Alerts to Action Group**
```powershell
# Update both alerts to use action group
Update-AzActivityLogAlert -Name "alert-policy-deny-actions" `
  -ResourceGroupName "rg-policy-remediation" `
  -ActionGroupId "/subscriptions/.../resourceGroups/rg-policy-remediation/providers/microsoft.insights/actionGroups/ag-policy-alerts"
```

**Expected Alerts:**
- **Deny Event**: Email when policy blocks resource creation/modification
- **Remediation Event**: Email when policy auto-fixes non-compliant resource
- **Compliance Change**: Notification when compliance percentage drops

---

## Success Criteria

### Phase A (Deploy)
- ✅ 46 out of 46 policies deployed
- ✅ No missing parameter errors
- ✅ All policies in "Audit" or "AuditIfNotExists" mode

### Phase B (Audit Compliance)
- ✅ All 46 policies report compliance data
- ✅ kv-compliant shows high compliance
- ✅ kv-noncompliant shows expected violations
- ✅ HTML/JSON/CSV reports generated

### Phase C (Deny Deploy)
- ✅ All 46 policies switched to Deny mode (where supported)
- ✅ Non-compliant resource creation blocked
- ✅ Error messages reference policy

### Phase D (Deny Compliance)
- ✅ Compliance rate improves vs Phase B
- ✅ No new violations created
- ✅ Existing violations still reported

### Phase E (Enforce - Optional)
- ✅ Remediation tasks created
- ✅ Some resources auto-fixed
- ✅ Activity logs show policy-triggered changes
- ⚠️ Infrastructure-dependent policies report "Not Applicable"

### Phase F (Alerts)
- ✅ Activity log alerts created
- ✅ Email notifications configured
- ✅ Test alert fires successfully
- ✅ Team receives deny/remediation notifications

---

## Execution Timeline

| Phase | Duration | Wait Time | Total |
|-------|----------|-----------|-------|
| A: Deploy Audit | 2-3 min | - | 3 min |
| B: Check Compliance | 2 min | 5-10 min | 12 min |
| C: Deploy Deny | 2-3 min | - | 3 min |
| C: Test Blocking | 5-10 min | - | 10 min |
| D: Check Compliance | 2 min | 5-10 min | 12 min |
| E: Enforce (Optional) | 10-15 min | 30-60 min | 75 min |
| F: Configure Alerts | 10 min | - | 10 min |
| **Total** | **~35-45 min** | **~45-80 min** | **~125 min** |

---

## Command Summary

**Phase A:**
```powershell
.\AzPolicyImplScript.ps1 -Environment DevTest -Phase Test -SkipRBACCheck
```

**Phase B:**
```powershell
# Wait 5-10 minutes
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**Phase C:**
```powershell
# Create Deny mode parameter file (manual or script)
# Redeploy with Deny mode
# Test blocking behavior with Set-AzKeyVaultSecret commands
```

**Phase D:**
```powershell
# Wait 5-10 minutes
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**Phase E:**
```powershell
# Create remediation tasks
Start-AzPolicyRemediation -Name "remediate-test" -PolicyAssignmentId "..."
Get-AzPolicyRemediation -ResourceGroupName "rg-policy-keyvault-test"
```

**Phase F:**
```powershell
# Create alerts (see detailed commands above)
New-AzActivityLogAlert -Name "alert-policy-deny-actions" ...
```

---

## Notes

### Placeholder Infrastructure
The following resources are placeholders and won't actually deploy/remediate:
- Log Analytics workspace: `/subscriptions/.../placeholder-workspace`
- Event Hub: `/subscriptions/.../placeholder-eventhub`
- Private Link subnet: `/subscriptions/.../placeholder-subnet`
- Private DNS zone: `/subscriptions/.../privatelink.vaultcore.azure.net`

**Impact:**
- Policies will evaluate and report compliance ✓
- Deny mode will block violations ✓
- DeployIfNotExists won't deploy (no real infrastructure) ⚠️
- Still achieves 46/46 policy coverage for testing ✓

### Production Deployment
After successful DevTest validation:
1. Create real infrastructure (Log Analytics, Event Hub, etc.)
2. Update PolicyParameters-Production.json with real resource IDs
3. Deploy to Production with stricter parameters
4. Enable all 46 policies in production environment

---

## Ready to Execute?

**Start with Phase A:**
```powershell
.\AzPolicyImplScript.ps1 -Environment DevTest -Phase Test -SkipRBACCheck
```

Type **RUN** when prompted to begin deployment of all 46 policies.
