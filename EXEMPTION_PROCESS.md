# Azure Key Vault Policy - Exemption Process

**Version**: 1.0  
**Last Updated**: January 13, 2026  
**Owner**: Azure Governance Team

---

## Overview

This document outlines the process for requesting, reviewing, and approving exemptions from Azure Key Vault policy requirements.

### Key Principles

- **Security First**: Exemptions are exceptions, not the rule
- **Time-Bound**: All exemptions have expiration dates (max 90 days)
- **Documented**: Every exemption requires business justification
- **Auditable**: All approvals tracked with approval authority
- **Renewable**: Exemptions can be renewed with re-justification

---

## Exemption Categories

### Valid Exemption Scenarios

| Scenario | Max Duration | Approval Required | Example |
|----------|--------------|-------------------|---------|
| **Legacy System Decommission** | 90 days | Security Architect | System scheduled for retirement in 60 days |
| **Third-Party Dependency** | 90 days (renewable) | CISO | Vendor software incompatible with RBAC |
| **Pilot/POC Environment** | 30 days | Security Architect | Temporary testing environment |
| **Break-Glass Access** | Indefinite (review annually) | CISO | Emergency access vault for production outages |
| **Technical Limitation** | 90 days + mitigation plan | CISO | Azure platform limitation documented |
| **Migration in Progress** | 90 days | Security Architect | Active migration to compliant architecture |

### Invalid Exemption Requests (Auto-Reject)

❌ **"Too hard to implement"** - Remediation support available  
❌ **"No business value"** - Security policies are non-negotiable  
❌ **"Testing only"** - Dev/test environments should also comply  
❌ **Indefinite exemptions without justification** - All exemptions require end date  
❌ **"We've always done it this way"** - Not a valid technical reason  
❌ **Cost avoidance alone** - Security requirements take precedence

---

## Approval Authority

### By Policy Priority

| Priority | Policies | Approval Required | Escalation |
|----------|----------|-------------------|------------|
| **P0** (Critical) | Soft delete, Purge protection, Public network access | **CISO** | Board/Executive Committee |
| **P1** (High) | Private link, RBAC, Key/Secret expiration | **Security Architect** | CISO |
| **P2** (Medium) | Certificate validity, HSM requirement, RSA key size | **Security Architect** | Security Architect Lead |

### Approval SLA

- **P0 policies**: 2 business days (expedited for emergencies)
- **P1 policies**: 3 business days
- **P2 policies**: 5 business days

### Automatic Approvals (Pre-Approved Categories)

The following scenarios are pre-approved with standard 30-day exemptions:
- **Temporary dev/test environments** (<30 days lifespan)
- **Documented vendor limitations** (with mitigation plan)
- **Active migration projects** (with completion date)

*Note: Still requires formal submission for audit trail*

---

## Exemption Request Process

### Step 1: Requestor Submits Exemption

**Method**: Azure Portal Policy Exemption OR ServiceNow ticket

**Required Information**:

1. **Resource Details**:
   - Resource ID (Key Vault name/ID)
   - Resource Group
   - Subscription
   - Tags (if applicable)

2. **Policy Details**:
   - Policy Assignment Name (e.g., "KV-Tier1-P0-SoftDelete")
   - Policy Display Name
   - Current compliance state (Compliant/Non-Compliant)

3. **Business Justification** (200-500 words):
   - Why is the resource non-compliant?
   - What business need requires the exemption?
   - What is the risk if exemption is not granted?
   - What is the plan to become compliant?

4. **Technical Details**:
   - Technical reason for non-compliance
   - Mitigation measures in place (if any)
   - Alternative controls (if any)
   - Remediation timeline (if applicable)

5. **Duration Request**:
   - Requested exemption start date
   - Requested exemption end date (max 90 days)
   - Renewal plan (if longer than 90 days needed)

6. **Requestor Information**:
   - Name
   - Email
   - Role/Title
   - Cost center/Department

### Step 2: Governance Team Review (1-2 days)

**Automated Checks**:
- ✅ All required fields completed
- ✅ Duration within limits (90 days)
- ✅ Resource exists and is non-compliant
- ✅ No duplicate active exemptions

**Manual Review**:
- Validate business justification quality
- Check for similar past exemptions
- Verify technical details accuracy
- Assess risk level
- Prepare recommendation for approver

**Outcome**:
- ✅ **Forward to Approver** (with recommendation)
- ❌ **Request More Information** (return to requestor)
- ❌ **Reject** (invalid scenario or insufficient justification)

### Step 3: Approval Decision (2-5 days)

**Approver Actions**:
1. Review governance team recommendation
2. Review business justification
3. Assess risk vs. business need
4. Make decision:
   - ✅ **Approve** (with conditions if needed)
   - ⏸️ **Approve with Shortened Duration** (e.g., 30 days instead of 90)
   - 🔄 **Conditional Approval** (requires additional controls)
   - ❌ **Deny** (with reason and alternative suggestions)

**Approval Conditions Examples**:
- "Approved for 60 days with weekly progress updates required"
- "Approved with compensating control: Enhanced monitoring + manual review"
- "Approved pending completion of mitigation plan by [date]"

### Step 4: Implementation (Same day)

**If Approved**:
```powershell
# Create policy exemption
New-AzPolicyExemption `
    -Name "exemption-<resource-name>-<timestamp>" `
    -PolicyAssignment $policyAssignment `
    -Scope "/subscriptions/xxx/resourceGroups/xxx/providers/Microsoft.KeyVault/vaults/xxx" `
    -ExemptionCategory "Waiver" `
    -DisplayName "[P0] Exception for legacy-vault - Decommission in progress" `
    -Description "Approved by CISO on 2026-01-13. Decommission scheduled for 2026-03-15." `
    -ExpiresOn (Get-Date).AddDays(90) `
    -Metadata @{
        TicketNumber = "INC0012345"
        ApprovedBy = "ciso@company.com"
        ApprovalDate = "2026-01-13"
        DecommissionDate = "2026-03-15"
        Requestor = "john.doe@company.com"
    }
```

**Notification Sent To**:
- Requestor (approval confirmation)
- Resource owner (if different from requestor)
- Governance team (for tracking)
- Security team (for audit log)

### Step 5: Ongoing Monitoring

**Weekly**:
- Review all active exemptions
- Check progress on remediation plans
- Identify exemptions expiring within 30 days

**Monthly**:
- Report exemption metrics to leadership
- Identify patterns/trends in exemption requests
- Review and update exemption criteria if needed

**Before Expiry** (7 days):
- Notify requestor of upcoming expiration
- Request renewal if needed (with updated justification)
- Automatically remove exemption if not renewed

---

## Exemption Categories (Azure Policy)

### Waiver
**Use When**: Permanent or long-term exemption needed  
**Example**: Break-glass emergency access vault  
**Expiration**: Required (reviewed annually)

### Mitigated
**Use When**: Compensating controls in place  
**Example**: Key Vault uses access policies instead of RBAC, but enhanced logging + approval workflow implemented  
**Expiration**: Required (reviewed every 90 days)

---

## Exemption Metrics & Reporting

### KPIs Tracked

| Metric | Target | Reporting Frequency |
|--------|--------|---------------------|
| Total Active Exemptions | <5% of resources | Monthly |
| Average Exemption Duration | <45 days | Monthly |
| Exemption Renewal Rate | <20% | Quarterly |
| Exemptions Expired (Auto-Removed) | >80% | Monthly |
| Emergency/Expedited Exemptions | <5 per month | Monthly |

### Monthly Report Contents

1. **Executive Summary**:
   - Total exemptions by priority (P0/P1/P2)
   - New exemptions granted this month
   - Exemptions expired/removed
   - Renewal requests processed

2. **Exemption Breakdown**:
   - By policy (which policies have most exemptions)
   - By resource group (which teams request most exemptions)
   - By category (Waiver vs Mitigated)
   - By approval authority (CISO vs Security Architect)

3. **Trends & Analysis**:
   - Are exemption requests increasing/decreasing?
   - Common reasons for exemptions
   - Remediation success rate
   - Recommendations for policy adjustments

4. **High-Risk Exemptions**:
   - P0 policy exemptions (highlight)
   - Long-duration exemptions (>60 days)
   - Exemptions without clear remediation plan

---

## Automation & Tooling

### Exemption Request Portal

**Option 1: Azure Portal** (Recommended)
- Navigate to Policy → Compliance → Select non-compliant resource → Request Exemption
- Pre-populated resource and policy details
- Integrated approval workflow

**Option 2: ServiceNow Ticket**
- Create ticket category: "Azure Policy Exemption Request"
- Form auto-populates required fields
- Routed to governance team queue
- Integration with Azure DevOps for tracking

### Automated Reminders

**Email Notifications**:
- **30 days before expiry**: "Your exemption expires in 30 days. Renew or remediate?"
- **7 days before expiry**: "URGENT: Your exemption expires in 7 days. Action required."
- **Day of expiry**: "Your exemption has expired. Resource may now be non-compliant."

**PowerShell Script** (runs daily):
```powershell
# Get exemptions expiring soon
Get-AzPolicyExemption | Where-Object { 
    $_.Properties.ExpiresOn -and 
    $_.Properties.ExpiresOn -lt (Get-Date).AddDays(30) 
} | ForEach-Object {
    # Send email notification
    # Log to tracking system
}
```

---

## Renewal Process

### Renewal Criteria

**Automatically Eligible for Renewal**:
- ✅ Original exemption was <90 days
- ✅ Remediation plan still in progress with documented milestones met
- ✅ No alternative solutions available
- ✅ Risk assessment updated

**Requires Re-Approval** (Same Process as New Exemption):
- Original exemption was >90 days
- Remediation plan not progressing as documented
- Multiple renewals (3+)
- P0 policy exemptions

### Renewal Documentation Required

1. **Progress Update**:
   - What has been completed toward remediation?
   - What blockers have been encountered?
   - What is the updated timeline?

2. **Risk Re-Assessment**:
   - Has the risk changed (increased/decreased)?
   - Are compensating controls still effective?
   - Any security incidents related to this exemption?

3. **Continued Business Need**:
   - Is the exemption still necessary?
   - Has the business requirement changed?
   - Alternative solutions explored?

---

## Escalation Process

### When to Escalate

- **Exemption denied** but requestor disagrees
- **Urgent exemption needed** (<24 hour approval required)
- **Conflicting policies** (multiple policies affecting same resource)
- **High-risk exemption** (CISO approval required but CISO unavailable)

### Escalation Path

1. **First Level**: Security Architect
2. **Second Level**: CISO
3. **Third Level**: CTO or Board/Executive Committee

### Emergency Exemption Process

**Criteria**: Production outage or business-critical impact

**Process**:
1. **Immediate**: Security Architect can grant 72-hour emergency exemption
2. **Within 24 hours**: Full exemption request submitted with justification
3. **Within 48 hours**: CISO reviews and approves/denies full exemption
4. **If denied**: 72-hour exemption expires, resource must be remediated immediately

---

## Audit & Compliance

### Audit Trail Requirements

All exemptions must be logged with:
- ✅ Requestor identity
- ✅ Approval authority
- ✅ Timestamp (request, approval, implementation)
- ✅ Business justification
- ✅ Technical details
- ✅ Expiration date
- ✅ Renewal history (if applicable)

### Annual Audit

**Frequency**: Annually (or more frequently for high-risk environments)

**Audit Scope**:
- Review all active exemptions
- Validate business justifications still valid
- Confirm compensating controls still effective
- Check remediation progress
- Identify exemptions that should be removed

**Audit Report Includes**:
- Total exemptions reviewed
- Exemptions removed (no longer needed)
- Exemptions renewed (with justification)
- Exemptions flagged for management review
- Recommendations for policy improvements

---

## Examples

### Example 1: Approved Exemption (Legacy System)

**Request**:
- **Resource**: legacy-keyvault-prod
- **Policy**: Key Vault should use RBAC permission model
- **Reason**: Legacy application uses access policies, cannot be updated (vendor end-of-support in 60 days). System scheduled for decommission March 15, 2026.
- **Duration**: 90 days
- **Mitigation**: Enhanced audit logging, manual access reviews weekly

**Decision**: ✅ **Approved by CISO**
- Duration: 60 days (shorter than requested to align with decommission)
- Condition: Weekly progress updates on decommission plan
- Tracking: Monthly check-ins with decommission project team

### Example 2: Denied Exemption (Insufficient Justification)

**Request**:
- **Resource**: dev-test-keyvault
- **Policy**: Keys should have expiration dates
- **Reason**: "Development environment, doesn't need expiration dates"
- **Duration**: 365 days

**Decision**: ❌ **Denied by Security Architect**
- **Reason**: Dev/test environments should also follow security best practices. Lack of expiration dates creates risk even in non-production.
- **Alternative**: Set longer expiration periods (e.g., 730 days instead of 365) if frequent rotation is operationally challenging
- **Guidance**: Remediate within 30 days or resubmit with stronger business justification and compensating controls

### Example 3: Conditional Approval (Mitigated)

**Request**:
- **Resource**: partner-integration-vault
- **Policy**: Azure Key Vault should disable public network access
- **Reason**: Third-party integration requires public HTTPS access (vendor limitation). Alternative private endpoint not supported by vendor.
- **Duration**: 90 days (renewable)
- **Mitigation**: Firewall rules restrict to vendor IP ranges only, enhanced monitoring alerts on access from unknown IPs

**Decision**: 🔄 **Conditionally Approved by CISO**
- **Approval**: 90 days with renewal option
- **Conditions**:
  - Firewall rules must be maintained and reviewed monthly
  - Vendor escalation to support private endpoints (roadmap confirmation required)
  - Quarterly review of vendor access logs
  - Automatic removal if vendor supports private endpoints

---

## Contact & Support

### Exemption Questions

- **Email**: azure-governance@company.com
- **Teams**: Azure Governance Team channel
- **ServiceNow**: Submit ticket (Category: Azure Policy Exemption)

### Approval Authority Contact

- **CISO**: ciso@company.com
- **Security Architect**: security-architects@company.com
- **Governance Team Lead**: azure-governance-lead@company.com

---

## Document History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-01-13 | Initial release | Azure Governance Team |

---

**Next Review Date**: 2026-04-13 (Quarterly)  
**Document Owner**: Azure Governance Team  
**Approval**: CISO
