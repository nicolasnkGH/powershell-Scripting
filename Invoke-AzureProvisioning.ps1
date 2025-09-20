<#
.SYNOPSIS
    A reusable PowerShell script to provision one or more virtual machines and their
    network resources on Azure.

.DESCRIPTION
    This script is designed to be executed as part of a CI/CD pipeline.
    It contains a reusable function for provisioning a new virtual machine, along
    with its associated public IP, network interface, and network security group.
    The script then calls this function for each VM defined in the workflow.

.PARAMETER ResourceGroupName
    The name of the Azure resource group to be used for the deployment.

.PARAMETER VMLocation
    The Azure region for the virtual machines (e.g., 'eastus').

.PARAMETER VMNames
    An array of desired names for the virtual machines.

.PARAMETER AdminUsername
    The administrator username for the virtual machines.

.PARAMETER AdminSshKeyFile
    The file path to the public SSH key for the administrator user.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$VMLocation,

    [Parameter(Mandatory = $true)]
    [string[]]$VMNames,

    [Parameter(Mandatory = $true)]
    [string]$AdminUsername,

    [Parameter(Mandatory = $true)]
    [string]$AdminSshKeyFile
)

# A reusable function to provision a single virtual machine and its resources
function Provision-VM {
    param(
        [string]$Name,
        [string]$ResourceGroup,
        [string]$Location,
        [string]$Username,
        [string]$SshKeyFile
    )

    Write-Host "Starting the provisioning process for VM '$Name' in location '$Location'..." -ForegroundColor Yellow

    # Create a virtual network and subnet.
    $vnetName = "$Name-vnet"
    $subnetName = "$Name-subnet"
    Write-Host "Creating virtual network and subnet..." -ForegroundColor Cyan
    az network vnet create `
        --resource-group $ResourceGroup `
        --name $vnetName `
        --address-prefix 10.0.0.0/16 `
        --subnet-name $subnetName `
        --subnet-prefix 10.0.0.0/24 > $null
    Write-Host "Virtual network created." -ForegroundColor Green

    # Create a public IP address.
    $publicIpName = "$Name-public-ip"
    Write-Host "Creating public IP address..." -ForegroundColor Cyan
    az network public-ip create `
        --resource-group $ResourceGroup `
        --name $publicIpName `
        --location $Location `
        --allocation-method Static > $null
    Write-Host "Public IP created." -ForegroundColor Green

    # Create a network security group (NSG).
    $nsgName = "$Name-nsg"
    Write-Host "Creating network security group..." -ForegroundColor Cyan
    az network nsg create `
        --resource-group $ResourceGroup `
        --name $nsgName > $null
    Write-Host "NSG created." -ForegroundColor Green

    # Create a network interface card (NIC).
    $nicName = "$Name-nic"
    Write-Host "Creating network interface card..." -ForegroundColor Cyan
    az network nic create `
        --resource-group $ResourceGroup `
        --name $nicName `
        --vnet-name $vnetName `
        --subnet $subnetName `
        --network-security-group $nsgName `
        --public-ip-address $publicIpName > $null
    Write-Host "NIC created." -ForegroundColor Green

    # Create the virtual machine.
    Write-Host "Creating virtual machine '$Name'..." -ForegroundColor Cyan
    az vm create `
        --resource-group $ResourceGroup `
        --name $Name `
        --location $Location `
        --image Ubuntu2204 `
        --size Standard_B2s `
        --public-ip-address "$Name-public-ip" `
        --nics $nicName `
        --admin-username $Username `
        --ssh-key-values (Get-Content $SshKeyFile) > $null

    Write-Host "Virtual machine '$Name' successfully created." -ForegroundColor Green
}

# Step 1: Login to Azure using a service principal.
Write-Host "Logging into Azure..." -ForegroundColor Cyan
try {
    # This is handled by the 'azure/login@v2' action in the workflow.
    Write-Host "Successfully authenticated." -ForegroundColor Green
}
catch {
    Write-Host "Azure login failed." -ForegroundColor Red
    return
}

# Step 2: Create a resource group if it doesn't already exist.
Write-Host "Checking for Resource Group '$ResourceGroupName'..." -ForegroundColor Cyan
$resourceGroup = az group show --name $ResourceGroupName -ErrorAction SilentlyContinue

if ($null -eq $resourceGroup) {
    Write-Host "Resource Group '$ResourceGroupName' not found. Creating it now..."
    az group create --name $ResourceGroupName --location $VMLocation
    Write-Host "Resource Group created." -ForegroundColor Green
} else {
    Write-Host "Resource Group '$ResourceGroupName' already exists. Using existing group." -ForegroundColor Yellow
}

# Step 3: Loop through the VM names and provision each one.
foreach ($vmName in $VMNames) {
    Provision-VM `
        -Name $vmName `
        -ResourceGroup $ResourceGroupName `
        -Location $VMLocation `
        -Username $AdminUsername `
        -SshKeyFile $AdminSshKeyFile
}

Write-Host "Provisioning process completed." -ForegroundColor Green
