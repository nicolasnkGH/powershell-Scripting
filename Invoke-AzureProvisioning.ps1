#!/usr/bin/env pwsh
# This script provisions Azure virtual machines and their dependencies using the Azure CLI.
# It is designed to be run as part of a GitHub Actions workflow.

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z]+[0-9]+$')]
    [string]$Location,

    [Parameter(Mandatory = $true)]
    [ValidateLength(1, 64)]
    [string]$Username,

    [Parameter(Mandatory = $true)]
    [ValidateScript({ $_ -match 'ssh-rsa|ssh-ed25519' })]
    [string]$SshKeyContent,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-z0-9-]+$')]
    [string]$VmPiholeName = 'pihole-vm',

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-z0-9-]+$')]
    [string]$VmDynatraceName = 'dynatrace-vm'
)

# Enable strict error handling
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Configuration constants
$vmSize = 'Standard_B2s'
$vmImage = 'Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest'

# Helper function for logging
function Write-Section {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "`n=== [$timestamp] $Message ===`n" -ForegroundColor Cyan
}

# Validate prerequisites
Write-Section 'Validating prerequisites...'

try {
    if (!(Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI (az) is not installed or not in PATH"
    }
    Write-Host 'Azure CLI detected' -ForegroundColor Green
} catch {
    Write-Error $_.Exception.Message
    exit 1
}

# Azure CLI version check
Write-Host 'Checking Azure CLI version...'
$azVersion = az --version --output tsv
Write-Host "Azure CLI: $azVersion" -ForegroundColor Gray

# --- Create Resource Group ---
Write-Section "Creating resource group '$ResourceGroupName'..."

$resourceGroupExists = az group exists --name $ResourceGroupName -ErrorAction SilentlyContinue
if ($resourceGroupExists) {
    Write-Host "Resource group '$ResourceGroupName' already exists. Reusing." -ForegroundColor Yellow
} else {
    try {
        az group create `
            --name $ResourceGroupName `
            --location $Location `
            --tags created_by='infrastructure-automation', project='pihole-dynatrace-stack' `
            --output none
        Write-Host "Resource group '$ResourceGroupName' created successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed to create resource group: $($_.Exception.Message)"
        exit 1
    }
}

# --- Networking Setup ---
$vnetName = "$ResourceGroupName-vnet"
$subnetName = "$ResourceGroupName-subnet"

Write-Section 'Creating virtual network and subnet...'

try {
    az network vnet create `
        --resource-group $ResourceGroupName `
        --name $vnetName `
        --address-prefix 10.0.0.0/16 `
        --subnet-name $subnetName `
        --subnet-prefix 10.0.0.0/24 `
        --location $Location `
        --tags created_by='infrastructure-automation' `
        --output none

    Write-Host 'Virtual network and subnet created successfully.' -ForegroundColor Green
} catch {
    Write-Error "Failed to create virtual network: $($_.Exception.Message)"
    exit 1
}

# --- Create Public IP Addresses ---
Write-Section 'Creating public IP addresses...'

$publicIps = @{
    pihole = 'pihole-public-ip'
    dynatrace = 'dynatrace-public-ip'
}

foreach ($service in $publicIps.Keys) {
    $ipName = $publicIps[$service]
    try {
        # Check if public IP exists before creating
        az network public-ip show `
            --resource-group $ResourceGroupName `
            --name $ipName `
            --query 'id' `
            --out tsv `
            --skip-error-check | Out-Null

        Write-Host "Public IP '$ipName' already exists. Reusing." -ForegroundColor Yellow
    } catch {
        try {
            az network public-ip create `
                --resource-group $ResourceGroupName `
                --name $ipName `
                --location $Location `
                --sku Standard `
                --public-ip-allocation static `
                --output none

            Write-Host "Public IP '$ipName' created successfully." -ForegroundColor Green
        } catch {
            Write-Error "Failed to create public IP '$ipName': $($_.Exception.Message)"
            exit 1
        }
    }
}

# --- Create Network Security Groups ---
Write-Section 'Creating network security groups...'

$nsgs = @{
    pihole = 'pihole-nsg'
    dynatrace = 'dynatrace-nsg'
}

foreach ($service in $nsgs.Keys) {
    $nsgName = $nsgs[$service]
    try {
        az network nsg show `
            --resource-group $ResourceGroupName `
            --name $nsgName `
            --query 'id' `
            --out tsv `
            --skip-error-check | Out-Null

        Write-Host "NSG '$nsgName' already exists. Skipping." -ForegroundColor Yellow
    } catch {
        try {
            az network nsg create `
                --resource-group $ResourceGroupName `
                --name $nsgName `
                --location $Location `
                --output none

            Write-Host "NSG '$nsgName' created successfully." -ForegroundColor Green
        } catch {
            Write-Error "Failed to create NSG '$nsgName': $($_.Exception.Message)"
            exit 1
        }
    }
}

# Add delay for NSG propagation
Write-Host 'Waiting for NSGs to propagate...' -ForegroundColor Gray
Start-Sleep -Seconds 5

# --- Add NSG Rules ---
function Add-NsgRules {
    param(
        [string]$NsgName,
        [string]$Service
    )

    $rules = switch ($Service) {
        'pihole' {
            @(
                @{ Name = 'allow-dns-tcp'; Priority = 100; Port = 53; Protocol = 'Tcp' }
                @{ Name = 'allow-dns-udp'; Priority = 101; Port = 53; Protocol = 'Udp' }
                @{ Name = 'allow-http'; Priority = 102; Port = 80; Protocol = 'Tcp' }
                @{ Name = 'allow-ssh'; Priority = 103; Port = 22; Protocol = 'Tcp' }
            )
        }
        'dynatrace' {
            @(
                @{ Name = 'allow-dynatrace'; Priority = 100; Port = 9999; Protocol = 'Tcp' }
                @{ Name = 'allow-ssh'; Priority = 101; Port = 22; Protocol = 'Tcp' }
            )
        }
    }

    foreach ($rule in $rules) {
        # Check if rule exists
        try {
            az network nsg rule show `
                --resource-group $ResourceGroupName `
                --nsg-name $NsgName `
                --name $rule.Name `
                --query 'id' `
                --out tsv `
                --skip-error-check | Out-Null

            Write-Host "NSG rule '$($rule.Name)' already exists." -ForegroundColor Gray
        } catch {
            try {
                az network nsg rule create `
                    --resource-group $ResourceGroupName `
                    --nsg-name $NsgName `
                    --name $rule.Name `
                    --priority $rule.Priority `
                    --direction Inbound `
                    --access Allow `
                    --protocol $rule.Protocol `
                    --source-address-prefixes '*' `
                    --source-port-ranges '*' `
                    --destination-address-prefixes '*' `
                    --destination-port-ranges $rule.Port `
                    --output none

                Write-Host "NSG rule '$($rule.Name)' created for '$NsgName'." -ForegroundColor Green
            } catch {
                Write-Error "Failed to create NSG rule '$($rule.Name)': $($_.Exception.Message)"
                exit 1
            }
        }
    }
}

Add-NsgRules -NsgName 'pihole-nsg' -Service 'pihole'
Add-NsgRules -NsgName 'dynatrace-nsg' -Service 'dynatrace'

# --- Provision VMs ---
function New-AzureVm {
    param(
        [string]$VmName,
        [string]$NicName,
        [string]$Tags
    )

    try {
        az vm show `
            --resource-group $ResourceGroupName `
            --name $VmName `
            --query 'id' `
            --out tsv `
            --skip-error-check | Out-Null

        Write-Host "VM '$VmName' already exists. Skipping." -ForegroundColor Yellow
        return
    } catch {
        try {
            az vm create `
                --resource-group $ResourceGroupName `
                --name $VmName `
                --image $vmImage `
                --size $vmSize `
                --nics $NicName `
                --admin-username $Username `
                --ssh-key-values $SshKeyContent `
                --tags $Tags `
                --output none

            Write-Host "VM '$VmName' provisioned successfully." -ForegroundColor Green

            # Get and display VM public IP
            $publicIp = az network public-ip show `
                --resource-group $ResourceGroupName `
                --name ($NicName -replace '-nic$', '-public-ip') `
                --query 'ipAddress' `
                --out tsv

            Write-Host "VM '$VmName' is accessible at: $publicIp:22" -ForegroundColor Cyan
        } catch {
            Write-Error "Failed to provision VM '$VmName': $($_.Exception.Message)"
            exit 1
        }
    }
}

Write-Section 'Provisioning Pi-hole VM...'
New-AzureVm `
    -VmName $VmPiholeName `
    -NicName 'pihole-nic' `
    -Tags "project=pihole,created_by=infrastructure-automation"

Write-Section 'Provisioning Dynatrace VM...'
New-AzureVm `
    -VmName $VmDynatraceName `
    -NicName 'dynatrace-nic' `
    -Tags "project=dynatrace,created_by=infrastructure-automation"

# --- Summary ---
Write-Section 'Provisioning Complete!'

Write-Host 'Summary:' -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroupName ($Location)" -ForegroundColor White
Write-Host "  Pi-hole VM:     $VmPiholeName (via pihole-public-ip)" -ForegroundColor White
Write-Host "  Dynatrace VM:   $VmDynatraceName (via dynatrace-public-ip)" -ForegroundColor White

Write-Host "`nTo SSH into VMs:" -ForegroundColor Cyan
Write-Host "  ssh $Username@<public-ip>" -ForegroundColor Gray

Write-Host "`nAll Azure resources have been provisioned successfully." -ForegroundColor Green
