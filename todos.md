# Todo List - Sprint 1 & v1.2.0 Release

**Updated**: 2026-01-29 17:15  
**Status**: Sprint 1 Task 1.1 Inventory Work + v1.2.0 Documentation Cleanup  
**Completed Today**: CSV bug fix (98.9% corruption), AAD inventory re-run (82 KVs), Secret mgmt gap analysis

---

## 🎯 SPRINT 1 TASK 1.1: Environment Discovery & Baseline Assessment

**User Story**: Conduct comprehensive discovery of all Azure subscriptions to establish deployment scope and baseline compliance state.

**Acceptance Criteria**: ✅ Complete inventory of all Azure subscriptions and Key Vault resources delivered in documented format (Excel/CSV with subscription IDs, resource counts, owners, environments)

### ✅ COMPLETED TODAY (January 29, 2026)

**Inventory & Data Gathering**:
- [x] **AAD Account Tests**: Ran Test 2 (Key Vaults) + Test 3 (Policies) successfully
- [x] **CSV Data Quality**: Fixed 98.9% corruption bug in Get-KeyVaultInventory.ps1
- [x] **Key Vault Inventory**: 82 vaults discovered across 838 subscriptions (100% valid data)
- [x] **Policy Inventory**: 34,642 policy assignments (99.2% valid data)
- [x] **Compliance Baseline**: Soft Delete 98.8%, Purge Protection 32.9%, RBAC 84.1%
- [x] **Secret Management Gap Analysis**: Discovered 0/20 secret/cert/key policies deployed (CRITICAL)
- [x] **Existing Policies**: Identified 3,225 KV-related assignments (Wiz scanner)
- [x] **Location Distribution**: westus2 (52%), westus (33%), eastus/eastus2 (15%)
- [x] **Bug Fixes**: Get-KeyVaultInventory.ps1 (4 changes) + Validate-CSVDataQuality.ps1 (482 lines)
- [x] **Documentation**: 5 new files (bug reports, policy matrix, impact analysis)

**MSA Account Tests** (Completed Earlier This Week):
- [x] **MSA Account Tests**: Ran comprehensive Test 0-4 (all passed)
- [x] **Subscription Count**: 838 subscriptions total (same for both accounts)
- [x] **Test Framework**: Validated Run-ComprehensiveTests.ps1 + Run-ParallelTests-Fast.ps1

### ⏳ PENDING - SPRINT 1 TASK 1.1 COMPLETION

**Priority 1: Complete AAD Account Test Coverage** (OPTIONAL but recommended for baseline):
- [ ] **Run AAD Comprehensive Tests**: Execute Run-ComprehensiveTests.ps1 -AccountType AAD
  - Adds Test 0 (Prerequisites/RBAC validation)
  - Adds Test 1 (Subscription inventory as standalone CSV)
  - Adds Test 4 (Full discovery - combined Test 2+3)
  - **Estimated Time**: 30 minutes
  - **Value**: Complete 5-test baseline matching MSA tests (documentation completeness)
  - **Risk**: LOW - We already have production data from Test 2+3
  - **User Decision Needed**: Run for complete baseline or skip (current data sufficient)?

**Priority 2: Pre-requisites Documentation Review**:
- [ ] **Review DEPLOYMENT-PREREQUISITES.md**: Verify it matches Sprint 1 needs
  - Current file: 717 lines, covers Azure permissions, modules, parameter files
  - **Question**: Does this meet user's earlier request for pre-reqs .md file?
  - **Action Needed**: Confirm if additional pre-reqs doc needed OR update existing file
  - **User Decision Needed**: Is current DEPLOYMENT-PREREQUISITES.md sufficient?

**Priority 3: Stakeholder & Environment Documentation** (Sprint 1 deliverables):
- [ ] **Create Stakeholder Contact List**: Cloud Brokers, Cyber Defense, subscription owners
  - Input: Need stakeholder names/contacts from Intel team
  - Output: STAKEHOLDER-CONTACTS.md with team matrix
  - **Blocker**: Requires user input (Intel organizational knowledge)
  
- [ ] **Create Gap Analysis Report**: What's missing vs what's needed
  - Based on: 82 KVs found, 0/20 secret policies, 32.9% purge protection, 20.7% private network
  - Output: SPRINT1-GAP-ANALYSIS.md
  - **Status**: Can be created from existing data
  
- [ ] **Create Risk Register**: Unknowns, dependencies, blockers
  - Based on: Secret expiration risk, purge protection gap, public network exposure
  - Output: SPRINT1-RISK-REGISTER.md
  - **Status**: Can be created from existing data

**Priority 4: Subscription Inventory Enhancement**:
- [ ] **Create Subscription Owners Mapping**: Link 838 subscriptions to business owners
  - Input: Requires Intel organizational data
  - Output: SUBSCRIPTION-OWNERS.md or enhanced CSV
  - **Blocker**: Requires user input (Intel organizational knowledge)
  
- [ ] **Environment Classification**: Tag subscriptions as Dev/Test/Prod
  - Current: 838 subscriptions, unknown environment split
  - Output: Enhanced CSV with Environment column
  - **Method**: Parse subscription names or user-provided mapping

**Priority 5: Workspace Cleanup** (remaining items):
- [ ] **Service Principal Testing**: Complete SP tests (deferred due to terminal issues)
  - Test: Run-ParallelTests-Fast.ps1 -AccountType ServicePrincipal
  - **Blocker**: Terminal instability needs resolution
  - **Estimated Time**: 20 minutes (if terminal stable)

---

## 📋 v1.2.0 Documentation Cleanup Tasks (51 Items)

### PACKAGE-README.md (8 items)
- [ ] 1. ✅ Release info already shows 1.2.0 (VERIFIED - no fix needed)
- [ ] 2. ✅ Package version already shows 1.2.0 (VERIFIED - no fix needed)
- [ ] 3. ✅ QUICKSTART.md already hyperlinked (VERIFIED - line 33)
- [ ] 4. Update verification report reference from "RELEASE-1.1.1" to "RELEASE-1.2.0" (line 55)
- [ ] 5. Break down DevTest scenarios 1-3 in deployment table if they are separate scenarios
- [ ] 6. ✅ CLEANUP-EVERYTHING-GUIDE.md already hyperlinked (VERIFIED - line 106)
- [ ] 7. ✅ Value-add metrics calculations already detailed (VERIFIED - lines 118-145)
- [ ] 8. Verify all hyperlinks work correctly (comprehensive check)

### FILE-MANIFEST.md (3 items)
- [ ] 9. Update package version number in title/header to 1.2.0 (currently shows 1.2.0 but verify)
- [ ] 10. Remove "enhanced" from Scripts section, "complete" from Documentation, and green checkmarks
- [ ] 11. Update verification report reference from "RELEASE-1.1.1" to "RELEASE-1.2.0"

### QUICKSTART.md (2 items)  
- [ ] 12. Add breaking-impact warning column to Scenario 5 table (auto-remediation risks)
- [ ] 13. Verify all scenario cross-reference links point to correct scenario numbers

### README.md (9 items)
- [ ] 14. Update git clone section per earlier chat history request (remove or revise clone instructions)
- [ ] 15. Fix font inconsistency: TESTING-MAPPING.md and PolicyParameters-QuickReference.md
- [ ] 16. Review "Testing & Validation" section - remove if Tier-based testing obsolete
- [ ] 17. Remove "Phased Rollout: Tier 1-4 deployment strategy" if obsolete
- [ ] 18. Fix font/style for items under "Comprehensive Test Documentation"
- [ ] 19. Update or remove Tier-based testing references throughout document
- [ ] 20. Fix "Code Location" line formatting/style
- [ ] 21. Update version from "2.0" to "1.2.0" (multiple locations)
- [ ] 22. Remove line: "Issues: GitHub Issues"

### CLEANUP-EVERYTHING-GUIDE.md (12 items)
- [ ] 23. Check if Cleanup-Workspace.ps1 script exists; remove reference if not needed
- [ ] 24. Remove "Tonight's Recommendation" section with temporal "tonight" references
- [ ] 25. Remove "OPTION 1: Keep everything overnight" guidance
- [ ] 26. Remove "OPTION 2: Remove ONLY expensive infrastructure" overnight guidance
- [ ] 27. Remove "Expected Tomorrow:" section with "tomorrow" references
- [ ] 28. Remove agenda items about "tomorrow" unless future-facing support guidance
- [ ] 29. Remove all "(Your Question)" text markers
- [ ] 30. Convert Related Documentation section to hyperlinks
- [ ] 31. Add timing guidance for future cleanup actions (when/how to cleanup after production use)
- [ ] 32. Add steps/caveats for production cleanup scenarios
- [ ] 33. Remove any other temporal "tonight"/"tomorrow" references
- [ ] 34. Keep strategic guidance but remove session-specific advice

### Comprehensive-Test-Plan.md (7 items)
- [ ] 35. Update test matrix - remove "T#.#" Tier terminology if obsolete
- [ ] 36. Remove "Test Execution Summary" section (should be in HTML reports, not plan)
- [ ] 37. Update "Test Execution and Phases" to match current scenario-based methodology
- [ ] 38. Verify MSDN subscription limitation #8 (blocked policy) - may be outdated
- [ ] 39. Check if "Scenario6-Final-Results.md" reference is valid or should be removed
- [ ] 40. Review "Test Summary" section - remove if not needed for release package
- [ ] 41. Review "Next Steps" section - remove session-specific items

### Cross-Cutting Tasks (8 items)
- [ ] 42. **Master Report Script**: Decide if it adds value beyond scenario HTML reports; include with docs or remove all references
- [ ] 43. **Multi-Subscription CSV**: Verify -SubscriptionMode All/CSV/Select works (code at lines 6133-6186)
- [ ] 44. **-WhatIf Testing**: Test -WhatIf for Scenarios 2-5 (Scenario 1 already tested successfully)
- [ ] 45. **Auto-Remediation Warnings**: Add user warnings + confirmations before deploying DINE/Modify policies
- [ ] 46. **Exemption Documentation**: Review exemption process docs (currently in CLEANUP-EVERYTHING-GUIDE), ensure comprehensive
- [ ] 47. **Release Package Contents**: Verify correct docs included with correct versions (not old package versions)
- [ ] 48. **Manual Test Guidance**: Document how users can run one-off tests for secrets/policy management
- [ ] 49. **Production Confirmation Prompts**: Ensure warnings exist before deploying breaking policies

### DEPLOYMENT-PREREQUISITES.md (2 items)
- [ ] 50. Verify DevTest-Full-Testing-Plan.md existence/naming (may be different name)
- [ ] 51. Validate "Minimal File Set" folder structure matches actual release package structure

---

## 🚀 Work Plan

### ASSIGNED TO GITHUB COPILOT CODING AGENT (PR Created)
✅ **PR Created**: All 51 documentation cleanup tasks + auto-remediation warnings
- Tasks 1-51: All documentation fixes across 8 files
- Auto-remediation warnings implementation (CRITICAL)
- Master Report script decision + documentation
- Exemption process documentation review
- Manual test guidance documentation

**Status**: Agent working asynchronously - monitor PR for completion

### PRIORITY FOR TOMORROW (Manual Testing Required - Est. 1-2 hours)
These tasks require manual testing and cannot be automated by coding agent:

1. **Test -WhatIf All Scenarios** (HIGH PRIORITY)
   - [ ] Test Scenario 2: DevTest Full (46 policies)
   - [ ] Test Scenario 3: Production Audit (46 policies)  
   - [ ] Test Scenario 4: Production Deny (34 Deny policies)
   - [ ] Test Scenario 5: Auto-Remediation (8 DINE/Modify policies)
   - Verify "WhatIf: Would create/update" messages display correctly
   - Verify no actual Azure resources are modified

2. **Verify Multi-Subscription Deployment** (MEDIUM PRIORITY)
   - [ ] Test -SubscriptionMode Current (default)
   - [ ] Test -SubscriptionMode All (with confirmation)
   - [ ] Test -SubscriptionMode Select (interactive)
   - [ ] Test -SubscriptionMode CSV with subscriptions-template.csv
   - Verify code at lines 6133-6186 handles all modes correctly

3. **Final Release Package Verification** (AFTER PR MERGE)
   - [ ] Merge coding agent PR
   - [ ] Copy fixed files to new v1.2.0-FINAL package
   - [ ] Verify all documentation files are latest versions
   - [ ] Verify all scripts include -WhatIf fix
   - [ ] Verify folder structure matches documentation
   - [ ] Create v1.2.0-FINAL release package ZIP

**Est. Total Time**: 1-2 hours for testing + 30 min for package creation

---

## 📊 Progress Tracking

**Workspace Todos**: 14 consolidated tasks (tracking same 51 items)
**Completion**: 0/51 items (3 verified as already correct)
**Est. Time Remaining**: 3-5 hours total work
