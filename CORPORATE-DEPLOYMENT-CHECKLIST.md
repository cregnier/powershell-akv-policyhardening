# Corporate AAD Deployment Checklist

**Version**: 1.0  
**Target Environment**: Corporate PC with Azure Active Directory  
**Expected Duration**: 25 minutes (15 min setup + 10 min deployment)  
**Prerequisites**: Windows 10/11, Administrator access, Internet connectivity

---

## ✅ Pre-Deployment Checklist (Complete BEFORE starting)

### 1. System Requirements Verification

- [ ] **Operating System**: Windows 10/11 or Windows Server 2019/2022
- [ ] **PowerShell Version**: PowerShell 7.0 or higher
  ```powershell
  # Check version
  $PSVersionTable.PSVersion
  # Should show: Major 7 or higher
  ```
- [ ] **Administrator Access**: Run PowerShell as Administrator
- [ ] **Internet Connectivity**: Required for Azure module download and Azure API access
- [ ] **Disk Space**: Minimum 500 MB free space (for Azure modules and logs)

### 2. Corporate Environment Validation

- [ ] **Proxy Configuration**: If behind corporate proxy, configure PowerShell proxy settings
  ```powershell
  # Check if proxy is required
  [System.Net.WebRequest]::DefaultWebProxy
  
  # If proxy required, set environment variables
  $env:HTTP_PROXY = "http://proxy.corporate.com:8080"
  $env:HTTPS_PROXY = "http://proxy.corporate.com:8080"
  ```

- [ ] **Execution Policy**: Set to RemoteSigned or Bypass
  ```powershell
  # Check current policy
  Get-ExecutionPolicy
  
  # Set policy (requires Administrator)
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
  ```

- [ ] **Corporate Firewall**: Ensure access to:
  - `https://management.azure.com` (Azure Resource Manager)
  - `https://login.microsoftonline.com` (Azure AD authentication)
  - `https://www.powershellgallery.com` (PowerShell Gallery for modules)

### 3. Azure Subscription Preparation

- [ ] **Azure Subscription ID**: Obtain subscription ID from Azure Portal or Azure admin
- [ ] **Azure AD Credentials**: Ensure you have credentials for account with required permissions
- [ ] **RBAC Permissions**: Verify account has **ONE** of these role combinations:
  - **Option 1 (Recommended)**: `Contributor` + `Resource Policy Contributor`
  - **Option 2**: `Owner` role
  - **Option 3**: Custom role with `Microsoft.Authorization/policyAssignments/*` permissions

  ```powershell
  # Verify roles after connecting to Azure
  Connect-AzAccount
  Get-AzRoleAssignment -SignInName "<your-email@corporate.com>"
  ```

### 4. Package Extraction Verification

- [ ] **Extract ZIP**: Extract `AzureKeyVaultPolicyGovernance-v1.0.zip` to `C:\Deploy\powershell-akv-policyhardening\`
- [ ] **Verify Core Files**: Ensure all 17 core files are present
  ```powershell
  cd C:\Deploy\powershell-akv-policyhardening
  
  # Check for main script
  Test-Path .\AzPolicyImplScript.ps1
  
  # Check for parameter files (should show 6 files)
  Get-ChildItem .\PolicyParameters-*.json | Measure-Object
  
  # Check for policy mapping (CRITICAL)
  Test-Path .\PolicyNameMapping.json
  ```

---

## 🚀 Deployment Steps

### STEP 1: Install Azure PowerShell Modules (15 minutes first time)

```powershell
# Open PowerShell 7 as Administrator
# Navigate to deployment directory
cd C:\Deploy\powershell-akv-policyhardening

# Install required modules (takes 10-15 minutes on first install)
Install-Module -Name Az.Accounts, Az.Resources, Az.PolicyInsights, Az.KeyVault -Force -Scope CurrentUser -AllowClobber

# Verify installation
Get-Module -Name Az.Accounts, Az.Resources, Az.PolicyInsights -ListAvailable
```

**Expected Output**:
```
ModuleType Version    Name
---------- -------    ----
Script     3.0.x      Az.Accounts
Script     7.x.x      Az.Resources
Script     2.x.x      Az.PolicyInsights
Script     5.x.x      Az.KeyVault
```

**Troubleshooting**:
- If module installation fails due to proxy: See proxy configuration above
- If "Access Denied" error: Ensure running PowerShell as Administrator
- If TLS error: Run `[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12`

---

### STEP 2: Connect to Azure Subscription

```powershell
# Connect to Azure (opens browser for authentication)
Connect-AzAccount

# If multiple tenants, specify tenant ID
Connect-AzAccount -TenantId "<your-tenant-id>"

# Set subscription context
Set-AzContext -Subscription "<your-subscription-id>"

# Verify connection
Get-AzContext
```

**Expected Output**:
```
Name                          Account              SubscriptionName     Environment TenantId
----                          -------              ----------------     ----------- --------
Corporate Subscription        user@corporate.com   Corporate Prod Sub   AzureCloud  <guid>
```

**Troubleshooting**:
- If browser doesn't open: Use `Connect-AzAccount -UseDeviceAuthentication` for device code flow
- If MFA required: Complete multi-factor authentication in browser
- If wrong subscription: Use `Get-AzSubscription` to list all, then `Set-AzContext -Subscription <name>`

---

### STEP 3: Choose Deployment Scenario

**DECISION POINT**: Select ONE scenario based on your deployment phase

#### Scenario 1: DevTest Baseline (RECOMMENDED FIRST)
**What**: 30 policies in Audit mode  
**Risk**: 🟢 Zero risk - monitoring only  
**Duration**: 5 minutes deployment + 30 minutes Azure evaluation  
**Use When**: First-time deployment, proof-of-concept, initial testing

```powershell
# Deploy 30 baseline policies
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest.json -SkipRBACCheck

# Wait 30 minutes, then check compliance
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**User Input Required**: None (uses default parameter file)

---

#### Scenario 2: DevTest Full (46 Policies)
**What**: All 46 policies in Audit mode  
**Risk**: 🟢 Zero risk - monitoring only  
**Duration**: 5 minutes deployment + 30 minutes Azure evaluation  
**Use When**: After Scenario 1 success, comprehensive testing

```powershell
# Deploy all 46 policies
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -SkipRBACCheck

# Wait 30 minutes, then check compliance
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**User Input Required**: None

---

#### Scenario 3: DevTest Auto-Remediation
**What**: 8 auto-remediation policies (DeployIfNotExists)  
**Risk**: 🟡 Medium - will modify resources automatically  
**Duration**: 5 minutes deployment + 30-60 minutes Azure remediation  
**Use When**: Testing automatic compliance fixes  
**Prerequisites**: Managed Identity with Contributor role (see Scenario 7 for setup)

```powershell
# Deploy auto-remediation policies
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -IdentityResourceId "/subscriptions/<SUBSCRIPTION-ID>/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation" `
    -SkipRBACCheck

# Wait 30-60 minutes, then check compliance
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**User Input Required**:
- Replace `<SUBSCRIPTION-ID>` with your Azure subscription ID (find with `Get-AzContext`)
- Ensure managed identity `id-policy-remediation` exists (or create with Setup-AzureKeyVaultPolicyEnvironment.ps1)

---

#### Scenario 4: Production Audit (RECOMMENDED BEFORE ENFORCEMENT)
**What**: All 46 policies in Audit mode in production  
**Risk**: 🟢 Zero risk - monitoring only  
**Duration**: 5 minutes deployment + 30-90 days monitoring  
**Use When**: Production baseline before enabling enforcement

```powershell
# Deploy all 46 policies in production audit mode
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production.json -SkipRBACCheck

# Wait 30 minutes, then check compliance
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**User Input Required**: None  
**Best Practice**: Monitor for 30-90 days before moving to Scenario 5

---

#### Scenario 5: Production Deny (ENFORCEMENT MODE)
**What**: All 46 policies in Deny mode - BLOCKS non-compliant operations  
**Risk**: 🔴 HIGH - will block new Key Vault deployments if non-compliant  
**Duration**: 5 minutes deployment + ongoing monitoring  
**Use When**: After 30-90 days of Scenario 4 audit monitoring

```powershell
# CRITICAL: This BLOCKS non-compliant operations!
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Deny.json -SkipRBACCheck

# Monitor compliance
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**User Input Required**: None  
**⚠️ WARNING**: New Key Vault deployments that violate policies will be BLOCKED. Ensure all deployment templates are compliant first.

---

#### Scenario 6: Production Auto-Remediation
**What**: 8 auto-remediation policies in production  
**Risk**: 🔴 HIGH - will modify production Key Vaults automatically  
**Duration**: 5 minutes deployment + 30-60 minutes Azure remediation  
**Use When**: After successful DevTest auto-remediation testing (Scenario 3)  
**Prerequisites**: Managed Identity with Contributor role in production

```powershell
# CRITICAL: This MODIFIES production resources!
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -IdentityResourceId "/subscriptions/<SUBSCRIPTION-ID>/resourceGroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation" `
    -SkipRBACCheck

# Monitor remediation
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**User Input Required**:
- Replace `<SUBSCRIPTION-ID>` with production subscription ID
- Ensure managed identity has Contributor role in production subscription

---

#### Scenario 7: Resource Group Scope (Limited Deployment)
**What**: Deploy policies to specific resource group only  
**Risk**: 🟢 Low - limited scope  
**Duration**: 5 minutes  
**Use When**: Testing policies on subset of resources

```powershell
# Deploy to specific resource group
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest.json `
    -ResourceGroupScope "/subscriptions/<SUBSCRIPTION-ID>/resourceGroups/<RESOURCE-GROUP-NAME>" `
    -SkipRBACCheck

# Check compliance for that resource group
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**User Input Required**:
- Replace `<SUBSCRIPTION-ID>` with your subscription ID
- Replace `<RESOURCE-GROUP-NAME>` with target resource group name

---

#### Scenario 8: Management Group Scope (Enterprise-Wide)
**What**: Deploy policies to entire management group hierarchy  
**Risk**: 🔴 VERY HIGH - affects all subscriptions under management group  
**Duration**: 5 minutes deployment  
**Use When**: Enterprise-wide governance rollout

```powershell
# Deploy to management group
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production.json `
    -ManagementGroupScope "/providers/Microsoft.Management/managementGroups/<MANAGEMENT-GROUP-ID>" `
    -SkipRBACCheck

# Check compliance across management group
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**User Input Required**:
- Replace `<MANAGEMENT-GROUP-ID>` with your management group ID (find with `Get-AzManagementGroup`)

---

#### Scenario 9: Rollback (Remove All Policies)
**What**: Removes all policy assignments with "KV-" prefix  
**Risk**: 🟡 Medium - removes governance controls  
**Duration**: 2 minutes  
**Use When**: Need to remove all policies (testing, decommissioning)

```powershell
# Remove all policy assignments
.\AzPolicyImplScript.ps1 -Rollback -SkipRBACCheck

# Verify removal
Get-AzPolicyAssignment | Where-Object { $_.Name -like 'KV-*' }
# Should return nothing
```

**User Input Required**: Confirm rollback when prompted

---

### STEP 4: Wait for Azure Policy Evaluation

**CRITICAL TIMING**: Azure Policy evaluation is NOT instant

| Deployment Type | Wait Time | What Happens |
|----------------|-----------|--------------|
| Audit mode | 30-60 minutes | Azure scans resources, generates compliance data |
| Deny mode | 30-60 minutes | Azure activates blocking, scans resources |
| Auto-remediation | 30-90 minutes | Azure creates remediation tasks, fixes resources |

**What to do while waiting**:
1. Review deployment logs in PowerShell output
2. Check Azure Portal → Policy → Assignments (should see new assignments)
3. Prepare for compliance review (have stakeholders ready)

---

### STEP 5: Verify Deployment Success

```powershell
# Check policy assignments
Get-AzPolicyAssignment | Where-Object { $_.Name -like 'KV-*' } | Select-Object Name, DisplayName, EnforcementMode

# Trigger compliance scan (forces Azure to re-evaluate)
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck

# Open HTML report (generated by compliance check)
Get-ChildItem ComplianceReport-*.html | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | ForEach-Object { Start-Process $_.FullName }
```

**Expected Results**:
- ✅ Policy assignments visible in `Get-AzPolicyAssignment`
- ✅ HTML compliance report generated (ComplianceReport-YYYYMMDD-HHMMSS.html)
- ✅ No [ERROR] messages in PowerShell output
- ⚠️ [WARN] messages about cryptographicType parameter are EXPECTED (see below)

---

## 🔍 Validation Checklist

### Console Output Validation

- [ ] **Deployment Banner**: Should show scenario-specific deployment type (DevTest30, DevTestFull46, etc.)
- [ ] **Success Messages**: `[SUCCESS]` for each policy assignment
- [ ] **Next Steps Guidance**: Console should display scenario-specific next steps
- [ ] **No Errors**: No `[ERROR]` messages (unless expected, e.g., policy already exists)
- [ ] **Expected Warnings**: DEBUG messages about `cryptographicType` parameter are NORMAL

**Example Expected Output**:
```
🎯 DevTest Full Deployment Complete (46 Policies - Audit Mode)

✅ What was deployed:
  → All 46 Azure Key Vault governance policies in Audit mode
  → Comprehensive compliance monitoring

📋 Recommended Next Steps:
  1. ⏳ Wait 30-60 minutes for Azure Policy evaluation cycle
  2. 📊 Generate compliance report
  3. 🧪 Test auto-remediation (8 DeployIfNotExists policies)
```

### HTML Report Validation

- [ ] **Report Generated**: File exists in deployment directory (ComplianceReport-*.html)
- [ ] **Open in Browser**: Double-click to open, verify it loads correctly
- [ ] **Next Steps Section**: Should show 3-phase roadmap (Review → Deny → Enforce)
- [ ] **Compliance Data**: Should show compliance percentage (after 30-60 min wait)
- [ ] **Policy List**: Should show all deployed policies with status

---

## ⚠️ Known Expected Warnings (NOT Errors)

### cryptographicType Parameter Warning (NORMAL)

**Warning Message**:
```
DEBUG: Parameter 'cryptographicType' NOT FOUND in policy definition - SKIPPED
Parameter 'cryptographicType' not defined in policy. Skipping to avoid UndefinedPolicyParameter error.
```

**Explanation**: This is CORRECT behavior. The script validates parameters against policy definitions and skips undefined parameters to prevent errors. This warning appears for the policy "Keys should be the specified cryptographic type RSA or EC" which only accepts `allowedKeyTypes` and `effect` parameters.

**Action Required**: None - this is working as designed.

---

## 🐛 Troubleshooting Common Issues

### Issue: "Connect-AzAccount" fails with proxy error

**Solution**:
```powershell
# Set proxy for current session
$env:HTTP_PROXY = "http://proxy.corporate.com:8080"
$env:HTTPS_PROXY = "http://proxy.corporate.com:8080"

# Or configure for all sessions
[System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy("http://proxy.corporate.com:8080")
```

---

### Issue: "Insufficient permissions" error during policy assignment

**Solution**:
```powershell
# Check your roles
Get-AzRoleAssignment -SignInName "<your-email@corporate.com>"

# If missing roles, request from Azure administrator:
# Required: Contributor + Resource Policy Contributor (or Owner)
```

---

### Issue: Policy assignments complete but compliance shows 0%

**Cause**: Azure Policy evaluation hasn't completed yet (takes 30-60 minutes)

**Solution**:
```powershell
# Wait 30 minutes, then trigger compliance scan
Start-Sleep -Seconds 1800
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

---

### Issue: HTML report shows "Compliance Data Not Yet Available"

**Cause**: Azure Policy evaluation lag (30-90 minutes)

**Solution**: Wait longer, then re-run compliance check. First compliance scan can take up to 90 minutes.

---

### Issue: Auto-remediation policies not fixing resources

**Checklist**:
- [ ] Did you provide `-IdentityResourceId` parameter?
- [ ] Does managed identity have Contributor role?
- [ ] Did you wait 30-60 minutes for remediation tasks to complete?
- [ ] Check remediation status: `Get-AzPolicyRemediation -Scope '/subscriptions/<subscription-id>'`

---

## 📋 Post-Deployment Checklist

- [ ] **Document Deployment**: Record deployment date, scenario used, subscription ID in change log
- [ ] **Notify Stakeholders**: Email teams about new governance policies
- [ ] **Schedule Review**: Set calendar reminder to review compliance in 30 days
- [ ] **Backup Configuration**: Save policy assignment IDs for audit trail
- [ ] **Test Key Vault Creation**: Verify new Key Vault deployments work (Audit mode) or are blocked appropriately (Deny mode)

---

## 📞 Support & Escalation

### Self-Service Resources
1. **QUICKSTART.md** - Quick reference guide
2. **DEPLOYMENT-PREREQUISITES.md** - Prerequisites and RBAC details
3. **WORKFLOW-TESTING-GUIDE.md** - Testing procedures
4. **PolicyParameters-QuickReference.md** - Parameter file selection guide

### Escalation Path
1. **Level 1**: Review documentation above
2. **Level 2**: Check GitHub repository issues (if available)
3. **Level 3**: Contact Azure administrator for RBAC or subscription access issues
4. **Level 4**: Azure Support (if subscription includes support plan)

---

## ✅ Success Criteria

Deployment is considered successful when:

- ✅ All policy assignments visible in Azure Portal → Policy → Assignments
- ✅ HTML compliance report generated without errors
- ✅ Console output shows scenario-specific next steps
- ✅ No [ERROR] messages in logs (warnings about cryptographicType are OK)
- ✅ Compliance scan completes after 30-60 minute wait
- ✅ Key Vault resources show compliance status in report

---

**Checklist Version**: 1.0  
**Last Updated**: 2026-01-22  
**Estimated Completion Time**: 25 minutes (first deployment) | 10 minutes (subsequent deployments)
