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

# --- Networking Setup ---
Write-Host "Creating Virtual Network and Subnet..."
$vnetName = "main-vnet"
$subnetName = "default-subnet"
az network vnet create `
    --resource-group $resourceGroupName `
    --name $vnetName `
    --address-prefix 10.0.0.0/16 `
    --subnet-name $subnetName `
    --subnet-prefix 10.0.0.0/24 `
    --location $location

# --- Create NSGs ---
$piholeNsgName = "pihole-nsg"
$dynatraceNsgName = "dynatrace-nsg"

Write-Host "Creating Network Security Groups..."
az network nsg create --resource-group $resourceGroupName --name $piholeNsgName --location $location
az network nsg create --resource-group $resourceGroupName --name $dynatraceNsgName --location $location

# Wait until NSGs exist to avoid race conditions
Start-Sleep -Seconds 5

# --- Provision the Pi-hole NIC ---
$piholeNicName = "pihole-nic"
Write-Host "Creating NIC for Pi-hole..."
az network nic create `
    --resource-group $resourceGroupName `
    --name $piholeNicName `
    --vnet-name $vnetName `
    --subnet $subnetName `
    --network-security-group $piholeNsgName `
    --public-ip-address "pihole-public-ip" `
    --location $location

# --- Provision the Pi-hole VM ---
Write-Host "Provisioning Pi-hole VM '$vmPiholeName'..."
az vm create `
    --resource-group $resourceGroupName `
    --name $vmPiholeName `
    --location $location `
    --image $vmImage `
    --size $vmSize `
    --nics $piholeNicName `
    --admin-username $username `
    --ssh-key-value $sshKeyContent `
    --tags project="pihole"

# --- Add NSG rules for Pi-hole ---
Write-Host "Adding NSG rules for Pi-hole..."
az network nsg rule create --resource-group $resourceGroupName --nsg-name $piholeNsgName --name "allow-dns-tcp" --priority 100 --direction Inbound --access Allow --protocol Tcp --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges 53
az network nsg rule create --resource-group $resourceGroupName --nsg-name $piholeNsgName --name "allow-dns-udp" --priority 101 --direction Inbound --access Allow --protocol Udp --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges 53
az network nsg rule create --resource-group $resourceGroupName --nsg-name $piholeNsgName --name "allow-http" --priority 102 --direction Inbound --access Allow --protocol Tcp --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges 80
az network nsg rule create --resource-group $resourceGroupName --nsg-name $piholeNsgName --name "allow-ssh" --priority 103 --direction Inbound --access Allow --protocol Tcp --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges 22

# --- Provision the Dynatrace NIC ---
$dynatraceNicName = "dynatrace-nic"
Write-Host "Creating NIC for Dynatrace..."
az network nic create `
    --resource-group $resourceGroupName `
    --name $dynatraceNicName `
    --vnet-name $vnetName `
    --subnet $subnetName `
    --network-security-group $dynatraceNsgName `
    --public-ip-address "dynatrace-public-ip" `
    --location $location

# --- Provision the Dynatrace VM ---
Write-Host "Provisioning Dynatrace VM '$vmDynatraceName'..."
az vm create `
    --resource-group $resourceGroupName `
    --name $vmDynatraceName `
    --location $location `
    --image $vmImage `
    --size $vmSize `
    --os-disk-size-gb 100 `
    --nics $dynatraceNicName `
    --admin-username $username `
    --ssh-key-value $sshKeyContent `
    --tags project="dynatrace"

# --- Add NSG rules for Dynatrace ---
Write-Host "Adding NSG rules for Dynatrace..."
az network nsg rule create --resource-group $resourceGroupName --nsg-name $dynatraceNsgName --name "allow-dynatrace" --priority 100 --direction Inbound --access Allow --protocol Tcp --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges 9999
az network nsg rule create --resource-group $resourceGroupName --nsg-name $dynatraceNsgName --name "allow-ssh" --priority 101 --direction Inbound --access Allow --protocol Tcp --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges 22

Write-Host "All Azure resources have been provisioned successfully."
