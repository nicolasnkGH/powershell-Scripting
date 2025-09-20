# This script provisions Azure virtual machines and their dependencies using the Azure CLI.
# It is designed to be run as part of a GitHub Actions workflow.

param (
    [string][Parameter(Mandatory=$true)] $ResourceGroupName,
    [string][Parameter(Mandatory=$true)] $Location,
    [string][Parameter(Mandatory=$true)] $Username,
    [string][Parameter(Mandatory=$true)] $SshKeyContent,
    [string][Parameter(Mandatory=$false)] $VmPiholeName = 'pihole-vm',
    [string][Parameter(Mandatory=$false)] $VmDynatraceName = 'dynatrace-vm'
)

Write-Host "Starting Azure provisioning process..."

# --- Define common VM size and image ---
$vmSize = "Standard_B2s"
$vmImage = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"

# --- Create Resource Group ---
# Create a resource group if it doesn't exist
Write-Host "Checking for Resource Group '$ResourceGroupName'..."
az group create --name $ResourceGroupName --location $Location

# --- Networking Setup ---
$vnetName = "$ResourceGroupName-vnet"
$subnetName = "$ResourceGroupName-subnet"

Write-Host "Creating Virtual Network and Subnet..."
az network vnet create `
    --resource-group $ResourceGroupName `
    --name $vnetName `
    --address-prefix 10.0.0.0/16 `
    --subnet-name $subnetName `
    --subnet-prefix 10.0.0.0/24 `
    --location $Location

# --- Create Public IP Addresses ---
Write-Host "Creating Public IP Addresses..."
az network public-ip create `
    --resource-group $ResourceGroupName `
    --name "pihole-public-ip" `
    --location $Location `
    --sku Standard

az network public-ip create `
    --resource-group $ResourceGroupName `
    --name "dynatrace-public-ip" `
    --location $Location `
    --sku Standard

# --- Create Network Security Groups ---
Write-Host "Creating Network Security Groups..."
$piholeNsgName = "pihole-nsg"
$dynatraceNsgName = "dynatrace-nsg"
az network nsg create --resource-group $ResourceGroupName --name $piholeNsgName --location $Location
az network nsg create --resource-group $ResourceGroupName --name $dynatraceNsgName --location $Location

# Wait until NSGs exist to avoid race conditions
Start-Sleep -Seconds 5

# --- Add NSG rules for Pi-hole ---
Write-Host "Adding NSG rules for Pi-hole..."
az network nsg rule create --resource-group $ResourceGroupName --nsg-name $piholeNsgName --name "allow-dns-tcp" --priority 100 --direction Inbound --access Allow --protocol Tcp --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges 53
az network nsg rule create --resource-group $ResourceGroupName --nsg-name $piholeNsgName --name "allow-dns-udp" --priority 101 --direction Inbound --access Allow --protocol Udp --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges 53
az network nsg rule create --resource-group $ResourceGroupName --nsg-name $piholeNsgName --name "allow-http" --priority 102 --direction Inbound --access Allow --protocol Tcp --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges 80
az network nsg rule create --resource-group $ResourceGroupName --nsg-name $piholeNsgName --name "allow-ssh" --priority 103 --direction Inbound --access Allow --protocol Tcp --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges 22

# --- Add NSG rules for Dynatrace ---
Write-Host "Adding NSG rules for Dynatrace..."
az network nsg rule create --resource-group $ResourceGroupName --nsg-name $dynatraceNsgName --name "allow-dynatrace" --priority 100 --direction Inbound --access Allow --protocol Tcp --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges 9999
az network nsg rule create --resource-group $ResourceGroupName --nsg-name $dynatraceNsgName --name "allow-ssh" --priority 101 --direction Inbound --access Allow --protocol Tcp --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges 22

# --- Provision the Pi-hole NIC ---
$piholeNicName = "pihole-nic"
Write-Host "Creating NIC for Pi-hole..."
az network nic create `
    --resource-group $ResourceGroupName `
    --name $piholeNicName `
    --vnet-name $vnetName `
    --subnet $subnetName `
    --network-security-group $piholeNsgName `
    --public-ip-address "pihole-public-ip" `
    --location $Location

# --- Provision the Pi-hole VM ---
Write-Host "Provisioning Pi-hole VM '$VmPiholeName'..."
az vm create `
    --resource-group $ResourceGroupName `
    --name $VmPiholeName `
    --image $vmImage `
    --size $vmSize `
    --nics $piholeNicName `
    --admin-username $Username `
    --ssh-key-value $SshKeyContent `
    --tags project="pihole"

Write-Host "Pi-hole VM provisioned successfully."

# --- Provision the Dynatrace NIC ---
$dynatraceNicName = "dynatrace-nic"
Write-Host "Creating NIC for Dynatrace..."
az network nic create `
    --resource-group $ResourceGroupName `
    --name $dynatraceNicName `
    --vnet-name $vnetName `
    --subnet $subnetName `
    --network-security-group $dynatraceNsgName `
    --public-ip-address "dynatrace-public-ip" `
    --location $Location

# --- Provision the Dynatrace VM ---
Write-Host "Provisioning Dynatrace VM '$VmDynatraceName'..."
az vm create `
    --resource-group $ResourceGroupName `
    --name $VmDynatraceName `
    --image $vmImage `
    --size $vmSize `
    --nics $dynatraceNicName `
    --admin-username $Username `
    --ssh-key-value $SshKeyContent `
    --tags project="dynatrace"

Write-Host "Dynatrace VM provisioned successfully."
Write-Host "All Azure resources have been provisioned successfully."
