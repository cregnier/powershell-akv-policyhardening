<#
.SYNOPSIS
    Helper script to capture terminal output for each deployment scenario test.

.DESCRIPTION
    Wraps Deploy-PolicyScenarios.ps1 execution with automatic transcript capture.
    Creates timestamped output files for review and validation.

.PARAMETER ScenarioNumber
    Scenario number to test (1-9).

.PARAMETER ScenarioName
    Descriptive name for the output file.

.PARAMETER OutputDirectory
    Directory to save transcript files. Default: current directory.

.EXAMPLE
    .\Capture-ScenarioOutput.ps1 -ScenarioNumber 1 -ScenarioName "devtest-baseline"
#>

param(
    [Parameter(Mandatory=$true)]
    [int]$ScenarioNumber,
    
    [Parameter(Mandatory=$true)]
    [string]$ScenarioName,
    
    [string]$OutputDirectory = "."
)

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outputFile = Join-Path $OutputDirectory "scenario$ScenarioNumber-$ScenarioName-$timestamp.txt"

Write-Host "`n════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " Scenario $ScenarioNumber Test: $ScenarioName" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "`nOutput will be captured to:" -ForegroundColor Yellow
Write-Host "  $outputFile`n" -ForegroundColor White

Write-Host "📝 Instructions:" -ForegroundColor Green
Write-Host "  1. Select scenario number: $ScenarioNumber" -ForegroundColor Gray
Write-Host "  2. Choose mode: A (Actual deployment)" -ForegroundColor Gray
Write-Host "  3. Confirm when prompted" -ForegroundColor Gray
Write-Host "  4. Transcript will auto-capture all output`n" -ForegroundColor Gray

Write-Host "Starting transcript and launching menu...`n" -ForegroundColor Yellow

Start-Transcript -Path $outputFile -Append

try {
    .\Deploy-PolicyScenarios.ps1
    
    Write-Host "`n✅ Scenario $ScenarioNumber completed" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Error during scenario execution: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Stop-Transcript
    
    Write-Host "`n✓ Transcript saved to: $outputFile" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "  1. Review the output file for errors" -ForegroundColor Gray
    Write-Host "  2. Check HTML report if generated" -ForegroundColor Gray
    Write-Host "  3. Verify parameter file used" -ForegroundColor Gray
    Write-Host "  4. Validate next steps in output`n" -ForegroundColor Gray
}
