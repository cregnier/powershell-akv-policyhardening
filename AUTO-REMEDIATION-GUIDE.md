# Auto-Remediation Guide - Azure Policy DINE/Modify Policies

**Version**: 1.0  
**Date**: January 26, 2026  
**Status**: Production Ready

---

## 📋 Table of Contents

1. [What is Auto-Remediation?](#what-is-auto-remediation)
2. [The 5 W's + How](#the-5-ws--how)
3. [Value Proposition](#value-proposition)
4. [8 Auto-Remediation Policies](#8-auto-remediation-policies)
5. [When to Use Auto-Remediation](#when-to-use-auto-remediation)
6. [How It Works (Timeline)](#how-it-works-timeline)
7. [Requirements](#requirements)
8. [Scenarios Using Auto-Remediation](#scenarios-using-auto-remediation)
9. [⚠️ Critical Warnings and Caveats](#-critical-warnings-and-caveats)
10. [Testing Process](#testing-process)
11. [Real-World Example](#real-world-example)
12. [Troubleshooting](#troubleshooting)

---

## What is Auto-Remediation?

**Auto-remediation** = Policies that automatically **FIX** non-compliant resources instead of just reporting them.

### Three Policy Enforcement Modes

| Mode | Effect | Action | Use Case | Scenarios |
|------|--------|--------|----------|-----------|
| **Audit** | AuditIfNotExists | Monitors only, reports violations | Discovery, baseline assessment | 2, 3, 5 |
| **Deny** | Deny | Blocks NEW non-compliant resources | Prevent future violations | 6 |
| **DINE/Modify** | DeployIfNotExists, Modify | Auto-fixes EXISTING non-compliant resources | Enterprise-scale remediation | 4, 7 |

**Key Difference**:
- **Audit/Deny**: Passive (report or block)
- **DINE/Modify**: Active (create resources or modify settings)

---

## The 5 W's + How

### WHO Should Use Auto-Remediation?
- **Enterprise IT teams** managing 50+ Key Vaults
- **Security teams** enforcing compliance at scale
- **DevOps teams** maintaining consistent configurations
- **Cloud architects** implementing Zero Trust policies

### WHAT Does It Do?
Auto-remediation policies perform **two types of actions**:

1. **DeployIfNotExists (DINE)** - Creates missing resources:
   - Private endpoints
   - Diagnostic settings
   - Private DNS zone links
   - Monitoring configurations

2. **Modify** - Changes existing resource properties:
   - Disables public network access
   - Enables firewall
   - Updates network ACLs

### WHEN Should You Use It?

**✅ Use Auto-Remediation When:**
- You have 50+ existing Key Vaults deployed before policies
- Manual remediation would take weeks/months
- You need consistent configurations across all vaults
- Compliance audit deadlines are approaching
- Cost of manual labor exceeds Azure automation costs

**❌ DO NOT Use Auto-Remediation When:**
- You have <10 Key Vaults (manual fix faster)
- Production applications haven't been tested with private endpoints
- Stakeholders haven't approved network changes
- You skipped testing in Scenario 4 (DevTest)
- Maintenance window not scheduled

### WHERE Is It Applied?
- **Subscription scope**: All Key Vaults in subscription
- **Resource Group scope**: Key Vaults in specific RG (testing only)
- **Management Group scope**: Enterprise-wide (future capability)

### WHY Is It Needed?

**Problem**: Legacy Key Vaults deployed before governance policies existed

**Common Issues**:
- 85% missing diagnostic logging (audit trail gaps)
- 70% have public network access enabled (security risk)
- 60% lack private endpoints (not Zero Trust compliant)
- 50% have firewall disabled (attack surface)

**Manual Remediation Challenges**:
- Time: 15-30 min per vault × 100 vaults = 25-50 hours
- Cost: $150/hr × 50 hrs = $7,500 labor
- Errors: Human mistakes on 5-10% of vaults
- Consistency: Configurations drift across teams/regions

**Auto-Remediation Solution**:
- Time: 60-90 minutes (Azure handles all vaults)
- Cost: $0 (included in Azure Policy service)
- Errors: 0% (standardized templates)
- Consistency: 100% identical configurations

### HOW Does It Work?

**Technical Flow**:
1. **Policy Assignment**: Azure Resource Manager creates policy assignment with managed identity
2. **Resource Evaluation**: Azure Policy scans resources every 30-90 minutes
3. **Compliance Detection**: Non-compliant resources identified
4. **Remediation Task Creation**: Azure creates remediation tasks for DINE/Modify policies
5. **Task Execution**: Managed identity deploys resources or modifies settings
6. **Compliance Update**: Next scan shows resources as compliant

**Timeline**:
- T+0 min: Deploy policies
- T+15-30 min: First resource evaluation
- T+30-60 min: Remediation tasks created
- T+45-90 min: Remediation tasks complete
- T+60-120 min: Next evaluation shows compliance

---

## Value Proposition

### Cost Savings

**Scenario**: 150 Key Vaults with 850 violations

| Metric | Manual Remediation | Auto-Remediation | Savings |
|--------|-------------------|------------------|---------|
| **Time** | 80 hours (2 weeks) | 90 minutes | 98.1% time savings |
| **Labor Cost** | $12,000 ($150/hr) | $0 | $12,000 saved |
| **Error Rate** | 5-10% (7-15 vaults) | 0% | Zero config drift |
| **Consistency** | Variable | 100% identical | Perfect compliance |
| **Ongoing** | Manual per vault | Automatic | Zero maintenance |

### Risk Reduction

| Risk | Manual Process | Auto-Remediation |
|------|---------------|------------------|
| **Human Error** | High (typos, wrong subnets) | Zero (template-based) |
| **Configuration Drift** | Gradual over time | Prevented automatically |
| **Audit Trail** | Incomplete (manual logging) | Complete (Azure Activity Log) |
| **Rollback** | Manual, error-prone | Automated with policy removal |
| **Documentation** | Often missing | Self-documenting in policy |

### Operational Efficiency

**Without Auto-Remediation**:
- New Key Vault deployed → Manual checklist (30 min)
- Quarterly audit → Find violations → Manual fix (hours/days)
- Team onboarding → Train on 46 policies → Errors happen

**With Auto-Remediation**:
- New Key Vault deployed → Auto-fixed within 60 min
- Quarterly audit → Zero violations (continuous compliance)
- Team onboarding → Policies enforce automatically → Zero errors

---

## 8 Auto-Remediation Policies

### DeployIfNotExists Policies (6 total)

#### 1. Configure Azure Key Vault Managed HSM with Private Endpoints
- **Effect**: DeployIfNotExists
- **Action**: Creates private endpoint for Managed HSM
- **Resources Created**: Microsoft.Network/privateEndpoints
- **Parameters**: `privateEndpointSubnetId`
- **Impact**: Disables direct public access, requires VNet connectivity
- **Testing**: kv-noncompliant-* should trigger this in Scenario 4

#### 2. Configure Azure Key Vaults to use Private DNS Zones
- **Effect**: DeployIfNotExists
- **Action**: Links private endpoint to DNS zone `privatelink.vaultcore.azure.net`
- **Resources Created**: Microsoft.Network/privateDnsZoneGroups
- **Parameters**: `privateDnsZoneId`
- **Impact**: DNS resolution for private endpoints
- **Testing**: Requires private endpoint creation first

#### 3. Deploy Diagnostic Settings for Key Vault to Event Hub
- **Effect**: DeployIfNotExists
- **Action**: Streams audit logs to Event Hub
- **Resources Created**: Microsoft.Insights/diagnosticSettings
- **Parameters**: `eventHubRuleId`, `eventHubLocation`
- **Impact**: Audit trail for SIEM/monitoring tools
- **Testing**: Check Event Hub namespace for incoming logs

#### 4. Deploy - Configure Diagnostic Settings to Event Hub (Managed HSM)
- **Effect**: DeployIfNotExists
- **Action**: Streams Managed HSM logs to Event Hub
- **Resources Created**: Microsoft.Insights/diagnosticSettings
- **Parameters**: `eventHubRuleId`, `eventHubLocation`
- **Impact**: Audit trail for Managed HSM operations
- **Testing**: Check diagnosticSettings resource exists

#### 5. Deploy - Configure Diagnostic Settings for Key Vault to Log Analytics
- **Effect**: DeployIfNotExists
- **Action**: Sends logs to Log Analytics workspace
- **Resources Created**: Microsoft.Insights/diagnosticSettings
- **Parameters**: `logAnalytics`
- **Impact**: Centralized logging, 90-day retention
- **Testing**: Query Log Analytics for AuditEvent logs

#### 6. Configure Azure Key Vaults with Private Endpoints
- **Effect**: DeployIfNotExists
- **Action**: Creates private endpoint for Key Vault
- **Resources Created**: Microsoft.Network/privateEndpoints
- **Parameters**: `privateEndpointSubnetId`
- **Impact**: Disables public access, requires VNet connectivity
- **Testing**: Check vault shows "Private endpoint connections"

### Modify Policies (2 total)

#### 7. Configure Azure Key Vault Managed HSM to Disable Public Network Access
- **Effect**: Modify
- **Action**: Sets `properties.publicNetworkAccess = 'Disabled'`
- **Resources Modified**: Microsoft.KeyVault/managedHSMs
- **Parameters**: None (always disables)
- **Impact**: **BREAKING** - Public connections fail immediately
- **Testing**: Verify `publicNetworkAccess` property changed

#### 8. Configure Key Vaults to Enable Firewall
- **Effect**: Modify
- **Action**: Sets `properties.networkAcls.defaultAction = 'Deny'`
- **Resources Modified**: Microsoft.KeyVault/vaults
- **Parameters**: None (always enables)
- **Impact**: **BREAKING** - Unauthorized IPs blocked
- **Testing**: Verify `networkAcls.defaultAction = 'Deny'`

---

## When to Use Auto-Remediation

### Decision Matrix

| Situation | Scenario | Recommended Action |
|-----------|----------|-------------------|
| **Initial Testing** | New to Azure Policy | Scenario 4 (DevTest Auto-Remediation) |
| **Few Vaults (<10)** | Manual fix faster | Manual configuration, skip auto-remediation |
| **Many Vaults (50+)** | Enterprise scale | Scenario 7 (Production Auto-Remediation) |
| **Greenfield Deployment** | No existing vaults | Use Deny mode (Scenario 6), skip remediation |
| **Brownfield Deployment** | 100+ existing vaults | **Mandatory** auto-remediation (Scenario 7) |
| **Compliance Audit** | Deadline in 30 days | Scenario 5 (Audit) → Scenario 7 (Remediation) |
| **Zero Trust Migration** | Moving to private endpoints | Scenario 4 testing → Scenario 7 production |

### Phased Rollout Strategy

**Phase 1: Discovery (Scenario 2 or 3)**
- Deploy Audit policies for 30-90 days
- Identify non-compliant resources
- Estimate remediation scope
- Review compliance reports weekly

**Phase 2: Prevention (Scenario 6)**
- Deploy Deny policies to block new violations
- Test with development teams (60-90 days)
- Validate no critical automations broken
- Adjust policies if needed

**Phase 3: Remediation (Scenario 7)**
- Deploy Auto-Remediation policies (DINE/Modify)
- Schedule maintenance window (Saturday 2am-6am)
- Notify stakeholders 7-14 days in advance
- Monitor remediation tasks in Azure Portal
- Validate compliance after 24 hours

---

## How It Works (Timeline)

### Detailed Execution Flow

```
T+0 min     Deploy Policies
            ├── Policy assignments created at subscription scope
            ├── Managed identity assigned to DINE/Modify policies
            └── Policies active immediately

T+15-30 min First Resource Evaluation
            ├── Azure Policy scans all Key Vaults
            ├── Compliance states calculated
            └── Non-compliant resources identified

T+30-60 min Remediation Tasks Created
            ├── Azure creates remediation tasks for DINE/Modify policies
            ├── Tasks queued for execution
            └── Managed identity permissions validated

T+45-90 min Remediation Tasks Execute
            ├── DINE policies: Create missing resources
            │   ├── Private endpoints
            │   ├── Diagnostic settings
            │   └── DNS zone links
            ├── Modify policies: Update resource properties
            │   ├── Disable public network access
            │   └── Enable firewall
            └── Azure Activity Log records all changes

T+60-120 min Next Evaluation Cycle
             ├── Resources re-evaluated
             ├── Compliance states updated
             └── Report shows "Compliant" status
```

### What Happens Behind the Scenes

1. **Policy Engine**: Evaluates resource against policy rule
2. **Compliance Detection**: Determines if `then.details.deployment` needed
3. **Identity Validation**: Checks managed identity has required permissions
4. **Template Rendering**: Generates ARM template from policy definition
5. **Deployment**: Calls Azure Resource Manager to create/modify resources
6. **Retry Logic**: Up to 3 retries if deployment fails
7. **Logging**: All actions logged to Azure Activity Log

---

## Requirements

### Mandatory Infrastructure (Phase 1)

Before deploying auto-remediation policies, **ALL** infrastructure must exist:

✅ **Managed Identity**: `id-policy-remediation`
- Location: rg-policy-remediation
- Type: User-Assigned Managed Identity
- Created by: `Setup-AzureKeyVaultPolicyEnvironment.ps1`

✅ **RBAC Roles**: Assigned to managed identity at **subscription scope**:
1. **Contributor** - Create/modify resources
2. **Network Contributor** - Manage private endpoints/DNS
3. **Log Analytics Contributor** - Configure diagnostic settings
4. **Private DNS Zone Contributor** - Link DNS zones

✅ **Log Analytics Workspace**: `law-policy-test-*`
- Location: rg-policy-remediation
- Purpose: Diagnostic settings destination
- Retention: 90 days (configurable)

✅ **Event Hub Namespace**: `eh-policy-test-*`
- Location: rg-policy-remediation
- Purpose: Diagnostic streaming for SIEM
- Auth Rule: RootManageSharedAccessKey

✅ **Private DNS Zone**: `privatelink.vaultcore.azure.net`
- Location: rg-policy-remediation
- Purpose: Private endpoint DNS resolution
- Linked VNets: vnet-policy-test

✅ **VNet + Subnet**: `vnet-policy-test` / `subnet-keyvault`
- Location: rg-policy-keyvault-test
- Address Space: 10.0.0.0/16
- Subnet: 10.0.1.0/24
- Purpose: Private endpoint connectivity

### Validation Command

```powershell
.\AzPolicyImplScript.ps1 -TestInfrastructure -Detailed
```

**Expected Output**:
```
✅ Managed Identity: id-policy-remediation exists
✅ Identity Roles: Contributor, Network Contributor, Log Analytics Contributor, Private DNS Zone Contributor
✅ Log Analytics: law-policy-test-6874 exists
✅ Event Hub: eh-policy-test-3464 exists
✅ Private DNS: privatelink.vaultcore.azure.net exists
✅ VNet: vnet-policy-test exists
✅ Subnet: subnet-keyvault exists (10.0.1.0/24)
✅ Test Vaults: 3 found (kv-compliant-*, kv-partial-*, kv-noncompliant-*)
```

---

## Scenarios Using Auto-Remediation

### Scenario 4: DevTest Auto-Remediation (Testing)

**Purpose**: Validate DINE/Modify policies work correctly before production

**Parameter File**: `PolicyParameters-DevTest-Full-Remediation.json`

**Policies**: 46 total (38 Audit + 8 DINE/Modify)

**Command**:
```powershell
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -PolicyMode Enforce `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck
```

**Expected Results**:
- 3 test vaults evaluated
- kv-noncompliant-* triggers 8 remediation tasks
- kv-partial-* triggers 2-4 remediation tasks
- kv-compliant-* triggers 0 remediation tasks

**Validation**:
```powershell
.\AzPolicyImplScript.ps1 -TestAutoRemediation
```

**Wait Time**: 30-60 minutes for Azure Policy evaluation

---

### Scenario 7: Production Auto-Remediation (Enforcement)

**Purpose**: Fix ALL existing non-compliant Key Vaults in production

**Parameter File**: `PolicyParameters-Production-Remediation.json`

**Policies**: 46 total (38 Audit + 8 DINE/Modify)

**Prerequisites**:
✅ Scenario 5 (Production-Audit) completed - violations identified  
✅ Scenario 6 (Production-Deny) validated - new resources blocked  
✅ Scenario 4 testing passed - remediation works correctly  
✅ Maintenance window scheduled - off-peak hours  
✅ Stakeholders notified - 7-14 days advance notice  
✅ Rollback plan documented - policy removal procedure  

**Command**:
```powershell
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# PRODUCTION - Use with caution!
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -PolicyMode Enforce `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck
```

**Monitoring**:
1. Azure Portal → Policy → Remediation Tasks
2. Azure Portal → Activity Log → Filter by "Microsoft.PolicyInsights"
3. Compliance Dashboard → Check after 60-90 minutes

**Rollback** (if needed):
```powershell
.\AzPolicyImplScript.ps1 -Rollback
```

---

## ⚠️ Critical Warnings and Caveats

### 🚨 PRODUCTION IMPACT WARNINGS

#### Warning 1: Network Connectivity Breaking Changes

**Modify Policy: Disable Public Network Access**

```
⚠️  CRITICAL: This policy will IMMEDIATELY block public access to Managed HSM
```

**Impact**:
- ❌ Applications using public endpoints WILL FAIL
- ❌ Azure Portal access WILL FAIL (requires VPN/ExpressRoute)
- ❌ CI/CD pipelines WILL FAIL (unless running in VNet)
- ❌ Developer workstations WILL FAIL (unless VPN connected)

**Mitigation**:
1. Ensure private endpoints deployed BEFORE disabling public access
2. Test VNet connectivity from all application tiers
3. Update connection strings to use private endpoint DNS
4. Schedule during maintenance window (2am-6am)

---

#### Warning 2: Firewall Breaking Changes

**Modify Policy: Enable Firewall**

```
⚠️  CRITICAL: This policy will IMMEDIATELY block unauthorized IP addresses
```

**Impact**:
- ❌ Connections from non-whitelisted IPs FAIL
- ❌ Azure services (App Service, Functions) FAIL unless "Allow trusted services" enabled
- ❌ Developer access FAILS unless IP whitelisted

**Mitigation**:
1. Whitelist all required IP addresses BEFORE enabling firewall
2. Enable "Allow trusted Microsoft services" bypass
3. Test from all application environments (dev/staging/prod)
4. Document IP whitelist in runbook

---

#### Warning 3: Azure Policy Evaluation Delays

```
⚠️  TIMING: Remediation tasks NOT created immediately
```

**Timeline Reality**:
- Policy assignment: Immediate
- First evaluation: 15-30 minutes
- Remediation task creation: 30-60 minutes
- Task execution: 45-90 minutes
- Compliance update: 60-120 minutes

**Do NOT**:
- ❌ Expect instant remediation
- ❌ Check compliance within first 15 minutes
- ❌ Assume failure if no tasks after 10 minutes

**Do**:
- ✅ Wait minimum 30 minutes before checking remediation tasks
- ✅ Trigger manual scan: `Start-AzPolicyComplianceScan`
- ✅ Check Azure Activity Log for deployment events

---

#### Warning 4: Managed Identity Permission Failures

```
⚠️  CRITICAL: Missing RBAC roles = Silent remediation failures
```

**Symptoms**:
- Remediation tasks show "Failed" status
- Error: "The client '...' with object id '...' does not have authorization"
- Compliance remains "Non-Compliant" after 2+ hours

**Solution**:
```powershell
# Verify roles assigned
$identityId = "/subscriptions/.../id-policy-remediation"
Get-AzRoleAssignment -ObjectId (Get-AzUserAssignedIdentity -ResourceId $identityId).PrincipalId

# Should show:
# Contributor
# Network Contributor  
# Log Analytics Contributor
# Private DNS Zone Contributor
```

---

#### Warning 5: Resource Limits and Quotas

```
⚠️  CAPACITY: Auto-remediation may hit Azure subscription limits
```

**Potential Quota Issues**:
- Private Endpoints: Default limit 1,000 per subscription
- Diagnostic Settings: 5 per resource (our policies create 3)
- Event Hub Namespaces: Varies by region/SKU
- VNet Subnets: IP address exhaustion

**Pre-Flight Check**:
```powershell
# Check private endpoint quota
Get-AzNetworkUsage -Location eastus | Where-Object {$_.Name.Value -eq 'PrivateEndpoints'}

# Check available subnet IPs
$subnet = Get-AzVirtualNetworkSubnetConfig -Name subnet-keyvault -VirtualNetwork (Get-AzVirtualNetwork -Name vnet-policy-test -ResourceGroupName rg-policy-keyvault-test)
$subnet.IpConfigurations.Count  # Should be < 250 for /24 subnet
```

---

### 🛡️ Safety Checks Before Production

**Mandatory Validation Checklist**:

```
☐ 1. Scenario 4 (DevTest) passed successfully
☐ 2. All 8 DINE/Modify policies tested with kv-noncompliant-*
☐ 3. Private endpoint connectivity validated from apps
☐ 4. Firewall IP whitelists documented and approved
☐ 5. Managed identity has all 4 required RBAC roles
☐ 6. Maintenance window scheduled (off-peak hours)
☐ 7. Stakeholders notified 7-14 days in advance
☐ 8. Rollback procedure tested in dev environment
☐ 9. Azure subscription quotas checked (private endpoints)
☐ 10. Monitoring alerts configured for policy violations
☐ 11. Change request approved (if required by governance)
☐ 12. On-call engineer available during deployment
```

**If ANY checkbox unchecked → DO NOT DEPLOY TO PRODUCTION**

---

### 🎯 User Choice: When to Deploy Auto-Remediation

The script provides **flexibility** for users to deploy auto-remediation at the right time:

**Option 1: Deploy Immediately (Scenario 4 or 7)**
- For users confident in infrastructure readiness
- When Scenario 4 testing already completed
- When maintenance window scheduled

**Option 2: Deploy Later (Skip Scenario 4/7)**
- When testing not yet complete
- When production impact assessment needed
- When stakeholder approval pending

**Script Supports Both**:
```powershell
# Now (Scenario 4)
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json ...

# Later (manual decision)
# Skip Scenario 4, continue with Scenario 5-6
# Return to Scenario 4/7 when ready
```

**Terminal Output Includes**:
```
⚠️  You are deploying auto-remediation policies (DINE/Modify)
⚠️  These policies will MODIFY production resources automatically
⚠️  Ensure you have completed Scenario 4 testing first
⚠️  Recommended: Schedule maintenance window for deployment

Continue? (Y/N) [N]: _
```

---

## Testing Process

### Scenario 4: Auto-Remediation Testing

**Step 1: Deploy Auto-Remediation Policies**

```powershell
# Get managed identity resource ID
$identityId = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-remediation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-policy-remediation"

# Deploy
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -PolicyMode Enforce `
    -IdentityResourceId $identityId `
    -ScopeType Subscription `
    -SkipRBACCheck
```

**Expected Output**:
```
✅ Created 46 policy assignments
✅ 8 DINE/Modify policies assigned with managed identity:
   • Configure Azure Key Vault Managed HSM with private endpoints
   • Configure Azure Key Vaults to use private DNS zones
   • Deploy Diagnostic Settings for Key Vault to Event Hub
   • Deploy - Configure diagnostic settings to Event Hub (Managed HSM)
   • Deploy - Configure diagnostic settings to Log Analytics
   • Configure Azure Key Vaults with private endpoints
   • Configure Azure Key Vault Managed HSM to disable public network access (Modify)
   • Configure key vaults to enable firewall (Modify)
```

---

**Step 2: Wait for Azure Policy Evaluation**

```
⏰ Timeline:
  T+0 min   : Policies deployed
  T+15 min  : First evaluation (check compliance)
  T+30 min  : Remediation tasks created
  T+60 min  : Remediation tasks complete
  T+90 min  : Next evaluation shows compliance
```

**During Wait**:
- Monitor Azure Portal → Policy → Compliance
- Check Azure Portal → Policy → Remediation Tasks
- Review Azure Activity Log for deployment events

---

**Step 3: Run Auto-Remediation Test**

```powershell
.\AzPolicyImplScript.ps1 -TestAutoRemediation
```

**Test Validates**:
1. ✅ kv-noncompliant-* has diagnostic settings (DINE policy worked)
2. ✅ kv-noncompliant-* has private endpoint (DINE policy worked)
3. ✅ kv-noncompliant-* firewall enabled (Modify policy worked)
4. ✅ kv-partial-* has diagnostic settings (DINE policy worked)
5. ✅ kv-compliant-* unchanged (already compliant)

**Expected Test Output**:
```
╔═══════════════════════════════════════════════════════════════╗
║      Auto-Remediation Policy Testing                         ║
╚═══════════════════════════════════════════════════════════════╝

Testing vault: kv-noncompliant-8891
  ✅ Diagnostic settings found (auto-remediation worked!)
  ✅ Private endpoint created (auto-remediation worked!)
  ✅ Firewall enabled: defaultAction = Deny (Modify policy worked!)

Testing vault: kv-partial-3147
  ✅ Diagnostic settings found (auto-remediation worked!)
  ⚠️  Private endpoint missing (may still be deploying, check again in 30 min)

Testing vault: kv-compliant-9487
  ✅ Already compliant - no remediation needed

═══ AUTO-REMEDIATION TEST SUMMARY ═══
  ✅ PASS: 8/8 DINE/Modify policies working
  ✅ kv-noncompliant-8891: Remediated successfully
  ✅ kv-partial-3147: Partially remediated (in progress)
  ✅ kv-compliant-9487: Already compliant
```

---

**Step 4: Verify Compliance Report**

```powershell
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan
```

**Expected Report**:
```
═══ Compliance Summary ═══
  Overall Compliance: 85-95% (was 25-35% before remediation)
  Policies Reporting: 11-15 / 46
  Resources Evaluated: 12 Key Vaults
  Compliant: 40-45 (was 34)
  Non-Compliant: 5-10 (was 98)
```

---

**Step 5: Check Remediation Tasks (Azure Portal)**

1. Navigate to: **Azure Portal** → **Policy** → **Remediation**
2. Filter: `PolicyAssignmentId contains "KeyVault"`
3. Verify tasks:
   - ✅ Status: Succeeded
   - ✅ Resources: 3 test vaults
   - ✅ Timestamp: Within last 90 minutes

---

## Real-World Example

### Enterprise Scenario: 150 Key Vaults

**Company**: Mid-size enterprise (5,000 employees)  
**Azure Footprint**: 3 subscriptions, 150 Key Vaults deployed over 3 years  
**Compliance Requirement**: Zero Trust by end of quarter (90 days)

---

#### BEFORE Auto-Remediation (Manual Process)

**Audit Results** (from Scenario 5):
```
Overall Compliance: 15%
Total Violations: 850
Non-Compliant Key Vaults: 142/150 (95%)

Breakdown:
  ❌ 120 vaults: No diagnostic logging (80%)
  ❌ 95 vaults: Public network access enabled (63%)
  ❌ 80 vaults: No private endpoints (53%)
  ❌ 65 vaults: Firewall disabled (43%)
  ❌ 50 vaults: No soft delete or purge protection (33%)
```

**Manual Remediation Estimate**:
```
Time Required:
  • 15 min per vault (basic configs)
  • 30 min per vault (private endpoints)
  • Average: 20 min × 150 vaults = 50 hours = 2 weeks

Labor Cost:
  • Senior Engineer: $150/hr × 50 hrs = $7,500
  • Cloud Architect (oversight): $200/hr × 10 hrs = $2,000
  • Total: $9,500

Error Rate:
  • Human errors: 5-10% of vaults (7-15 misconfigurations)
  • Rework: +5 hours = $750
  • Total with errors: $10,250

Timeline:
  • Week 1: Plan and document (10 hrs)
  • Week 2-3: Execute changes (50 hrs)
  • Week 4: Validation and rework (10 hrs)
  • Total: 4 weeks
```

---

#### AFTER Auto-Remediation (Azure Policy)

**Deployment** (Scenario 7):
```powershell
# Saturday 2am EST (off-peak)
.\AzPolicyImplScript.ps1 `
    -ParameterFile .\PolicyParameters-Production-Remediation.json `
    -PolicyMode Enforce `
    -IdentityResourceId $identityId `
    -ScopeType Subscription
```

**Timeline**:
```
T+0 min (2:00am): Policies deployed
T+30 min (2:30am): First evaluation complete, 850 violations detected
T+60 min (3:00am): Remediation tasks created for 142 vaults
T+90 min (3:30am): Tasks executing
  • Creating 120 diagnostic settings
  • Creating 80 private endpoints
  • Linking 80 DNS zones
  • Modifying 95 vaults (disable public access)
  • Modifying 65 vaults (enable firewall)
T+120 min (4:00am): All remediation tasks complete
T+150 min (4:30am): Next evaluation shows 95% compliance
```

**Results**:
```
Overall Compliance: 95% (from 15%)
Total Violations: 42 (from 850)
Remediation Time: 2.5 hours (vs 4 weeks)
Labor Cost: $0 (vs $10,250)
Error Rate: 0% (vs 5-10%)
Configuration Consistency: 100% identical
```

---

#### Cost-Benefit Analysis

| Metric | Manual | Auto-Remediation | Savings |
|--------|--------|------------------|---------|
| **Time** | 4 weeks | 2.5 hours | **99.3% faster** |
| **Cost** | $10,250 | $0 | **$10,250 saved** |
| **Errors** | 7-15 vaults | 0 vaults | **100% accuracy** |
| **Consistency** | Variable | 100% identical | **Perfect compliance** |
| **Documentation** | Manual (often incomplete) | Self-documenting | **Audit-ready** |
| **Ongoing** | Manual per vault | Auto-fix within 60 min | **Zero maintenance** |

**ROI**: $10,250 saved / $0 invested = **Infinite ROI**

---

#### Ongoing Benefits (Post-Deployment)

**Scenario**: New Key Vault deployed by dev team

**Without Auto-Remediation**:
1. Developer creates vault with default settings
2. Security team finds violation in quarterly audit
3. Ticket created for remediation
4. Engineer spends 30 min fixing
5. **Total time to compliance**: 30-90 days

**With Auto-Remediation**:
1. Developer creates vault with default settings
2. Azure Policy evaluates within 30 minutes
3. Remediation task auto-fixes violations
4. Vault compliant within 60 minutes
5. **Total time to compliance**: 60 minutes

**Savings per New Vault**:
- Time: 30 min (manual) → 0 min (automatic) = 30 min saved
- Cost: $75 (engineer time) → $0 = $75 saved
- If 20 new vaults/year: 20 × $75 = **$1,500 annual savings**

---

## Troubleshooting

### Issue 1: Remediation Tasks Not Created

**Symptoms**:
- 60+ minutes after deployment
- Azure Portal → Policy → Remediation shows 0 tasks
- Compliance still shows "Non-Compliant"

**Diagnosis**:
```powershell
# Check policy assignments
Get-AzPolicyAssignment -Scope "/subscriptions/<sub-id>" | 
    Where-Object {$_.Properties.DisplayName -like "*KeyVault*"} |
    Select-Object Name, EnforcementMode, @{N='HasIdentity';E={$null -ne $_.Identity}}

# Should show:
# EnforcementMode = Default (NOT DoNotEnforce)
# HasIdentity = True (for DINE/Modify policies)
```

**Solutions**:
1. Verify policies deployed with `-PolicyMode Enforce` (not Audit)
2. Check managed identity assigned: `$assignment.Identity` should not be null
3. Trigger manual scan: `Start-AzPolicyComplianceScan -ResourceGroupName rg-policy-keyvault-test`
4. Wait full 90 minutes (Azure Policy backend delay)

---

### Issue 2: Remediation Tasks Failed

**Symptoms**:
- Azure Portal → Remediation → Status = "Failed"
- Error: "The client does not have authorization to perform action"

**Diagnosis**:
```powershell
# Check managed identity roles
$identity = Get-AzUserAssignedIdentity -ResourceGroupName rg-policy-remediation -Name id-policy-remediation
Get-AzRoleAssignment -ObjectId $identity.PrincipalId -Scope "/subscriptions/<sub-id>"
```

**Expected Roles** (all 4 required):
- Contributor
- Network Contributor
- Log Analytics Contributor
- Private DNS Zone Contributor

**Solution**:
```powershell
# Assign missing roles
$identityId = $identity.Id
New-AzRoleAssignment -ObjectId $identity.PrincipalId -RoleDefinitionName "Contributor" -Scope "/subscriptions/<sub-id>"
New-AzRoleAssignment -ObjectId $identity.PrincipalId -RoleDefinitionName "Network Contributor" -Scope "/subscriptions/<sub-id>"
# ... repeat for other roles
```

---

### Issue 3: Private Endpoint Creation Failed

**Symptoms**:
- Remediation task failed with "InvalidTemplateDeployment"
- Error: "Subnet does not exist" or "Subnet full"

**Diagnosis**:
```powershell
# Check subnet exists and has available IPs
Get-AzVirtualNetworkSubnetConfig -Name subnet-keyvault `
    -VirtualNetwork (Get-AzVirtualNetwork -Name vnet-policy-test -ResourceGroupName rg-policy-keyvault-test) |
    Select-Object Name, AddressPrefix, @{N='UsedIPs';E={$_.IpConfigurations.Count}}
```

**Solution**:
```powershell
# If subnet missing, create it
$vnet = Get-AzVirtualNetwork -Name vnet-policy-test -ResourceGroupName rg-policy-keyvault-test
Add-AzVirtualNetworkSubnetConfig -Name subnet-keyvault -AddressPrefix "10.0.1.0/24" -VirtualNetwork $vnet
$vnet | Set-AzVirtualNetwork

# If subnet full (/24 = 251 IPs max), expand or create new subnet
Set-AzVirtualNetworkSubnetConfig -Name subnet-keyvault -AddressPrefix "10.0.1.0/23" -VirtualNetwork $vnet
$vnet | Set-AzVirtualNetwork
```

---

### Issue 4: Diagnostic Settings Not Created

**Symptoms**:
- Remediation task shows "Succeeded" but no diagnostic settings on vault
- Log Analytics workspace shows no data

**Diagnosis**:
```powershell
# Check diagnostic settings on vault
Get-AzDiagnosticSetting -ResourceId "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>"
```

**Common Causes**:
1. Log Analytics workspace doesn't exist
2. Event Hub namespace doesn't exist
3. Workspace in different region (some policies region-specific)

**Solution**:
```powershell
# Verify infrastructure
Get-AzOperationalInsightsWorkspace -ResourceGroupName rg-policy-remediation
Get-AzEventHubNamespace -ResourceGroupName rg-policy-remediation

# If missing, run infrastructure setup
.\Setup-AzureKeyVaultPolicyEnvironment.ps1
```

---

### Issue 5: Modify Policy Not Changing Resource

**Symptoms**:
- Remediation task shows "Succeeded"
- Resource property unchanged (e.g., publicNetworkAccess still "Enabled")

**Diagnosis**:
```powershell
# Check current resource state
$vault = Get-AzKeyVault -VaultName kv-noncompliant-8891 -ResourceGroupName rg-policy-keyvault-test
$vault | Select-Object VaultName, PublicNetworkAccess, @{N='FirewallDefaultAction';E={$_.NetworkAcls.DefaultAction}}
```

**Common Causes**:
1. Azure Policy evaluation delay (wait 30 more minutes)
2. Policy parameter mismatch (effect = Audit instead of Modify)
3. Resource locked by another operation

**Solution**:
```powershell
# Trigger manual remediation task
Start-AzPolicyRemediation -Name "ManualRemediation-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    -PolicyAssignmentId "/subscriptions/<sub-id>/providers/Microsoft.Authorization/policyAssignments/<assignment-name>" `
    -ResourceGroupName rg-policy-keyvault-test
```

---

## Summary

### Key Takeaways

✅ **What**: Policies that auto-fix non-compliant resources (DINE/Modify)  
✅ **Why**: Enterprise-scale compliance without manual labor  
✅ **When**: After Audit (Scenario 5) and Deny (Scenario 6) validation  
✅ **Where**: Subscription scope (all Key Vaults)  
✅ **How**: Azure Policy with managed identity executes ARM templates  

### Value Proposition

- **Time Savings**: 99% faster (90 min vs 2 weeks)
- **Cost Savings**: $10,000+ per deployment
- **Accuracy**: 0% error rate vs 5-10% manual
- **Consistency**: 100% identical configurations
- **Ongoing**: Auto-fix within 60 min for new vaults

### Critical Warnings

🚨 **Test in Scenario 4 FIRST** - Never deploy to production without testing  
🚨 **Schedule Maintenance Window** - Network changes can break apps  
🚨 **Notify Stakeholders** - 7-14 days advance notice required  
🚨 **Verify Infrastructure** - All 7 resources must exist before deployment  
🚨 **Wait 60-90 Minutes** - Azure Policy evaluation not instant  

### Next Steps

1. ✅ Complete Scenario 4 testing
2. ✅ Review compliance reports
3. ✅ Schedule production deployment
4. ✅ Deploy Scenario 7 during maintenance window
5. ✅ Monitor remediation tasks
6. ✅ Validate compliance after 24 hours

---

**Questions or Issues?**  
Review [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) or check Azure Activity Log for deployment errors.
