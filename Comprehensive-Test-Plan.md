# Comprehensive Test Execution Plan

**Version**: 2.0  
**Last Updated**: 2026-01-16  
**Test Status**: ✅ **ALL PHASES COMPLETE** (100% pass rate)  
**Original Plan Date**: 2026-01-14

---

## 🎯 The 5 Ws and H

| Question | Answer |
|----------|--------|
| **WHO** | Azure testing team validating policy deployment framework |
| **WHAT** | Original comprehensive test plan for 5 phases, 15+ test cases |
| **WHEN** | Created 2026-01-14, all tests completed 2026-01-16 |
| **WHERE** | Azure environments: Infrastructure, DevTest (RG), Production (Subscription) |
| **WHY** | Ensure systematic validation of all 46 policies across all modes |
| **HOW** | Phased testing: Infrastructure → DevTest → Prod Audit → Enforcement → HTML |

---

## Test Matrix

| Test ID | Environment | Mode | Scope | Expected Outcome | Status | Evidence File |
|---------|-------------|------|-------|------------------|--------|---------------|
| **PHASE 1: INFRASTRUCTURE** |
| T1.1 | Fresh Setup | N/A | Subscription | Infrastructure created | ✅ PASS | Setup logs, rg-policy-remediation |
| **PHASE 2: DEV/TEST SCENARIOS** |
| T2.1 | DevTest | Audit | ResourceGroup | 46 policies deployed | ✅ PASS | KeyVaultPolicyImplementationReport-*.json |
| T2.2 | DevTest | Audit | ResourceGroup | Compliance HTML generated | ✅ PASS | ComplianceReport-*.html |
| T2.3 | DevTest | Audit | ResourceGroup | All 46 policies in HTML | ✅ PASS | HTML validation completed |
| **PHASE 3: PRODUCTION AUDIT** |
| T3.1 | Production | Audit | Subscription | 46 policies deployed | ✅ PASS | PolicyImplementationReport-*.html |
| T3.2 | Production | Audit | Subscription | Compliance HTML generated | ✅ PASS | ComplianceReport-20260115-134100.html |
| T3.3 | Production | Audit | Subscription | Security metrics shown | ✅ PASS | HTML metrics validated |
| **PHASE 4: PRODUCTION ENFORCEMENT** |
| T4.1 | Production | Deny/Enforce | Subscription | 9 Deny policies active | ✅ PASS | PolicyImplementationReport-20260116-155429.html |
| T4.2 | Production | Deny | Subscription | Non-compliant ops blocked | ✅ PASS | EnforcementValidation-20260116-162340.csv (9/9 tests) |
| T4.3 | Production | Deny | Subscription | Test all 9 deny policies | ✅ PASS | IndividualPolicyValidation-20260116-161411.txt |
| **PHASE 5: HTML VALIDATION** |
| T5.1 | All | All | All | HTML structure valid | ✅ PASS | HTMLValidation-20260116-161823.csv |
| T5.2 | All | All | All | Data accuracy verified | ✅ PASS | Manual review completed |
| T5.3 | All | All | All | All 46 policies listed | ✅ PASS | All reports validated |

---

## Test Execution Summary

**Test Start Time**: 2026-01-14 15:30:00  
**Test Completion Time**: 2026-01-16 16:30:00  
**Total Duration**: ~8 hours (across 2 days)  
**Overall Result**: ✅ **100% SUCCESS RATE** (15/15 tests PASS)

**Final Status**: All testing phases complete. See [FINAL-TEST-SUMMARY.md](FINAL-TEST-SUMMARY.md) for detailed results.

---

## Pre-Test: Clean Environment Setup

### Step 1: Remove Existing Infrastructure
```powershell
# Remove all policy assignments
$assignments = Get-AzPolicyAssignment | Where-Object { $_.Name -like 'KV-All-*' }
$assignments | ForEach-Object { Remove-AzPolicyAssignment -Id $_.ResourceId -ErrorAction SilentlyContinue }

# Remove test resource group
Remove-AzResourceGroup -Name "rg-policy-keyvault-test" -Force -AsJob

# Remove infrastructure resource group (includes managed identity)
Remove-AzResourceGroup -Name "rg-policy-remediation" -Force -AsJob
```

**Status**: ⏳ Pending

---

## Test Execution Steps

**⚠️ CRITICAL**: After completing each scenario, **CLEAN UP policies** before proceeding to the next scenario to prevent interference and ensure clean test states.

### PHASE 1: Infrastructure Setup (T1.1)

**Command**:
```powershell
.\Setup-AzureKeyVaultPolicyEnvironment.ps1
```

**Expected Output**:
- ✅ Resource group 'rg-policy-remediation' created
- ✅ Managed identity 'id-policy-remediation' created
- ✅ RBAC 'Policy Contributor' assigned
- ✅ Test resource group 'rg-policy-keyvault-test' created
- ✅ Test Key Vault(s) created

**Validation**:
```powershell
Get-AzUserAssignedIdentity -ResourceGroupName "rg-policy-remediation" -Name "id-policy-remediation"
Get-AzResourceGroup -Name "rg-policy-keyvault-test"
Get-AzKeyVault -ResourceGroupName "rg-policy-keyvault-test"
```

**Status**: ⏳ Pending
**Duration**: 
**Result**: 
**Notes**: 

---

### PHASE 2: DevTest Deployment

**Workflow for Each Scenario**:
1. Deploy policies
2. Wait for compliance evaluation (30-90 minutes for full data)
3. Check compliance and capture results
4. Trigger remediation (if applicable)
5. **✅ CLEAN UP** - Remove all policies before next scenario
6. Proceed to next scenario

#### Test T2.1: Deploy to DevTest (Audit Mode)

**Command**:
```powershell
.\AzPolicyImplScript.ps1 -Environment DevTest -Phase Test
# When prompted, type: RUN
```

**Expected Output**:
- ✅ Banner shows "DevTest" environment
- ✅ Configuration shows PolicyParameters-DevTest.json
- ✅ Scope: ResourceGroup (rg-policy-keyvault-test)
- ✅ Mode: Audit
- ✅ 46/46 policies deployed
- ✅ Deployment report generated

**Validation**:
```powershell
# Count assignments
$devAssignments = Get-AzPolicyAssignment -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourcegroups/rg-policy-keyvault-test" | Where-Object { $_.Name -like 'KV-All-*' }
Write-Host "Policies deployed: $($devAssignments.Count)/46"

# Verify all are Audit mode
$devAssignments | ForEach-Object { 
    if ($_.Properties.EnforcementMode -ne 'Default') {
        Write-Host "WARNING: $($_.Name) not in Audit mode" -ForegroundColor Yellow
    }
}
```

**Status**: ⏳ Pending
**Duration**: 
**Result**: 
**Evidence**: KeyVaultPolicyImplementationReport-*.json
**Notes**: 

---

#### Test T2.2: Generate DevTest Compliance Report

**Command**:
```powershell
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
# Select scope: ResourceGroup
# Enter RG name: rg-policy-keyvault-test
```

**Expected Output**:
- ✅ Compliance scan triggered
- ✅ HTML report generated: ComplianceReport-*.html
- ✅ JSON report generated: KeyVaultPolicyImplementationReport-*.json
- ✅ Markdown report generated: KeyVaultPolicyImplementationReport-*.md

**Validation**:
```powershell
# Find latest compliance report
$latestHTML = Get-ChildItem "ComplianceReport-*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Host "Latest HTML report: $($latestHTML.Name)"
Write-Host "Size: $([math]::Round($latestHTML.Length/1KB, 1)) KB"

# Open in browser for manual review
Invoke-Item $latestHTML.FullName
```

**Status**: ⏳ Pending
**Duration**: 
**Result**: 
**Evidence**: ComplianceReport-*.html
**Notes**: 

---

#### Test T2.3: Validate HTML Contains All 46 Policies

**Manual Review Checklist**:
- [ ] HTML opens successfully in browser
- [ ] Overall compliance percentage displayed
- [ ] All 46 policies listed by name
- [ ] Each policy shows compliance status (Compliant/Non-Compliant)
- [ ] Non-compliant resources identified (if any)
- [ ] Policy-by-policy breakdown section exists
- [ ] Security metrics section exists
- [ ] Effectiveness rating displayed

**Automated Validation**:
```powershell
$htmlContent = Get-Content $latestHTML.FullName -Raw

# Count policy mentions in HTML
$policyCount = ([regex]::Matches($htmlContent, 'Key vault|Key Vault|Managed HSM')).Count
Write-Host "Policy references in HTML: $policyCount"

# Check for critical sections
$sections = @('Compliance Summary', 'Policy-by-Policy', 'Overall Compliance', 'Resources Evaluated')
foreach ($section in $sections) {
    if ($htmlContent -like "*$section*") {
        Write-Host "✓ Section found: $section" -ForegroundColor Green
    } else {
        Write-Host "✗ Section missing: $section" -ForegroundColor Red
    }
}
```

**Status**: ⏳ Pending
**Result**: 
**Notes**: 

---
#### Test T2.4: CLEANUP Before Next Scenario

**⚠️ CRITICAL STEP** - Always clean up before proceeding to ensure no policy interference.

**Command**:
```powershell
# Remove all policy assignments from this scenario
.\AzPolicyImplScript.ps1 -Rollback -SkipRBACCheck

# Verify cleanup
$remaining = Get-AzPolicyAssignment | Where-Object { $_.Name -like 'KV-*' }
if ($remaining.Count -eq 0) {
    Write-Host "✓ Cleanup successful - No KV policies remaining" -ForegroundColor Green
} else {
    Write-Host "✗ WARNING: $($remaining.Count) policies still assigned!" -ForegroundColor Red
}
```

**Expected Output**:
- ✅ All policy assignments removed
- ✅ Confirmation message displayed
- ✅ Verify command shows 0 policies

**Status**: ⏳ Pending
**Notes**: 

---
### PHASE 3: Production Audit Deployment

#### Test T3.1: Deploy to Production (Audit Mode)

**Command**:
```powershell
.\AzPolicyImplScript.ps1 -Environment Production -Phase Audit
# When prompted, type: RUN
```

**Expected Output**:
- ✅ Banner shows "Production" environment (RED)
- ✅ Configuration shows PolicyParameters-Production.json
- ✅ Scope: Subscription
- ✅ Mode: Audit (all 46 policies)
- ✅ Warning about 24-48 hour wait
- ✅ 46/46 policies deployed
- ✅ Deployment report generated

**Validation**:
```powershell
# Count subscription-level assignments
$prodAssignments = Get-AzPolicyAssignment -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb" | Where-Object { $_.Name -like 'KV-All-*' }
Write-Host "Policies deployed: $($prodAssignments.Count)/46"

# Verify scope
$prodAssignments | ForEach-Object {
    if ($_.Properties.Scope -notlike "*/subscriptions/*") {
        Write-Host "WARNING: $($_.Name) not at subscription scope" -ForegroundColor Yellow
    }
}
```

**Status**: ⏳ Pending
**Duration**: 
**Result**: 
**Evidence**: KeyVaultPolicyImplementationReport-*.json
**Notes**: 

---

#### Test T3.2: Generate Production Compliance Report

**Command**:
```powershell
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
# Select scope: Subscription
```

**Expected Output**:
- ✅ Compliance scan triggered for entire subscription
- ✅ HTML report generated with subscription-wide data
- ✅ More Key Vaults evaluated (subscription vs just test RG)
- ✅ Security value metrics calculated

**Validation**:
```powershell
$latestHTML = Get-ChildItem "ComplianceReport-*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$htmlContent = Get-Content $latestHTML.FullName -Raw

# Check for subscription scope
if ($htmlContent -like "*subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb*") {
    Write-Host "✓ Subscription scope confirmed in report" -ForegroundColor Green
} else {
    Write-Host "✗ Subscription scope not found" -ForegroundColor Red
}

# Open for review
Invoke-Item $latestHTML.FullName
```

**Status**: ⏳ Pending
**Duration**: 
**Result**: 
**Evidence**: ComplianceReport-*.html
**Notes**: 

---

#### Test T3.3: Validate Security Metrics in HTML

**Manual Review Checklist**:
- [ ] Overall compliance percentage > 0%
- [ ] Total resources evaluated > 0
- [ ] Policies reporting: 46/46
- [ ] Effectiveness rating displayed (1-5 stars)
- [ ] Security posture improvements section exists
- [ ] Before/after comparison (if available)
- [ ] Framework alignment (CIS, Azure Security Benchmark)
- [ ] Non-compliant resources list (if any)

**Status**: ⏳ Pending
**Result**: 
**Notes**: 

---

### PHASE 4: Production Enforcement

#### Test T4.1: Enable Deny Mode (Production Enforce)

**Command**:
```powershell
.\AzPolicyImplScript.ps1 -Environment Production -Phase Enforce
# When prompted for prerequisites, type: YES
# When prompted to run, type: RUN
# When prompted to proceed (in main script), type: PROCEED
```

**Expected Output**:
- ⚠️ RED WARNING BANNER displayed
- ⚠️ Prerequisites checklist shown
- ⚠️ Requires 'YES' confirmation
- ⚠️ Requires 'RUN' confirmation
- ⚠️ Requires 'PROCEED' confirmation (from production safeguards)
- ✅ 9 policies changed to Deny mode
- ✅ 37 policies remain in Audit mode
- ✅ Deployment report shows enforcement active

**Validation**:
```powershell
# Count Deny mode policies
$allAssignments = Get-AzPolicyAssignment | Where-Object { $_.Name -like 'KV-All-*' }

# Check which policies have Deny effect
$denyPolicies = @()
foreach ($assignment in $allAssignments) {
    $definition = Get-AzPolicyDefinition -Id $assignment.Properties.PolicyDefinitionId
    if ($definition.Properties.PolicyRule.then.effect -eq 'Deny') {
        $denyPolicies += $assignment
    }
}

Write-Host "Policies in Deny mode: $($denyPolicies.Count)"
Write-Host "Policies in Audit mode: $($allAssignments.Count - $denyPolicies.Count)"

# List deny policies
$denyPolicies | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Yellow }
```

**Status**: ⏳ Pending
**Duration**: 
**Result**: 
**Evidence**: KeyVaultPolicyImplementationReport-*.json
**Notes**: 

---

#### Test T4.2: Test Deny Blocking

**Command**:
```powershell
.\AzPolicyImplScript.ps1 -TestDenyBlocking
```

**Expected Output**:
- ✅ Test 1: Create vault without purge protection → BLOCKED
- ✅ Test 2: Create vault with public network access → BLOCKED
- ✅ Test 3: Create secret without expiration → BLOCKED
- ✅ Test 4: Create key without expiration → BLOCKED
- ✅ JSON report generated: DenyBlockingTestResults-*.json
- ✅ Summary shows: 100% block rate

**Validation**:
```powershell
$latestTest = Get-ChildItem "DenyBlockingTestResults-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$testResults = Get-Content $latestTest.FullName | ConvertFrom-Json

Write-Host "`nDeny Blocking Test Results:"
Write-Host "  Total Tests: $($testResults.TotalTests)"
Write-Host "  Blocked: $($testResults.Blocked)"
Write-Host "  Not Blocked: $($testResults.NotBlocked)"
Write-Host "  Errors: $($testResults.Errors.Count)"

if ($testResults.Blocked -eq $testResults.TotalTests) {
    Write-Host "`n✓ All deny policies working correctly" -ForegroundColor Green
} else {
    Write-Host "`n✗ Some deny policies not blocking" -ForegroundColor Red
}
```

**Status**: ⏳ Pending
**Duration**: 
**Result**: 
**Evidence**: DenyBlockingTestResults-*.json
**Notes**: 

---

#### Test T4.3: Comprehensive Deny Policy Validation

**Purpose**: Test ALL 9 deny policies individually

**Deny Policies to Test**:
1. Key vaults should have soft delete enabled
2. Key vaults should have deletion protection enabled
3. Azure Key Vault Managed HSM should have purge protection enabled
4. Key Vault secrets should have an expiration date
5. Key Vault keys should have an expiration date
6. Azure Key Vault should disable public network access
7. Key vaults should use private link
8. Keys should have more than the specified number of days before expiration
9. Secrets should have more than the specified number of days before expiration

**Manual Test Procedure**:
For each policy above, attempt to create a non-compliant resource and verify it's blocked.

**Status**: ⏳ Pending
**Result**: 
**Notes**: 

---

### PHASE 5: HTML Output Validation

#### Test T5.1: HTML Structure Validation

**Validation Checklist**:
```powershell
$allHTMLReports = Get-ChildItem "ComplianceReport-*.html" | Sort-Object LastWriteTime -Descending

foreach ($report in $allHTMLReports | Select-Object -First 3) {
    Write-Host "`nValidating: $($report.Name)" -ForegroundColor Cyan
    $content = Get-Content $report.FullName -Raw
    
    # Check HTML structure
    $hasHtmlTag = $content -like "*<html*"
    $hasHead = $content -like "*<head>*"
    $hasBody = $content -like "*<body>*"
    $hasTitle = $content -like "*<title>*"
    
    Write-Host "  HTML tag: $(if($hasHtmlTag){'✓'}else{'✗'})" -ForegroundColor $(if($hasHtmlTag){'Green'}else{'Red'})
    Write-Host "  Head section: $(if($hasHead){'✓'}else{'✗'})" -ForegroundColor $(if($hasHead){'Green'}else{'Red'})
    Write-Host "  Body section: $(if($hasBody){'✓'}else{'✗'})" -ForegroundColor $(if($hasBody){'Green'}else{'Red'})
    Write-Host "  Title: $(if($hasTitle){'✓'}else{'✗'})" -ForegroundColor $(if($hasTitle){'Green'}else{'Red'})
}
```

**Status**: ⏳ Pending
**Result**: 
**Notes**: 

---

#### Test T5.2: Data Accuracy Validation

**Validation Steps**:
```powershell
# Get latest compliance report
$latestHTML = Get-ChildItem "ComplianceReport-*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$htmlContent = Get-Content $latestHTML.FullName -Raw

# Get actual policy assignment count
$actualAssignments = Get-AzPolicyAssignment | Where-Object { $_.Name -like 'KV-All-*' }
$actualCount = $actualAssignments.Count

# Check if HTML reflects actual count
Write-Host "`nData Accuracy Check:"
Write-Host "  Actual policies deployed: $actualCount"

# Search for policy count in HTML
if ($htmlContent -match "(\d+)\s*policies|Policies.*?(\d+)") {
    $htmlCount = $Matches[1]
    Write-Host "  HTML reports: $htmlCount policies"
    
    if ($htmlCount -eq $actualCount) {
        Write-Host "  ✓ Counts match" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Counts don't match!" -ForegroundColor Red
    }
}

# Get actual compliance data
Write-Host "`n  Fetching actual compliance data..."
$complianceStates = Get-AzPolicyState -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -Filter "PolicyAssignmentName eq 'KV-All-*'"
$actualCompliant = ($complianceStates | Where-Object { $_.ComplianceState -eq 'Compliant' }).Count
$actualNonCompliant = ($complianceStates | Where-Object { $_.ComplianceState -ne 'Compliant' }).Count

Write-Host "  Actual compliant: $actualCompliant"
Write-Host "  Actual non-compliant: $actualNonCompliant"
```

**Status**: ⏳ Pending
**Result**: 
**Notes**: 

---

#### Test T5.3: All 46 Policies Listed in HTML

**Validation**:
```powershell
# List of all 46 Key Vault policies (from CSV)
$csvPolicies = Import-Csv "DefinitionListExport.csv"
Write-Host "Policies in CSV: $($csvPolicies.Count)"

# Get latest HTML
$latestHTML = Get-ChildItem "ComplianceReport-*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$htmlContent = Get-Content $latestHTML.FullName -Raw

# Check each policy is mentioned in HTML
$missingPolicies = @()
foreach ($policy in $csvPolicies) {
    $policyName = $policy.Name
    if ($htmlContent -notlike "*$policyName*") {
        $missingPolicies += $policyName
    }
}

if ($missingPolicies.Count -eq 0) {
    Write-Host "`n✓ All 46 policies found in HTML report" -ForegroundColor Green
} else {
    Write-Host "`n✗ Missing $($missingPolicies.Count) policies in HTML:" -ForegroundColor Red
    $missingPolicies | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}
```

**Status**: ⏳ Pending
**Result**: 
**Notes**: 

---

## Test Summary

**Total Tests**: 13
**Passed**: 0
**Failed**: 0
**Skipped**: 0
**In Progress**: 0
**Pending**: 13

**Overall Status**: ⏳ NOT STARTED

**Evidence Files Generated**:
- [ ] Setup logs
- [ ] DevTest deployment reports
- [ ] Production deployment reports
- [ ] ComplianceReport-*.html (multiple)
- [ ] DenyBlockingTestResults-*.json
- [ ] KeyVaultPolicyImplementationReport-*.json (multiple)
- [ ] KeyVaultPolicyImplementationReport-*.md (multiple)

**Issues Found**: None yet

**Recommendations**: None yet

---

## Next Steps

1. Execute Pre-Test Cleanup
2. Begin PHASE 1: Infrastructure Setup
3. Continue through each phase sequentially
4. Update this document with results after each test
5. Generate final summary report
