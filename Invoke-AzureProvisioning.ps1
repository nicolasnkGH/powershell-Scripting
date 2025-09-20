<#
.SYNOPSIS
    Provisions a set of Azure Virtual Machines and their associated networking resources.

.DESCRIPTION
    This script automates the provisioning of Azure infrastructure, including a
    resource group, virtual network, public IP, network security group, and virtual
    machines. It is designed to be run from a pipeline or a CI/CD environment.

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group to create.

.PARAMETER VMLocation
    The Azure region where the resources will be provisioned.

.PARAMETER AdminUsername
    The username for the virtual machines' administrator account.

.PARAMETER AdminSshKeyFile
    The path to the SSH public key file to be used for authentication.

.PARAMETER VMNames
    A comma-separated list of virtual machine names to provision.

.EXAMPLE
    ./Invoke-AzureProvisioning.ps1 `
        -ResourceGroupName "my-test-rg" `
        -VMLocation "eastus" `
        -AdminUsername "myuser" `
        -AdminSshKeyFile "C:\users\myuser\.ssh\id_rsa.pub" `
        -VMNames "vm1","vm2"
    This example provisions a new resource group and two VMs.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$VMLocation,

    [Parameter(Mandatory = $true)]
    [string]$AdminUsername,

    [Parameter(Mandatory = $true)]
    [string]$AdminSshKeyFile,

    [Parameter(Mandatory = $true)]
    [string[]]$VMNames
)

Write-Host "Starting the provisioning process..." -ForegroundColor Yellow

# Check if the resource group exists and create it if not
Write-Host "Checking for Resource Group '$ResourceGroupName'..." -ForegroundColor Yellow
try {
    az group show --resource-group $ResourceGroupName
}
catch {
    Write-Host "Resource Group '$ResourceGroupName' not found. Creating it now..." -ForegroundColor Cyan
    try {
        az group create --name $ResourceGroupName --location $VMLocation
        Write-Host "Resource Group created." -ForegroundColor Green
    }
    catch {
        Write-Host "An error occurred while creating the resource group." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
}

# Loop through each VM name and provision the necessary resources
foreach ($vmName in $VMNames) {
    Write-Host "Starting the provisioning process for VM '$vmName' in location '$VMLocation'..." -ForegroundColor Yellow

    try {
        # Create virtual network and subnet
        Write-Host "Creating virtual network and subnet..." -ForegroundColor Yellow
        az network vnet create --resource-group $ResourceGroupName `
            --name "$vmName-vnet" `
            --address-prefix 10.0.0.0/16 `
            --subnet-name "$vmName-subnet" `
            --subnet-prefix 10.0.0.0/24 > $null

        # Create public IP address
        Write-Host "Creating public IP address..." -ForegroundColor Yellow
        $ip = az network public-ip create --resource-group $ResourceGroupName `
            --name "$vmName-public-ip" `
            --allocation-method Static `
            --dns-name "$vmName" `
            --sku Standard --query publicIp.ipAddress `
            -o tsv > $null

        # Create network security group
        Write-Host "Creating network security group..." -ForegroundColor Yellow
        az network nsg create --resource-group $ResourceGroupName `
            --name "$vmName-nsg" > $null

        # Create inbound rule for SSH
        Write-Host "Creating network interface card..." -ForegroundColor Yellow
        az network nsg rule create --resource-group $ResourceGroupName `
            --name "Allow-SSH" `
            --nsg-name "$vmName-nsg" `
            --priority 1000 `
            --protocol tcp `
            --destination-port-ranges 22 > $null

        # Create network interface card
        Write-Host "Creating network interface card..." -ForegroundColor Yellow
        az network nic create --resource-group $ResourceGroupName `
            --name "$vmName-nic" `
            --vnet-name "$vmName-vnet" `
            --subnet "$vmName-subnet" `
            --network-security-group "$vmName-nsg" `
            --public-ip-address "$vmName-public-ip" > $null

        # Create virtual machine
        Write-Host "Creating virtual machine '$vmName'..." -ForegroundColor Yellow
        az vm create --resource-group $ResourceGroupName `
            --name $vmName `
            --location $VMLocation `
            --image Ubuntu2204 `
            --size Standard_B1s `
            --admin-username $AdminUsername `
            --nics "$vmName-nic" `
            --ssh-key-values (Get-Content $AdminSshKeyFile) > $null
        
        Write-Host "VM '$vmName' provisioned successfully." -ForegroundColor Green

    }
    catch {
        Write-Host "An error occurred during provisioning of VM '$vmName'." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
}

Write-Host "All virtual machines have been successfully provisioned." -ForegroundColor Green
