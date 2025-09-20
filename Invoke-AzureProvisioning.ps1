# This script provisions Azure virtual machines using the Azure CLI.
# It is designed to be run as part of a GitHub Actions workflow.

param (
    [string]$resourceGroupName,
    [string]$location,
    [string]$vmPiholeName,
    [string]$vmDynatraceName,
    [string]$username,
    [string]$sshKeyContent
)

Write-Host "Starting Azure provisioning process..."

# Define the common VM size and image
$vmSize = "Standard_B2s"
$vmImage = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"

# Create a resource group if it doesn't exist
Write-Host "Checking for Resource Group '$resourceGroupName'..."
az group create --name $resourceGroupName --location $location

# --- Provision the Pi-hole VM and NSG ---
Write-Host "Creating Pi-hole Network Security Group..."
az network nsg create `
    --resource-group $resourceGroupName `
    --name "pihole-nsg" `
    --location $location

Write-Host "Provisioning Pi-hole VM '$vmPiholeName'..."
az vm create `
    --resource-group $resourceGroupName `
    --name $vmPiholeName `
    --location $location `
    --image $vmImage `
    --size $vmSize `
    --admin-username $username `
    --ssh-key-value $sshKeyContent `
    --public-ip-sku Standard `
    --nsg "pihole-nsg" `
    --tags project="pihole"

Write-Host "Provisioned Pi-hole VM."

# Add required Network Security Group rules for Pi-hole
az network nsg rule create `
    --resource-group $resourceGroupName `
    --nsg-name "pihole-nsg" `
    --name "allow-dns-tcp" `
    --priority 100 `
    --direction Inbound `
    --access Allow `
    --protocol Tcp `
    --source-address-prefixes "*" `
    --source-port-ranges "*" `
    --destination-address-prefixes "*" `
    --destination-port-ranges 53

az network nsg rule create `
    --resource-group $resourceGroupName `
    --nsg-name "pihole-nsg" `
    --name "allow-dns-udp" `
    --priority 101 `
    --direction Inbound `
    --access Allow `
    --protocol Udp `
    --source-address-prefixes "*" `
    --source-port-ranges "*" `
    --destination-address-prefixes "*" `
    --destination-port-ranges 53

az network nsg rule create `
    --resource-group $resourceGroupName `
    --nsg-name "pihole-nsg" `
    --name "allow-http" `
    --priority 102 `
    --direction Inbound `
    --access Allow `
    --protocol Tcp `
    --source-address-prefixes "*" `
    --source-port-ranges "*" `
    --destination-address-prefixes "*" `
    --destination-port-ranges 80

az network nsg rule create `
    --resource-group $resourceGroupName `
    --nsg-name "pihole-nsg" `
    --name "allow-ssh" `
    --priority 103 `
    --direction Inbound `
    --access Allow `
    --protocol Tcp `
    --source-address-prefixes "*" `
    --source-port-ranges "*" `
    --destination-address-prefixes "*" `
    --destination-port-ranges 22

# --- Provision the Dynatrace VM and NSG ---
# Note: For this PoC, we will use the default OS disk. However, for best practices
# and production environments, it's recommended to provision a separate data disk for logs
# and other application data.
# The NSG must be created before the VM.
Write-Host "Creating Dynatrace Network Security Group..."
az network nsg create `
    --resource-group $resourceGroupName `
    --name "dynatrace-nsg" `
    --location $location

Write-Host "Provisioning Dynatrace VM '$vmDynatraceName'..."
az vm create `
    --resource-group $resourceGroupName `
    --name $vmDynatraceName `
    --location $location `
    --image $vmImage `
    --size $vmSize `
    --os-disk-size-gb 100 `
    --admin-username $username `
    --ssh-key-value $sshKeyContent `
    --public-ip-sku Standard `
    --nsg "dynatrace-nsg" `
    --tags project="dynatrace"

Write-Host "Provisioned Dynatrace VM."

# Add required Network Security Group rules for Dynatrace ActiveGate
# Dynatrace ActiveGate uses port 9999 for incoming connections
az network nsg rule create `
    --resource-group $resourceGroupName `
    --nsg-name "dynatrace-nsg" `
    --name "allow-dynatrace" `
    --priority 100 `
    --direction Inbound `
    --access Allow `
    --protocol Tcp `
    --source-address-prefixes "*" `
    --source-port-ranges "*" `
    --destination-address-prefixes "*" `
    --destination-port-ranges 9999

az network nsg rule create `
    --resource-group $resourceGroupName `
    --nsg-name "dynatrace-nsg" `
    --name "allow-ssh" `
    --priority 101 `
    --direction Inbound `
    --access Allow `
    --protocol Tcp `
    --source-address-prefixes "*" `
    --source-port-ranges "*" `
    --destination-address-prefixes "*" `
    --destination-port-ranges 22

Write-Host "All Azure resources have been provisioned successfully."
