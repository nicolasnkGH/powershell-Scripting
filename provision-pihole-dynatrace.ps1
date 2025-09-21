# The following two scripts are designed to be run from a GitHub Actions workflow.
# They require the 'ssh' command to be available in the runner environment to connect to the VMs.

# Script to deploy Pi-hole on a Linux VM
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
        # Check if the VM is reachable
        Write-Host "Attempting to connect to the VM..."
        ssh -i $SshPrivateKeyPath -o StrictHostKeyChecking=no "$VmUsername@$VmPublicIp" "echo 'Connected successfully.'"

        # Execute Pi-hole installation commands via SSH
        Write-Host "Running Pi-hole installation script..."
        ssh -i $SshPrivateKeyPath -o StrictHostKeyChecking=no "$VmUsername@$VmPublicIp" 'sudo apt-get update && sudo apt-get install -y git && git clone https://github.com/pi-hole/pi-hole.git --depth 1 && cd "pi-hole/automated install/" && sudo bash basic-install.sh'
        
        Write-Host "Pi-hole deployment completed."
    }
    catch {
        Write-Error "Failed to install Pi-hole on VM: $_"
        exit 1
    }
}

# Script to deploy Dynatrace on a Linux VM
function Install-Dynatrace {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VmPublicIp,

        [Parameter(Mandatory = $true)]
        [string]$VmUsername,

        [Parameter(Mandatory = $true)]
        [string]$SshPrivateKeyPath
    )

    Write-Host "Starting Dynatrace deployment on VM with IP: $VmPublicIp"

    try {
        # Check if the VM is reachable
        Write-Host "Attempting to connect to the VM..."
        ssh -i $SshPrivateKeyPath -o StrictHostKeyChecking=no "$VmUsername@$VmPublicIp" "echo 'Connected successfully.'"

        # Execute Dynatrace installation commands via SSH
        Write-Host "Downloading and installing Dynatrace agent..."
        ssh -i $SshPrivateKeyPath -o StrictHostKeyChecking=no "$VmUsername@$VmPublicIp" 'sudo apt-get update && wget -O /tmp/dynatrace-oneagent.sh "https://downloads.dynatrace.com/oneagent/installer/latest/linux/default/installer.sh?arch=x86_64" && sudo sh /tmp/dynatrace-oneagent.sh'
        
        Write-Host "Dynatrace deployment completed."
    }
    catch {
        Write-Error "Failed to install Dynatrace on VM: $_"
        exit 1
    }
}
