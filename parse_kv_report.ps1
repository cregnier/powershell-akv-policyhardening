$path = 'c:\Temp\KeyVaultPolicyImplementationReport-20260112-173345.json'
if (-not (Test-Path $path)) { Write-Host "Report not found: $path"; exit 2 }
try {
    $raw = Get-Content $path -Raw
    $j = $raw | ConvertFrom-Json
} catch {
    Write-Host "Failed to parse JSON: $($_)"
    exit 3
}
$keys = ($j | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) -join ','
Write-Host "TopLevelKeys: $keys"
$v = if ($j.Verification) { $j.Verification.Count } else { 0 }
$rawCount = if ($j.Compliance -and $j.Compliance.Raw) { $j.Compliance.Raw.Count } else { 0 }
$reportTime = if ($j.Compliance.ReportGeneratedAt) { $j.Compliance.ReportGeneratedAt } else { '' }
$nonCompliantReasonCount = 0
if ($j.Compliance.NonCompliantReasons) {
    if ($j.Compliance.NonCompliantReasons -is [System.Collections.IEnumerable]) { $nonCompliantReasonCount = $j.Compliance.NonCompliantReasons.Count } else { $nonCompliantReasonCount = 1 }
}
Write-Host "VerificationCount: $v"
Write-Host "ComplianceRawCount: $rawCount"
Write-Host "ReportGeneratedAt: $reportTime"
Write-Host "NonCompliantReasonsCount: $nonCompliantReasonCount"
Write-Host ""
Write-Host "Sample Verification[0]:"
$j.Verification[0] | ConvertTo-Json -Depth 3
Write-Host ""
Write-Host "Sample Compliance.Raw[0] (fields):"
$first = $j.Compliance.Raw[0]
if ($first) {
    $obj = [PSCustomObject]@{ ResourceId = $first.ResourceId; PolicyAssignmentName = $first.PolicyAssignmentName; ComplianceState = $first.ComplianceState; Timestamp = $first.Timestamp }
    $obj | ConvertTo-Json -Depth 4
} else { Write-Host "No Raw entries" }
Write-Host ""
Write-Host "Basic integrity checks:"
$ok = $true
if ($v -eq 0) { Write-Host "- WARNING: No Verification entries found"; $ok = $false } else { Write-Host "- Verification entries present: $v" }
if ($rawCount -eq 0) { Write-Host "- WARNING: No Compliance.Raw entries found"; $ok = $false } else { Write-Host "- Compliance.Raw entries: $rawCount" }
if ($reportTime -eq '') { Write-Host "- WARNING: ReportGeneratedAt missing"; $ok = $false } else { Write-Host "- ReportGeneratedAt: $reportTime" }
if ($ok) { Write-Host "Report integrity: OK" } else { Write-Host "Report integrity: Issues found" }
