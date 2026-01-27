# Blocking Test Coverage Analysis: 9 Tests vs 34 Deny Policies

**Analysis Date**: January 23, 2026  
**Scenario**: Production Deny Mode (Scenario 5)  
**Total Deny Policies Deployed**: 34  
**Current Test Coverage**: 9 tests (26% coverage)  
**Testing Gap**: 25 policies NOT covered by blocking tests (74% gap)

---

## Executive Summary

**FINDING**: The current `Test-ProductionEnforcement` function tests only **9 operations** to validate **34 Deny policies**, resulting in a **74% testing gap**. This represents significant risk for production deployment confidence.

**RECOMMENDATION**: Expand to **22-25 comprehensive tests** covering all CRITICAL and HIGH priority policies, while documenting why certain LOW priority or parameter-variation policies are excluded.

---

## Current Test Coverage (9 Tests)

### Vault-Level Tests (3)
| Test # | Policy Tested | Priority | Phase | Status |
|--------|--------------|----------|-------|--------|
| 1 | Key vaults should have deletion protection enabled | **CRITICAL** | Phase 3 | ✅ Covered |
| 2 | Azure Key Vault should have firewall enabled | **HIGH** | Phase 2 | ✅ Covered |
| 3 | Azure Key Vault should use RBAC permission model | **HIGH** | Phase 2 | ✅ Covered |

### Baseline Test (1)
| Test # | Purpose | Priority | Phase | Status |
|--------|---------|----------|-------|--------|
| 4 | Compliant vault creation (ALL security requirements) | **CRITICAL** | All | ✅ Covered |

### Resource-Level Tests (5)
| Test # | Policy Tested | Priority | Phase | Status |
|--------|--------------|----------|-------|--------|
| 5 | Key Vault keys should have an expiration date | **HIGH** | Phase 2 | ✅ Covered |
| 6 | Key Vault secrets should have an expiration date | **HIGH** | Phase 2 | ✅ Covered |
| 7 | Keys using RSA should have minimum 2048 key size | **MEDIUM** | Phase 2 | ✅ Covered |
| 8 | Certificates should have maximum 12 month validity | **MEDIUM** | Phase 2 | ✅ Covered |
| 9 | Certificates should not expire within 30 days | **MEDIUM** | Phase 2 | ⚠️ Partial (API limitation) |

**Summary**: 9 tests cover 9 policies directly (26% coverage)

---

## Missing Test Coverage (25 Policies NOT Tested)

### 🔴 CRITICAL Priority Gaps (1 policy)
| Policy | Why Not Tested? | Risk Level | Recommendation |
|--------|----------------|------------|----------------|
| **Key vaults should have soft delete enabled** | Assumed enabled by default in modern vaults | **HIGH** | **ADD TEST** - Critical security control |

### 🟠 HIGH Priority Gaps (8 policies)
| Policy | Why Not Tested? | Risk Level | Recommendation |
|--------|----------------|------------|----------------|
| **Azure Key Vault should disable public network access** | Similar to firewall test (#2) | Medium | **ADD TEST** - Distinct from firewall rule |
| **Azure Key Vault Managed HSM should have purge protection enabled** | Managed HSM variant | Medium | Consider adding for HSM testing |
| **Azure Key Vaults should use private link** | Infrastructure complexity (requires VNet, private endpoint) | Medium | **ADD TEST** - Critical for production |
| **Keys should have maximum validity period (365 days)** | Testing expiration date covers this | Low | Consider adding parameter validation test |
| **Secrets should have maximum validity period (365 days)** | Testing expiration date covers this | Low | Consider adding parameter validation test |
| **Keys should have more than 90 days before expiration** | Overlaps with expiration date test | Low | Consider adding boundary test |
| **Secrets should have more than 90 days before expiration** | Overlaps with expiration date test | Low | Consider adding boundary test |
| **Keys should not be active longer than 365 days** | Similar to max validity test | Low | Parameter variation - can skip |

### 🟡 MEDIUM Priority Gaps (11 policies)
| Policy | Why Not Tested? | Risk Level | Recommendation |
|--------|----------------|------------|----------------|
| **Certificates should use allowed key types (RSA, EC)** | Testing RSA size validates RSA type | Low | Consider adding EC test |
| **Certificates using EC should have allowed curve names** | EC variant | Low | Add if testing EC certificates |
| **Certificates should have lifetime action triggers** | Advanced cert management | Low | Optional - lower priority |
| **Certificates issued by integrated CA (DigiCert, GlobalSign)** | Requires external CA integration | Medium | **ADD TEST** - Important for PKI compliance |
| **Certificates issued by non-integrated CA (ContosoCA)** | Requires external CA | Medium | **ADD TEST** if using non-integrated CAs |
| **Certificates issued by one of specified non-integrated CAs** | Multiple CA variant | Low | Parameter variation of above |
| **Keys should be specified cryptographic type RSA or EC** | Testing RSA validates this | Low | Consider adding EC test |
| **Keys using EC should have specified curve names** | EC variant | Low | Add if testing EC keys |
| **Certificates using RSA should have minimum 4096 key size** | Cert RSA variant | Low | **ADD TEST** - Different from key RSA test |
| **Keys should be backed by HSM** | Requires HSM-enabled vault | Medium | Consider for HSM testing scenario |
| **Secrets should have content type set** | Lower priority metadata | Low | Optional - nice-to-have |

### 🟢 LOW Priority Gaps (5 Managed HSM policies - Preview)
| Policy | Why Not Tested? | Risk Level | Recommendation |
|--------|----------------|------------|----------------|
| **[Preview] Azure Key Vault Managed HSM should disable public network access** | Managed HSM, preview feature | Low | Skip for v1.0 - preview feature |
| **[Preview] Managed HSM keys should have expiration date** | Managed HSM, covered by regular key test | Low | Skip - covered by regular keys |
| **[Preview] Managed HSM keys should have 90+ days before expiration** | Managed HSM variant | Low | Skip - covered by regular keys |
| **[Preview] Managed HSM keys using EC should have allowed curves** | Managed HSM EC variant | Low | Skip - preview feature |
| **[Preview] Managed HSM keys using RSA should have min 4096 size** | Managed HSM RSA variant | Low | Skip - covered by regular keys |

---

## Root Cause Analysis: Why Only 9 Tests?

### Design Philosophy (Inferred)
The current test suite appears designed for **representative sampling** rather than **comprehensive coverage**:

1. **Category Coverage**: Tests cover major categories (vault config, keys, secrets, certs)
2. **Risk-Based Sampling**: Focuses on CRITICAL/HIGH priority policies
3. **Practical Constraints**: 
   - Infrastructure complexity (Private Link requires VNet setup)
   - API limitations (Can't create certs with <30 day validity)
   - Managed HSM costs (expensive to test, preview features)
4. **Parameter Variations Excluded**: Policies that are parameter variations (e.g., "90 days before expiration" vs "365 days max validity") treated as duplicate tests

### Valid Reasons for Gaps
- **Parameter Variations** (6 policies): Testing one parameter validates the mechanism
- **Managed HSM Preview** (5 policies): Preview features, expensive, low adoption
- **Infrastructure Complexity** (2 policies): Private Link, external CAs require complex setup
- **API Limitations** (1 policy): Cannot test cert <30 day expiration via API

### Concerning Gaps
- **Soft Delete**: CRITICAL policy not explicitly tested
- **Public Network Access**: Different from firewall, should test both
- **Private Link**: HIGH priority for production, infrastructure complexity justified
- **CA Enforcement**: Important for PKI compliance scenarios

---

## Recommended Testing Expansion

### Option A: Moderate Expansion (17 tests total - RECOMMENDED)
Add **8 new tests** to existing 9, focusing on CRITICAL/HIGH gaps:

**New Tests to Add:**
1. ✅ **Soft Delete Required** (CRITICAL - vault-level)
2. ✅ **Public Network Access Disabled** (HIGH - vault-level)
3. ✅ **Private Link Required** (HIGH - vault-level, requires VNet setup)
4. ✅ **Certificate RSA Minimum 4096** (MEDIUM - different from key RSA test)
5. ✅ **Certificate Allowed Key Types (EC)** (MEDIUM - test EC alongside RSA)
6. ✅ **Integrated CA Enforcement (DigiCert/GlobalSign)** (MEDIUM - PKI compliance)
7. ✅ **Non-Integrated CA Enforcement** (MEDIUM - custom PKI scenarios)
8. ✅ **Key Cryptographic Type (EC)** (MEDIUM - test EC keys)

**Coverage Impact**: 17/34 = **50% coverage** (all CRITICAL + HIGH policies)

### Option B: Comprehensive Expansion (25 tests total)
Add **16 new tests** covering all non-preview, non-duplicate policies:

**All tests from Option A, PLUS:**
9. Keys using EC should have allowed curve names (P-256, P-384, P-521)
10. Certificates using EC should have allowed curve names
11. Certificate lifetime action triggers (80% life / 90 days before expiry)
12. Keys maximum validity period (365 days)
13. Secrets maximum validity period (365 days)
14. Keys minimum days before expiration (90 days)
15. Secrets minimum days before expiration (90 days)
16. Keys not active longer than 365 days
17. Secrets not active longer than 365 days
18. Keys should be HSM-backed
19. Secrets should have content type set

**Coverage Impact**: 25/34 = **74% coverage** (excludes only 5 Managed HSM preview + 4 duplicate parameter variations)

### Option C: Minimal Expansion (12 tests total)
Add **3 new tests** for CRITICAL gaps only:

**New Tests:**
1. ✅ **Soft Delete Required** (CRITICAL)
2. ✅ **Public Network Access Disabled** (HIGH)
3. ✅ **Private Link Required** (HIGH - if infrastructure exists)

**Coverage Impact**: 12/34 = **35% coverage** (all CRITICAL, most HIGH)

---

## Implementation Recommendations

### For v1.0 Release: **Option A (17 tests, 50% coverage)**

**Rationale:**
- Covers 100% of CRITICAL policies
- Covers 100% of HIGH policies
- Includes important MEDIUM policies (PKI, crypto diversity)
- Excludes LOW priority and parameter variations
- Practical implementation effort (2-3 hours)
- Infrastructure requirements manageable (VNet for Private Link test)

**Implementation Plan:**
1. **Phase 1** (30 min): Add 2 vault-level tests (Soft Delete, Public Access)
2. **Phase 2** (60 min): Add 4 resource-level tests (Cert RSA 4096, Cert EC, Key EC, CA enforcement)
3. **Phase 3** (60 min): Add Private Link test (requires VNet infrastructure setup)

### For v2.0 Future Work: **Option B (25 tests, 74% coverage)**

**Additional Tests:**
- Parameter boundary tests (90 days, 365 days, content type)
- HSM-backed resources test
- EC curve name variations
- Certificate lifetime action triggers

**Benefit:** Comprehensive validation for regulated industries (finance, healthcare, government)

---

## Testing Gap Impact Assessment

### Current Risk (9 tests)
- **CRITICAL policies**: 1/2 tested (50%) - **Soft Delete NOT tested**
- **HIGH policies**: 5/9 tested (56%) - Missing Public Access, Private Link, max validity variations
- **MEDIUM policies**: 3/13 tested (23%) - Missing CA enforcement, EC testing, HSM
- **Overall confidence**: 26% coverage leaves 74% of policies unvalidated

### Risk Mitigation with Option A (17 tests)
- **CRITICAL policies**: 2/2 tested (100%) ✅
- **HIGH policies**: 9/9 tested (100%) ✅
- **MEDIUM policies**: 6/13 tested (46%)
- **Overall confidence**: 50% coverage, 100% CRITICAL+HIGH validation

### Production Deployment Confidence
| Option | Tests | Coverage | CRITICAL | HIGH | Release Ready? |
|--------|-------|----------|----------|------|----------------|
| Current (9) | 9 | 26% | 50% | 56% | ⚠️ **Not recommended** - Soft Delete gap |
| Option C (12) | 12 | 35% | 100% | 78% | ⚠️ **Marginal** - Missing CA, crypto diversity |
| **Option A (17)** | 17 | 50% | 100% | 100% | ✅ **RECOMMENDED** for v1.0 |
| Option B (25) | 25 | 74% | 100% | 100% | ✅ **Ideal** for regulated industries |

---

## Technical Implementation Notes

### New Test Infrastructure Requirements

#### Test: Private Link Required
**Requirement**: VNet with private endpoint capability
```powershell
# Setup (one-time infrastructure)
- VNet: existing from Setup-AzureKeyVaultPolicyEnvironment.ps1
- Subnet: dedicated for private endpoints
- Private DNS: privatelink.vaultcore.azure.net
- NSG: allow Azure backbone traffic
```

#### Test: CA Enforcement (Integrated)
**Requirement**: Configure vault to allow integrated CAs
```powershell
# Policy parameter: "allowedCAs": ["DigiCert", "GlobalSign"]
# Test: Create cert with "IssuerName Self" (should be blocked)
# Alternative: Create cert with integrated CA (should pass)
```

#### Test: CA Enforcement (Non-Integrated)
**Requirement**: External CA certificate
```powershell
# Policy parameter: "caCommonName": "ContosoCA"
# Test: Create cert with different CA (should be blocked)
# Challenge: Requires actual external CA integration
# Workaround: Test policy blocks creation when CA name doesn't match
```

#### Test: Elliptic Curve Keys/Certs
**Requirement**: None (built-in Azure Key Vault support)
```powershell
# Keys: Add-AzKeyVaultKey -KeyType 'EC' -CurveName 'P-521' (invalid curve)
# Certs: New-AzKeyVaultCertificatePolicy -KeyType 'EC' -Curve 'P-521'
```

---

## Proposed Test Function Enhancement

### New Function: `Test-AllDenyPolicies` (25 tests - Option B)
Location: AzPolicyImplScript.ps1, lines ~1200-2000

**Structure:**
```powershell
function Test-AllDenyPolicies {
    [CmdletBinding()]
    param(
        [ValidateSet('Critical', 'High', 'Medium', 'Low', 'All')]
        [string]$Priority = 'High',
        
        [switch]$IncludeManagedHSM,
        [switch]$IncludeInfrastructureTests  # Private Link, CAs
    )
    
    # Test organization:
    # 1. Vault-Level (6 tests: purge, soft delete, RBAC, firewall, public access, private link)
    # 2. Certificate Tests (9 tests: expiration, validity, CA, RSA size, EC curves, key types)
    # 3. Key Tests (7 tests: expiration, validity, RSA size, EC curves, key types, HSM, active days)
    # 4. Secret Tests (5 tests: expiration, validity, content type, min days, active days)
    # 5. Managed HSM Tests (5 tests - optional with -IncludeManagedHSM)
}
```

### Enhanced Function: `Test-ProductionEnforcement` (17 tests - Option A)
**Change**: Add 8 new tests to existing function

**Pros:**
- Maintains existing test framework
- Backward compatible with current scripts
- Incremental improvement

**Cons:**
- Function becomes longer (1200+ lines)
- Harder to maintain
- All-or-nothing execution

**Recommendation**: Keep `Test-ProductionEnforcement` at 17 tests (Option A), create separate `Test-AllDenyPolicies` for comprehensive 25-test suite (Option B).

---

## Documentation Updates Required

### 1. Update TestCoverageMatrix.md
- Add new section: "Blocking Test Coverage Gap Analysis"
- Reference this document
- Mark policies tested vs not tested

### 2. Update DEPLOYMENT-WORKFLOW-GUIDE.md
- Document recommended testing strategy (Option A for v1.0)
- Explain why certain policies aren't tested
- Provide manual verification steps for untested policies

### 3. Create KNOWN-ISSUES.md
- Document testing limitations:
  - API cannot create certs with <30 day validity
  - Managed HSM tests require expensive infrastructure
  - CA enforcement tests require external CA integration
  - Private Link tests require VNet setup

### 4. Update todos.md
- Mark Task 10 as "in-progress"
- Add new task: "Implement Expanded Blocking Tests (Option A - 8 new tests)"

---

## Conclusion

**CURRENT STATE**: 9 tests provide basic validation but miss CRITICAL gaps (Soft Delete) and important HIGH priority policies (Public Access, Private Link, CA enforcement).

**RECOMMENDED ACTION**: Implement **Option A (17 tests, 50% coverage)** for v1.0 release:
- ✅ 100% CRITICAL policy coverage
- ✅ 100% HIGH policy coverage
- ✅ Key MEDIUM policies (PKI, crypto diversity)
- ⏱️ 2-3 hours implementation effort
- ✅ Acceptable production deployment confidence

**FUTURE WORK**: Consider **Option B (25 tests, 74% coverage)** for v2.0 or regulated industry deployments requiring comprehensive validation.

**RISK MITIGATION**: Document untested policies in KNOWN-ISSUES.md with manual verification procedures for customers who need 100% coverage.

---

## Appendix: Full Policy Mapping

### All 34 Deny Policies by Category

#### Vault-Level Policies (6)
1. ✅ **Key vaults should have soft delete enabled** [CRITICAL] - **NOT TESTED** ❌
2. ✅ **Key vaults should have deletion protection enabled** [CRITICAL] - **TESTED** (Test 1)
3. **Azure Key Vault should disable public network access** [HIGH] - **NOT TESTED** ❌
4. ✅ **Azure Key Vault should have firewall enabled** [HIGH] - **TESTED** (Test 2)
5. **Azure Key Vault Managed HSM should have purge protection enabled** [HIGH-HSM] - **NOT TESTED**
6. ✅ **Azure Key Vault should use RBAC permission model** [HIGH] - **TESTED** (Test 3)

#### Certificate Policies (9)
7. **Certificates should use allowed key types** [MEDIUM] - **NOT TESTED** ❌
8. **Certificates using EC should have allowed curve names** [MEDIUM] - **NOT TESTED**
9. ✅ **Certificates should have maximum validity period (12mo)** [MEDIUM] - **TESTED** (Test 8)
10. **Certificates should have lifetime action triggers** [MEDIUM] - **NOT TESTED**
11. **Certificates issued by integrated CA (DigiCert/GlobalSign)** [MEDIUM] - **NOT TESTED** ❌
12. **Certificates issued by non-integrated CA (ContosoCA)** [MEDIUM] - **NOT TESTED** ❌
13. **Certificates issued by one of non-integrated CAs** [MEDIUM] - **NOT TESTED**
14. ✅ **Certificates should not expire within 90 days** [MEDIUM] - **PARTIAL TESTED** (Test 9)
15. **Certificates using RSA should have minimum 4096 key size** [MEDIUM] - **NOT TESTED** ❌

#### Key Policies (13)
16. **Keys should have maximum validity period (365 days)** [HIGH] - **NOT TESTED**
17. ✅ **Key Vault keys should have an expiration date** [HIGH] - **TESTED** (Test 5)
18. **Keys should have more than 90 days before expiration** [HIGH] - **NOT TESTED**
19. **Keys should not be active longer than 365 days** [HIGH] - **NOT TESTED**
20. **Keys should be specified cryptographic type RSA or EC** [MEDIUM] - **NOT TESTED** ❌
21. ✅ **Keys using RSA should have minimum 2048 key size** [MEDIUM] - **TESTED** (Test 7)
22. **Keys using EC should have specified curve names** [MEDIUM] - **NOT TESTED**
23. **Keys should be backed by HSM** [MEDIUM] - **NOT TESTED**
24. **[Preview] Managed HSM keys should have expiration date** [LOW-HSM] - **NOT TESTED**
25. **[Preview] Managed HSM keys should have 90+ days before expiration** [LOW-HSM] - **NOT TESTED**
26. **[Preview] Managed HSM keys using EC should have allowed curves** [LOW-HSM] - **NOT TESTED**
27. **[Preview] Managed HSM keys using RSA should have min 4096 size** [LOW-HSM] - **NOT TESTED**
28. **[Preview] Managed HSM should disable public network access** [LOW-HSM] - **NOT TESTED**

#### Secret Policies (6)
29. **Secrets should have maximum validity period (365 days)** [HIGH] - **NOT TESTED**
30. ✅ **Key Vault secrets should have an expiration date** [HIGH] - **TESTED** (Test 6)
31. **Secrets should have more than 90 days before expiration** [HIGH] - **NOT TESTED**
32. **Secrets should not be active longer than 365 days** [HIGH] - **NOT TESTED**
33. **Secrets should have content type set** [LOW] - **NOT TESTED**
34. **Azure Key Vaults should use private link** [HIGH] - **NOT TESTED** ❌

**Legend:**
- ✅ = Policy tested in current suite
- ❌ = Critical gap requiring test
- [CRITICAL/HIGH/MEDIUM/LOW] = Priority level
- [HSM] = Managed HSM variant
