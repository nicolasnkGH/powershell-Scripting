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
        $sshCommand = "ssh -v -i $SshPrivateKeyPath -o StrictHostKeyChecking=no ${VmUsername}@${VmPublicIp} `"echo 'Connected successfully.'`""
        Write-Host "Executing: $sshCommand"
        Invoke-Expression $sshCommand 2>&1

        # Create temporary bash script for Pi-hole installation
        $piholeScript = "/tmp/install-pihole.sh"
        $scriptContent = @"
#!/bin/bash
# Ensure curl is installed
if ! command -v curl >/dev/null 2>&1; then
    echo "Installing curl..."
    sudo apt-get update && sudo apt-get install -y curl
    if [ \$? -ne 0 ]; then
        echo "Error: Failed to install curl"
        exit 1
    fi
fi
# Run Pi-hole installer
echo "Running Pi-hole installer..."
curl -sSL https://install.pi-hole.net | bash --unattended
if [ \$? -ne 0 ]; then
    echo "Error: Pi-hole installation failed"
    exit 1
fi
echo "Pi-hole installation completed successfully"
"@
        # Write script to local file
        Set-Content -Path $piholeScript -Value $scriptContent
        Write-Host "Created temporary script $piholeScript"

        # Copy script to remote VM
        Write-Host "Copying Pi-hole install script to VM..."
        $scpCommand = "scp -i $SshPrivateKeyPath -o StrictHostKeyChecking=no $piholeScript ${VmUsername}@${VmPublicIp}:/tmp/install-pihole.sh"
        Write-Host "Executing: $scpCommand"
        Invoke-Expression $scpCommand 2>&1

        # Execute script on remote VM
        Write-Host "Executing Pi-hole install script..."
        $sshExecCommand = "ssh -v -i $SshPrivateKeyPath -o StrictHostKeyChecking=no ${VmUsername}@${VmPublicIp} `"chmod +x /tmp/install-pihole.sh && /bin/bash /tmp/install-pihole.sh`""
        Write-Host "Executing: $sshExecCommand"
        Invoke-Expression $sshExecCommand 2>&1

        # Clean up local script
        Remove-Item -Path $piholeScript -Force
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
        $sshCommand = "ssh -v -i $SshPrivateKeyPath -o StrictHostKeyChecking=no ${VmUsername}@${VmPublicIp} `"echo 'Connected successfully.'`""
        Write-Host "Executing: $sshCommand"
        Invoke-Expression $sshCommand 2>&1

        # Install wget if not present, then download and install Dynatrace OneAgent
        Write-Host "Downloading and installing Dynatrace OneAgent..."
        $dynatraceCommand = "ssh -v -i $SshPrivateKeyPath -o StrictHostKeyChecking=no ${VmUsername}@${VmPublicIp} `"sudo apt-get update && sudo apt-get install -y wget && wget -O /tmp/dynatrace-oneagent.sh '$DynatraceEnvUrl/api/v1/deployment/installer/agent/unix/default/latest?Api-Token=$DynatraceApiToken&arch=x86_64&flavor=default' && sudo sh /tmp/dynatrace-oneagent.sh`""
        Write-Host "Executing: $dynatraceCommand"
        Invoke-Expression $dynatraceCommand 2>&1

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