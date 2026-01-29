# Old Files Cleanup Report
## Generated: January 29, 2026

This document lists files identified for cleanup, organized by category. Files marked with ✅ are kept (most recent/best results), others can be safely deleted.

---

## Compliance Reports (HTML)

**KEEP (Most Recent)**:
- ✅ `ComplianceReport-20260127-152209.html` (Latest comprehensive report)

**DELETE (Older versions)**:
- ❌ `ComplianceReport-20260126-162020.html`
- ❌ `ComplianceReport-20260126-133719.html`
- ❌ `ComplianceReport-20260126-123248.html`
- ❌ `ComplianceReport-20260126-114131.html`
- ❌ `ComplianceReport-20260120-152316.html`
- ❌ `ComplianceReport-20260116-155949.html`
- ❌ `ComplianceReport-20260115-134100.html`

---

## AAD Test Results (Today's Tests)

**KEEP (Most Recent - Successful AAD Parallel Run)**:
- ✅ `TestResults-AAD-PARALLEL-FAST-20260129-151114/` (SUCCESSFUL 14:26 run with 2,156 KVs)
  - Contains: Test2-KeyVaults-AAD-PARALLEL.txt, Test3-PolicyAssignments-AAD.txt
  - CSV outputs: KeyVaultInventory, PolicyAssignmentInventory

**DELETE (Earlier failed/partial AAD tests today)**:
- ❌ `TestResults-AAD-20260129-114132/` (Early AAD test before parallel)
- ❌ `TestResults-AAD-20260129-130236/` (Bug #11 discovered)
- ❌ `TestResults-AAD-PARALLEL-20260129-143755/` (Parallel testing iteration)
- ❌ `TestResults-AAD-PARALLEL-FAST-20260129-144022/` (Testing iteration)
- ❌ `TestResults-AAD-PARALLEL-FAST-20260129-144114/` (Testing iteration)
- ❌ `TestResults-AAD-PARALLEL-FAST-20260129-145956/` (Testing iteration)
- ❌ `TestResults-AAD-PARALLEL-FAST-20260129-150202/` (Testing iteration)
- ❌ `TestResults-AAD-PARALLEL-FAST-20260129-150607/` (Testing iteration before final)

---

## MSA Test Results (Today's Tests)

**KEEP (Most Recent MSA Reference)**:
- ✅ `TestResults-MSA-Fixed-20260129-112234/` (Bug fixes validated, 9 KVs baseline)

**DELETE**:
- ❌ `TestResults-MSA-20260129-111529/` (Pre-fix version)

---

## Discovery Attempts (Today - All Failed/Incomplete)

**DELETE ALL** (None successful, superseded by TestResults):
- ❌ `Discovery-20260129-103252/`
- ❌ `Discovery-20260129-103429/`
- ❌ `Discovery-20260129-103808/`
- ❌ `Discovery-20260129-103934/`
- ❌ `Discovery-20260129-104842/`
- ❌ `Discovery-20260129-110642/`
- ❌ `Discovery-20260129-111051/`
- ❌ `Discovery-20260129-111709/`
- ❌ `Discovery-20260129-112338/`

---

## CSV Inventory Files (Root Directory)

**KEEP (AAD Results from Final Test)**:
- ✅ Files already in `TestResults-AAD-PARALLEL-FAST-20260129-151114/`

**DELETE (Duplicates/Older)**:
- ❌ `KeyVaultInventory-20260129-112313.csv` (Early run)
- ❌ `KeyVaultInventory-20260129-132720.csv` (Mid-testing)
- ❌ `PolicyAssignmentInventory-20260129-112329.csv` (Early run)
- ❌ `SubscriptionInventory-20260129-112305.csv` (Early run)
- ❌ `SubscriptionInventory-20260129-114230.csv` (Mid-testing)
- ❌ `SubscriptionInventory-20260129-130354.csv` (Mid-testing)

---

## Policy Implementation Reports (Massive Quantity)

**KEEP (Latest Production Reports)**:
- ✅ `KeyVaultPolicyImplementationReport-20260128-183454.json/md` (Most recent)
- ✅ `PolicyImplementationReport-20260128-183454.html` (Most recent HTML)

**DELETE (250+ older implementation reports from testing phases)**:
All `KeyVaultPolicyImplementationReport-*` and `PolicyImplementationReport-*` files dated before 2026-01-27:
- ❌ All reports from 2026-01-12 through 2026-01-27 (development/testing iterations)
- ❌ Approximately 150+ JSON files
- ❌ Approximately 150+ HTML files
- ❌ Approximately 50+ MD files

**Specific Cleanup Pattern**:
```powershell
# Remove reports older than Jan 27, 2026
Get-ChildItem -Path "." -Filter "KeyVaultPolicyImplementationReport-202601[12][0-6]*" | Remove-Item
Get-ChildItem -Path "." -Filter "PolicyImplementationReport-202601[12][0-6]*" | Remove-Item
```

---

## Deployment Packages (Duplicates)

**KEEP (Latest Release Packages)**:
- ✅ `azure-keyvault-policy-governance-1.1.1-FINAL.zip` (Latest 1.1.1 release)
- ✅ `release-package-1.1-20260128-113757/` (Latest package directory)

**DELETE (Older/Duplicate)**:
- ❌ `azure-keyvault-policy-governance-1.1.0-FINAL.zip` (Superseded by 1.1.1)
- ❌ `AzureKeyVaultPolicyGovernance-v1.0.zip` (Very old v1.0)
- ❌ `deployment-package-20260127-145929/` (Old test)
- ❌ `deployment-package-20260127-145942/` (Old test)
- ❌ `deployment-package-20260127-145942.zip` (Old test)
- ❌ `deployment-package-20260127-150012/` (Old test)
- ❌ `deployment-package-20260127-150400/` (Old test)
- ❌ `deployment-package-20260127-150400.zip` (Old test)

---

## Master Test Reports

**KEEP (Most Recent)**:
- ✅ `MasterTestReport-20260127-164959.html` (Latest)

**DELETE**:
- ❌ `MasterTestReport-20260127-143212.html` (Older same day)

---

## Summary Statistics

| Category | Files to Keep | Files to Delete | Disk Space Saved (Est.) |
|----------|--------------|-----------------|------------------------|
| Compliance Reports | 1 | 7 | ~2 MB |
| AAD Test Results | 1 dir | 8 dirs | ~50 MB |
| MSA Test Results | 1 dir | 1 dir | ~5 MB |
| Discovery Attempts | 0 | 9 dirs | ~30 MB |
| CSV Files (Root) | 0 | 6 files | ~30 MB |
| Policy Reports (JSON/HTML/MD) | 2 | 250+ | ~150 MB |
| Deployment Packages | 2 | 6 | ~20 MB |
| Master Reports | 1 | 1 | ~500 KB |
| **TOTAL** | **8 items** | **290+ items** | **~287 MB** |

---

## Cleanup Script

Run this PowerShell script to perform automated cleanup:

```powershell
# Navigate to workspace
cd C:\Source\powershell-akv-policyhardening

# Backup first (optional but recommended)
$backupDate = Get-Date -Format "yyyyMMdd-HHmmss"
New-Item -ItemType Directory -Path ".\archive\cleanup-backup-$backupDate" -Force

# 1. Cleanup old compliance reports
Get-ChildItem -Path "." -Filter "ComplianceReport-202601[12][0-6]*" -File | Move-Item -Destination ".\archive\cleanup-backup-$backupDate\"

# 2. Cleanup old AAD test results (keep only 20260129-151114)
Get-ChildItem -Path "." -Filter "TestResults-AAD-*" -Directory | 
    Where-Object { $_.Name -ne "TestResults-AAD-PARALLEL-FAST-20260129-151114" } | 
    Move-Item -Destination ".\archive\cleanup-backup-$backupDate\"

# 3. Cleanup MSA test results (keep only Fixed)
Get-ChildItem -Path "." -Filter "TestResults-MSA-20260129-111529" -Directory | 
    Move-Item -Destination ".\archive\cleanup-backup-$backupDate\"

# 4. Cleanup all Discovery attempts
Get-ChildItem -Path "." -Filter "Discovery-20260129-*" -Directory | 
    Move-Item -Destination ".\archive\cleanup-backup-$backupDate\"

# 5. Cleanup old CSV files
$oldCSVs = @(
    "KeyVaultInventory-20260129-112313.csv",
    "KeyVaultInventory-20260129-132720.csv",
    "PolicyAssignmentInventory-20260129-112329.csv",
    "SubscriptionInventory-20260129-112305.csv",
    "SubscriptionInventory-20260129-114230.csv",
    "SubscriptionInventory-20260129-130354.csv"
)
$oldCSVs | ForEach-Object { 
    if (Test-Path $_) { 
        Move-Item $_ -Destination ".\archive\cleanup-backup-$backupDate\" 
    }
}

# 6. Cleanup old policy implementation reports (MASSIVE CLEANUP)
Get-ChildItem -Path "." -Filter "KeyVaultPolicyImplementationReport-202601[12][0-7]*" -File | 
    Move-Item -Destination ".\archive\cleanup-backup-$backupDate\"
    
Get-ChildItem -Path "." -Filter "PolicyImplementationReport-202601[12][0-7]*" -File | 
    Move-Item -Destination ".\archive\cleanup-backup-$backupDate\"

# 7. Cleanup old deployment packages
$oldPackages = @(
    "azure-keyvault-policy-governance-1.1.0-FINAL.zip",
    "AzureKeyVaultPolicyGovernance-v1.0.zip",
    "deployment-package-20260127-145929",
    "deployment-package-20260127-145942",
    "deployment-package-20260127-145942.zip",
    "deployment-package-20260127-150012",
    "deployment-package-20260127-150400",
    "deployment-package-20260127-150400.zip"
)
$oldPackages | ForEach-Object {
    if (Test-Path $_) {
        Move-Item $_ -Destination ".\archive\cleanup-backup-$backupDate\"
    }
}

# 8. Cleanup old master report
if (Test-Path "MasterTestReport-20260127-143212.html") {
    Move-Item "MasterTestReport-20260127-143212.html" -Destination ".\archive\cleanup-backup-$backupDate\"
}

# Summary
Write-Host "`n=== Cleanup Complete ===" -ForegroundColor Green
Write-Host "Backed up files to: .\archive\cleanup-backup-$backupDate\" -ForegroundColor Cyan
Write-Host "Estimated space saved: ~287 MB" -ForegroundColor Yellow

# Show remaining test results
Write-Host "`n=== Remaining Test Results ===" -ForegroundColor Cyan
Get-ChildItem -Path "." -Filter "TestResults-*" -Directory | Select-Object Name, LastWriteTime
```

---

## Files to Keep (Final Clean Workspace)

**Documentation** (All recent/important docs):
- ✅ All `.md` documentation files in root (AAD-TEST-ANALYSIS.md, SESSION-SUMMARY-20260129.md, etc.)
- ✅ PREREQUISITES-GUIDE.md (432 lines, essential)
- ✅ LONG-RUNNING-JOBS-GUIDE.md (just created)
- ✅ AAD-vs-MSA-Comparison-Report.md (just created)

**Test Results**:
- ✅ `TestResults-AAD-PARALLEL-FAST-20260129-151114/` (Final AAD success)
- ✅ `TestResults-MSA-Fixed-20260129-112234/` (MSA baseline)

**Scripts** (All core scripts):
- ✅ `AzPolicyImplScript.ps1` (main policy deployment)
- ✅ `Get-KeyVaultInventory.ps1` (with parallel processing)
- ✅ `Get-PolicyAssignmentInventory.ps1` (bug fixes applied)
- ✅ `Get-AzureSubscriptionInventory.ps1` (bug fixes applied)
- ✅ `Run-ParallelTests-Fast.ps1` (successful test runner)
- ✅ `Setup-AzureKeyVaultPolicyEnvironment.ps1` (infrastructure setup)

**Configuration**:
- ✅ All `PolicyParameters-*.json` files (6 parameter files)
- ✅ `PolicyImplementationConfig.json`
- ✅ `PolicyNameMapping.json`
- ✅ `DefinitionListExport.csv`

**Latest Reports**:
- ✅ `ComplianceReport-20260127-152209.html`
- ✅ `MasterTestReport-20260127-164959.html`
- ✅ `KeyVaultPolicyImplementationReport-20260128-183454.*` (Latest 3 files)

**Release Packages**:
- ✅ `azure-keyvault-policy-governance-1.1.1-FINAL.zip`
- ✅ `release-package-1.1-20260128-113757/`

---

## Post-Cleanup Workspace Structure

After cleanup, the workspace will contain:
- ~40 documentation files (.md)
- ~15 core PowerShell scripts (.ps1)
- ~10 configuration/mapping files (.json/.csv)
- 2 test result directories (AAD + MSA)
- 2 release packages (latest only)
- 3 latest reports (compliance, master, policy implementation)
- archive/ directory with backup of deleted files

**Total Files**: ~70 essential files vs current 500+ files  
**Estimated Workspace Size**: 50-100 MB vs current ~337 MB  
**Cleanup Benefit**: Faster Git operations, easier navigation, clearer workspace
