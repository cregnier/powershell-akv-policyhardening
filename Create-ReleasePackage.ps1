<#
.SYNOPSIS
    Creates deployment package ZIP for Azure Key Vault Policy Governance Framework.

.DESCRIPTION
    Packages all required files for corporate AAD deployment:
    - Core scripts (AzPolicyImplScript.ps1, Setup-AzureKeyVaultPolicyEnvironment.ps1)
    - Parameter files (all 6 JSON configurations)
    - Supporting data (PolicyNameMapping.json, DefinitionListExport.csv)
    - Documentation (README.md, QUICKSTART.md, guides)
    
    Excludes test artifacts, logs, and backup files to create clean deployment package.

.PARAMETER OutputPath
    Path for generated ZIP file. Default: .\AzureKeyVaultPolicyGovernance-v1.0.zip

.PARAMETER IncludeTestScripts
    Include optional testing scripts in package. Default: $false

.PARAMETER Verify
    Verify package contents after creation. Default: $true

.EXAMPLE
    .\Create-ReleasePackage.ps1
    Creates ZIP package with default settings

.EXAMPLE
    .\Create-ReleasePackage.ps1 -OutputPath "C:\Deploy\AKV-Policy-v1.0.zip" -IncludeTestScripts
    Creates ZIP with custom path and includes testing scripts

.NOTES
    Version: 1.0
    Last Updated: 2026-01-22
    Package Size: ~500 KB (uncompressed) | ~150 KB (compressed)
#>

[CmdletBinding()]
param(
    [string]$OutputPath = ".\AzureKeyVaultPolicyGovernance-v1.0.zip",
    [switch]$IncludeTestScripts,
    [switch]$Verify = $true
)

# Ensure we're in the correct directory
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
    $ScriptRoot = Get-Location
}

Set-Location $ScriptRoot

Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Azure Key Vault Policy Governance - Release Package Creator" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Define core files required for deployment (17 files minimum)
$CoreFiles = @(
    # Core scripts (2 files)
    "AzPolicyImplScript.ps1"
    "Setup-AzureKeyVaultPolicyEnvironment.ps1"
    
    # Parameter files (6 files)
    "PolicyParameters-DevTest.json"
    "PolicyParameters-DevTest-Full.json"
    "PolicyParameters-DevTest-Full-Remediation.json"
    "PolicyParameters-Production.json"
    "PolicyParameters-Production-Deny.json"
    "PolicyParameters-Production-Remediation.json"
    
    # Supporting data files (3 files)
    "PolicyNameMapping.json"
    "DefinitionListExport.csv"
    "PolicyImplementationConfig.json"
    
    # Documentation files (6 files)
    "README.md"
    "QUICKSTART.md"
    "DEPLOYMENT-PREREQUISITES.md"
    "DEPLOYMENT-WORKFLOW-GUIDE.md"
    "PolicyParameters-QuickReference.md"
    "WORKFLOW-TESTING-GUIDE.md"
)

# Optional files (include if IncludeTestScripts specified)
$OptionalFiles = @(
    "Run-All-Workflow-Tests.ps1"
    "Test-AllWorkflowNextSteps.ps1"
    "Test-AllScenariosWithHTMLValidation.ps1"
    "PRE-DEPLOYMENT-CHECKLIST.md"
    "EMAIL-ALERT-CONFIGURATION.md"
    "EXEMPTION_PROCESS.md"
    "KEYVAULT_POLICY_REFERENCE.md"
    "CORPORATE-DEPLOYMENT-CHECKLIST.md"
    "RELEASE-PACKAGE-MANIFEST.md"
)

# Build file list
$FilesToPackage = $CoreFiles
if ($IncludeTestScripts) {
    Write-Host "📦 Including optional test scripts and additional documentation..." -ForegroundColor Yellow
    $FilesToPackage += $OptionalFiles
}

# Validate all files exist
Write-Host "🔍 Validating file existence..." -ForegroundColor Cyan
$MissingFiles = @()
$ExistingFiles = @()

foreach ($file in $FilesToPackage) {
    if (Test-Path $file) {
        $ExistingFiles += $file
        $fileSize = (Get-Item $file).Length
        $fileSizeKB = [math]::Round($fileSize / 1KB, 2)
        Write-Host "  ✅ $file ($fileSizeKB KB)" -ForegroundColor Green
    } else {
        $MissingFiles += $file
        Write-Host "  ❌ MISSING: $file" -ForegroundColor Red
    }
}

if ($MissingFiles.Count -gt 0) {
    Write-Host "`n⚠️  WARNING: $($MissingFiles.Count) files are missing!" -ForegroundColor Yellow
    Write-Host "Missing files:" -ForegroundColor Yellow
    $MissingFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    
    $continue = Read-Host "`nContinue packaging without missing files? (y/N)"
    if ($continue -ne 'y' -and $continue -ne 'Y') {
        Write-Host "`n❌ Package creation cancelled." -ForegroundColor Red
        exit 1
    }
}

# Calculate total package size
$TotalSize = 0
$ExistingFiles | ForEach-Object {
    $TotalSize += (Get-Item $_).Length
}
$TotalSizeKB = [math]::Round($TotalSize / 1KB, 2)
$TotalSizeMB = [math]::Round($TotalSize / 1MB, 2)

Write-Host "`n📊 Package Statistics:" -ForegroundColor Cyan
Write-Host "  Files to package: $($ExistingFiles.Count)" -ForegroundColor White
Write-Host "  Total size: $TotalSizeKB KB ($TotalSizeMB MB)" -ForegroundColor White
Write-Host "  Estimated compressed size: ~$([math]::Round($TotalSizeMB * 0.3, 2)) MB" -ForegroundColor White

# Remove existing ZIP if present
if (Test-Path $OutputPath) {
    Write-Host "`n⚠️  Existing package found: $OutputPath" -ForegroundColor Yellow
    $overwrite = Read-Host "Overwrite existing package? (y/N)"
    if ($overwrite -ne 'y' -and $overwrite -ne 'Y') {
        Write-Host "`n❌ Package creation cancelled." -ForegroundColor Red
        exit 1
    }
    Remove-Item $OutputPath -Force
    Write-Host "  ✅ Removed existing package" -ForegroundColor Green
}

# Create ZIP package
Write-Host "`n📦 Creating ZIP package..." -ForegroundColor Cyan

try {
    # Use .NET compression for better control
    Add-Type -Assembly System.IO.Compression.FileSystem
    $CompressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
    
    # Create temporary directory for staging
    $TempDir = Join-Path $env:TEMP "AKV-Policy-Package-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    
    # Copy files to temp directory
    Write-Host "  → Staging files..." -ForegroundColor White
    foreach ($file in $ExistingFiles) {
        Copy-Item -Path $file -Destination $TempDir -Force
    }
    
    # Create ZIP from temp directory
    Write-Host "  → Compressing package..." -ForegroundColor White
    [System.IO.Compression.ZipFile]::CreateFromDirectory($TempDir, $OutputPath, $CompressionLevel, $false)
    
    # Clean up temp directory
    Remove-Item $TempDir -Recurse -Force
    
    Write-Host "`n✅ Package created successfully!" -ForegroundColor Green
    Write-Host "  Location: $OutputPath" -ForegroundColor White
    
    # Get ZIP file info
    $ZipInfo = Get-Item $OutputPath
    $ZipSizeKB = [math]::Round($ZipInfo.Length / 1KB, 2)
    $ZipSizeMB = [math]::Round($ZipInfo.Length / 1MB, 2)
    $CompressionRatio = [math]::Round((1 - ($ZipInfo.Length / $TotalSize)) * 100, 2)
    
    Write-Host "  Size: $ZipSizeKB KB ($ZipSizeMB MB)" -ForegroundColor White
    Write-Host "  Compression ratio: $CompressionRatio%" -ForegroundColor White
    
} catch {
    Write-Host "`n❌ Failed to create package!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verify package contents
if ($Verify) {
    Write-Host "`n🔍 Verifying package contents..." -ForegroundColor Cyan
    
    try {
        Add-Type -Assembly System.IO.Compression.FileSystem
        $Zip = [System.IO.Compression.ZipFile]::OpenRead($OutputPath)
        
        $ZipEntries = $Zip.Entries | Select-Object -ExpandProperty FullName
        $Zip.Dispose()
        
        Write-Host "  Files in package: $($ZipEntries.Count)" -ForegroundColor White
        
        # Check for missing core files in ZIP
        $MissingInZip = @()
        foreach ($file in $CoreFiles) {
            if ($ZipEntries -notcontains $file) {
                $MissingInZip += $file
            }
        }
        
        if ($MissingInZip.Count -eq 0) {
            Write-Host "  ✅ All core files present in package" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  WARNING: $($MissingInZip.Count) core files missing from package!" -ForegroundColor Yellow
            $MissingInZip | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
        }
        
        # Show file list if verbose
        if ($PSCmdlet.MyInvocation.BoundParameters['Verbose']) {
            Write-Host "`nPackage contents:" -ForegroundColor Cyan
            $ZipEntries | Sort-Object | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
        }
        
    } catch {
        Write-Host "  ⚠️  Could not verify package: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Calculate SHA256 hash for integrity verification
Write-Host "`n🔐 Calculating package hash..." -ForegroundColor Cyan
$Hash = Get-FileHash -Path $OutputPath -Algorithm SHA256
Write-Host "  SHA256: $($Hash.Hash)" -ForegroundColor White

# Generate deployment instructions
Write-Host "`n📋 Deployment Instructions" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Transfer package to target PC:" -ForegroundColor Yellow
Write-Host "   Copy: $OutputPath" -ForegroundColor White
Write-Host ""
Write-Host "2. Extract package:" -ForegroundColor Yellow
Write-Host "   Expand-Archive -Path AzureKeyVaultPolicyGovernance-v1.0.zip -DestinationPath C:\Deploy\powershell-akv-policyhardening" -ForegroundColor Green
Write-Host ""
Write-Host "3. Follow deployment checklist:" -ForegroundColor Yellow
Write-Host "   cd C:\Deploy\powershell-akv-policyhardening" -ForegroundColor Green
Write-Host "   Get-Content CORPORATE-DEPLOYMENT-CHECKLIST.md" -ForegroundColor Green
Write-Host ""
Write-Host "4. Quick start deployment:" -ForegroundColor Yellow
Write-Host "   Get-Content QUICKSTART.md" -ForegroundColor Green
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Summary
Write-Host "`n✅ PACKAGE CREATION COMPLETE" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "Package: $OutputPath" -ForegroundColor White
Write-Host "Files: $($ExistingFiles.Count)" -ForegroundColor White
Write-Host "Size: $ZipSizeMB MB" -ForegroundColor White
Write-Host "Hash: $($Hash.Hash)" -ForegroundColor White
Write-Host "════════════════════════════════════════════════════════════`n" -ForegroundColor Green

# Open folder containing ZIP
if ($IsWindows -or $env:OS -match 'Windows') {
    $OpenFolder = Read-Host "Open folder containing package? (y/N)"
    if ($OpenFolder -eq 'y' -or $OpenFolder -eq 'Y') {
        explorer.exe /select,"$OutputPath"
    }
}
