# Smart Auto-Remediation Monitor with Timing Tracking
# Checks every 5 minutes and logs actual Azure Policy timing

param(
    [int]$CheckIntervalSeconds = 300,  # 5 minutes
    [int]$MaxWaitMinutes = 60
)

$startTime = Get-Date
$maxWaitTime = $MaxWaitMinutes * 60
$logFile = ".\AutoRemediation-Timing-Log.txt"

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Auto-Remediation Smart Monitor - Started                ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Initialize log file
@"
=== Auto-Remediation Timing Log ===
Deployment Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Scenario: 3.3 DevTest Full Auto-Remediation (46 policies, 9 with managed identity)
Subscription: ab1336c7-687d-4107-b0f6-9649a0458adb

"@ | Out-File $logFile

Write-Host "START TIME:     $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
Write-Host "CHECK INTERVAL: Every $($CheckIntervalSeconds/60) minutes" -ForegroundColor Yellow
Write-Host "MAX WAIT:       $MaxWaitMinutes minutes" -ForegroundColor Yellow
Write-Host "LOG FILE:       $logFile`n" -ForegroundColor Gray

$remediationTasksFound = $false
$remediationCompleted = $false
$checkCount = 0

while ((Get-Date) -lt $startTime.AddSeconds($maxWaitTime)) {
    $checkCount++
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
    
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "[Check #$checkCount] Time Elapsed: $elapsed minutes ($(Get-Date -Format 'HH:mm:ss'))" -ForegroundColor Yellow
    
    # Check for remediation tasks
    try {
        $remediations = Get-AzPolicyRemediation -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb" -ErrorAction SilentlyContinue
        
        if ($remediations -and -not $remediationTasksFound) {
            $remediationTasksFound = $true
            $taskFoundTime = Get-Date
            $timeToCreate = [math]::Round(($taskFoundTime - $startTime).TotalMinutes, 1)
            
            Write-Host "`n  🎯 MILESTONE: Remediation Tasks Created!" -ForegroundColor Green
            Write-Host "  ⏱️  Time from deployment: $timeToCreate minutes`n" -ForegroundColor Green
            
            @"
[MILESTONE 1] Remediation Tasks Created
Time to Task Creation: $timeToCreate minutes
Task Found At: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Number of Tasks: $($remediations.Count)

"@ | Out-File $logFile -Append
        }
        
        if ($remediations) {
            $inProgress = ($remediations | Where-Object { $_.ProvisioningState -in @('Running', 'Accepted', 'Created') }).Count
            $succeeded = ($remediations | Where-Object { $_.ProvisioningState -eq 'Succeeded' }).Count
            $failed = ($remediations | Where-Object { $_.ProvisioningState -eq 'Failed' }).Count
            
            Write-Host "  📊 Tasks Status:" -ForegroundColor Cyan
            Write-Host "     Total:       $($remediations.Count)" -ForegroundColor White
            Write-Host "     In Progress: $inProgress" -ForegroundColor Yellow
            Write-Host "     Succeeded:   $succeeded" -ForegroundColor Green
            if ($failed -gt 0) {
                Write-Host "     Failed:      $failed" -ForegroundColor Red
            }
            
            # Log task details
            "Check #$checkCount at $elapsed min:" | Out-File $logFile -Append
            $remediations | ForEach-Object {
                "  - $($_.Name): $($_.ProvisioningState)" | Out-File $logFile -Append
            }
            "" | Out-File $logFile -Append
            
            # Check if all tasks completed
            if ($inProgress -eq 0 -and ($succeeded + $failed) -gt 0 -and -not $remediationCompleted) {
                $remediationCompleted = $true
                $completedTime = Get-Date
                $timeToComplete = [math]::Round(($completedTime - $startTime).TotalMinutes, 1)
                
                Write-Host "`n  ✅ MILESTONE: All Remediation Tasks Completed!" -ForegroundColor Green
                Write-Host "  ⏱️  Total time: $timeToComplete minutes`n" -ForegroundColor Green
                
                @"
[MILESTONE 2] All Remediation Tasks Completed
Time to Completion: $timeToComplete minutes
Completed At: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Tasks Succeeded: $succeeded
Tasks Failed: $failed

=== TIMING SUMMARY ===
Phase 1 (Task Creation): $timeToCreate minutes
Phase 2 (Task Execution): $([math]::Round($timeToComplete - $timeToCreate, 1)) minutes
Total Time: $timeToComplete minutes

Recommendation for Future Deployments:
- Wait $([math]::Ceiling($timeToComplete)) minutes before checking remediation status
- Check for task creation after $([math]::Ceiling($timeToCreate)) minutes

"@ | Out-File $logFile -Append
                
                Write-Host "`n  Running comprehensive status check...`n" -ForegroundColor Cyan
                .\Check-AutoRemediation.ps1
                
                Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
                Write-Host "║          ACTUAL TIMING RESULTS (for future use)             ║" -ForegroundColor Green
                Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
                Write-Host "  Phase 1 - Task Creation:  $timeToCreate minutes" -ForegroundColor White
                Write-Host "  Phase 2 - Task Execution: $([math]::Round($timeToComplete - $timeToCreate, 1)) minutes" -ForegroundColor White
                Write-Host "  Total Time:               $timeToComplete minutes" -ForegroundColor White
                Write-Host "`n  💾 Detailed log saved to: $logFile" -ForegroundColor Gray
                Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green
                
                break
            }
        } else {
            Write-Host "  ⏳ No remediation tasks yet" -ForegroundColor Gray
            Write-Host "     Azure is still evaluating policy compliance..." -ForegroundColor DarkGray
        }
        
    } catch {
        Write-Host "  ⚠️  Error checking remediation status: $($_.Exception.Message)" -ForegroundColor Red
        "Error at check #$checkCount : $($_.Exception.Message)" | Out-File $logFile -Append
    }
    
    # Wait before next check (unless we're done)
    if ((Get-Date) -lt $startTime.AddSeconds($maxWaitTime) -and -not $remediationCompleted) {
        $nextCheck = (Get-Date).AddSeconds($CheckIntervalSeconds)
        Write-Host "`n  ⏰ Next check at: $($nextCheck.ToString('HH:mm:ss'))" -ForegroundColor DarkGray
        Write-Host "     (waiting $($CheckIntervalSeconds/60) minutes...)`n" -ForegroundColor DarkGray
        Start-Sleep -Seconds $CheckIntervalSeconds
    }
}

# Timeout handling
if (-not $remediationCompleted) {
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
    Write-Host "`n⚠️  Timeout reached after $elapsed minutes" -ForegroundColor Yellow
    Write-Host "   Remediation may still be in progress. Running final check...`n" -ForegroundColor Yellow
    
    "Timeout reached after $elapsed minutes" | Out-File $logFile -Append
    "Final check performed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $logFile -Append
    
    .\Check-AutoRemediation.ps1
}

Write-Host "`n✅ Monitoring complete. Check the HTML report for compliance improvements.`n" -ForegroundColor Green
