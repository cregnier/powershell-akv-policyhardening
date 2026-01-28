# Bulk Update Script for Release Package 1.1
# Removes sensitive data and adds proper references

$packagePath = ".\release-package-1.1-20260128-113757"
$mdFiles = Get-ChildItem -Path "$packagePath\documentation" -Filter "*.md" -Recurse

Write-Host "Found $($mdFiles.Count) markdown files to update..." -ForegroundColor Cyan

# Define replacements
$replacements = @{
    # Subscription ID replacements
    'ab1336c7-687d-4107-b0f6-9649a0458adb' = '<your-subscription-id>'
    
    # GitHub repository references
    'github.com/cregnier/powershell-akv-policyhardening' = 'the extracted release package'
    
    # MSDN references
    'MSDN subscription' = 'dev/test subscription'
    'MSDN Subscription' = 'Dev/Test Subscription'
    'MSDN DevTest' = 'Dev/Test Environment'
    'MSDN/Visual Studio subscriptions' = 'dev/test subscriptions'
    'standard MSDN' = 'standard dev/test'
    'in MSDN' = 'in dev/test subscriptions'
}

$totalReplacements = 0

foreach ($file in $mdFiles) {
    Write-Host "`nProcessing: $($file.Name)" -ForegroundColor Yellow
    
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    $fileReplacements = 0
    
    foreach ($find in $replacements.Keys) {
        $replace = $replacements[$find]
        if ($content -match $find) {
            $matches = [regex]::Matches($content, $find)
            $count = $matches.Count
            $content = $content -replace $find, $replace
            $fileReplacements += $count
            Write-Host "  - Replaced '$find' → '$replace' ($count occurrences)" -ForegroundColor Green
        }
    }
    
    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "  ✅ Updated $fileReplacements items in $($file.Name)" -ForegroundColor Green
        $totalReplacements += $fileReplacements
    } else {
        Write-Host "  ⏭️ No changes needed" -ForegroundColor Gray
    }
}

# Also update PACKAGE-README.md
Write-Host "`nProcessing: PACKAGE-README.md" -ForegroundColor Yellow
$packageReadme = Get-Item "$packagePath\PACKAGE-README.md"
$content = Get-Content $packageReadme.FullName -Raw
$originalContent = $content
$fileReplacements = 0

foreach ($find in $replacements.Keys) {
    $replace = $replacements[$find]
    if ($content -match $find) {
        $matches = [regex]::Matches($content, $find)
        $count = $matches.Count
        $content = $content -replace $find, $replace
        $fileReplacements += $count
        Write-Host "  - Replaced '$find' → '$replace' ($count occurrences)" -ForegroundColor Green
    }
}

if ($content -ne $originalContent) {
    Set-Content -Path $packageReadme.FullName -Value $content -NoNewline
    Write-Host "  ✅ Updated $fileReplacements items in PACKAGE-README.md" -ForegroundColor Green
    $totalReplacements += $fileReplacements
}

Write-Host "`n═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ BULK UPDATE COMPLETE" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Total replacements: $totalReplacements" -ForegroundColor White
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Review changes in documentation/" -ForegroundColor White
Write-Host "2. Test a sample deployment command" -ForegroundColor White
Write-Host "3. Rebuild release ZIP if satisfied" -ForegroundColor White
