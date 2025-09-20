<#
.SYNOPSIS
    Deletes an Azure Resource Group and all of its resources.

.DESCRIPTION
    This script connects to an Azure account, checks for the existence of a specified
    resource group, and if it exists, it permanently removes the resource group and all
    associated resources, such as virtual machines and networks.

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group to delete.

.EXAMPLE
    ./Destroy-AzureResources.ps1 -ResourceGroupName "my-test-rg"
    This will delete the resource group named "my-test-rg".
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [switch]$Force
)

Write-Host "Checking for the existence of resource group '$ResourceGroupName'..." -ForegroundColor Yellow

# Use the az group show command to check for the resource group's existence
try {
    az group show --name $ResourceGroupName -o json -o json | Out-Null
}
catch {
    Write-Host "Resource group '$ResourceGroupName' not found. Nothing to do." -ForegroundColor Green
    return
}

# Prompt for confirmation to avoid accidental deletion unless the -Force parameter is used.
if (-not $Force) {
    Write-Host "WARNING: This will permanently delete the resource group '$ResourceGroupName' and all its contents." -ForegroundColor Red
    Write-Host "Are you sure you want to proceed? (Y/N)" -ForegroundColor Red

    $confirm = Read-Host

    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-Host "Deletion canceled." -ForegroundColor Cyan
        return
    }
}

Write-Host "Deleting resource group '$ResourceGroupName'..." -ForegroundColor Yellow
try {
    # The -Force parameter is used to suppress the confirmation prompt in non-interactive sessions
    # such as a GitHub Actions runner.
    Remove-AzResourceGroup -Name $ResourceGroupName -Force -ErrorAction Stop
    Write-Host "Resource group '$ResourceGroupName' has been successfully deleted." -ForegroundColor Green
}
catch {
    Write-Host "An error occurred during deletion of resource group '$ResourceGroupName'." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
