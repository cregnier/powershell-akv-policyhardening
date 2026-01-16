# Azure Key Vault Policy - Tier Categorization Guide

**Purpose**: Explain why each policy is assigned to a specific tier, prioritization criteria, implementation timing, and business impact.

**Last Updated**: January 15, 2026  
**Reference**: ProductionRolloutPlan.md - Complete 46-policy phased deployment strategy

---

## 📋 Tier Categorization Criteria

Each of the 46 Azure Key Vault built-in policies is assigned to one of four tiers based on:

| Criteria | Description | Business Impact |
|----------|-------------|-----------------|
| **Operational Impact** | How disruptive is enforcement? | LOW = Minimal changes / HIGH = Major restructuring |
| **Security Value** | How critical for compliance/security? | CRITICAL = Data protection / MEDIUM = Best practices |
| **Prerequisites** | Infrastructure/budget requirements? | None = Deploy now / HIGH = 6-12 month buildout |
| **Deployment Readiness** | Can we deploy today? | Ready = Yes / Blocked = Needs approval/infrastructure |
| **Business Disruption** | Effect on users and applications? | LOW = Transparent / HIGH = Training + process changes |

---

## 🎯 Tier 1: Baseline Security (9 Policies)

### Selection Criteria
✅ **Deny-capable** enforcement (real-time blocking)  
✅ **High security value** (data protection, audit requirements)  
✅ **Low business disruption** (Azure defaults or industry standards)  
✅ **Immediate deployment ready** (no infrastructure prerequisites)

### Timeline: Months 1-3
- **Month 1**: Deploy in Audit mode (30 days baseline)
- **Month 2**: Activate Deny mode (30 days monitoring)
- **Month 3**: Full enforcement (stable operations)

### Why These 9 Policies?

| Policy | Why Tier 1? | Security Value | Impact | Readiness |
|--------|-------------|----------------|--------|-----------|
| **Soft delete enabled** | Azure auto-enables on new vaults (2023+) | 🔒 CRITICAL (prevents accidental deletion) | ⚠️ LOW (most vaults compliant) | ✅ Ready |
| **Deletion protection** | Prevents permanent deletion | 🔒 CRITICAL (protects against malicious deletion) | ⚠️ LOW (opt-in feature) | ✅ Ready |
| **RBAC permission model** | Industry best practice (vs legacy access policies) | 🔒 HIGH (centralized access control) | ⚠️ MEDIUM (requires RBAC migration) | ✅ Ready |
| **Firewall enabled** | Network security standard | 🔒 HIGH (prevents unauthorized access) | ⚠️ LOW ("Allow trusted MS services" option) | ✅ Ready |
| **Keys have expiration** | Cryptographic hygiene requirement | 🔒 HIGH (key rotation enforcement) | ⚠️ MEDIUM (requires rotation process) | ✅ Ready |
| **Secrets have expiration** | Prevents stale credentials | 🔒 HIGH (credential lifecycle) | ⚠️ MEDIUM (requires rotation process) | ✅ Ready |
| **Cert max validity ≤12mo** | Industry standard (CA/Browser Forum) | 🔒 MEDIUM (aligns with public CAs) | ⚠️ LOW (matches existing practice) | ✅ Ready |
| **RSA min key size 2048** | NIST/cryptographic standard | 🔒 MEDIUM (prevents weak keys) | ⚠️ LOW (standard since 2015) | ✅ Ready |
| **Cert expiration warning** | Operational continuity | 🔒 MEDIUM (prevents outages) | ⚠️ LOW (advance notice only) | ✅ Ready |

### Business Justification
- **Quick wins**: Immediate security improvement with minimal disruption
- **Foundation**: Establishes baseline for Tier 2 deployment
- **Compliance**: Satisfies audit requirements (SOC2, ISO 27001, PCI-DSS)
- **ROI**: High security value with <5% expected violation rate

---

## 🔄 Tier 2: Lifecycle Management (25 Policies)

### Selection Criteria
✅ **Deny-capable** enforcement available  
⚠️ **Moderate operational impact** (process changes required)  
✅ **Security/compliance value** (lifecycle management, cryptography standards)  
⚠️ **Preparation required** (rotation processes, certificate lifecycle)

### Timeline: Months 4-9
- **Months 4-5**: Audit mode (60 days - establish baseline)
- **Months 6-7**: Deny mode (60 days - monitor/support)
- **Months 8-9**: Full enforcement (stable operations)

### Why 25 Policies in Tier 2?

**Category Breakdown:**

#### Keys (7 policies)
- Maximum age limits (365 days)
- Expiration warnings (30 days before)
- Rotation policy enforcement
- Maximum validity periods
- Cryptographic type restrictions (RSA/EC)
- Elliptic curve naming standards
- Resource logging requirements

**Why not Tier 1?** Requires operational processes for key rotation, lifecycle management tooling, and application updates.

#### Secrets (4 policies)
- Maximum age limits
- Expiration warnings
- Content type requirements (metadata)
- Maximum validity periods

**Why not Tier 1?** Secrets rotation often requires application code changes, database connection string updates, and coordination across teams.

#### Certificates (8 policies)
- RSA minimum key size
- Allowed key types (RSA/EC)
- Elliptic curve naming standards
- Lifetime action triggers (renewal automation)
- Certificate Authority requirements (integrated/non-integrated)
- Multiple CA support

**Why not Tier 1?** Certificate lifecycle management requires CA integrations, renewal processes, and application deployment coordination (especially for public-facing services).

#### Managed HSM (6 policies)
- Purge protection
- Key expiration requirements
- Expiration warnings
- RSA key size minimums
- Elliptic curve standards
- Resource logging

**Why not Tier 1?** Managed HSM adoption is limited (Premium tier requirement), fewer organizations use it, so less urgent than standard vault policies.

### Business Justification
- **Process maturity**: Builds on Tier 1 foundation with structured lifecycle processes
- **Compliance evolution**: Satisfies advanced compliance requirements (FedRAMP, HIPAA)
- **Risk reduction**: Prevents expired credentials, weak cryptography
- **Success criteria**: <10% violation rate before Deny mode (vs <5% for Tier 1)

---

## ⚠️ Tier 3: High-Impact Infrastructure (3 Policies)

### Selection Criteria
⛔ **CRITICAL IMPACT** - Requires significant budget/infrastructure investment  
⚠️ **LONG LEAD TIME** - 3-12 month prerequisites before deployment  
🔒 **HIGH SECURITY VALUE** - But deployment timing depends on infrastructure readiness  
📊 **AUDIT MODE INITIALLY** - Deny mode TBD based on business case approval

### Timeline: Months 10-12+ (Extended)
- **Months 10-12**: Audit mode indefinitely
- **TBD**: Deny mode activation ONLY after infrastructure complete

### Why Only 3 Policies?

| Policy | Why Tier 3? | Cost/Impact | Prerequisites | Timeline |
|--------|-------------|-------------|---------------|----------|
| **HSM-backed keys required** | ⛔ **BLOCKS ALL software keys** | $1,500+/mo per vault (Premium SKU) | Budget approval + Premium vault migration | 6-12 months |
| **Private link required** | ⛔ **BLOCKS ALL public access** | VNet infrastructure buildout | Private endpoints + DNS + NSG rules | 3-6 months |
| **Managed HSM private link** | ⛔ **BLOCKS Managed HSM public access** | Managed HSM infrastructure | PE + DNS for Managed HSM | 3-6 months |

### Why Not Combined with Tier 1 or 2?

1. **HSM Policy ("Keys should be backed by HSM")**:
   - **Impact**: Blocks 100% of Standard vault operations when in Deny mode
   - **Cost**: ~$1,500/month per vault (Standard = ~$3/month)
   - **Migration**: Requires application testing with HSM keys
   - **Decision Point**: Business case required - is 500x cost increase justified?
   - **Alternative**: Deploy in Audit mode only for visibility

2. **Private Link Policies**:
   - **Impact**: Requires private endpoint for EVERY Key Vault
   - **Infrastructure**: VNet, subnet, private DNS zone, NSG rules
   - **Application Changes**: Update connection strings, test connectivity
   - **On-Premises**: Firewall rules, VPN/ExpressRoute configuration
   - **Timeline**: 3-6 months for complete buildout

### Business Justification
- **Cost-benefit analysis required**: Leadership approval needed
- **Infrastructure dependency**: Cannot deploy Deny mode without infrastructure
- **Audit mode value**: Provides visibility into compliance gaps
- **Phased approach**: Parallel infrastructure buildout during Tier 1/2 deployment

### Deployment Options

**Option A: Audit Mode Only (RECOMMENDED)**
- Effect: `Audit` (no blocking)
- Cost: $0 (no infrastructure changes)
- Timeline: Deploy immediately (Month 1)
- Next Steps: Business case for infrastructure investment

**Option B: Infrastructure First, Then Deny**
- Effect: `Deny` (full enforcement)
- Cost: HIGH (Premium vaults + private endpoints)
- Timeline: 6-12 months
- Prerequisites: Budget approval + infrastructure complete

**Option C: Exclude from Production**
- Effect: Not deployed
- Impact: Compliance gap
- Timeline: Revisit in 12-18 months

---

## 🤖 Tier 4: Auto-Remediation (9 Policies)

### Selection Criteria
🔄 **Auto-remediation** via DeployIfNotExists/Modify effects  
🤖 **Managed identities** required for automated actions  
📋 **Infrastructure parameters** needed (subnet, workspace, Event Hub)  
✅ **Deploy early** to automate compliance (parallel with Tier 1)

### Timeline: Months 1-6 (Parallel Deployment)
- **Month 1**: Create infrastructure + deploy policies with managed identities
- **Months 2-3**: Test remediation in dev/test
- **Months 4-6**: Production remediation active, monitoring success rate

### Why 9 Policies in Tier 4?

**Policy Breakdown:**

| # | Policy | Effect | Why Tier 4? | Prerequisites |
|---|--------|--------|-------------|---------------|
| 1 | Configure private endpoints | DeployIfNotExists | Auto-creates PEs for non-compliant vaults | Subnet ID |
| 2 | Configure private DNS zones | DeployIfNotExists | Auto-configures DNS for PEs | DNS Zone ID |
| 3 | Configure firewall | Modify | Auto-enables vault firewall | None (modifies existing) |
| 4 | Deploy diagnostics (Log Analytics) | DeployIfNotExists | Auto-configures logging | Workspace ID |
| 5 | Deploy diagnostics (Event Hub) | DeployIfNotExists | Auto-configures streaming | Event Hub ID |
| 6 | Managed HSM diagnostics (Event Hub) | DeployIfNotExists | Auto-configures HSM logging | Event Hub ID |
| 7 | Managed HSM disable public access | Modify | Auto-disables public access | None |
| 8 | Managed HSM configure PEs | DeployIfNotExists | Auto-creates Managed HSM PEs | Subnet ID |
| 9 | Managed HSM monitoring (Audit) | Audit | Monitors compliance (no auto-remediation) | None |

### Why Separate from Tier 1-3?

1. **Different enforcement model**: 
   - Tiers 1-3 = **Preventive** (block non-compliant actions)
   - Tier 4 = **Corrective** (fix existing non-compliant resources)

2. **Managed identity requirement**:
   - Requires system-assigned managed identity per policy
   - Needs RBAC role assignments (Contributor, Network Contributor)
   - Additional security review required

3. **Infrastructure parameters**:
   - Must provide subnet IDs, workspace IDs, Event Hub IDs
   - Cannot deploy without infrastructure in place
   - Different deployment workflow than Deny/Audit policies

4. **Parallel deployment strategy**:
   - Deploy alongside Tier 1 (Month 1) to automate compliance
   - Reduces manual remediation workload
   - Complements Deny policies (Deny = prevent, Tier 4 = fix)

### Business Justification
- **Automation value**: Reduces manual remediation by 95%
- **Operational efficiency**: Auto-configures infrastructure for compliance
- **Consistent enforcement**: Ensures all vaults have logging, private endpoints
- **ROI**: Staff time saved on manual configuration > infrastructure cost

---

## 📊 Tier Summary Matrix

| Tier | Policies | Timeline | Impact | Cost | Prerequisites | Success Criteria |
|------|----------|----------|--------|------|---------------|------------------|
| **1** | 9 | Months 1-3 | LOW | $0 | None | <5% violations |
| **2** | 25 | Months 4-9 | MEDIUM | $0 | Rotation processes | <10% violations |
| **3** | 3 | Months 10-12+ | HIGH | $$$$ | Infrastructure + budget | Business case approval |
| **4** | 9 | Months 1-6 (parallel) | MEDIUM | $$$ | VNet, LA, EH | 95% auto-remediation |

**Total**: 46 policies across 9-12 month phased deployment

---

## 🎯 Why This Matters

### For Security Teams
- **Risk-based prioritization**: Address highest security gaps first (Tier 1)
- **Compliance roadmap**: Phased approach satisfies audit requirements progressively
- **Measurable progress**: Clear success criteria per tier

### For Operations Teams
- **Change management**: Gradual adoption minimizes disruption
- **Process development**: Time to build rotation, lifecycle processes
- **Training**: Phased user education (Tier 1 → Tier 2 → Tier 3)

### For Leadership
- **Budget planning**: Tier 3 costs identified early for next fiscal year
- **Risk transparency**: Audit mode provides visibility before enforcement
- **Business case**: Data-driven decisions on infrastructure investment

### For Application Teams
- **Predictable timelines**: Know when policies will be enforced
- **Preparation time**: 60-90 day audit periods before Deny mode
- **Support availability**: Phased rollout ensures adequate support capacity

---

## 📅 Implementation Priority & Timing

### Why This Order?

**Foundation First (Tier 1)**:
- Establishes baseline security posture
- Builds stakeholder confidence with quick wins
- Validates policy deployment process

**Processes Second (Tier 2)**:
- Requires Tier 1 foundation (rotation builds on expiration policies)
- Needs operational maturity from Tier 1 deployment
- Longer preparation time (60 vs 30 days)

**Infrastructure Last (Tier 3)**:
- Longest lead time (6-12 months)
- Highest cost (requires budget approval)
- Can run in parallel with Tier 1/2 (infrastructure buildout)

**Automation Throughout (Tier 4)**:
- Deploys parallel to Tier 1 (Month 1)
- Reduces manual remediation burden
- Supports Tier 1-3 enforcement by auto-fixing non-compliance

---

## 🔍 How to Use This Guide

1. **For initial deployment**: Follow tier sequence (1 → 2 → 3, with 4 parallel)
2. **For policy questions**: Reference categorization criteria per tier
3. **For business justification**: Use security value + impact analysis
4. **For timeline planning**: Use success criteria to gauge readiness for next tier
5. **For exemptions**: Tier 3 policies are candidates for long-term exemptions (high cost/impact)

---

**See Also**:
- [ProductionRolloutPlan.md](ProductionRolloutPlan.md) - Complete deployment guide
- [DEPLOYMENT-PREREQUISITES.md](DEPLOYMENT-PREREQUISITES.md) - Infrastructure requirements
- [PolicyParameters-Tier*.json](.) - Tier-specific parameter files
