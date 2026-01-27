# Azure Policy Cleanup Guide

**Last Updated**: 2026-01-26  
**Purpose**: Document the correct method for cleaning up Azure Key Vault policies between test scenarios

---

## 🎯 Executive Summary

**RECOMMENDED METHOD**: Use `Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst`

**Why**: Comprehensive policy detection, built-in safeguards, handles hash-based naming, better than manual or Rollback methods.

---

## 📋 Three Cleanup Methods Comparison

### Method 1: Setup Script -CleanupFirst ✅ RECOMMENDED

**File**: `Setup-AzureKeyVaultPolicyEnvironment.ps1`  
**Parameter**: `-CleanupFirst`

```powershell
# Cleanup policies only (answer DELETE, then decline infrastructure cleanup)
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst

# Full cleanup (policies + infrastructure - for fresh start)
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst
# Answer 'DELETE' and 'YES' to all prompts
```

**Advantages**:
- ✅ **Comprehensive filters**: Matches hash-based policy names using multiple patterns
  - `*KeyVault*`, `*Keys*`, `*Secrets*`, `*Certificates*`
  - DisplayName patterns: `*Key Vault*`, `*Managed HSM*`
  - Excludes only `sys.*` and `SecurityCenter*` (correct exclusions)
- ✅ **Preview mode**: Shows all policies before removal with confirmation prompt
- ✅ **Better removal API**: Uses `-Id` property (more reliable than Name+Scope)
- ✅ **Error handling**: Try/catch with detailed logging and summary counts
- ✅ **Dual cleanup**: Can clean policies only OR policies + infrastructure
- ✅ **Built-in safeguards**: Requires 'DELETE' and 'YES' confirmations

**Filter Logic** (lines 286-299):
```powershell
$assignments = Get-AzPolicyAssignment | Where-Object { 
    # Legacy naming patterns
    $_.Name -like 'KV-All-*' -or 
    $_.Name -like 'KV-Tier*' -or 
    # Name-based patterns (covers truncated hash names)
    $_.Name -like '*KeyVault*' -or 
    $_.Name -like '*keyvault*' -or
    $_.Name -like '*Keys*' -or
    $_.Name -like '*Secrets*' -or
    $_.Name -like '*Certificates*' -or
    # DisplayName patterns
    $_.DisplayName -like '*Key Vault*' -or
    $_.DisplayName -like '*Managed HSM*' -or
    # Exclude system policies
    ($_.Name -notlike 'sys.*' -and $_.Name -notlike 'SecurityCenter*')
}
```

**Removal Code** (line 342):
```powershell
Remove-AzPolicyAssignment -Id $assignment.Id -ErrorAction Stop
```

**When to Use**:
- ✅ Between test scenarios (Scenarios 5 → 6 → 7)
- ✅ Before fresh infrastructure setup
- ✅ When hash-based policy names are deployed
- ✅ When you need policy preview before removal

---

### Method 2: AzPolicyImplScript.ps1 -Rollback ❌ DOES NOT WORK

**File**: `AzPolicyImplScript.ps1`  
**Parameter**: `-Rollback`

```powershell
# Attempt to rollback policies (WILL FAIL)
.\AzPolicyImplScript.ps1 -Rollback
```

**Why It Fails**:
- ❌ **Searches for "KV" pattern**: Looks for policies named `KV-*` 
- ❌ **Reality**: Policies use hash-based names like `Keyvaultsshouldhavesoftdeleteenabled-1789932088`
- ❌ **Result**: Finds 0 policies, removes nothing

**Output**:
```
No Key Vault policy assignments found at scope: /subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb
```

**When to Use**:
- ❌ **NEVER** - Does not work with current policy naming convention
- ⚠️ Only works if policies were deployed with "KV-*" prefix (legacy naming)

**Fix Needed**: Update Rollback function to use same filter logic as Setup script

---

### Method 3: Manual PowerShell Loop ⚠️ WORKS BUT NOT RECOMMENDED

**Method**: Direct PowerShell commands

```powershell
# Get subscription scope
$scope = "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb"

# Get all policy assignments
$assignments = Get-AzPolicyAssignment -Scope $scope

# Filter out system policies
$toRemove = $assignments | Where-Object { 
    $_.Name -ne 'sys.blockwesteurope' -and 
    $_.Name -notlike 'SecurityCenter*' 
}

# Remove each assignment (WORKING METHOD)
foreach ($assignment in $toRemove) {
    Remove-AzPolicyAssignment -Name $assignment.Name -Scope $scope
    Write-Host "✓ Removed: $($assignment.Name)"
}
```

**Advantages**:
- ✅ Works with hash-based names
- ✅ Simple and direct
- ✅ No external script dependencies

**Disadvantages**:
- ❌ No preview mode
- ❌ No confirmation prompts (dangerous)
- ❌ Less robust error handling
- ❌ Requires correct parameter knowledge (Name+Scope, not ResourceId)
- ❌ Manual process (no logging/tracking)

**Historical Note**: 
This method required **3 attempts** during Scenario 4 cleanup:
1. Attempt 1: Used Rollback → Failed (wrong filter)
2. Attempt 2: Used ResourceId → Failed (empty string property)
3. Attempt 3: Used Name+Scope → Success (46/46 removed)

**When to Use**:
- ⚠️ Only as last resort if Setup script unavailable
- ⚠️ For custom filtering scenarios
- ⚠️ When you understand the API parameters

---

## 🔧 Troubleshooting

### Issue: "Parameter 'Id' cannot be bound (empty string)"

**Symptom**: 
```powershell
Remove-AzPolicyAssignment -Id $assignment.ResourceId
# Error: Cannot bind argument to parameter 'Id' because it is an empty string
```

**Root Cause**: `$assignment.ResourceId` property returns empty string in newer Az.Resources module

**Solution**: Use one of these alternatives:
```powershell
# Option 1: Use Id property (RECOMMENDED - Setup script uses this)
Remove-AzPolicyAssignment -Id $assignment.Id

# Option 2: Use Name + Scope (WORKS - manual method)
Remove-AzPolicyAssignment -Name $assignment.Name -Scope $assignment.Properties.Scope
```

---

### Issue: Rollback Finds 0 Policies

**Symptom**: 
```powershell
.\AzPolicyImplScript.ps1 -Rollback
# Output: No Key Vault policy assignments found
```

**Root Cause**: Script searches for "KV-*" naming pattern, but policies use hash-based names

**Verification**:
```powershell
# Check actual policy names
Get-AzPolicyAssignment | Select-Object Name | Out-GridView

# Example names:
# Keyvaultsshouldhavesoftdeleteenabled-1789932088
# Certificatesshouldhavethespecifiedmaximumvalidityperi-1606864759
# (No "KV-" prefix)
```

**Solution**: Use Setup script -CleanupFirst instead

---

### Issue: Need to Remove Infrastructure AND Policies

**Scenario**: Fresh start for complete testing from scratch

**Solution**: Full cleanup with Setup script
```powershell
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst

# Prompts you'll see:
# 1. "Type 'DELETE' to confirm cleanup" → Type: DELETE
# 2. Preview of policies to remove
# 3. "Proceed with cleanup? Type 'YES' to confirm" → Type: YES
# 4. Removes: All policies, test vaults, infrastructure (both resource groups)
```

**Removes**:
- ✅ All Key Vault policy assignments (46 policies)
- ✅ Resource group: `rg-policy-keyvault-test` (test vaults)
- ✅ Resource group: `rg-policy-remediation` (managed identity, networking, monitoring)

---

## 📖 Recommended Workflow

### Between Scenarios (Policies Only)

**Use Case**: Cleanup Scenario 5 before deploying Scenario 6

```powershell
# Start logging
Start-Transcript -Path ".\logs\Scenario5-Cleanup-20260126.log" -Append

# Run cleanup
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst

# At first prompt: Type 'DELETE' and press Enter
# Review policy list (46 policies shown)
# At second prompt: Type 'YES' and press Enter
# When asked about infrastructure cleanup: Type 'no' or just press Ctrl+C after policies removed

# Verify cleanup
Get-AzPolicyAssignment -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb" | 
    Where-Object { $_.Name -notlike 'sys.*' -and $_.Name -notlike 'SecurityCenter*' } | 
    Measure-Object
# Should show: Count = 0

Stop-Transcript
```

---

### Fresh Start (Policies + Infrastructure)

**Use Case**: Complete reset before starting full 9-scenario testing

```powershell
# Create logs directory
New-Item -ItemType Directory -Path ".\logs" -Force

# Start logging
Start-Transcript -Path ".\logs\Phase0-Cleanup-20260126.log" -Append

# Full cleanup
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CleanupFirst
# Answer 'DELETE' then 'YES' to all prompts

# Verify complete cleanup
Get-AzResourceGroup | Where-Object { 
    $_.ResourceGroupName -like 'rg-policy-*' 
} | Select-Object ResourceGroupName
# Should show: Nothing (both RGs removed)

Get-AzPolicyAssignment -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb" | 
    Where-Object { $_.Name -notlike 'sys.*' -and $_.Name -notlike 'SecurityCenter*' } | 
    Measure-Object
# Should show: Count = 0

Stop-Transcript

# Fresh infrastructure setup
Start-Transcript -Path ".\logs\Phase1-Infrastructure-20260126.log" -Append
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -ActionGroupEmail "your-email@company.com"
Stop-Transcript
```

---

## 📊 Cleanup Method Decision Matrix

| Scenario | Method | Why |
|----------|--------|-----|
| **Between Scenarios 5-6-7** | Setup -CleanupFirst | Comprehensive, safe, built-in |
| **Before fresh infrastructure** | Setup -CleanupFirst (full) | Removes policies + infrastructure |
| **Hash-based policy names** | Setup -CleanupFirst | Only method that works reliably |
| **Need policy preview** | Setup -CleanupFirst | Shows all policies before removal |
| **Legacy "KV-*" names** | Rollback (might work) | Only if old naming convention |
| **Custom filtering needed** | Manual PowerShell | When Setup script filters too broad |
| **Emergency cleanup** | Manual PowerShell | Setup script unavailable |

---

## 🎯 Best Practices

1. **Always log cleanup operations**:
   ```powershell
   Start-Transcript -Path ".\logs\Cleanup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
   # ... cleanup commands ...
   Stop-Transcript
   ```

2. **Verify cleanup success**:
   ```powershell
   # Check remaining policies
   $remaining = Get-AzPolicyAssignment -Scope "/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb" | 
       Where-Object { $_.Name -notlike 'sys.*' -and $_.Name -notlike 'SecurityCenter*' }
   
   if ($remaining.Count -eq 0) {
       Write-Host "✅ Cleanup successful - 0 policies remaining" -ForegroundColor Green
   } else {
       Write-Host "⚠️  WARNING: $($remaining.Count) policies still exist!" -ForegroundColor Yellow
   }
   ```

3. **Review policy list before confirming**:
   - Setup script shows preview with DisplayName, Name, and Scope
   - Verify the list matches expected policies (46 for full deployment)
   - Ensure no critical system policies in the list

4. **Cleanup timing**:
   - Cleanup takes 2-5 minutes for 46 policies
   - No Azure evaluation delay (instant removal)
   - Can proceed to next scenario immediately after cleanup

5. **Handle cleanup failures gracefully**:
   - Setup script shows: "X removed, Y failed"
   - Review failed policies in transcript log
   - Retry failed removals manually if needed

---

## 📝 Documentation Updates Required

Based on this cleanup investigation, the following files need updates:

1. **Workflow-Test-User-Input-Guide.md**:
   - Update all scenario cleanup instructions to use Setup script
   - Remove manual PowerShell cleanup steps
   - Add -CleanupFirst examples

2. **MASTER-TEST-PLAN-20260126.md**:
   - Update cleanup method in all scenarios
   - Add reference to CLEANUP-GUIDE.md
   - Document why Rollback doesn't work

3. **AzPolicyImplScript.ps1**:
   - Fix Rollback function filter logic (lines ~3500-3700)
   - Use same filter as Setup script (KeyVault/Keys/Secrets/Certificates patterns)
   - Add deprecation warning and recommend Setup script

4. **todos.md**:
   - Update cleanup steps for Scenarios 5-7
   - Change from manual commands to Setup script

---

## 🔍 Technical Details

### Policy Naming Convention Evolution

**Old Convention** (Legacy):
- Pattern: `KV-All-<PolicyName>` or `KV-Tier1-<PolicyName>`
- Example: `KV-All-SoftDelete-Required`
- Rollback: Works (searches for "KV-*")

**New Convention** (Current - Since 2024):
- Pattern: `<TruncatedDisplayName>-<NumericHash>`
- Example: `Keyvaultsshouldhavesoftdeleteenabled-1789932088`
- Rollback: Fails (no "KV-*" prefix)
- Setup: Works (searches for KeyVault/Keys/Secrets/Certificates keywords)

**Why Hash-Based Names?**:
- Azure truncates long policy display names to 64 characters
- Numeric suffix prevents naming conflicts
- More reliable than manual naming conventions

### Filter Patterns Explained

**Setup Script Comprehensive Filter**:
```powershell
# Matches hash-based names
$_.Name -like '*KeyVault*' -or    # KeyVault anywhere in name
$_.Name -like '*Keys*' -or         # Keys policies
$_.Name -like '*Secrets*' -or      # Secrets policies  
$_.Name -like '*Certificates*' -or # Certificate policies

# Matches via DisplayName (when available)
$_.DisplayName -like '*Key Vault*' -or  # Any Key Vault policy
$_.DisplayName -like '*Managed HSM*'    # Managed HSM policies

# Excludes system policies
$_.Name -notlike 'sys.*' -and           # Azure system policies
$_.Name -notlike 'SecurityCenter*'      # Defender for Cloud policies
```

**Coverage**: All 46 Key Vault governance policies

---

## 📚 Related Documentation

- [MASTER-TEST-PLAN-20260126.md](MASTER-TEST-PLAN-20260126.md) - Complete testing workflow
- [Workflow-Test-User-Input-Guide.md](Workflow-Test-User-Input-Guide.md) - Scenario-by-scenario guide
- [AUTO-REMEDIATION-GUIDE.md](AUTO-REMEDIATION-GUIDE.md) - Auto-remediation policies
- [Setup-AzureKeyVaultPolicyEnvironment.ps1](Setup-AzureKeyVaultPolicyEnvironment.ps1) - Infrastructure script (lines 266-360 for cleanup)

---

**Last Tested**: 2026-01-26  
**Validated On**: Azure subscription ab1336c7-687d-4107-b0f6-9649a0458adb  
**Policy Count**: 46 Key Vault policies  
**Module Version**: Az.Resources 7.5.0, Az.PolicyInsights 1.6.4
