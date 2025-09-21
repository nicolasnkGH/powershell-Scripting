# Script to deploy Pi-hole and Dynatrace on Linux VMs

function Install-Pihole {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VmPublicIp,
        [Parameter(Mandatory = $true)]
        [string]$VmUsername,
        [Parameter(Mandatory = $true)]
        [string]$SshPrivateKeyPath
    )

    Write-Host "Starting Pi-hole deployment on VM with IP: $VmPublicIp"

    try {
        # Check if the VM is reachable with verbose output
        Write-Host "Testing SSH connection..."
        ssh -v -i $SshPrivateKeyPath -o StrictHostKeyChecking=no "$VmUsername@$VmPublicIp" "echo 'Connected successfully.'" 2>&1

        # Execute Pi-hole one-step installer via SSH
        Write-Host "Running Pi-hole one-step installer..."
        ssh -v -i $SshPrivateKeyPath -o StrictHostKeyChecking=no "$VmUsername@$VmPublicIp" "curl -sSL https://install.pi-hole.net | bash --unattended" 2>&1

        Write-Host "Pi-hole deployment completed."
    }
    catch {
        Write-Error "Failed to install Pi-hole on VM ${VmPublicIp}: $_"
        exit 1
    }
}

function Install-Dynatrace {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VmPublicIp,
        [Parameter(Mandatory = $true)]
        [string]$VmUsername,
        [Parameter(Mandatory = $true)]
        [string]$SshPrivateKeyPath,
        [Parameter(Mandatory = $true)]
        [string]$DynatraceApiToken,
        [Parameter(Mandatory = $true)]
        [string]$DynatraceEnvUrl
    )

    Write-Host "Starting Dynatrace deployment on VM with IP: $VmPublicIp"

    try {
        # Check if the VM is reachable with verbose output
        Write-Host "Testing SSH connection..."
        ssh -v -i $SshPrivateKeyPath -o StrictHostKeyChecking=no "$VmUsername@$VmPublicIp" "echo 'Connected successfully.'" 2>&1

        # Install wget if not present, then download and install Dynatrace OneAgent
        Write-Host "Downloading and installing Dynatrace OneAgent..."
        ssh -v -i $SshPrivateKeyPath -o StrictHostKeyChecking=no "$VmUsername@$VmPublicIp" "sudo apt-get update && sudo apt-get install -y wget && wget -O /tmp/dynatrace-oneagent.sh '$DynatraceEnvUrl/api/v1/deployment/installer/agent/unix/default/latest?Api-Token=$DynatraceApiToken&arch=x86_64&flavor=default' && sudo sh /tmp/dynatrace-oneagent.sh" 2>&1

        Write-Host "Dynatrace deployment completed."
    }
    catch {
        Write-Error "Failed to install Dynatrace on VM ${VmPublicIp}: $_"
        exit 1
    }
}

# Main execution
param (
    [Parameter(Mandatory = $true)]
    [string]$VmPublicIp,
    [Parameter(Mandatory = $true)]
    [string]$VmUsername,
    [Parameter(Mandatory = $true)]
    [string]$SshPrivateKeyPath,
    [Parameter(Mandatory = $false)]
    [string]$DynatraceApiToken,
    [Parameter(Mandatory = $false)]
    [string]$DynatraceEnvUrl
)

if ($VmPublicIp -eq $env:PIHOLE_IP) {
    Install-Pihole -VmPublicIp $VmPublicIp -VmUsername $VmUsername -SshPrivateKeyPath $SshPrivateKeyPath
}
elseif ($VmPublicIp -eq $env:DYNATRACE_IP) {
    if (-not $DynatraceApiToken -or -not $DynatraceEnvUrl) {
        Write-Error "Dynatrace API token and environment URL are required for Dynatrace installation."
        exit 1
    }
    Install-Dynatrace -VmPublicIp $VmPublicIp -VmUsername $VmUsername -SshPrivateKeyPath $SshPrivateKeyPath -DynatraceApiToken $DynatraceApiToken -DynatraceEnvUrl $DynatraceEnvUrl
}
else {
    Write-Error "Invalid VM IP provided: ${VmPublicIp}. Must match PIHOLE_IP or DYNATRACE_IP."
    exit 1
}