#!/usr/bin/env pwsh
# This script destroys Azure infrastructure created by Invoke-AzureProvisioning.ps1.
# WARNING: This action CANNOT be undone. Resources will be permanently deleted.

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Enable strict error handling
$ErrorActionPreference = 'Stop'

Write-Host "`n==================================================" -ForegroundColor DarkGray
Write-Host "           AZURE INFRASTRUCTURE CLEANUP          " -ForegroundColor Red
Write-Host "==================================================`n" -ForegroundColor DarkGray

Write-Host 'WARNING: This will permanently delete all resources in the resource group!' -ForegroundColor Yellow
Write-Host "Resource Group: $ResourceGroupName`n" -ForegroundColor Red

if (-not $Force) {
    $confirm = Read-Host 'Type ""$ResourceGroupName"" to confirm and proceed with deletion'
    if ($confirm -ne $ResourceGroupName) {
        Write-Host 'Deletion cancelled.' -ForegroundColor Yellow
        exit 0
    }
}

Write-Section 'Starting cleanup...'

# Verify resource group exists
try {
    $rgExists = az group exists --name $ResourceGroupName
    if (-not $rgExists) {
        Write-Host "Resource group '$ResourceGroupName' does not exist. Nothing to clean up." -ForegroundColor Green
        exit 0
    }
} catch {
    Write-Error "Failed to check resource group status: $($_.Exception.Message)"
    exit 1
}

# Get list of resources
Write-Host 'Listing resources...' -ForegroundColor Gray
$resources = az resource list --resource-group $ResourceGroupName --query '[].{Name:name, Type:type, ResourceGroup:resourceGroup}' --output table

if ($resources) {
    Write-Host "Found $($resources.Count) resources to delete:" -ForegroundColor Yellow
    Write-Host $resources
} else {
    Write-Host 'No resources found in resource group.' -ForegroundColor Green
}

# Confirm before deletion
if (-not $Force) {
    $confirm = Read-Host "`nType 'DELETE' to confirm permanent deletion"
    if ($confirm -ne 'DELETE') {
        Write-Host 'Deletion cancelled.' -ForegroundColor Yellow
        exit 0
    }
}

# Delete resource group with async operation
Write-Section 'Deleting resource group...'

try {
    az group delete `
        --name $ResourceGroupName `
        --yes `
        --no-wait `
        --output none

    Write-Host "`nDeletion initiated asynchronously." -ForegroundColor Green
    Write-Host "You can track progress with: az group delete --name $ResourceGroupName --yes (remove --no-wait)" -ForegroundColor Gray
} catch {
    Write-Error "Failed to initiate deletion: $($_.Exception.Message)"
    exit 1
}

Write-Host "`n==================================================" -ForegroundColor DarkGray
Write-Host 'Cleanup initiated successfully.' -ForegroundColor Green
Write-Host '==================================================`n' -ForegroundColor DarkGray
