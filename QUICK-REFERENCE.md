# Quick Reference Card - Sprint 1 Story 1.1

## 🚀 Quick Start (Choose Your Scenario)

### Scenario 1: MSDN Subscription (Guest MSA)
```powershell
Connect-AzAccount
.\Test-DiscoveryPrerequisites.ps1 -FixIssues
.\Start-EnvironmentDiscovery.ps1
# Select option 4 (Full Discovery)
```

### Scenario 2: Corporate AAD (Intel Azure)
```powershell
Connect-AzAccount -TenantId '<intel-tenant-id>'
.\Test-DiscoveryPrerequisites.ps1 -Detailed
# If FAIL: Request Reader role, then retry
.\Start-EnvironmentDiscovery.ps1
# Select option 4 (Full Discovery)
```

---

## 📋 Script Reference

| Script | Purpose | When to Use |
|--------|---------|-------------|
| **Start-EnvironmentDiscovery.ps1** | Unified menu-driven tool | **START HERE** - Main entry point |
| **Test-DiscoveryPrerequisites.ps1** | Validate prerequisites | Before running discovery |
| Get-AzureSubscriptionInventory.ps1 | Subscription inventory | Standalone use (optional) |
| Get-KeyVaultInventory.ps1 | Key Vault inventory | Standalone use (optional) |
| Get-PolicyAssignmentInventory.ps1 | Policy inventory | Standalone use (optional) |
| Invoke-EnvironmentDiscovery.ps1 | Orchestration (no menu) | Automation/scripting |

---

## 🔑 Required Permissions

| Scenario | Minimum Role | Optional | For Story 1.2 |
|----------|-------------|----------|---------------|
| **MSDN Guest MSA** | Owner (already have) | N/A | Owner (already have) |
| **Corporate AAD** | Reader | User Access Admin | Contributor + Policy Contributor |

---

## 📦 Required Modules

```powershell
Install-Module Az.Accounts -MinimumVersion 2.0.0 -Scope CurrentUser -Force
Install-Module Az.Resources -MinimumVersion 6.0.0 -Scope CurrentUser -Force
Install-Module Az.KeyVault -MinimumVersion 4.0.0 -Scope CurrentUser -Force
Install-Module Az.Monitor -MinimumVersion 4.0.0 -Scope CurrentUser -Force  # Optional
```

---

## 📂 Output Files

| File | Format | Purpose |
|------|--------|---------|
| **subscriptions-template.csv** | SubscriptionId, Name, Environment, Notes | Compatible with existing template |
| SubscriptionInventory.csv | Full details | All subscription metadata |
| KeyVaultInventory.csv | Full details | Key Vault configurations + compliance |
| PolicyAssignmentInventory.csv | Full details | Existing policy assignments |
| DiscoveryReport.txt | Text summary | Executive summary + next steps |

---

## 🎯 Menu Options (Start-EnvironmentDiscovery.ps1)

| Option | Action | Output |
|--------|--------|--------|
| **0** | Prerequisites check | Validation report |
| **1** | Subscription inventory | subscriptions-template.csv + SubscriptionInventory.csv |
| **2** | Key Vault inventory | KeyVaultInventory.csv |
| **3** | Policy inventory | PolicyAssignmentInventory.csv |
| **4** | Full discovery (detailed) | ALL CSVs + DiscoveryReport.txt |
| **5** | Quick discovery (basic) | ALL CSVs (faster, less detail) |
| **6** | Toggle template filter | Use existing subscriptions-template.csv |
| **7** | Toggle detailed mode | RBAC, network rules, parameters |
| **8** | View configuration | Current settings |
| **9** | Change output dir | Set custom path |
| **Q** | Quit | Exit script |

---

## ⚡ Common Commands

### Validate Everything
```powershell
.\Test-DiscoveryPrerequisites.ps1 -Detailed -FixIssues
```

### Run Full Discovery (Auto)
```powershell
.\Start-EnvironmentDiscovery.ps1 -AutoRun
```

### Filter by Existing Template
```powershell
.\Start-EnvironmentDiscovery.ps1 -UseExistingTemplate
```

### Check Your Permissions
```powershell
$subId = '<subscription-id>'
Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id -Scope "/subscriptions/$subId"
```

---

## 🚨 Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| "Not connected to Azure" | No Azure session | `Connect-AzAccount` |
| "No subscriptions found" | No access | Request Reader role |
| "Module not found" | Missing Az modules | `.\Test-DiscoveryPrerequisites.ps1 -FixIssues` |
| "Insufficient privileges" | Limited permissions | Expected with Reader role, script continues |
| "Access denied" for RBAC | No User Access Admin | Optional - skip `-IncludeRBAC` |

---

## 📖 Documentation Files

| File | Purpose |
|------|---------|
| **QUESTIONS-ANSWERED.md** | Answers to your 4 questions |
| **PREREQUISITES-GUIDE.md** | Complete permissions guide |
| **SPRINT1-STORY1.1-README.md** | Full documentation |
| Stakeholder-Contact-Template.csv | Track stakeholders |
| Gap-Analysis-Template.csv | Track gaps (28 pre-filled) |
| Risk-Register-Template.csv | Track risks (20 pre-filled) |

---

## ✅ Acceptance Criteria Checklist

- [ ] Run prerequisites validation: `.\Test-DiscoveryPrerequisites.ps1 -Detailed`
- [ ] All checks PASS (or access requested if corporate AAD)
- [ ] Run unified discovery: `.\Start-EnvironmentDiscovery.ps1`
- [ ] Select option 4 (Full Discovery)
- [ ] Review subscriptions-template.csv (compatible format) ✅
- [ ] Review SubscriptionInventory.csv (subscription IDs, resource counts) ✅
- [ ] Review KeyVaultInventory.csv (Key Vault resources, owners, environment) ✅
- [ ] Review PolicyAssignmentInventory.csv (existing policies)
- [ ] Review DiscoveryReport.txt (executive summary)
- [ ] Fill Stakeholder-Contact-Template.csv
- [ ] Fill Gap-Analysis-Template.csv
- [ ] Update Risk-Register-Template.csv

**Story 1.1 Complete!** ✅

---

## 🎯 Next Story

**Sprint 1, Story 1.2**: Pilot Environment Setup & Initial Deployment
- Select 2-3 pilot subscriptions from inventory
- Deploy 46 Key Vault policies in Audit mode
- Capture baseline compliance metrics
