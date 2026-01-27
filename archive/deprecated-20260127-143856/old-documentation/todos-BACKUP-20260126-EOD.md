# Todo List - Master Test Execution (2026-01-26)

## 🎯 OBJECTIVE: Fresh Start - Complete 9-Scenario Validation

**PREVIOUS WORK SUPERSEDED**: All prior P1-P10 tasks replaced with systematic 9-scenario testing plan.

**NEW PLAN**: See [MASTER-TEST-PLAN-20260126.md](MASTER-TEST-PLAN-20260126.md) for complete details.

---

## 📋 Active Testing Workflow

### Pre-Test Phase
- [X] ✅ **PRE-TEST**: Cleanup All Resources - COMPLETED (Scenario 4 cleanup 2026-01-26)
  - Method: Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst (RECOMMENDED)
  - Why: Comprehensive filters, handles hash-based names, built-in safeguards
  - See: [CLEANUP-GUIDE.md](CLEANUP-GUIDE.md) for method comparison
  - Alternatives: Rollback (❌ doesn't work), Manual (⚠️ not recommended)
  - Removes: All 46 Key Vault policy assignments
  - Result: Fresh baseline established (only sys.blockwesteurope remains)

### Phase 1: Infrastructure
- [X] ✅ **PHASE 1**: Fresh Infrastructure Setup - COMPLETED
  - Run: `.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -ActionGroupEmail "your-email@company.com"`
  - Creates: 2 RGs, managed identity, 3 test vaults, networking, monitoring
  - Duration: 15-20 minutes
  - Status: Infrastructure exists, ready for testing

### Scenario 2-7: Policy Deployments
- [X] ✅ **SCENARIO 2**: DevTest-Audit (30 policies) - SKIPPED (using full 46 instead)
  - Reason: Scenario 3 provides more comprehensive testing
  - Decision: Proceed directly to Scenario 3 for complete coverage

- [X] ✅ **SCENARIO 3**: DevTest-Full-Audit (46 policies) - COMPLETED
  - File: PolicyParameters-DevTest-Full.json
  - Scope: Subscription (updated from Resource Group)
  - Mode: Audit
  - Result: 46/46 policies deployed successfully
  - Verified: Verify-PolicyDeployment.ps1 -Scenario 3
  - Compliance: 34.97% (64 compliant, 119 non-compliant)
  - **CLEANUP**: ✅ Removed all assignments using Setup script

- [X] ✅ **SCENARIO 4**: DevTest-Remediation (46 policies with 8 DINE/Modify) - COMPLETED
  - File: PolicyParameters-DevTest-Full-Remediation.json
  - Scope: Subscription (updated from Resource Group)
  - Mode: All 46 (38 Audit + 6 DINE + 2 Modify)
  - Result: 46/46 policies deployed successfully
  - Breakdown: 38 Audit, 6 DeployIfNotExists, 2 Modify, 0 Deny
  - Fixes Applied: Verify script counts (8→46), API parameter (EnableRbacAuthorization)
  - Verified: All 46 policies confirmed deployed
  - **CLEANUP**: ✅ Removed all 46 assignments using manual method (Setup script recommended for future)

- [ ] 🔴 **SCENARIO 5**: Production-Audit (46 policies) - READY TO DEPLOY
  - File: PolicyParameters-Production.json
  - Scope: Subscription
  - Mode: Audit
  - Test: Subscription-wide compliance
  - Command: See Workflow-Test-User-Input-Guide.md Scenario 5
  - Managed Identity: Required (/subscriptions/.../id-policy-remediation)
  - Duration: 10-15 min deployment + 30-60 min evaluation
  - Log: `logs\Scenario5-Production-Audit-20260126.log` (use Start-Transcript)
  - Verify: `.\Verify-PolicyDeployment.ps1 -Scenario 5` (expect 46/46)
  - **CLEANUP**: `.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst` (answer DELETE, YES)

- [ ] 🔴 **SCENARIO 6**: Production-Deny (34 policies) - CRITICAL TESTING
  - File: PolicyParameters-Production-Deny.json
  - Scope: Subscription
  - Mode: **Deny** (blocks non-compliant resources)
  - Test: **Test-AllDenyPolicies (34 comprehensive tests)** OR Test-ProductionEnforcement (9 quick tests)
  - User Choice: Add `-TestMode Quick|Comprehensive` parameter
  - Expected Results (34 tests): 23/34 PASS, 11/34 SKIP (Managed HSM costs $500-$1000/month)
  - Expected Results (9 tests): All PASS (quick validation)
  - Document: Both testing options in TestingGuide.md
  - Duration: 15 min deployment + 15 min wait + 30-45 min testing
  - Log: `logs\Scenario6-Production-Deny-20260126.log` (use Start-Transcript)
  - Verify: `.\Verify-PolicyDeployment.ps1 -Scenario 6` (expect 34/34 or policy count)
  - **CLEANUP**: `.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst`

- [ ] 🔴 **SCENARIO 7**: Production-Remediation (46 policies with 8 DINE/Modify)
  - File: PolicyParameters-Production-Remediation.json
  - Scope: Subscription
  - Mode: All 46 policies (38 Audit + 6 DINE + 2 Modify)
  - Test: Subscription-wide auto-remediation (8 policies auto-fix non-compliant resources)
  - Auto-Remediation Policies: Private Endpoints (2), Diagnostic Settings (3), Firewall (2), Public Access (1)
  - Warning: See AUTO-REMEDIATION-GUIDE.md for prerequisites and warnings
  - Duration: 15 min deployment + 60-90 min remediation wait
  - Log: `logs\Scenario7-Production-Remediation-20260126.log` (use Start-Transcript)
  - Verify: `.\Verify-PolicyDeployment.ps1 -Scenario 7` (expect 46/46)
  - Test: `.\AzPolicyImplScript.ps1 -TestAutoRemediation` (verify DINE/Modify worked)
  - **CLEANUP**: `.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst`

### Optional & Reporting
- [ ] 🟡 **SCENARIO 8**: Tier Testing (Optional)
  - Files: Tier1-4 parameter files
  - Scope: Subscription
  - Mode: Mixed (Audit/Deny)
  - Test: Progressive tiered rollout
  - Duration: 90 minutes
  - Log: `logs\Scenario8-Tiers-20260126.log`
  - **CLEANUP**: `.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst`

- [ ] 🔴 **SCENARIO 9**: Master HTML Report - CRITICAL DELIVERABLE
  - Generate: MasterTestReport-20260126.html
  - Sections: 
    * Executive summary with compliance progression
    * All scenarios 1-7 with before/after metrics
    * Policy coverage breakdown (Audit/Deny/DINE/Modify)
    * Deny validation results (34 tests or 9 tests with PASS/SKIP)
    * Compliance dashboard data integration
    * Errors and warnings from all logs
    * Recommendations and lessons learned
  - Input Files: All 7+ scenario logs from logs\ directory
  - Duration: 30-45 minutes
  - Log: `logs\Scenario9-MasterReport-20260126.log`

---

## 📝 Additional Tracking Items

### Terminal Output Logging (Item 4)
- [ ] 🔴 **Implement for Scenarios 5-7**: Redirect all terminal output to log files
  - Method: Wrap each scenario with `Start-Transcript` / `Stop-Transcript`
  - Format: `logs\Scenario#-Name-YYYYMMDD.log`
  - Purpose: Capture errors, warnings, timing, auth issues for later analysis
  - Example:
    ```powershell
    Start-Transcript -Path ".\logs\Scenario5-Production-Audit-20260126.log" -Append
    # Run deployment commands
    Stop-Transcript
    ```
  - Status: Required for all remaining scenarios
  - Analysis: Create ErrorAnalysis-20260126.md from all logs after completion

### Deny Testing Options (Item 5)
- [ ] 🔴 **Document 9-test vs 34-test options**: Create TestingGuide.md
  - **9-test (Quick)**: Test-ProductionEnforcement function
    - Duration: 15-20 minutes
    - Coverage: Core deny policies (keys, secrets, certificates)
    - Use case: CI/CD pipelines, quick validation
  - **34-test (Comprehensive)**: Test-AllDenyPolicies function
    - Duration: 30-45 minutes
    - Coverage: All deny policies including Managed HSM
    - Expected: 23 PASS, 11 SKIP (cost constraints)
    - Use case: Governance audits, complete validation
  - Add parameter to AzPolicyImplScript.ps1: `-TestMode Quick|Comprehensive`
  - User choice: Let user select testing depth based on time/cost constraints
  - Document: When to use each option in TestingGuide.md

### HTML Report (Item 6)
- [ ] 🔴 **Generate after Scenario 7**: Summary of all scenarios
  - Timeline view: Scenario progression with timestamps
  - Compliance metrics: Before/after for each scenario
  - Policy effectiveness: Which policies found most issues
  - Deny validation: Results from Scenario 6 testing (9 or 34 tests)
  - Auto-remediation impact: Before/after from Scenario 7
  - Error summary: All issues encountered with resolutions
  - Format: HTML dashboard with charts and tables
  - Output: MasterTestReport-20260126.html

### Verification Tracking (Item 7)
- [X] ✅ **Implementation of policies**: Scenarios 1-4 complete (46 policies verified)
- [ ] 🟡 **Verification policies implemented and working**: In progress
  - Scenarios 1-4: ✅ Verified with Verify-PolicyDeployment.ps1
  - Scenarios 5-7: ⏳ Pending deployment and verification
  - Next: Run verification after each scenario deployment
- [ ] 🟡 **Verification policies show data**: Partially complete
  - Audit data: ✅ Scenario 3-4 showed 34.97% compliance (64 compliant, 119 non-compliant)
  - Blocking operations: ⏳ Scenario 6 will test (Deny mode)
  - Auto-remediation: ⏳ Scenario 7 will verify (DINE/Modify)
  - Next: Check compliance after each scenario, document findings
- [X] ✅ **Cleanup when necessary**: Scenario 4 cleanup complete
  - Method: Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst (DOCUMENTED)
  - Alternative: Manual method works, Rollback doesn't work (documented in CLEANUP-GUIDE.md)
  - Next: Use Setup cleanup between Scenarios 5-6-7
- [ ] 🔴 **Compliance dashboard**: Pending final report
  - Script exists: CreateComplianceDashboard.ps1
  - Status: Not yet executed
  - Next: Generate after Scenario 7 complete
  - Integration: Include in MasterTestReport-20260126.html

---

## 📚 Documentation Tasks

- [ ] 🔴 **DOC-1**: Create TestingGuide.md
  - Explain: Test-ProductionEnforcement (9 tests) vs Test-AllDenyPolicies (34 tests)
  - When to use: Quick (CI/CD) vs Comprehensive (governance audit)
  - Add parameter: `-TestMode Quick|Comprehensive`

- [ ] 🔴 **DOC-2**: Create KNOWN-LIMITATIONS.md
  - Document 11 SKIP tests: Managed HSM (7), VNet (1), CA (3)
  - Explain costs: Managed HSM $500-$1000/month
  - Mark as: "Validated via Configuration Review"

- [ ] 🔴 **DOC-3**: Log Analysis
  - Analyze all 9 log files for: Errors, warnings, timing, retries, auth issues
  - Create: ErrorAnalysis-20260126.md
  - Findings: Documented issues and resolutions

---

## 🎯 Success Criteria

### Must Pass ✅
- [ ] All infrastructure resources created
- [ ] All 9 scenarios (or 8 if skipping Tier testing) complete
- [ ] Scenario 6: 23/34 PASS (100% of testable policies)
- [ ] Scenario 6: 11/34 SKIP documented
- [ ] All log files captured
- [ ] Master HTML report generated

### Nice to Have 🎨
- [ ] All scenarios complete in <8 hours
- [ ] Zero policy assignment failures
- [ ] Compliance data within 30 minutes
- [ ] Remediation tasks successful

---

## 📊 Progress Tracking

**Total Scenarios**: 9 (PRE-TEST + 1-9)  
**Completed**: 0  
**In Progress**: None  
**Remaining**: 9  
**Estimated Time**: 7-8 hours

**Current Status**: 🔴 NOT STARTED

---

## 🚀 Quick Start

```powershell
# Create logs directory
New-Item -ItemType Directory -Path ".\logs" -Force

# Step 1: Cleanup
Start-Transcript -Path ".\logs\Phase0-Cleanup-20260126.log" -Append
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst
Stop-Transcript

# Step 2: Infrastructure
Start-Transcript -Path ".\logs\Phase1-Infrastructure-20260126.log" -Append
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -ActionGroupEmail "your-email@company.com"
Stop-Transcript

# Step 3: Proceed with Scenarios 2-9 (see MASTER-TEST-PLAN-20260126.md)
```

---

## 📋 Resource Groups Explained

**Why Two Resource Groups?**

1. **rg-policy-remediation** (Infrastructure - PERMANENT)
   - Managed Identity for policy automation
   - Log Analytics + Event Hub
   - VNet + Private DNS
   - Cost: ~$15-30/month
   - Lifecycle: Persistent across all scenarios

2. **rg-policy-keyvault-test** (Test Vaults - TEMPORARY)
   - 3 Key Vaults (compliant/partial/non-compliant)
   - Test data (secrets, keys, certificates)
   - Cost: Free (Standard tier)
   - Lifecycle: Created/deleted during testing

---

## 📝 Notes

- **CRITICAL**: Always remove policy assignments between scenarios to prevent interference
- **Timing**: Azure Policy evaluation takes 30-90 minutes - build this into schedule
- **Logging**: All terminal output captured via `Start-Transcript`
- **Cleanup**: Use `-CleanupFirst` flag for fresh start
- **Testing**: Scenario 6 uses comprehensive 34-test validation (not 9-test)

---

## 📚 Reference: Previous Testing Work

**Previous accomplishments** (preserved in todos-BACKUP-20260126.md):
- ✅ Test-AllDenyPolicies function (34 tests, 832 lines)
- ✅ Manual policy validation (6 policies verified)
- ✅ Parameter fixes (8 replacements)
- ✅ Public vault access fix
- ✅ Test 12 investigation (resolved)

**Lessons learned applied to new plan**:
- Policies enforce at creation time (need fresh vaults)
- Public network access required for testing
- EC keys require explicit curve parameters
- Azure Policy has mandatory 30-90 min evaluation delays
- Cleanup between scenarios prevents interference
