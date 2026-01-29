# Todo List - v1.2.0 Release Preparation

**Updated**: 2026-01-28 18:50  
**Status**: Documentation Cleanup in Progress  
**Completed Today**: -WhatIf critical bug fix (AzPolicyImplScript.ps1 line 6770)

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
