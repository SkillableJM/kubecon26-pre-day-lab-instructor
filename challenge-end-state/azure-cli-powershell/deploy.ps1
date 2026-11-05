<#
.SYNOPSIS
    KubeCon AKS capture-the-flag lab - deploy the END state with the Azure CLI (PowerShell).

.DESCRIPTION
    Creates (or reuses) an AKS Automatic cluster plus the Azure services the selected
    challenges need, then deploys each challenge in its solved state (the result of
    the expected repair). What "solved" looks like: ../challenges/<id>-*/README.md
    It uses the shared PowerShell module of the lab repository (kubecon26-pre-day-lab), cloned next to this
    repository by default.

.EXAMPLE
    ./deploy.ps1                                  # all challenges in westus3
.EXAMPLE
    ./deploy.ps1 -Challenges c1,c3 -Location centralus
.EXAMPLE
    ./deploy.ps1 -ResourceGroup rg-kubecon-ctf-begin-pwsh   # solve a begin-state environment in place
#>
#Requires -Version 7.4
[CmdletBinding()]
param(
    # Challenge IDs (c1 c2 c3 c4 a1 a2 a3 a4 a5 a6) or 'all'.
    [string[]]$Challenges = $(if ($env:CHALLENGES) { $env:CHALLENGES } else { 'all' }),
    # Default: the resource group's region when it exists, otherwise westus3.
    [string]$Location = $env:LOCATION,
    [string]$ResourceGroup = $(if ($env:RESOURCE_GROUP) { $env:RESOURCE_GROUP } else { 'rg-kubecon-ctf-end-pwsh' }),
    # Defaults to aks-<resource group without the rg- prefix>.
    [string]$ClusterName = $env:CLUSTER_NAME,
    # Delete and re-create the selected challenges first (default: apply the solved state on top).
    [switch]$Reset,
    # Do not create or update Azure resources; only (re)apply the challenges.
    [switch]$SkipInfra,
    # C4 model settings.
    [string]$ModelName = $(if ($env:AOAI_MODEL_NAME) { $env:AOAI_MODEL_NAME } else { 'gpt-6-luna' }),
    [string]$ModelVersion = $(if ($env:AOAI_MODEL_VERSION) { $env:AOAI_MODEL_VERSION } else { '2026-09-22' }),
    [string]$DeploymentName = $(if ($env:AOAI_DEPLOYMENT_NAME) { $env:AOAI_DEPLOYMENT_NAME } else { 'store-assistant' }),
    [int]$ModelCapacity = $(if ($env:AOAI_CAPACITY) { [int]$env:AOAI_CAPACITY } else { 50 }),
    # The Foundry account's region. Default: the region, if it offers the model as Global Standard; otherwise the
    # first of westus3, eastus2, and swedencentral that does.
    [string]$AoaiLocation = $env:AOAI_LOCATION,
    # The lab repository (default: CTF_LAB_REPO, or ../../../kubecon26-pre-day-lab from this folder).
    [string]$LabRepo = $env:CTF_LAB_REPO
)$ErrorActionPreference = 'Stop'
# The lab repository's shared PowerShell module: -LabRepo, CTF_LAB_REPO, or a clone next to this repository.
if (-not $LabRepo) { $LabRepo = Join-Path $PSScriptRoot '../../../kubecon26-pre-day-lab' }
$module = Join-Path $LabRepo 'shared/azure-cli-powershell/CtfLab.psm1'
if (-not (Test-Path -LiteralPath $module)) {
    throw "The lab repository isn't in $LabRepo. Clone https://github.com/bbenz/kubecon26-pre-day-lab next to this repository, or pass -LabRepo."
}
$repoRoot = Resolve-Path $LabRepo
Import-Module $module -Force

# Apply the solved configuration on top of whatever is there (use -Reset for a clean re-create).
Initialize-CtfLab -State end -RepoRoot $repoRoot -StateDir (Join-Path $PSScriptRoot '..') -ResourceGroup $ResourceGroup -Challenges $Challenges `
    -Location $Location -ClusterName $ClusterName -Reset $Reset.IsPresent -SkipInfra $SkipInfra.IsPresent `
    -ModelName $ModelName -ModelVersion $ModelVersion -DeploymentName $DeploymentName `
    -ModelCapacity $ModelCapacity -AoaiLocation $AoaiLocation
Test-CtfPrerequisites

# Shared platform
New-CtfResourceGroup
Grant-CtfClusterAdmin   # before the cluster exists, so RBAC has propagated when it is ready
Install-CtfCluster
Get-CtfCredentials

# Azure services needed by individual challenges
Enable-CtfAppRouting   # C2: application routing add-on - managed NGINX + Gateway API (approuting-istio)
Enable-CtfPrometheus   # A2: Managed Prometheus for the Grafana dashboards
Install-CtfC4Azure     # C4: Foundry model deployment + ai-service workload identity
Install-CtfA4Azure     # A4: Key Vault + identity; federated subject from challenges/a4-*/azure.env

# Kubernetes objects for each challenge
foreach ($id in (Get-CtfLabSettings).Challenges) { Install-CtfChallenge $id }

Write-CtfSummary
