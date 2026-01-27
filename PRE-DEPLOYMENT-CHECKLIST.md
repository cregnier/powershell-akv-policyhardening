# Azure Key Vault Policy Governance - Pre-Deployment Checklist

**Version**: 1.0  
**Last Updated**: January 20, 2026  
**Purpose**: Comprehensive go/no-go checklist for Azure Policy deployment

---

## 📋 HOW TO USE THIS CHECKLIST

1. **Print or open this checklist** before starting each deployment phase
2. **Check each box** as you complete validation steps
3. **Document findings** in the "Notes" section for each phase
4. **Get stakeholder approval** before proceeding to production phases
5. **Archive completed checklists** for audit trail and compliance

---

## ✅ PHASE 1: Infrastructure Setup

### Prerequisites Validation

- [ ] **Azure Subscription Access**
  - Subscription ID confirmed: ___________________________
  - Owner or Contributor role assigned
  - Verified with: `Get-AzRoleAssignment -SignInName <your-email>`

- [ ] **PowerShell Environment**
  - PowerShell 7.x or later installed
  - Version confirmed: `$PSVersionTable.PSVersion`
  - Az modules installed (Az.Accounts, Az.Resources, Az.PolicyInsights, Az.Monitor, Az.KeyVault)
  - Verified with: `Get-Module -ListAvailable -Name Az.*`

- [ ] **Azure Authentication**
  - Successfully authenticated to Azure
  - Correct subscription selected
  - Command: `Connect-AzAccount; Set-AzContext -SubscriptionId <subscription-id>`

- [ ] **Resource Group Created**
  - Resource group name: ___________________________
  - Location: ___________________________
  - Command: `Get-AzResourceGroup -Name <rg-name>`

### Infrastructure Deployment Test

- [ ] **Setup Script Executed**
  - Command: `.\Setup-AzureKeyVaultPolicyEnvironment.ps1`
  - Execution successful (no errors)
  - Log Analytics workspace created
  - Event Hub namespace created
  - Managed Identity created (for auto-remediation)

- [ ] **Test Key Vaults Created** (DevTest only)
  - `kv-compliant-test` - All features enabled
  - `kv-non-compliant-test` - Missing soft delete and purge protection
  - `kv-partial-test` - Soft delete enabled, no purge protection

- [ ] **Infrastructure Test Passed**
  - Command: `.\AzPolicyImplScript.ps1 -TestInfrastructure -Detailed`
  - All 11 validation checks passed
  - Test results saved: `InfrastructureValidation-<timestamp>.csv`

### Go/No-Go Decision

**Status**: ☐ GO  ☐ NO-GO  ☐ CONDITIONAL

**Notes**:
```
______________________________________________________________________________
______________________________________________________________________________
______________________________________________________________________________
```

**Sign-off**: __________________________ Date: ______________

---

## ✅ PHASE 2: RBAC and Firewall Audit

### RBAC Configuration Analysis

- [ ] **Current Key Vault RBAC Audited**
  - Number of Key Vaults in scope: ___________
  - RBAC model vaults: ___________
  - Access Policy model vaults: ___________
  - Command: `Get-AzKeyVault | Where-Object { $_.EnableRbacAuthorization }`

- [ ] **RBAC Policy Impact Assessed**
  - Policy `9bfa6f9e-3c58-4ed4-9cfc-5d1ea13d38f7` (RBAC authorization should be used)
  - Number of vaults requiring conversion: ___________
  - Stakeholder approval for RBAC conversion: ☐ Yes  ☐ No

- [ ] **RBAC Conversion Plan Created**
  - Migration timeline: ___________________________
  - Team responsible: ___________________________
  - User communication plan: ☐ Complete  ☐ In Progress

### Firewall Configuration Analysis

- [ ] **Current Firewall Settings Audited**
  - Public network access enabled vaults: ___________
  - Private endpoint vaults: ___________
  - IP-restricted vaults: ___________
  - Command: `Get-AzKeyVault | Select-Object VaultName, PublicNetworkAccess`

- [ ] **Firewall Policy Impact Assessed**
  - Policy `14a49709-8e6d-4dc6-8ca3-c5abbe90ad91` (Public network access should be disabled)
  - Number of vaults requiring firewall: ___________
  - Application connectivity impact: ☐ Assessed  ☐ Needs Review

- [ ] **Firewall Configuration Plan Created**
  - Private endpoint deployment: ☐ Required  ☐ Not Required
  - IP allowlist created: ☐ Yes  ☐ No
  - Connectivity testing plan: ☐ Complete  ☐ In Progress

### Go/No-Go Decision

**Status**: ☐ GO  ☐ NO-GO  ☐ CONDITIONAL

**Notes**:
```
______________________________________________________________________________
______________________________________________________________________________
______________________________________________________________________________
```

**Sign-off**: __________________________ Date: ______________

---

## ✅ PHASE 3: Purge Protection Audit

### Current Purge Protection Status

- [ ] **Purge Protection Audited**
  - Soft delete enabled vaults: ___________
  - Purge protection enabled vaults: ___________
  - No soft delete vaults: ___________
  - Command: `Get-AzKeyVault | Select-Object VaultName, EnableSoftDelete, EnablePurgeProtection`

- [ ] **Purge Protection Policy Impact Assessed**
  - Policy `0b60c0b2-2dc2-4e1c-b5c9-abbed971de53` (Deletion protection should be enabled)
  - Number of vaults requiring purge protection: ___________
  - **⚠️ CRITICAL**: Once enabled, purge protection **cannot be disabled**

- [ ] **Stakeholder Approval for Purge Protection**
  - Security team approval: ☐ Yes  ☐ No
  - Compliance team approval: ☐ Yes  ☐ No
  - Application owners notified: ☐ Yes  ☐ No
  - Understanding of **permanent** nature: ☐ Confirmed

### Impact Analysis

- [ ] **Soft Delete Retention Period Reviewed**
  - Current retention: ___________ days (default: 90)
  - New retention: ___________ days (policy requirement)
  - Storage cost impact: ☐ Assessed  ☐ Needs Review

- [ ] **Vault Deletion Process Updated**
  - Documentation updated for purge requirement
  - Runbooks updated for 90-day retention
  - Team training completed: ☐ Yes  ☐ No

### Go/No-Go Decision

**Status**: ☐ GO  ☐ NO-GO  ☐ CONDITIONAL

**Notes**:
```
______________________________________________________________________________
______________________________________________________________________________
______________________________________________________________________________
```

**Sign-off**: __________________________ Date: ______________

---

## ✅ PHASE 4: DevTest Deployment (30 Policies, Audit Mode)

### Pre-Deployment Validation

- [ ] **Parameter File Reviewed**
  - File: `PolicyParameters-DevTest.json`
  - 30 policies configured
  - All policies in **Audit mode** (non-blocking)
  - Validity periods: 730 days (certificates), 730 days (keys/secrets)

- [ ] **Deployment Scope Confirmed**
  - Subscription ID: ___________________________
  - Resource group filter: ___________________________ (or "All")
  - Dry-run completed: ☐ Yes  ☐ No

- [ ] **DevTest Deployment Executed**
  - Command: `.\AzPolicyImplScript.ps1 -DeployDevTest -SkipRBACCheck`
  - Deployment successful: ☐ Yes  ☐ No
  - Policies assigned: ___________/30

### Compliance Monitoring

- [ ] **Initial Compliance Check**
  - Wait time: 24-48 hours for Azure Policy evaluation
  - Compliance check run: `.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan`
  - HTML report generated: `ComplianceReport-<timestamp>.html`

- [ ] **Test Key Vault Compliance Verified**
  - `kv-compliant-test`: ☐ 100% compliant  ☐ Issues found
  - `kv-non-compliant-test`: ☐ Expected non-compliance  ☐ Unexpected results
  - `kv-partial-test`: ☐ Expected partial compliance  ☐ Unexpected results

- [ ] **Compliance Data Quality**
  - Total policies reporting: ___________/30
  - Compliant resources: ___________%
  - Non-compliant resources: ___________%
  - No data / Not applicable: ___________%

### Go/No-Go Decision

**Status**: ☐ GO  ☐ NO-GO  ☐ CONDITIONAL

**Notes**:
```
______________________________________________________________________________
______________________________________________________________________________
______________________________________________________________________________
```

**Sign-off**: __________________________ Date: ______________

---

## ✅ PHASE 5: DevTest Full Deployment (46 Policies, Audit Mode)

### Pre-Deployment Validation

- [ ] **Parameter File Reviewed**
  - File: `PolicyParameters-DevTest-Full.json`
  - 46 policies configured
  - All policies in **Audit mode** (non-blocking)
  - Additional 16 policies beyond DevTest (keys, secrets, certificates, networking)

- [ ] **DevTest Full Deployment Executed**
  - Command: `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -SkipRBACCheck`
  - Deployment successful: ☐ Yes  ☐ No
  - Policies assigned: ___________/46

### Compliance Monitoring

- [ ] **Comprehensive Compliance Check**
  - Wait time: 24-48 hours for Azure Policy evaluation
  - Compliance check run: `.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan`
  - HTML report generated: `ComplianceReport-<timestamp>.html`

- [ ] **All Policy Categories Validated**
  - Vault configuration policies: ☐ Reporting  ☐ Issues
  - Key policies: ☐ Reporting  ☐ Issues
  - Secret policies: ☐ Reporting  ☐ Issues
  - Certificate policies: ☐ Reporting  ☐ Issues
  - Networking policies: ☐ Reporting  ☐ Issues
  - Monitoring policies: ☐ Reporting  ☐ Issues

- [ ] **Compliance Baseline Established**
  - Overall compliance percentage: ___________%
  - Acceptable threshold met (>= 50%): ☐ Yes  ☐ No
  - Non-compliant resources documented: ☐ Yes  ☐ No

### Go/No-Go Decision

**Status**: ☐ GO  ☐ NO-GO  ☐ CONDITIONAL

**Notes**:
```
______________________________________________________________________________
______________________________________________________________________________
______________________________________________________________________________
```

**Sign-off**: __________________________ Date: ______________

---

## ✅ PHASE 6: Production Audit Deployment (46 Policies, Audit Mode)

### Pre-Deployment Validation

- [ ] **Production Readiness Checklist**
  - Change request approved: ☐ Yes  ☐ No (Ticket #: _________)
  - Maintenance window scheduled: ☐ Yes  ☐ No (Date/Time: _________)
  - Rollback plan documented: ☐ Yes  ☐ No
  - Stakeholder notification sent: ☐ Yes  ☐ No

- [ ] **Parameter File Reviewed**
  - File: `PolicyParameters-Production.json`
  - 46 policies configured
  - All policies in **Audit mode** initially (non-blocking)
  - Production validity periods: 397 days (certificates), 730 days (keys/secrets)

- [ ] **Production Deployment Executed**
  - Command: `.\AzPolicyImplScript.ps1 -DeployProduction -SkipRBACCheck`
  - Deployment successful: ☐ Yes  ☐ No
  - Policies assigned: ___________/46

### Monitoring and Validation

- [ ] **Compliance Baseline Established**
  - Wait time: 24-48 hours for Azure Policy evaluation
  - Initial compliance percentage: ___________%
  - Non-compliant resources count: ___________
  - Priority remediation targets identified: ☐ Yes  ☐ No

- [ ] **Stakeholder Communication**
  - Compliance report shared with teams: ☐ Yes  ☐ No
  - Non-compliant resource owners notified: ☐ Yes  ☐ No
  - Remediation timeline communicated: ☐ Yes  ☐ No

- [ ] **Audit Period Monitoring (30-90 days recommended)**
  - Weekly compliance reports generated: ☐ Yes  ☐ No
  - Compliance trend tracking: ☐ Improving  ☐ Stable  ☐ Declining
  - Exemption requests processed: ☐ Yes  ☐ No

### Go/No-Go Decision (Proceed to Enforcement)

**Acceptance Criteria**:
- [ ] Compliance >= 70% OR all non-compliant resources have remediation plans
- [ ] No critical application impact from policy evaluation
- [ ] Exemption process tested and working
- [ ] Stakeholder approval for enforcement mode

**Status**: ☐ GO  ☐ NO-GO  ☐ CONDITIONAL

**Notes**:
```
______________________________________________________________________________
______________________________________________________________________________
______________________________________________________________________________
```

**Sign-off**: __________________________ Date: ______________

---

## ✅ PHASE 7: Production Enforcement (9 Deny Policies)

### **⚠️ CRITICAL PRE-DEPLOYMENT CHECKS**

- [ ] **Enforcement Impact Assessment**
  - All 9 Deny policies reviewed: ☐ Yes  ☐ No
  - Application teams notified of blocking policies: ☐ Yes  ☐ No
  - Exemption process documented and tested: ☐ Yes  ☐ No
  - Emergency rollback procedure ready: ☐ Yes  ☐ No

- [ ] **9 Deny Policies Validated in DevTest**
  - Test results: `EnforcementValidation-<timestamp>.csv`
  - All 9 policies tested: ☐ 9/9 PASS  ☐ Issues found
  - Policies validated:
    - [ ] Soft delete should be enabled
    - [ ] Deletion protection should be enabled  
    - [ ] Managed HSM purge protection should be enabled
    - [ ] Public network access should be disabled
    - [ ] RBAC authorization should be used
    - [ ] Keys should have expiration date
    - [ ] Secrets should have expiration date
    - [ ] Certificates should have expiration date
    - [ ] Certificates should have max validity period (13 months)

### Production Enforcement Deployment

- [ ] **Parameter File Reviewed**
  - File: `PolicyParameters-Production.json` (confirmed Deny mode for 9 policies)
  - Remaining 37 policies stay in Audit mode
  - User confirmation prompt understood: ☐ Yes  ☐ No

- [ ] **Stakeholder Approval**
  - Security team approval: ☐ Yes  ☐ No
  - Compliance team approval: ☐ Yes  ☐ No
  - Application owners notified: ☐ Yes  ☐ No
  - Change advisory board approval: ☐ Yes  ☐ No (CAB Ticket #: _________)

- [ ] **Production Enforcement Executed**
  - Command: `.\AzPolicyImplScript.ps1 -DeployProduction -SkipRBACCheck`
  - User confirmed Deny mode deployment: ☐ Yes
  - Deployment successful: ☐ Yes  ☐ No
  - 9 Deny policies assigned: ☐ Yes  ☐ No

### Post-Deployment Monitoring (Critical - First 48 Hours)

- [ ] **Denial Monitoring (Hourly for first 24 hours)**
  - Azure Activity Log monitored: ☐ Yes  ☐ No
  - Policy denial count: ___________
  - Legitimate vs. incorrect denials: ___________ / ___________
  - Emergency exemptions required: ☐ Yes  ☐ No (Count: _______)

- [ ] **Application Impact Assessment**
  - Critical applications functioning: ☐ Yes  ☐ No
  - User-reported issues: ☐ None  ☐ Minor  ☐ Major
  - Rollback required: ☐ Yes  ☐ No

- [ ] **Compliance Impact**
  - Compliance percentage change: ___________% → ___________%
  - New non-compliant resource creation blocked: ☐ Confirmed  ☐ Not Confirmed

### Go/No-Go Decision (Maintain Enforcement)

**Acceptance Criteria**:
- [ ] No critical application outages
- [ ] Denial rate acceptable (<5% of vault operations)
- [ ] Exemption requests manageable (<10% of resources)
- [ ] Stakeholder satisfaction confirmed

**Status**: ☐ GO  ☐ ROLLBACK  ☐ PARTIAL ROLLBACK

**Notes**:
```
______________________________________________________________________________
______________________________________________________________________________
______________________________________________________________________________
```

**Sign-off**: __________________________ Date: ______________

---

## ✅ PHASE 8: Auto-Remediation (8 DeployIfNotExists/Modify Policies)

### Pre-Remediation Validation

- [ ] **Managed Identity Configured**
  - Managed identity name: ___________________________
  - Resource ID confirmed: ___________________________
  - RBAC roles assigned: ☐ Key Vault Contributor  ☐ Monitoring Contributor

- [ ] **Remediation Parameter File Reviewed**
  - File: `PolicyParameters-Production-Remediation.json`
  - 8 DeployIfNotExists/Modify policies configured
  - Remaining 38 policies stay in Audit/Deny mode
  - Policies to remediate:
    - [ ] Resource logs in Key Vault should be enabled (Log Analytics)
    - [ ] Resource logs in Key Vault should be enabled (Event Hub)
    - [ ] Resource logs in Key Vault should be enabled (Storage Account)
    - [ ] Azure Key Vault should use private link
    - [ ] Diagnostic settings for Key Vault
    - [ ] Azure Key Vault Managed HSM keys should have more than specified days before expiration
    - [ ] Secrets/Keys expiration warnings
    - [ ] Certificate lifecycle automation

### Auto-Remediation Deployment

- [ ] **Remediation Test Executed (DevTest)**
  - Command: `.\AzPolicyImplScript.ps1 -TestAutoRemediation -SkipRBACCheck`
  - Wait time: 30-60 minutes for Azure Policy evaluation
  - Test vault remediated automatically: ☐ Yes  ☐ No
  - Remediation tasks created: ☐ Yes  ☐ No

- [ ] **Production Remediation Deployment**
  - Command: `.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Production-Remediation.json -IdentityResourceId "<managed-identity-id>" -SkipRBACCheck`
  - Deployment successful: ☐ Yes  ☐ No
  - 8 remediation policies assigned: ☐ Yes  ☐ No

### Remediation Monitoring

- [ ] **Remediation Task Tracking**
  - Wait time: 15-30 minutes for remediation tasks to appear
  - Remediation tasks created: ___________
  - Tasks succeeded: ___________
  - Tasks failed: ___________
  - Command: `Get-AzPolicyRemediation -Scope <subscription-id>`

- [ ] **Remediation Impact Assessment**
  - Resources remediated: ___________
  - Compliance improvement: ___________% → ___________%
  - Application impact: ☐ None  ☐ Minor  ☐ Major
  - Cost impact assessed: ☐ Yes  ☐ No (Log Analytics, Event Hub, Storage)

### Go/No-Go Decision

**Status**: ☐ GO  ☐ NO-GO  ☐ CONDITIONAL

**Notes**:
```
______________________________________________________________________________
______________________________________________________________________________
______________________________________________________________________________
```

**Sign-off**: __________________________ Date: ______________

---

## ✅ ONGOING: Compliance Maintenance

### Monthly Compliance Review

- [ ] **Compliance Report Generation**
  - Command: `.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan`
  - Report reviewed: `ComplianceReport-<timestamp>.html`
  - Overall compliance percentage: ___________%
  - Trend: ☐ Improving  ☐ Stable  ☐ Declining

- [ ] **Non-Compliant Resource Analysis**
  - New non-compliant resources: ___________
  - Existing non-compliant resources: ___________
  - Resources remediated this month: ___________
  - Outstanding exemption requests: ___________

- [ ] **Policy Effectiveness Review**
  - Policies not reporting data: ___________
  - Policies with high exemption rate (>20%): ___________
  - Policy parameter adjustments needed: ☐ Yes  ☐ No

### Quarterly Governance Review

- [ ] **Policy Set Review**
  - New Azure built-in policies available: ☐ Yes  ☐ No
  - Policy parameters need adjustment: ☐ Yes  ☐ No
  - Exemptions review completed: ☐ Yes  ☐ No

- [ ] **Stakeholder Feedback**
  - Security team feedback: ☐ Collected  ☐ Pending
  - Application teams feedback: ☐ Collected  ☐ Pending
  - Compliance team feedback: ☐ Collected  ☐ Pending

- [ ] **Continuous Improvement**
  - Process improvements identified: ☐ Yes  ☐ No
  - Training needs identified: ☐ Yes  ☐ No
  - Documentation updates required: ☐ Yes  ☐ No

### Review Sign-off

**Quarter**: Q____ 20____  
**Reviewer**: __________________________  
**Date**: ______________  
**Next Review Date**: ______________

---

## 📊 ACCEPTANCE THRESHOLDS

Use these thresholds to make go/no-go decisions:

| Phase | Metric | Minimum Acceptable | Target |
|-------|--------|-------------------|--------|
| Infrastructure | Test validation pass rate | 100% | 100% |
| RBAC Audit | Vaults audited | 100% | 100% |
| Purge Protection | Stakeholder approval | Required | Required |
| DevTest Deployment | Policies deployed | 100% (30/30) | 100% |
| DevTest Full | Policies deployed | 100% (46/46) | 100% |
| Production Audit | Initial compliance | >= 30% | >= 50% |
| Production Enforcement | Application availability | 99.9% | 100% |
| Production Enforcement | Denial rate | < 5% of operations | < 1% |
| Auto-Remediation | Remediation success rate | >= 80% | >= 95% |

---

## 🚨 ROLLBACK PROCEDURES

### Emergency Rollback (Critical Application Impact)

If critical applications are impacted:

1. **Immediate Rollback Command**:
   ```powershell
   .\AzPolicyImplScript.ps1 -Rollback
   ```
   This removes ALL KV-* policy assignments.

2. **Notify Stakeholders**: Send incident notification with impact assessment

3. **Root Cause Analysis**: Identify which policy caused the issue

4. **Targeted Fix**: Re-deploy with problem policy exempted

### Partial Rollback (Specific Policy Issues)

If only specific policies are problematic:

1. **Identify Problem Policy**: Review Azure Activity Log for denials

2. **Create Exemption**:
   ```powershell
   New-AzPolicyExemption -Name "emergency-exemption-<policy-name>" `
     -PolicyAssignment <assignment-id> `
     -Scope <resource-id> `
     -ExemptionCategory Waiver `
     -Description "Emergency exemption - Ticket #12345"
   ```

3. **Document Issue**: Create incident report and remediation plan

---

## 📝 CHECKLIST COMPLETION RECORD

| Phase | Completed Date | Signed By | Status | Notes |
|-------|---------------|-----------|--------|-------|
| 1. Infrastructure Setup | ____________ | __________ | ☐ GO ☐ NO-GO | ________________ |
| 2. RBAC and Firewall Audit | ____________ | __________ | ☐ GO ☐ NO-GO | ________________ |
| 3. Purge Protection Audit | ____________ | __________ | ☐ GO ☐ NO-GO | ________________ |
| 4. DevTest Deployment | ____________ | __________ | ☐ GO ☐ NO-GO | ________________ |
| 5. DevTest Full Deployment | ____________ | __________ | ☐ GO ☐ NO-GO | ________________ |
| 6. Production Audit | ____________ | __________ | ☐ GO ☐ NO-GO | ________________ |
| 7. Production Enforcement | ____________ | __________ | ☐ GO ☐ NO-GO | ________________ |
| 8. Auto-Remediation | ____________ | __________ | ☐ GO ☐ NO-GO | ________________ |

---

## 📚 RELATED DOCUMENTATION

- **QUICKSTART.md**: Step-by-step deployment guide
- **DEPLOYMENT-PREREQUISITES.md**: Technical prerequisites and RBAC requirements
- **TESTING-MAPPING.md**: Complete test framework and validation procedures
- **FINAL-TEST-SUMMARY.md**: Test results and evidence documentation
- **PARAMETER-FILE-USAGE-GUIDE.md**: Parameter file selection guide
- **V1.0-RELEASE-NOTES.md**: Release package contents and deployment instructions

---

**END OF CHECKLIST**
