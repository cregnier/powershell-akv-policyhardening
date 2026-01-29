# Long-Running Jobs Best Practices Guide
## Enterprise-Scale Azure Key Vault Discovery

**Document Version**: 1.0  
**Last Updated**: January 29, 2026  
**Target Scenarios**: 500+ subscriptions, multi-hour execution times

---

## Overview

When discovering Azure resources across large enterprise environments (500+ subscriptions, thousands of resources), inventory scans can take significant time even with parallel processing. This guide provides best practices for managing long-running jobs, preventing timeouts, and ensuring reliable execution.

**Performance Baseline** (from testing):
- **838 subscriptions** with parallel processing: **14 minutes**
- **838 subscriptions** without parallel: **90+ minutes** (estimated)
- **Scaling factor**: Add ~1 minute per 60 additional subscriptions with parallel

---

## Table of Contents

1. [Session Management](#session-management)
2. [Azure Automation Deployment](#azure-automation-deployment)
3. [Azure Cloud Shell Usage](#azure-cloud-shell-usage)
4. [Progress Monitoring](#progress-monitoring)
5. [Troubleshooting Long Jobs](#troubleshooting-long-jobs)
6. [Performance Optimization](#performance-optimization)

---

## Session Management

### Local PowerShell Session Best Practices

#### 1. Terminal Session Persistence

**Problem**: Local terminal sessions may timeout or disconnect during long-running jobs

**Solution: Use Screen/Tmux (Linux/WSL) or Windows Terminal**

```bash
# Linux/WSL with screen
screen -S azure-discovery
.\Run-ParallelTests-Fast.ps1 -AccountType AAD

# Detach: Ctrl+A, D
# Reattach: screen -r azure-discovery

# Linux/WSL with tmux
tmux new -s azure-discovery
.\Run-ParallelTests-Fast.ps1 -AccountType AAD

# Detach: Ctrl+B, D
# Reattach: tmux attach -t azure-discovery
```

#### 2. PowerShell Transcript Logging

**Always enable transcript for long jobs**:

```powershell
# Start transcript before running long job
Start-Transcript -Path ".\Logs\Discovery-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"

# Run your discovery
.\Run-ParallelTests-Fast.ps1 -AccountType AAD

# Stop transcript
Stop-Transcript
```

**Built-in Transcript**: Our test runners already include transcript logging automatically

#### 3. Authentication Token Expiration

**Problem**: Azure authentication tokens expire after 1-2 hours

**Solution: Refresh token or use Service Principal**

```powershell
# Option 1: Refresh token mid-execution (manual)
# If job runs >90 minutes, run this in separate terminal:
Connect-AzAccount -UseDeviceAuthentication

# Option 2: Use Service Principal (recommended for automation)
$tenantId = "<tenant-id>"
$appId = "<app-id>"
$thumbprint = "<cert-thumbprint>"

Connect-AzAccount `
    -ServicePrincipal `
    -TenantId $tenantId `
    -ApplicationId $appId `
    -CertificateThumbprint $thumbprint

# Service Principal tokens last 24 hours by default
```

---

## Azure Automation Deployment

### Why Use Azure Automation

✅ **Benefits**:
- Persistent execution environment (no terminal timeouts)
- Automatic retry on transient failures
- Scheduled execution (nightly/weekly scans)
- Centralized logging and monitoring
- No dependency on developer workstation

### Setup Azure Automation Account

```powershell
# 1. Create Automation Account
$resourceGroup = "rg-automation-prod"
$automationAccount = "aa-keyvault-discovery"
$location = "eastus"

New-AzResourceGroup -Name $resourceGroup -Location $location

New-AzAutomationAccount `
    -Name $automationAccount `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -Plan "Basic"

# 2. Enable System-Assigned Managed Identity
Set-AzAutomationAccount `
    -ResourceGroupName $resourceGroup `
    -Name $automationAccount `
    -AssignSystemIdentity

# Get managed identity for RBAC assignment
$identity = (Get-AzAutomationAccount -ResourceGroupName $resourceGroup -Name $automationAccount).Identity.PrincipalId

# 3. Assign Reader role to managed identity
New-AzRoleAssignment `
    -ObjectId $identity `
    -RoleDefinitionName "Reader" `
    -Scope "/subscriptions/<subscription-id>"
```

### Import PowerShell Modules

```powershell
# Import required Az modules to Automation Account
$modules = @('Az.Accounts', 'Az.Resources', 'Az.KeyVault', 'Az.Monitor')

foreach ($module in $modules) {
    New-AzAutomationModule `
        -ResourceGroupName $resourceGroup `
        -AutomationAccountName $automationAccount `
        -Name $module `
        -ContentLinkUri "https://www.powershellgallery.com/api/v2/package/$module"
}

# Wait for module imports to complete (5-10 minutes)
do {
    Start-Sleep -Seconds 30
    $moduleStatus = Get-AzAutomationModule -ResourceGroupName $resourceGroup -AutomationAccountName $automationAccount
    $importing = $moduleStatus | Where-Object { $_.ProvisioningState -eq 'Creating' }
    Write-Host "Modules still importing: $($importing.Count)"
} while ($importing.Count -gt 0)
```

### Create Runbook

```powershell
# Create runbook for Key Vault discovery
$runbookName = "KeyVault-Discovery-Parallel"
$runbookContent = @'
param(
    [Parameter(Mandatory = $false)]
    [int]$ThrottleLimit = 20
)

# Authenticate with Managed Identity
Connect-AzAccount -Identity

# Import discovery script content
# (Upload Get-KeyVaultInventory.ps1 as Automation Asset or embed here)

# Run parallel discovery
.\Get-KeyVaultInventory.ps1 `
    -Parallel `
    -ThrottleLimit $ThrottleLimit `
    -OutputPath "C:\Temp\KeyVaultInventory-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"

# Upload CSV to Azure Storage Account
$storageAccount = "stkeyvaultreports"
$container = "discovery-reports"
$csvFile = Get-ChildItem "C:\Temp\KeyVaultInventory-*.csv" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

Set-AzStorageBlobContent `
    -File $csvFile.FullName `
    -Container $container `
    -Blob $csvFile.Name `
    -Context (Get-AzStorageAccount -ResourceGroupName "rg-automation-prod" -Name $storageAccount).Context

Write-Output "Discovery complete. CSV uploaded to: $($csvFile.Name)"
'@

# Create runbook
New-AzAutomationRunbook `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccount `
    -Name $runbookName `
    -Type PowerShell `
    -Description "Parallel Key Vault discovery across all subscriptions"

# Import runbook content
Import-AzAutomationRunbook `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccount `
    -Name $runbookName `
    -Path "C:\Scripts\KeyVault-Discovery-Runbook.ps1" `
    -Type PowerShell `
    -Force

# Publish runbook
Publish-AzAutomationRunbook `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccount `
    -Name $runbookName
```

### Schedule Runbook Execution

```powershell
# Create weekly schedule (every Sunday at 2 AM)
$scheduleName = "Weekly-KeyVault-Scan"
$startTime = (Get-Date "02:00:00").AddDays(7 - (Get-Date).DayOfWeek.value__)

New-AzAutomationSchedule `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccount `
    -Name $scheduleName `
    -StartTime $startTime `
    -WeekInterval 1 `
    -DaysOfWeek Sunday

# Link schedule to runbook
Register-AzAutomationScheduledRunbook `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccount `
    -RunbookName $runbookName `
    -ScheduleName $scheduleName `
    -Parameters @{ ThrottleLimit = 20 }
```

---

## Azure Cloud Shell Usage

### Benefits of Cloud Shell

✅ **No local dependencies** - PowerShell 7.x and Az modules pre-installed  
✅ **Persistent storage** - Scripts and logs persist across sessions  
✅ **No authentication timeouts** - Cloud Shell manages tokens automatically  
✅ **Browser-based** - No terminal emulator required  

### Setup Cloud Shell for Discovery

```powershell
# 1. Open Cloud Shell (https://shell.azure.com)

# 2. Upload discovery scripts to Cloud Shell storage
# Method A: Use Upload button in Cloud Shell UI
# Method B: Clone from GitHub
git clone https://github.com/cregnier/powershell-akv-policyhardening.git
cd powershell-akv-policyhardening

# 3. Verify modules
Get-Module -Name Az.* -ListAvailable

# 4. Run parallel discovery
.\Run-ParallelTests-Fast.ps1 -AccountType AAD

# 5. Download CSVs
# Click Download button in Cloud Shell UI or use Azure Storage integration
```

### Cloud Shell Timeout Management

**Cloud Shell session timeout**: 20 minutes of inactivity

**Workaround for long jobs**:
```powershell
# Use nohup-style background execution
Start-Job -ScriptBlock {
    .\Run-ParallelTests-Fast.ps1 -AccountType AAD
} -Name "KeyVaultDiscovery"

# Check job status
Get-Job -Name "KeyVaultDiscovery"

# Retrieve results
Receive-Job -Name "KeyVaultDiscovery" -Keep

# Or reconnect to Cloud Shell after 30 minutes and check logs
Get-Content ".\TestResults-*/Test2-KeyVaults-AAD-PARALLEL.txt" -Tail 50
```

---

## Progress Monitoring

### Built-in Progress Indicators

Our parallel-enabled scripts include real-time progress:

```powershell
# Run with parallel processing
.\Get-KeyVaultInventory.ps1 -Parallel -ThrottleLimit 20

# Output shows:
# [PROGRESS] 50/838 subscriptions (6.0%) | Key Vaults found: 125
# [PROGRESS] 100/838 subscriptions (11.9%) | Key Vaults found: 287
# [PROGRESS] 150/838 subscriptions (17.9%) | Key Vaults found: 412
```

### Custom Progress Monitoring Script

```powershell
# Monitor-DiscoveryProgress.ps1
param(
    [string]$TranscriptPath
)

while ($true) {
    if (Test-Path $TranscriptPath) {
        $content = Get-Content $TranscriptPath -Tail 10
        $progressLine = $content | Where-Object { $_ -match '\[PROGRESS\]' } | Select-Object -Last 1
        
        if ($progressLine) {
            Clear-Host
            Write-Host "=== Discovery Progress Monitor ===" -ForegroundColor Cyan
            Write-Host $progressLine -ForegroundColor Yellow
            
            # Extract percentage
            if ($progressLine -match '(\d+)/(\d+) subscriptions \((\d+\.\d+)%\)') {
                $current = [int]$Matches[1]
                $total = [int]$Matches[2]
                $percent = [double]$Matches[3]
                
                # Estimate time remaining (assumes 1 sub/second with parallel)
                $remaining = $total - $current
                $estimatedMinutes = [math]::Ceiling($remaining / 60)
                
                Write-Host "Estimated time remaining: $estimatedMinutes minutes" -ForegroundColor Green
            }
        }
    }
    
    Start-Sleep -Seconds 5
}

# Usage: Run in separate terminal
.\Monitor-DiscoveryProgress.ps1 -TranscriptPath ".\TestResults-AAD-PARALLEL-FAST-*/Test2-KeyVaults-AAD-PARALLEL.txt"
```

---

## Troubleshooting Long Jobs

### Issue 1: Job Appears Hung (No Progress for 5+ Minutes)

**Diagnosis**:
```powershell
# Check transcript file for latest activity
Get-Content ".\TestResults-*/Test2-KeyVaults-AAD-PARALLEL.txt" -Tail 20

# Check if PowerShell process is consuming CPU
Get-Process -Name pwsh | Select-Object CPU, WorkingSet
```

**Common Causes**:
- Azure API throttling (429 errors)
- Network connectivity issues
- Subscription with thousands of Key Vaults

**Solution**:
```powershell
# Reduce throttle limit to avoid API throttling
.\Get-KeyVaultInventory.ps1 -Parallel -ThrottleLimit 10

# Or use sequential processing for problematic subscriptions
.\Get-KeyVaultInventory.ps1 -SubscriptionIds @('problematic-sub-id')
```

### Issue 2: Out of Memory Errors

**Symptoms**:
```
OutOfMemoryException: Exception of type 'System.OutOfMemoryException' was thrown.
```

**Causes**:
- Too many parallel threads (ThrottleLimit too high)
- Large CSV files held in memory

**Solution**:
```powershell
# Reduce parallel threads
.\Get-KeyVaultInventory.ps1 -Parallel -ThrottleLimit 10  # Default is 20

# Or run in batches
$allSubs = Get-AzSubscription
$batchSize = 200

for ($i = 0; $i -lt $allSubs.Count; $i += $batchSize) {
    $batch = $allSubs[$i..([math]::Min($i + $batchSize - 1, $allSubs.Count - 1))]
    .\Get-KeyVaultInventory.ps1 -SubscriptionIds $batch.Id -Parallel
}
```

### Issue 3: Authentication Expired Mid-Execution

**Symptoms**:
```
Connect-AzAccount : AADSTS70043: The refresh token has expired
```

**Prevention**:
```powershell
# Use Service Principal with long-lived tokens
Connect-AzAccount -ServicePrincipal -TenantId $tenantId -ApplicationId $appId -CertificateThumbprint $thumbprint

# Service Principal tokens last 24 hours (vs 1-2 hours for user tokens)
```

---

## Performance Optimization

### Parallel Processing Recommendations

| Environment Size | ThrottleLimit | Expected Time | Notes |
|------------------|---------------|---------------|-------|
| <50 subscriptions | Sequential (no parallel) | <5 minutes | Parallel overhead not worth it |
| 50-200 subscriptions | 10 | 5-10 minutes | Conservative parallelism |
| 200-500 subscriptions | 15 | 10-15 minutes | Balanced performance |
| 500-1000 subscriptions | 20 | 15-20 minutes | Maximum safe parallelism |
| 1000+ subscriptions | 20 | 20-30 minutes | Consider batching |

### Network Optimization

```powershell
# Run from Azure VM in same region as most resources
# Reduces latency by 50-100ms per API call

# Example: 838 subs * 5 API calls/sub * 75ms latency = 5 minutes saved
```

### Filtering Strategies

```powershell
# If you only need specific resource types, filter early
.\Get-KeyVaultInventory.ps1 -Parallel | Where-Object { $_.Location -eq 'eastus' }

# Or target specific subscriptions
.\Get-KeyVaultInventory.ps1 -SubscriptionIds (Get-Content .\production-subs.txt)
```

---

## Checkpoint/Resume Capability (Future Enhancement)

**Planned Feature**: Save progress and resume from last successful subscription

```powershell
# Conceptual implementation
.\Get-KeyVaultInventory.ps1 -Parallel -CheckpointFile ".\progress.json"

# If interrupted, resume from checkpoint
.\Get-KeyVaultInventory.ps1 -Parallel -ResumeFromCheckpoint ".\progress.json"
```

**Current Workaround**: Process subscriptions in batches

```powershell
# Batch 1: Subscriptions 1-200
.\Get-KeyVaultInventory.ps1 -SubscriptionIds ($allSubs[0..199].Id) -Parallel

# Batch 2: Subscriptions 201-400
.\Get-KeyVaultInventory.ps1 -SubscriptionIds ($allSubs[200..399].Id) -Parallel

# Combine CSVs manually
$csv1 = Import-Csv ".\KeyVaultInventory-Batch1.csv"
$csv2 = Import-Csv ".\KeyVaultInventory-Batch2.csv"
$combined = $csv1 + $csv2
$combined | Export-Csv ".\KeyVaultInventory-Combined.csv" -NoTypeInformation
```

---

## Recommended Workflow for Enterprise

```powershell
# 1. Initial discovery (manual, one-time)
Connect-AzAccount -ServicePrincipal -TenantId $tenantId -ApplicationId $appId -CertificateThumbprint $thumbprint
.\Run-ParallelTests-Fast.ps1 -AccountType AAD

# 2. Review results
.\Analyze-ComplianceResults.ps1

# 3. Setup Azure Automation for recurring scans
.\Deploy-AutomationRunbook.ps1

# 4. Schedule weekly scans
.\Create-WeeklySchedule.ps1

# 5. Monitor automation jobs
Get-AzAutomationJob -ResourceGroupName "rg-automation-prod" -AutomationAccountName "aa-keyvault-discovery"
```

---

## Summary

**Best Practices**:
- ✅ Use **parallel processing** for 200+ subscriptions
- ✅ Use **Service Principal** for production automation
- ✅ Use **Azure Automation** for scheduled scans
- ✅ Enable **transcript logging** for all long jobs
- ✅ Monitor **progress indicators** for status updates
- ✅ Use **Azure Cloud Shell** for browser-based execution
- ✅ Set **ThrottleLimit=20** for maximum performance
- ✅ Plan for **15-20 minutes** per 1000 subscriptions

**Avoid**:
- ❌ Running 500+ subscription scans from local laptop without session management
- ❌ Using user authentication for automated/scheduled jobs
- ❌ Setting ThrottleLimit >20 (causes Azure API throttling)
- ❌ Running sequential scans on large environments (takes hours)

---

**Next Steps**: See [PREREQUISITES-GUIDE.md](PREREQUISITES-GUIDE.md) for authentication setup and [AAD-vs-MSA-Comparison-Report.md](AAD-vs-MSA-Comparison-Report.md) for performance benchmarks.
