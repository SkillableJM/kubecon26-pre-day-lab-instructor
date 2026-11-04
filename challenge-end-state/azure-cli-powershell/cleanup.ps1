<#
.SYNOPSIS
    KubeCon AKS capture-the-flag lab - delete an END-state environment.

.DESCRIPTION
    Deletes the resource group created by deploy.ps1 (AKS cluster, Foundry account,
    Key Vault, identities), purges the soft-deleted Key Vault and Foundry account so
    the names can be reused, and removes the kubectl context.

.EXAMPLE
    ./cleanup.ps1                 # asks for confirmation
.EXAMPLE
    ./cleanup.ps1 -ResourceGroup my-rg -Confirm:$false
#>
#Requires -Version 7.4
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string]$ResourceGroup = $(if ($env:RESOURCE_GROUP) { $env:RESOURCE_GROUP } else { 'rg-kubecon-ctf-end-pwsh' }),
    [string]$ClusterName = $env:CLUSTER_NAME,
    # Start the deletion and return (skips purging soft-deleted resources).
    [switch]$NoWait,
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

if ($PSCmdlet.ShouldProcess($ResourceGroup, 'Delete the lab resource group and everything in it')) {
    Remove-CtfLab -ResourceGroup $ResourceGroup -ClusterName $ClusterName -RepoRoot $repoRoot -NoWait:$NoWait -Confirm:$false
}