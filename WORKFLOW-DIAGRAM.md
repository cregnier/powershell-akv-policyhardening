# Azure Key Vault Policy Governance - Workflow Diagram

**Version**: 1.0  
**Last Updated**: 2026-01-16  
**Purpose**: Visual reference for all deployment and testing workflows

---

## Complete Workflow Overview

```mermaid
flowchart TD
    Start([Start: Policy Governance Implementation]) --> InfraSetup[Infrastructure Setup Workflow]
    
    InfraSetup --> DevTestWorkflow[DevTest Workflow<br/>30 Policies, Audit Mode]
    InfraSetup --> DevTestFullWorkflow[DevTest Full Workflow<br/>46 Policies, Audit Mode]
    
    DevTestFullWorkflow --> ProdAuditWorkflow[Production Audit Workflow<br/>46 Policies, Audit Mode]
    
    ProdAuditWorkflow --> ProdEnforcementWorkflow[Production Enforcement Workflow<br/>9 Policies, Deny Mode]
    
    DevTestFullWorkflow --> RemediationWorkflow[Auto-Remediation Workflow<br/>8 Policies, DeployIfNotExists/Modify]
    
    ProdEnforcementWorkflow --> ComplianceWorkflow[Compliance Monitoring Workflow]
    ProdAuditWorkflow --> ComplianceWorkflow
    DevTestFullWorkflow --> ComplianceWorkflow
    
    ProdEnforcementWorkflow --> TestingWorkflow[Testing & Validation Workflow]
    
    ComplianceWorkflow --> End([End: Governance Active])
    TestingWorkflow --> End

    style Start fill:#e1f5e1
    style End fill:#e1f5e1
    style InfraSetup fill:#fff3cd
    style DevTestWorkflow fill:#d1ecf1
    style DevTestFullWorkflow fill:#d1ecf1
    style ProdAuditWorkflow fill:#f8d7da
    style ProdEnforcementWorkflow fill:#f8d7da
    style RemediationWorkflow fill:#d4edda
    style ComplianceWorkflow fill:#cfe2ff
    style TestingWorkflow fill:#e7e7e7
```

---

## Workflow 1: Infrastructure Setup

```mermaid
flowchart LR
    Start([Start Infrastructure Setup]) --> Script[Setup-AzureKeyVaultPolicyEnvironment.ps1]
    
    Script --> |Creates| RG[Resource Group:<br/>rg-policy-remediation]
    Script --> |Creates| MI[Managed Identity:<br/>id-policy-remediation]
    Script --> |Creates| LAW[Log Analytics:<br/>law-policy-test-*]
    Script --> |Creates| EH[Event Hub:<br/>eh-policy-test-*]
    Script --> |Creates| VNET[Virtual Network:<br/>vnet-policy-test]
    Script --> |Creates| DNS[Private DNS Zone:<br/>privatelink.vaultcore.azure.net]
    Script --> |Creates| TestVaults[Test Key Vaults:<br/>kv-compliant-test<br/>kv-non-compliant-test<br/>kv-partial-test]
    
    RG --> Complete([Infrastructure Ready])
    MI --> Complete
    LAW --> Complete
    EH --> Complete
    VNET --> Complete
    DNS --> Complete
    TestVaults --> Complete

    style Start fill:#e1f5e1
    style Complete fill:#e1f5e1
    style Script fill:#fff3cd
    style RG fill:#d4edda
    style MI fill:#d4edda
    style LAW fill:#d4edda
    style EH fill:#d4edda
    style VNET fill:#d4edda
    style DNS fill:#d4edda
    style TestVaults fill:#d4edda
```

**Command**:
```powershell
.\Setup-AzureKeyVaultPolicyEnvironment.ps1 -CreateTestEnvironment
```

**Outputs**:
- Azure resources created (no files)
- Console logs with resource IDs

---

## Workflow 2: DevTest Deployment (30 Policies)

```mermaid
flowchart TD
    Start([Start DevTest Deployment]) --> InputFiles{Input Files}
    
    InputFiles --> Script[AzPolicyImplScript.ps1]
    InputFiles --> ParamFile[PolicyParameters-DevTest.json]
    InputFiles --> DefList[DefinitionListExport.csv]
    InputFiles --> NameMap[PolicyNameMapping.json]
    
    Script --> |Deploys 30 policies| Assign[Policy Assignments<br/>Audit Mode<br/>ResourceGroup Scope]
    ParamFile --> Assign
    DefList --> Assign
    NameMap --> Assign
    
    Assign --> Output1[KeyVaultPolicyImplementationReport-*.json<br/>172 KB, Deployment details]
    Assign --> Output2[PolicyImplementationReport-*.html<br/>21 KB, HTML summary]
    
    Output1 --> Complete([30 Policies Active])
    Output2 --> Complete

    style Start fill:#e1f5e1
    style Complete fill:#e1f5e1
    style Script fill:#d1ecf1
    style ParamFile fill:#cfe2ff
    style DefList fill:#cfe2ff
    style NameMap fill:#cfe2ff
    style Assign fill:#fff3cd
    style Output1 fill:#d4edda
    style Output2 fill:#d4edda
```

**Command**:
```powershell
.\AzPolicyImplScript.ps1 -DeployDevTest -SkipRBACCheck
```

**Outputs**:
- `KeyVaultPolicyImplementationReport-[timestamp].json` (172 KB)
- `PolicyImplementationReport-[timestamp].html` (21 KB)

---

## Workflow 3: DevTest Full Deployment (46 Policies)

```mermaid
flowchart TD
    Start([Start DevTest Full]) --> InputFiles{Input Files}
    
    InputFiles --> Script[AzPolicyImplScript.ps1]
    InputFiles --> ParamFile[PolicyParameters-DevTest-Full.json]
    InputFiles --> DefList[DefinitionListExport.csv]
    InputFiles --> NameMap[PolicyNameMapping.json]
    
    Script --> |Deploys 46 policies| Assign[Policy Assignments<br/>Audit Mode<br/>ResourceGroup Scope]
    ParamFile --> Assign
    DefList --> Assign
    NameMap --> Assign
    
    Assign --> Output1[KeyVaultPolicyImplementationReport-*.json<br/>539 KB, All 46 policies]
    Assign --> Output2[PolicyImplementationReport-*.html<br/>33 KB, HTML summary]
    
    Output1 --> Complete([46 Policies Active<br/>DevTest])
    Output2 --> Complete

    style Start fill:#e1f5e1
    style Complete fill:#e1f5e1
    style Script fill:#d1ecf1
    style ParamFile fill:#cfe2ff
    style DefList fill:#cfe2ff
    style NameMap fill:#cfe2ff
    style Assign fill:#fff3cd
    style Output1 fill:#d4edda
    style Output2 fill:#d4edda
```

**Command**:
```powershell
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -SkipRBACCheck
```

**Outputs**:
- `KeyVaultPolicyImplementationReport-[timestamp].json` (539 KB)
- `PolicyImplementationReport-[timestamp].html` (33 KB)

---

## Workflow 4: Production Audit Deployment (46 Policies)

```mermaid
flowchart TD
    Start([Start Production Audit]) --> InputFiles{Input Files}
    
    InputFiles --> Script[AzPolicyImplScript.ps1]
    InputFiles --> ParamFile[PolicyParameters-Production.json]
    InputFiles --> DefList[DefinitionListExport.csv]
    InputFiles --> NameMap[PolicyNameMapping.json]
    
    Script --> |Deploys 46 policies| Assign[Policy Assignments<br/>Audit Mode<br/>Subscription Scope]
    ParamFile --> Assign
    DefList --> Assign
    NameMap --> Assign
    
    Assign --> Output1[KeyVaultPolicyImplementationReport-*.json<br/>~500 KB, Production data]
    Assign --> Output2[PolicyImplementationReport-*.html<br/>~35 KB, HTML summary]
    
    Output1 --> Complete([46 Policies Active<br/>Production Audit])
    Output2 --> Complete

    style Start fill:#e1f5e1
    style Complete fill:#e1f5e1
    style Script fill:#f8d7da
    style ParamFile fill:#cfe2ff
    style DefList fill:#cfe2ff
    style NameMap fill:#cfe2ff
    style Assign fill:#fff3cd
    style Output1 fill:#d4edda
    style Output2 fill:#d4edda
```

**Command**:
```powershell
.\AzPolicyImplScript.ps1 -DeployProduction -SkipRBACCheck
```

**Outputs**:
- `KeyVaultPolicyImplementationReport-[timestamp].json` (~500 KB)
- `PolicyImplementationReport-[timestamp].html` (~35 KB)

---

## Workflow 5: Production Enforcement (9 Tier 1 Deny Policies)

```mermaid
flowchart TD
    Start([Start Production Enforcement]) --> InputFiles{Input Files}
    
    InputFiles --> Script[AzPolicyImplScript.ps1]
    InputFiles --> ParamFile[PolicyParameters-Tier1-Deny.json]
    InputFiles --> DefList[DefinitionListExport.csv]
    InputFiles --> NameMap[PolicyNameMapping.json]
    
    Script --> |Deploys 9 Deny policies| Assign[Policy Assignments<br/>DENY MODE<br/>Subscription Scope]
    ParamFile --> Assign
    DefList --> Assign
    NameMap --> Assign
    
    Assign --> Output1[KeyVaultPolicyImplementationReport-*.json<br/>172 KB, 9 Deny policies]
    Assign --> Output2[PolicyImplementationReport-*.html<br/>21 KB, Enforcement summary]
    
    Output1 --> Complete([9 Deny Policies BLOCKING<br/>Non-Compliant Operations])
    Output2 --> Complete

    style Start fill:#e1f5e1
    style Complete fill:#f8d7da
    style Script fill:#f8d7da
    style ParamFile fill:#cfe2ff
    style DefList fill:#cfe2ff
    style NameMap fill:#cfe2ff
    style Assign fill:#fff3cd
    style Output1 fill:#d4edda
    style Output2 fill:#d4edda
```

**Command**:
```powershell
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Tier1-Deny.json -SkipRBACCheck
```

**Outputs**:
- `KeyVaultPolicyImplementationReport-[timestamp].json` (172 KB)
- `PolicyImplementationReport-[timestamp].html` (21 KB)

---

## Workflow 6: Auto-Remediation (8 Policies)

```mermaid
flowchart TD
    Start([Start Auto-Remediation]) --> InputFiles{Input Files}
    
    InputFiles --> Script[AzPolicyImplScript.ps1]
    InputFiles --> ParamFile[PolicyParameters-DevTest-Full-Remediation.json]
    InputFiles --> DefList[DefinitionListExport.csv]
    InputFiles --> NameMap[PolicyNameMapping.json]
    InputFiles --> MI[Managed Identity:<br/>id-policy-remediation]
    
    Script --> |Deploys 8 remediation policies| Assign[Policy Assignments<br/>DeployIfNotExists/Modify<br/>With Managed Identity]
    ParamFile --> Assign
    DefList --> Assign
    NameMap --> Assign
    MI --> Assign
    
    Assign --> |Wait 30-60 min| Evaluate[Azure Policy Evaluation<br/>Creates Remediation Tasks]
    
    Evaluate --> Output1[KeyVaultPolicyImplementationReport-*.json<br/>Remediation details]
    Evaluate --> Output2[PolicyImplementationReport-*.html<br/>Task status]
    Evaluate --> Output3[RemediationTaskResults-*.json<br/>Success/Failure data]
    
    Output1 --> Complete([8 Remediation Policies<br/>Auto-Fixing Non-Compliant Resources])
    Output2 --> Complete
    Output3 --> Complete

    style Start fill:#e1f5e1
    style Complete fill:#d4edda
    style Script fill:#d4edda
    style ParamFile fill:#cfe2ff
    style DefList fill:#cfe2ff
    style NameMap fill:#cfe2ff
    style MI fill:#fff3cd
    style Assign fill:#fff3cd
    style Evaluate fill:#fff3cd
    style Output1 fill:#d4edda
    style Output2 fill:#d4edda
    style Output3 fill:#d4edda
```

**Commands**:
```powershell
# Deploy remediation policies
.\AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json `
    -IdentityResourceId "/subscriptions/.../id-policy-remediation" -SkipRBACCheck

# Test auto-remediation (creates test vault, waits for policy evaluation)
.\AzPolicyImplScript.ps1 -TestAutoRemediation -SkipRBACCheck
```

**Outputs**:
- `KeyVaultPolicyImplementationReport-[timestamp].json` (remediation details)
- `PolicyImplementationReport-[timestamp].html` (task status)
- `RemediationTaskResults-[timestamp].json` (success/failure data)

---

## Workflow 7: Compliance Monitoring

```mermaid
flowchart TD
    Start([Start Compliance Check]) --> Script[AzPolicyImplScript.ps1<br/>-CheckCompliance]
    
    Script --> |Optional| Trigger[Trigger Policy Scan<br/>-TriggerScan flag]
    Script --> |Wait 15-30 min| Scan[Azure Policy Evaluation]
    Trigger --> Scan
    
    Scan --> Collect[Collect Compliance Data<br/>Get-AzPolicyState]
    
    Collect --> Output1[ComplianceReport-*.html<br/>54 KB, Visual dashboard]
    Collect --> Output2[ComplianceData-*.json<br/>Detailed compliance state]
    Collect --> Output3[ComplianceSummary-*.csv<br/>Excel-friendly summary]
    
    Output1 --> Complete([Compliance Data Available])
    Output2 --> Complete
    Output3 --> Complete

    style Start fill:#e1f5e1
    style Complete fill:#e1f5e1
    style Script fill:#cfe2ff
    style Trigger fill:#fff3cd
    style Scan fill:#fff3cd
    style Collect fill:#fff3cd
    style Output1 fill:#d4edda
    style Output2 fill:#d4edda
    style Output3 fill:#d4edda
```

**Commands**:
```powershell
# Check compliance (uses cached data)
.\AzPolicyImplScript.ps1 -CheckCompliance -SkipRBACCheck

# Check compliance with fresh scan (triggers Azure Policy evaluation)
.\AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck
```

**Outputs**:
- `ComplianceReport-[timestamp].html` (54 KB, visual dashboard)
- `ComplianceData-[timestamp].json` (detailed state)
- `ComplianceSummary-[timestamp].csv` (Excel-friendly)

---

## Workflow 8: Testing & Validation

```mermaid
flowchart TD
    Start([Start Testing]) --> Choice{Test Type?}
    
    Choice --> |Infrastructure| InfraTest[Test-Infrastructure<br/>11 validation checks]
    Choice --> |Enforcement| EnforceTest[Test-ProductionEnforcement<br/>9 blocking tests]
    Choice --> |Auto-Remediation| RemediateTest[Test-AutoRemediation<br/>Create vault, wait for fix]
    
    InfraTest --> Output1[Console output:<br/>✅ PASS/❌ FAIL per check]
    EnforceTest --> Output2[EnforcementValidation-*.csv<br/>1 KB, 9 test results]
    RemediateTest --> Output3[RemediationResults-*.json<br/>Task success/failure]
    
    Output1 --> Complete([Testing Complete])
    Output2 --> Complete
    Output3 --> Complete

    style Start fill:#e1f5e1
    style Complete fill:#e1f5e1
    style InfraTest fill:#e7e7e7
    style EnforceTest fill:#e7e7e7
    style RemediateTest fill:#e7e7e7
    style Output1 fill:#d4edda
    style Output2 fill:#d4edda
    style Output3 fill:#d4edda
```

**Commands**:
```powershell
# Test infrastructure (11 checks: managed identity, Log Analytics, Event Hub, VNet, etc.)
.\AzPolicyImplScript.ps1 -TestInfrastructure -Detailed -SkipRBACCheck

# Test enforcement blocking (9 tests: soft delete, purge protection, firewall, RBAC, keys, secrets, certificates)
.\AzPolicyImplScript.ps1 -TestProductionEnforcement -SkipRBACCheck

# Test auto-remediation (creates non-compliant vault, waits for Azure Policy to fix it)
.\AzPolicyImplScript.ps1 -TestAutoRemediation -SkipRBACCheck
```

**Outputs**:
- Infrastructure: Console output (11 validation checks)
- Enforcement: `EnforcementValidation-[timestamp].csv` (9 test results)
- Remediation: `RemediationResults-[timestamp].json` (task details)

---

## Complete File Dependency Map

```mermaid
flowchart LR
    subgraph Inputs
        Script1[AzPolicyImplScript.ps1<br/>Main Script]
        Script2[Setup-AzureKeyVaultPolicyEnvironment.ps1<br/>Infrastructure Script]
        
        Param1[PolicyParameters-DevTest.json<br/>30 policies, Audit]
        Param2[PolicyParameters-DevTest-Full.json<br/>46 policies, Audit]
        Param3[PolicyParameters-Production.json<br/>46 policies, Audit]
        Param4[PolicyParameters-Tier1-Deny.json<br/>9 policies, Deny]
        Param5[PolicyParameters-DevTest-Full-Remediation.json<br/>8 policies, Remediation]
        
        Ref1[DefinitionListExport.csv<br/>46 policy definitions]
        Ref2[PolicyNameMapping.json<br/>Display name → ID mapping]
    end
    
    subgraph Outputs
        HTML1[PolicyImplementationReport-*.html<br/>Deployment summary]
        HTML2[ComplianceReport-*.html<br/>Compliance dashboard]
        
        JSON1[KeyVaultPolicyImplementationReport-*.json<br/>Detailed deployment data]
        JSON2[ComplianceData-*.json<br/>Compliance state]
        JSON3[RemediationResults-*.json<br/>Remediation task status]
        
        CSV1[EnforcementValidation-*.csv<br/>9 blocking tests]
        CSV2[ComplianceSummary-*.csv<br/>Excel-friendly summary]
        CSV3[HTMLValidation-*.csv<br/>HTML structure validation]
    end
    
    Script1 --> HTML1
    Script1 --> HTML2
    Script1 --> JSON1
    Script1 --> JSON2
    Script1 --> JSON3
    Script1 --> CSV1
    Script1 --> CSV2
    Script1 --> CSV3
    
    Param1 --> Script1
    Param2 --> Script1
    Param3 --> Script1
    Param4 --> Script1
    Param5 --> Script1
    
    Ref1 --> Script1
    Ref2 --> Script1

    style Script1 fill:#d1ecf1
    style Script2 fill:#fff3cd
    style HTML1 fill:#d4edda
    style HTML2 fill:#d4edda
    style JSON1 fill:#d4edda
    style JSON2 fill:#d4edda
    style JSON3 fill:#d4edda
    style CSV1 fill:#d4edda
    style CSV2 fill:#d4edda
    style CSV3 fill:#d4edda
```

---

## Phased Deployment Timeline

```mermaid
gantt
    title Azure Key Vault Policy Governance - Deployment Timeline
    dateFormat YYYY-MM-DD
    section Phase 1
    Infrastructure Setup           :done, infra, 2026-01-14, 1d
    section Phase 2
    DevTest (30 policies)          :done, dev1, 2026-01-14, 1d
    DevTest Full (46 policies)     :done, dev2, 2026-01-15, 1d
    Auto-Remediation Testing       :done, remed, 2026-01-15, 1d
    section Phase 3
    Production Audit (46 policies) :done, prod1, 2026-01-15, 1d
    Compliance Monitoring (30 days):active, comp, 2026-01-15, 30d
    section Phase 4
    Tier 1 Deny (9 policies)       :done, tier1, 2026-01-16, 1d
    Enforcement Testing            :done, test, 2026-01-16, 1d
    section Phase 5
    HTML Validation                :done, html, 2026-01-16, 1d
    Final Documentation            :done, docs, 2026-01-16, 1d
```

---

## Quick Reference Table

| Workflow | Parameter File | Policies | Mode | Scope | Command | Key Outputs |
|----------|---------------|----------|------|-------|---------|-------------|
| **Infrastructure** | N/A | 0 | N/A | Subscription | `Setup-AzureKeyVaultPolicyEnvironment.ps1 -CreateTestEnvironment` | Azure resources |
| **DevTest (30)** | PolicyParameters-DevTest.json | 30 | Audit | ResourceGroup | `AzPolicyImplScript.ps1 -DeployDevTest -SkipRBACCheck` | Implementation JSON/HTML |
| **DevTest Full (46)** | PolicyParameters-DevTest-Full.json | 46 | Audit | ResourceGroup | `AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full.json -SkipRBACCheck` | Implementation JSON/HTML |
| **Production Audit** | PolicyParameters-Production.json | 46 | Audit | Subscription | `AzPolicyImplScript.ps1 -DeployProduction -SkipRBACCheck` | Implementation JSON/HTML |
| **Tier 1 Deny** | PolicyParameters-Tier1-Deny.json | 9 | **Deny** | Subscription | `AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-Tier1-Deny.json -SkipRBACCheck` | Implementation JSON/HTML |
| **Auto-Remediation** | PolicyParameters-DevTest-Full-Remediation.json | 8 | DeployIfNotExists/Modify | ResourceGroup | `AzPolicyImplScript.ps1 -ParameterFile .\PolicyParameters-DevTest-Full-Remediation.json -IdentityResourceId "..." -SkipRBACCheck` | Remediation JSON |
| **Compliance Check** | N/A | All active | All | All | `AzPolicyImplScript.ps1 -CheckCompliance -TriggerScan -SkipRBACCheck` | Compliance HTML/JSON/CSV |
| **Test Infrastructure** | N/A | N/A | N/A | N/A | `AzPolicyImplScript.ps1 -TestInfrastructure -Detailed -SkipRBACCheck` | Console output |
| **Test Enforcement** | N/A | 9 | Deny | Subscription | `AzPolicyImplScript.ps1 -TestProductionEnforcement -SkipRBACCheck` | EnforcementValidation CSV |
| **Test Remediation** | N/A | 8 | DeployIfNotExists/Modify | ResourceGroup | `AzPolicyImplScript.ps1 -TestAutoRemediation -SkipRBACCheck` | Remediation JSON |

---

## Output File Legend

| File Pattern | Size | Content | Use Case |
|-------------|------|---------|----------|
| **PolicyImplementationReport-[timestamp].html** | 21-35 KB | HTML summary of policy deployment with success/failure counts | Quick visual review of deployment |
| **KeyVaultPolicyImplementationReport-[timestamp].json** | 172-539 KB | Complete JSON data: all policies, parameters, assignment IDs, timestamps | Programmatic analysis, audit trail |
| **ComplianceReport-[timestamp].html** | 54-97 KB | Visual compliance dashboard with charts, policy breakdowns, security metrics | Executive reporting, compliance review |
| **ComplianceData-[timestamp].json** | Varies | Detailed compliance state for every resource evaluated by Azure Policy | Deep analysis, troubleshooting |
| **ComplianceSummary-[timestamp].csv** | Small | Excel-friendly summary of compliance percentages | Spreadsheet analysis |
| **EnforcementValidation-[timestamp].csv** | 1 KB | 9 test results: Test ID, Policy, Operation, Expected Result, Actual Result, Status | Validation that Deny policies block correctly |
| **HTMLValidation-[timestamp].csv** | <1 KB | HTML structure validation results for compliance reports | Quality assurance |
| **IndividualPolicyValidation-[timestamp].txt** | 3 KB | Detailed test logs for each of 9 Deny policies | Troubleshooting test failures |
| **RemediationResults-[timestamp].json** | Varies | Auto-remediation task status: task ID, success/failure, resource fixed | Monitor automated fixes |

---

**Last Updated**: 2026-01-16  
**Version**: 1.0  
**Repository**: powershell-akv-policyhardening
