<#
.SYNOPSIS
    Archive outdated documentation and test files

.DESCRIPTION
    Moves old reports, test results, and documentation to archive/deprecated-[timestamp]/
    Keeps workspace clean with only current/relevant files
#>

param(
    [switch]$WhatIf
)

$archiveDate = Get-Date -Format 'yyyyMMdd-HHmmss'
$deprecatedPath = ".\archive\deprecated-$archiveDate"

Write-Host "`n📦 WORKSPACE CLEANUP - Archiving Outdated Files..." -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Gray

# Create archive structure
if (-not $WhatIf) {
    New-Item -ItemType Directory -Path $deprecatedPath -Force | Out-Null
    'old-reports', 'old-test-results', 'old-scenarios', 'old-documentation', 'old-json' | ForEach-Object {
        New-Item -ItemType Directory -Path (Join-Path $deprecatedPath $_) -Force | Out-Null
    }
}

# Track files to move
$filesToMove = @{
    'old-reports' = @()
    'old-test-results' = @()
    'old-scenarios' = @()
    'old-documentation' = @()
    'old-json' = @()
}

Write-Host "`n🔍 Identifying files to archive..." -ForegroundColor Yellow

# Old HTML/JSON/MD reports (before Jan 27, keep only latest)
$filesToMove['old-reports'] += Get-ChildItem -Path . -Filter "PolicyImplementationReport-20260[12]*.html" -File | 
    Where-Object { $_.LastWriteTime -lt (Get-Date "2026-01-27") }
$filesToMove['old-reports'] += Get-ChildItem -Path . -Filter "KeyVaultPolicyImplementationReport-20260[12]*.md" -File | 
    Where-Object { $_.LastWriteTime -lt (Get-Date "2026-01-27") }
$filesToMove['old-reports'] += Get-ChildItem -Path . -Filter "KeyVaultPolicyImplementationReport-20260[12]*.json" -File | 
    Where-Object { $_.LastWriteTime -lt (Get-Date "2026-01-27") }
$filesToMove['old-reports'] += Get-ChildItem -Path . -Filter "ComplianceReport-20260[12]*.html" -File | 
    Where-Object { $_.LastWriteTime -lt (Get-Date "2026-01-27") }

# Old CSV test results (keep only Jan 27 files)
$filesToMove['old-test-results'] += Get-ChildItem -Path . -Filter "AllDenyPoliciesValidation-20260[12]*.csv" -File | 
    Where-Object { $_.Name -notmatch '20260127' }
$filesToMove['old-test-results'] += Get-ChildItem -Path . -Filter "EnforcementValidation-20260[12]*.csv" -File | 
    Where-Object { $_.Name -notmatch '20260127' }
$filesToMove['old-test-results'] += Get-ChildItem -Path . -Filter "HTMLValidation-*.csv" -File

# Old scenario output files
$filesToMove['old-scenarios'] += Get-ChildItem -Path . -Filter "scenario*.txt" -File
$filesToMove['old-scenarios'] += Get-ChildItem -Path . -Filter "scenario*.log" -File
$filesToMove['old-scenarios'] += Get-ChildItem -Path . -Filter "test-*.txt" -File
$filesToMove['old-scenarios'] += Get-ChildItem -Path . -Filter "workflow-test-*.txt" -File

# Superseded documentation
$supersededDocs = @(
    'Scenario5-Results.md',
    'Scenario6-Results.md',
    'Scenario6-HSM-Limitation-Analysis.md',
    'Test-Script-Fix-Summary.md',
    'Test-Validation-Fixes-Summary.md',
    'Production-Deny-Policy-Fix-Summary.md',
    'FINAL-TEST-SUMMARY.md',
    'MASTER-TEST-PLAN-20260126.md',
    'BlockingTestCoverageAnalysis.md',
    'Actual-Deployment-Test-Execution-Plan.md',
    'Complete-Deployment-Scenario-Guide.md',
    'DevTest-Full-Testing-Plan.md',
    'DevTest-Policy-Modes-Summary.md',
    'Documentation-Consolidation-Analysis.md',
    'Effect-Values-Corrections-Summary.md',
    'Email-Alert-Configuration-Analysis.md',
    'TestCoverageMatrix.md',
    'Workflow-Testing-Analysis.md',
    'Workflow-Testing-Summary.md',
    'WORKFLOW-TESTING-SESSION-SUMMARY.md',
    'Sprint-Planning-12-Weeks.md',
    'Sprint-Requirements-Gap-Analysis.md',
    'Test-Validation-Fixes-Summary.md',
    'V1.0-ENHANCEMENT-TEST-PLAN.md',
    'V1.0-RELEASE-NOTES.md',
    'todos-BACKUP-20260126.md',
    'todos-BACKUP-20260126-EOD.md'
)
foreach ($doc in $supersededDocs) {
    if (Test-Path $doc) {
        $filesToMove['old-documentation'] += Get-Item $doc
    }
}

# Old JSON files
$filesToMove['old-json'] += Get-ChildItem -Path . -Filter "Missing9PoliciesFix-*.json" -File
$filesToMove['old-json'] += Get-ChildItem -Path . -Filter "Tier1ProductionDeployment-*.json" -File
$filesToMove['old-json'] += Get-ChildItem -Path . -Filter "All46Policies*.json" -File
$filesToMove['old-json'] += Get-ChildItem -Path . -Filter "DenyBlockingTestResults-*.json" -File
$filesToMove['old-json'] += Get-ChildItem -Path . -Filter "DenyModeTestResults-*.json" -File
$filesToMove['old-json'] += Get-ChildItem -Path . -Filter "BlockingValidationResults-*.json" -File
$filesToMove['old-json'] += Get-ChildItem -Path . -Filter "ComplianceDashboard-*.json" -File

# Old text files
$filesToMove['old-scenarios'] += Get-ChildItem -Path . -Filter "*.txt" -File | 
    Where-Object { $_.Name -match '^(deployment-errors|DryRunSummary|IndividualPolicyValidation|RollbackProcedure|AutoRemediation-Timing-Log|ComplianceDashboard-Deployment-Instructions)' }

# Display summary
Write-Host "`n📊 Files to Archive:" -ForegroundColor Cyan
$totalCount = 0
foreach ($category in $filesToMove.Keys | Sort-Object) {
    $count = @($filesToMove[$category]).Count
    if ($count -gt 0) {
        Write-Host "   $category`: $count files" -ForegroundColor Gray
        $totalCount += $count
    }
}
Write-Host "   TOTAL: $totalCount files" -ForegroundColor Yellow

if ($WhatIf) {
    Write-Host "`n⚠️  WHATIF MODE: No files will be moved" -ForegroundColor Yellow
    Write-Host "`nTo perform cleanup, run without -WhatIf parameter" -ForegroundColor Gray
    return
}

# Move files
Write-Host "`n🚚 Moving files to archive..." -ForegroundColor Cyan
$movedCount = 0
foreach ($category in $filesToMove.Keys) {
    if ($filesToMove[$category].Count -gt 0) {
        $catPath = Join-Path $deprecatedPath $category
        foreach ($file in $filesToMove[$category]) {
            try {
                Move-Item -Path $file.FullName -Destination $catPath -Force -ErrorAction Stop
                $movedCount++
            } catch {
                Write-Host "   ⚠️  Failed to move: $($file.Name)" -ForegroundColor Yellow
            }
        }
    }
}

Write-Host "✅ Archived $movedCount files" -ForegroundColor Green

# Create archive README
$readmeContent = @"
# Deprecated Files Archive

**Archive Date**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Files Archived**: $movedCount

## Reason for Archival
These files are superseded by current project deliverables and final test results.
Archived to keep workspace clean and focused on production-ready materials.

## Categories

### old-reports ($(@($filesToMove['old-reports']).Count) files)
HTML/JSON/MD compliance reports from testing iterations (Jan 12-26).
**Current**: PolicyImplementationReport-20260127-*.html, MasterTestReport-*.html

### old-test-results ($(@($filesToMove['old-test-results']).Count) files)
CSV test validation results from earlier testing phases.
**Current**: AllDenyPoliciesValidation-20260127-135137.csv (final 25/34 PASS)

### old-scenarios ($(@($filesToMove['old-scenarios']).Count) files)
Scenario output files from workflow testing iterations.
**Current**: Final results documented in Scenario6-Final-Results.md

### old-documentation ($(@($filesToMove['old-documentation']).Count) files)
Superseded planning documents, interim test plans, and analysis files.
**Current**: DEPLOYMENT-PREREQUISITES.md, QUICKSTART.md, todos.md

### old-json ($(@($filesToMove['old-json']).Count) files)
Interim JSON configuration and test result files.
**Current**: PolicyParameters-Production-*.json

## Restoration
If any file is needed, copy from this archive folder back to workspace root.
Archive preserved for historical reference and audit trail.
"@

$readmeContent | Out-File -FilePath (Join-Path $deprecatedPath "README.md") -Encoding UTF8 -Force

Write-Host "`n📄 Archive README created" -ForegroundColor Gray
Write-Host "`n✅ Workspace cleanup complete!" -ForegroundColor Green
Write-Host "   Archive location: $deprecatedPath" -ForegroundColor Cyan
Write-Host "   Workspace freed: ~$([math]::Round((Get-ChildItem $deprecatedPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 2)) MB" -ForegroundColor Gray
