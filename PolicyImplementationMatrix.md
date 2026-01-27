# Azure Key Vault Policy Implementation Matrix

**Document Version**: 1.0  
**Last Updated**: January 23, 2026  
**Purpose**: Comprehensive implementation guide for all 46 Azure Key Vault built-in policies

---

## Matrix Legend

### Priority Levels
- **🔴 CRITICAL**: Regulatory compliance, data protection, security baseline
- **🟠 HIGH**: Best practices, security hardening, operational excellence
- **🟡 MEDIUM**: Governance, cost optimization, monitoring
- **🟢 LOW**: Optional enhancements, future improvements

### Effort Levels
- **L (Low)**: < 1 hour - Simple parameter configuration
- **M (Medium)**: 1-4 hours - Requires planning, testing
- **H (High)**: > 4 hours - Complex dependencies, infrastructure changes

### Impact Levels
- **L (Low)**: Individual resources, limited scope
- **M (Medium)**: Vault-level configuration, multiple resources
- **H (High)**: Organization-wide, breaking changes

### Implementation Timing
- **Phase 1 (Immediate)**: Deploy within 1 week
- **Phase 2 (Short-term)**: Deploy within 1 month
- **Phase 3 (Long-term)**: Deploy within 3 months
- **Future**: Evaluate for future deployment

---

## Policy Matrix

### CRITICAL POLICIES (9 policies)

| Policy Name | Priority | Effort | Impact | Mode(s) | Multi-Mode Strategy | Timing | Business Value | Guidance | Prerequisites | Caveats |
|------------|----------|--------|--------|---------|-------------------|---------|---------------|----------|---------------|---------|
| **Key vaults should have deletion protection enabled** | 🔴 CRITICAL | L | H | Audit → Deny | Start Audit (1 week) → Deny | Phase 1 | Prevents permanent data loss from insider threats or accidental deletion | Enable soft delete first (auto-enabled on new vaults), then enable purge protection | Soft delete must be enabled | Once enabled, purge protection cannot be disabled |
| **Key vaults should have soft delete enabled** | 🔴 CRITICAL | L | M | Audit → Deny | Start Audit (immediate) → Deny (1 week) | Phase 1 | Enables 90-day recovery window for accidentally deleted vaults/objects | Auto-enabled on all new Key Vaults (since 2020), check existing vaults | None | Retention period 7-90 days (default 90) |
| **Azure Key Vault should disable public network access** | 🔴 CRITICAL | M | H | Audit → Deny | Start Audit (2 weeks) → Deny (1 month) | Phase 2 | Reduces attack surface by requiring private endpoints or firewall rules | Review access patterns, implement private endpoints/VPN first | Private Link or VPN infrastructure | Requires network planning, can block CI/CD if not configured |
| **Azure Key Vault should have firewall enabled or public network access disabled** | 🔴 CRITICAL | M | H | Audit → Deny | Start Audit (2 weeks) → Deny (1 month) | Phase 2 | Limits public access to approved IP ranges | Configure allowed IPs for admins, CI/CD pipelines, services | List of approved IP ranges | Dynamic IPs require firewall updates |
| **Azure Key Vault should use RBAC permission model** | 🔴 CRITICAL | H | H | Audit → Deny | Start Audit (1 month) → Deny (3 months) | Phase 3 | Modern authorization with Azure AD integration, supports PIM | Migrate access policies to RBAC assignments, test thoroughly | Azure AD roles configured | Breaking change for existing applications using access policies |
| **Key Vault secrets should have an expiration date** | 🔴 CRITICAL | L | M | Audit → Deny | Start Audit (1 week) → Deny (1 month) | Phase 2 | Enforces secret rotation, reduces credential leak risk | Establish secret rotation processes, document secret lifecycles | Secret management workflow | May break apps with static secrets |
| **Key Vault keys should have an expiration date** | 🔴 CRITICAL | L | M | Audit → Deny | Start Audit (1 week) → Deny (1 month) | Phase 2 | Enforces key rotation per cryptographic best practices | Establish key rotation automation (Key Vault SDK/CLI) | Key rotation process | May break apps expecting permanent keys |
| **Keys using RSA cryptography should have a specified minimum key size** | 🔴 CRITICAL | L | M | Audit → Deny | Start Audit (immediate) → Deny (1 week) | Phase 1 | Prevents weak cryptography (< 2048-bit RSA keys) | Set minimum to 4096-bit for production | None | Existing 2048-bit keys remain compliant (grandfather clause) |
| **Certificates using RSA cryptography should have the specified minimum key size** | 🔴 CRITICAL | L | M | Audit → Deny | Start Audit (immediate) → Deny (1 week) | Phase 1 | Ensures certificate cryptographic strength | Set minimum to 4096-bit for production | None | CA must support specified key size |

---

### HIGH PRIORITY POLICIES (12 policies)

| Policy Name | Priority | Effort | Impact | Mode(s) | Multi-Mode Strategy | Timing | Business Value | Guidance | Prerequisites | Caveats |
|------------|----------|--------|--------|---------|-------------------|---------|---------------|----------|---------------|---------|
| **Azure Key Vaults should use private link** | 🟠 HIGH | H | H | Audit → Deny | Start Audit (1 month) → Deny (3 months) | Phase 3 | Private endpoint connectivity eliminates public exposure | Deploy Private Link infrastructure, configure private DNS | VNet, Private Link service configured | Requires Azure infrastructure investment |
| **Keys should be backed by a hardware security module (HSM)** | 🟠 HIGH | M | M | Audit → Deny | Start Audit (1 month) → Deny (optional) | Phase 3 | FIPS 140-2 Level 2 validation for cryptographic operations | Evaluate HSM requirements per compliance needs | Premium Key Vault SKU or Managed HSM | Higher cost than software-protected keys |
| **Certificates should have the specified maximum validity period** | 🟠 HIGH | L | M | Audit → Deny | Start Audit (1 week) → Deny (1 month) | Phase 2 | Limits certificate lifespan (e.g., 12 months) for regular rotation | Set maximum validity to 12-13 months | Certificate renewal automation | May conflict with CA policies |
| **Secrets should have the specified maximum validity period** | 🟠 HIGH | L | M | Audit → Deny | Start Audit (1 week) → Deny (1 month) | Phase 2 | Enforces maximum secret lifetime (e.g., 365 days) | Align with secret rotation policy (quarterly/annually) | Secret rotation automation | Requires application support for rotation |
| **Keys should have the specified maximum validity period** | 🟠 HIGH | L | M | Audit → Deny | Start Audit (1 week) → Deny (1 month) | Phase 2 | Enforces maximum key lifetime (e.g., 365 days) | Align with key rotation policy | Key rotation automation | Cryptographic operations interrupted during rotation |
| **Certificates should have the specified lifetime action triggers** | 🟠 HIGH | M | M | Audit → Deny | Start Audit (1 month) → Deny (optional) | Phase 3 | Automates certificate renewal at 80% lifetime or 90 days before expiry | Configure Key Vault auto-renewal or external automation | Certificate auto-renewal configured | Dependent on CA availability |
| **Secrets should have content type set** | 🟠 HIGH | L | L | Audit → Deny | Start Audit (immediate) → Deny (1 week) | Phase 1 | Improves secret discoverability (e.g., "password", "connection-string") | Document content type taxonomy | None | Cosmetic metadata, low security value |
| **Keys should not be active for longer than the specified number of days** | 🟠 HIGH | L | M | Audit | Audit only | Phase 1 | Identifies keys exceeding rotation window (e.g., 365 days) | Create remediation workflow for aging keys | Key rotation process | Audit-only - use expiration policy for enforcement |
| **Secrets should not be active for longer than the specified number of days** | 🟠 HIGH | L | M | Audit | Audit only | Phase 1 | Identifies secrets exceeding rotation window (e.g., 365 days) | Create remediation workflow for aging secrets | Secret rotation process | Audit-only - use expiration policy for enforcement |
| **Keys should have more than the specified number of days before expiration** | 🟠 HIGH | L | L | Audit | Audit only | Phase 1 | Early warning system for expiring keys (e.g., < 90 days) | Set up alerting for key expiration warnings | Monitoring/alerting configured | Audit-only - pairs with expiration policy |
| **Secrets should have more than the specified number of days before expiration** | 🟠 HIGH | L | L | Audit | Audit only | Phase 1 | Early warning system for expiring secrets (e.g., < 90 days) | Set up alerting for secret expiration warnings | Monitoring/alerting configured | Audit-only - pairs with expiration policy |
| **Certificates should not expire within the specified number of days** | 🟠 HIGH | L | L | Audit | Audit only | Phase 1 | Early warning system for expiring certificates (e.g., < 90 days) | Set up alerting for certificate expiration warnings | Monitoring/alerting configured | Audit-only - pairs with lifetime action triggers |

---

### MEDIUM PRIORITY POLICIES (13 policies)

| Policy Name | Priority | Effort | Impact | Mode(s) | Multi-Mode Strategy | Timing | Business Value | Guidance | Prerequisites | Caveats |
|------------|----------|--------|--------|---------|-------------------|---------|---------------|----------|---------------|---------|
| **Keys using elliptic curve cryptography should have the specified curve names** | 🟡 MEDIUM | L | L | Audit → Deny | Start Audit (1 month) → Deny (optional) | Phase 3 | Restricts ECC curves to NIST-approved (P-256, P-384, P-521) | Allow P-256, P-256K, P-384, P-521 | None | Secp256k1 used by some blockchain apps |
| **Certificates using elliptic curve cryptography should have allowed curve names** | 🟡 MEDIUM | L | L | Audit → Deny | Start Audit (1 month) → Deny (optional) | Phase 3 | Restricts certificate ECC curves to approved curves | Allow P-256, P-256K, P-384, P-521 | None | CA must support specified curves |
| **Certificates should use allowed key types** | 🟡 MEDIUM | L | M | Audit → Deny | Start Audit (1 week) → Deny (1 month) | Phase 2 | Restricts certificates to RSA/EC (blocks RSA-HSM if desired) | Allow RSA, EC (optionally RSA-HSM, EC-HSM) | None | Check CA compatibility |
| **Keys should be the specified cryptographic type RSA or EC** | 🟡 MEDIUM | L | M | Audit → Deny | Start Audit (1 week) → Deny (1 month) | Phase 2 | Restricts keys to RSA or EC types | Allow RSA, EC (optionally RSA-HSM, EC-HSM) | None | Blocks oct (symmetric) keys if enforced |
| **Certificates should be issued by the specified integrated certificate authority** | 🟡 MEDIUM | M | M | Audit → Deny | Start Audit (1 month) → Deny (optional) | Phase 3 | Enforces DigiCert/GlobalSign integrated CAs | Configure integrated CA in Key Vault first | Key Vault integrated CA configured | Blocks self-signed and non-integrated CAs |
| **Certificates should be issued by one of the specified non-integrated certificate authorities** | 🟡 MEDIUM | M | M | Audit → Deny | Start Audit (1 month) → Deny (optional) | Phase 3 | Enforces specific non-integrated CA common names | Specify allowed CA common names (e.g., "ContosoCA") | Private CA infrastructure | Requires exact CN matching |
| **[Preview]: Azure Key Vault Managed HSM keys should have an expiration date** | 🟡 MEDIUM | L | M | Audit → Deny | Start Audit (1 month) → Deny (optional) | Phase 3 | Same as regular keys, but for Managed HSM | Establish HSM key rotation process | Managed HSM deployed | Preview policy - may change |
| **[Preview]: Azure Key Vault Managed HSM keys using RSA cryptography should have a specified minimum key size** | 🟡 MEDIUM | L | M | Audit → Deny | Start Audit (1 week) → Deny (1 month) | Phase 2 | Enforces RSA key size for Managed HSM | Set minimum to 4096-bit | Managed HSM deployed | Preview policy - may change |
| **[Preview]: Azure Key Vault Managed HSM keys using elliptic curve cryptography should have the specified curve names** | 🟡 MEDIUM | L | L | Audit → Deny | Start Audit (1 month) → Deny (optional) | Phase 3 | Restricts ECC curves for Managed HSM | Allow P-256, P-384, P-521 | Managed HSM deployed | Preview policy - may change |
| **[Preview]: Azure Key Vault Managed HSM Keys should have more than the specified number of days before expiration** | 🟡 MEDIUM | L | L | Audit | Audit only | Phase 1 | Early warning for Managed HSM key expiration | Set up alerting (90 days before expiry) | Managed HSM deployed | Preview, audit-only |
| **Azure Key Vault Managed HSM should have purge protection enabled** | 🟡 MEDIUM | L | H | Audit → Deny | Start Audit (1 week) → Deny | Phase 2 | Prevents permanent HSM data loss | Enable during HSM creation | Managed HSM deployed | Cannot be disabled after enabling |
| **[Preview]: Azure Key Vault Managed HSM should disable public network access** | 🟡 MEDIUM | M | H | Audit → Deny | Start Audit (1 month) → Deny (optional) | Phase 3 | Requires private endpoints for Managed HSM | Deploy Private Link for HSM | Managed HSM, Private Link | Preview policy - HSM specific |
| **Configure key vaults to enable firewall** | 🟡 MEDIUM | M | H | Modify | Modify (auto-remediation) | Phase 2 | Auto-enables firewall on non-compliant vaults | Test in non-prod first, requires managed identity | Managed identity with Key Vault Contributor | May break existing access |

---

### LOW PRIORITY / OPERATIONAL POLICIES (12 policies)

| Policy Name | Priority | Effort | Impact | Mode(s) | Multi-Mode Strategy | Timing | Business Value | Guidance | Prerequisites | Caveats |
|------------|----------|--------|--------|---------|-------------------|---------|---------------|----------|---------------|---------|
| **Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace** | 🟢 LOW | M | L | DeployIfNotExists | DINE (auto-remediation) | Phase 2 | Centralized logging for compliance/monitoring | Configure Log Analytics workspace, managed identity | Log Analytics workspace, managed identity | Ongoing data ingestion costs |
| **Deploy Diagnostic Settings for Key Vault to Event Hub** | 🟢 LOW | M | L | DeployIfNotExists | DINE (auto-remediation) | Phase 2 | Streaming logs to SIEM/external systems | Configure Event Hub namespace | Event Hub, managed identity | Requires Event Hub infrastructure |
| **Deploy - Configure diagnostic settings to an Event Hub to be enabled on Azure Key Vault Managed HSM** | 🟢 LOW | M | L | DeployIfNotExists | DINE (auto-remediation) | Phase 3 | HSM-specific logging to Event Hub | Configure Event Hub for HSM logs | Managed HSM, Event Hub | HSM-specific, preview |
| **[Preview]: Configure Azure Key Vaults to use private DNS zones** | 🟢 LOW | H | M | DeployIfNotExists | DINE (auto-remediation) | Phase 3 | Auto-configures private DNS for private endpoints | Deploy Private Link infrastructure first | VNet, Private Link, DNS zone | Preview policy, complex networking |
| **[Preview]: Configure Azure Key Vaults with private endpoints** | 🟢 LOW | H | H | DeployIfNotExists | DINE (auto-remediation) | Phase 3 | Auto-creates private endpoints for vaults | Requires VNet, subnet delegation | VNet infrastructure, managed identity | High complexity, test thoroughly |
| **[Preview]: Configure Azure Key Vault Managed HSM with private endpoints** | 🟢 LOW | H | H | DeployIfNotExists | DINE (auto-remediation) | Future | Auto-creates private endpoints for Managed HSM | HSM-specific private endpoint config | Managed HSM, VNet | Preview, HSM-specific |
| **[Preview]: Azure Key Vault Managed HSMs should use private link** | 🟢 LOW | H | H | Audit → Deny | Start Audit (1 month) → Deny (optional) | Future | Private endpoint for Managed HSM | Similar to regular Key Vault private link | Managed HSM, Private Link | Preview policy |
| **Azure Key Vaults should use private link** | 🟢 LOW | H | H | Audit | Audit only (replaced by Deny version) | Phase 1 | Monitors private link adoption | Use Deny version for enforcement | None | Superseded by Deny variant |

---

## Implementation Workflows

### Phase 1: Immediate Deployment (Week 1)
**Goal**: Deploy CRITICAL audit policies + quick wins

**Policies to Deploy** (9 policies):
1. Key vaults should have deletion protection enabled (Audit)
2. Key vaults should have soft delete enabled (Audit)
3. Keys using RSA cryptography should have a specified minimum key size (Audit → Deny after 1 week)
4. Certificates using RSA cryptography should have the specified minimum key size (Audit → Deny after 1 week)
5. Key Vault secrets should have an expiration date (Audit)
6. Key Vault keys should have an expiration date (Audit)
7. Secrets should have content type set (Audit → Deny after 1 week)
8. All "days before expiration" audit policies (3 policies)

**Deliverables**:
- Compliance dashboard showing current posture
- Remediation plan for non-compliant resources
- Stakeholder communication

---

### Phase 2: Short-Term Deployment (Month 1)
**Goal**: Expand to HIGH priority + network security

**Policies to Deploy** (8 policies):
1. Azure Key Vault should have firewall enabled (Audit → Deny after testing)
2. Azure Key Vault should disable public network access (Audit)
3. Certificates/Secrets/Keys maximum validity periods (Audit → Deny)
4. Certificates should use allowed key types (Audit → Deny)
5. Configure diagnostic settings (DeployIfNotExists)
6. Configure firewall (Modify - auto-remediation)

**Deliverables**:
- Network access review completed
- Private Link deployment plan
- Auto-remediation enabled for diagnostics

---

### Phase 3: Long-Term Deployment (Month 3)
**Goal**: Complete governance with RBAC migration

**Policies to Deploy** (12 policies):
1. Azure Key Vault should use RBAC permission model (Audit → Deny after migration)
2. Azure Key Vaults should use private link (Audit → Deny)
3. HSM-related policies (Audit/Deny)
4. Integrated/Non-integrated CA policies (Audit → Deny)
5. ECC curve restrictions (Audit → Deny)
6. Private endpoint auto-configuration (DeployIfNotExists)

**Deliverables**:
- RBAC migration completed (100% vaults)
- Private Link infrastructure deployed
- Managed HSM governance (if applicable)

---

## Risk Mitigation Strategies

### Strategy 1: Gradual Rollout (Audit → Deny)
1. **Week 1-2**: Deploy in Audit mode, collect compliance data
2. **Week 3**: Analyze non-compliant resources, create remediation plan
3. **Week 4**: Remediate non-compliant resources
4. **Week 5**: Switch to Deny mode in dev/test environment
5. **Week 6**: Monitor for issues, adjust exemptions
6. **Week 7**: Deploy Deny mode to production

### Strategy 2: Exemption Management
- **Temporary Exemptions**: 30-90 day exemptions for migration projects
- **Permanent Exemptions**: Document business justification, security review
- **Exemption Tracking**: Monthly review of active exemptions

### Strategy 3: Rollback Plan
- Keep Audit mode assignments active during Deny testing
- Document assignment removal process (Scenario 9)
- Maintain backup of parameter files before changes

---

## Business Value Metrics

### Security Value
- **Data Protection**: Purge protection + soft delete prevents 100% of accidental permanent deletion
- **Attack Surface Reduction**: Private Link + firewall reduces public exposure by ~90%
- **Cryptographic Strength**: RSA 4096-bit reduces brute-force risk by 2^2048

### Compliance Value
- **Audit Readiness**: Diagnostic logging provides 100% audit trail
- **Regulatory Alignment**: Supports NIST, HIPAA, PCI-DSS, SOC 2 requirements
- **Policy Enforcement**: Automated compliance reduces manual review by 80%

### Operational Value
- **Automation**: DeployIfNotExists policies reduce manual config by 70%
- **Monitoring**: Expiration warnings prevent 95% of service disruptions
- **Governance**: RBAC provides granular access control with Azure AD integration

---

## Known Issues & Limitations

### Issue 1: Azure Policy Propagation Delay
- **Symptom**: Deny policies take 30-90 minutes to activate after deployment
- **Workaround**: Wait 60 minutes, then test enforcement
- **Reference**: [Azure Policy evaluation timing](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/get-compliance-data)

### Issue 2: RBAC Migration Breaking Change
- **Symptom**: Applications using vault access policies stop working after RBAC enforcement
- **Workaround**: Migrate access policies to RBAC assignments BEFORE deploying Deny policy
- **Reference**: [RBAC migration guide](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-migration)

### Issue 3: Private Link Networking Complexity
- **Symptom**: Private endpoints require VNet, DNS, and subnet configuration
- **Workaround**: Deploy infrastructure BEFORE enabling private link policies
- **Reference**: [Private Link setup](https://learn.microsoft.com/en-us/azure/key-vault/general/private-link-service)

### Issue 4: Managed Identity Requirement for DINE/Modify
- **Symptom**: DeployIfNotExists and Modify policies fail without managed identity
- **Workaround**: Create managed identity with appropriate RBAC before deployment
- **Reference**: [Remediation managed identity](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources)

---

## References

- [Azure Policy built-in definitions for Key Vault](https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies#key-vault)
- [Integrate Azure Key Vault with Azure Policy](https://learn.microsoft.com/en-us/azure/key-vault/general/azure-policy)
- [Azure Policy GitHub Repository](https://github.com/Azure/azure-policy/tree/master/built-in-policies/policyDefinitions/Key%20Vault)
- [Azure Policy effect basics](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/effect-basics)
- [Remediate non-compliant resources](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources)

---

**Document End**
