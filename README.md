# Azure VM Provisioning with GitHub Actions

## Project Overview

This project demonstrates **Infrastructure as Code (IaC)** by provisioning Azure virtual machines using:

- **PowerShell scripts** (`Invoke-AzureProvisioning.ps1`) to run Azure CLI commands
- **YAML workflow** (`.github/workflows/main.yaml`) to automate everything via **GitHub Actions**
- **Cleanup script** (`Invoke-AzureCleanup.ps1`) for safe resource destruction

The result is a **repeatable, automated process** for creating and managing Azure infrastructure.

---

## Key Files

### `.github/workflows/main.yaml`
Defines the GitHub Actions workflow with:
- Input parameters via `workflow_dispatch` (no manual edits needed)
- Azure login using service principal credentials
- Automatic provisioning and verification steps

### `Invoke-AzureProvisioning.ps1`
PowerShell script that provisions:
- Resource group with tags
- Virtual network (10.0.0.0/16) with subnet (10.0.0.0/24)
- Two public IP addresses (Standard SKU, static allocation)
- Two Network Security Groups with port rules:
  - **Pi-hole VM**: DNS (53 TCP/UDP), HTTP (80), SSH (22)
  - **Dynatrace VM**: Dynatrace port (9999), SSH (22)
- Two Ubuntu 22.04 LTS VMs (`Standard_B2s` size)

**Improvements in v2:**
- Input validation with `[ValidatePattern]` and `[ValidateLength]` attributes
- Proper parameter syntax using `[Parameter(Mandatory=...)]` style
- Existence checks before creating resources (idempotent)
- Error handling with `$ErrorActionPreference = 'Stop'`
- Tagging all resources for cost tracking
- Progress indication and colored output
- Public IP display after VM creation

### `Invoke-AzureCleanup.ps1`
Safe destruction of all infrastructure:
- Resource enumeration before deletion
- Double confirmation prompts
- Asynchronous deletion to avoid timeout

---

## Prerequisites

1. **GitHub repository** with Actions enabled
2. **Azure Service Principal** with Contributor access to subscription
3. **SSH key pair** for VM authentication
4. **Azure CLI** installed locally (for testing)

---

## Setup Instructions

### 1. Create SSH Key Pair (if not exists)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519adb -C "your@email.com"
```

Copy the public key content:
```bash
cat ~/.ssh/id_ed25519adb.pub
```

### 2. Create Azure Service Principal

```bash
az account set --subscription "YOUR-SUBSCRIPTION-ID"
az ad sp create-for-rbac \
  --name "azure-automation-sp" \
  --role contributor \
  --scopes "/subscriptions/YOUR-SUBSCRIPTION-ID"
```

Save the JSON output (you'll need `clientId`, `clientSecret`, and `tenant`).

### 3. Configure GitHub Secrets

In your GitHub repo, go to **Settings → Secrets → Actions** and add:

| Secret Name | Value |
|-------------|-------|
| `AZURE_CREDENTIALS` | Full JSON from Service Principal creation |
| `SSH_PUBLIC_KEY` | Content of your SSH public key (`cat ~/.ssh/id_ed25519adb.pub`) |

---

## Usage

### Trigger via GitHub UI

1. Go to **Actions** tab
2. Select **Provision Azure Infrastructure** workflow
3. Fill in parameters:
   - **Resource Group**: `pihole-dynatrace-rg` (or your choice)
   - **Location**: `eastus`, `westus2`, etc.
   - **Pi-hole VM Name**: `pihole-vm`
   - **Dynatrace VM Name**: `dynatrace-vm`
   - **Username**: Your preferred admin username
4. Click **Run workflow**

### Trigger via API/Curl (Optional)

```bash
curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  -d '{"ref":"main","inputs":{"resource_group":"my-rg","location":"eastus","username":"azureuser"}}' \
  https://api.github.com/repos/OWNER/REPO/actions/workflows/main.yaml/dispatches
```

---

## Expected Output

```
=== [2026-03-21 14:30:00] Validating prerequisites... ===
Azure CLI detected

=== [2026-03-21 14:30:01] Creating resource group 'pihole-dynatrace-rg'... ===
Resource group 'pihole-dynatrace-rg' created successfully.

=== [2026-03-21 14:30:05] Creating virtual network and subnet... ===
Virtual network and subnet created successfully.

...

VM 'pihole-vm' is accessible at: 52.174.123.45:22
VM 'dynatrace-vm' is accessible at: 52.174.123.46:22

Summary:
  Resource Group: pihole-dynatrace-rg (eastus)
  Pi-hole VM:     pihole-vm (via pihole-public-ip)
  Dynatrace VM:   dynatrace-vm (via dynatrace-public-ip)
```

---

## Cleanup

To destroy all resources:

### Option A: Manual Local Execution
```bash
pwsh -File Invoke-AzureCleanup.ps1 -ResourceGroupName pihole-dynatrace-rg -Force
```

### Option B: Create GitHub Actions Workflow for Cleanup

Add a new workflow `.github/workflows/cleanup.yaml`:

```yaml
name: Cleanup Azure Infrastructure

on:
  workflow_dispatch:
    inputs:
      resource_group:
        description: 'Resource group to delete'
        required: true

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Azure Login
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - name: Delete resources
        shell: pwsh
        run: |
          ./Invoke-AzureCleanup.ps1 `
            -ResourceGroupName '${{ github.event.inputs.resource_group }}' `
            -Force
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Resources                          │
├─────────────────────────────────────────────────────────────┤
│  Resource Group: pihole-dynatrace-rg                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Virtual Network: 10.0.0.0/16                          │   │
│  │ Subnet: 10.0.0.0/24                                   │   │
│  │                                                       │   │
│  │ ┌──────────────┐    ┌──────────────┐                 │   │
│  │ │ Pi-hole VM   │    │ Dynatrace VM │                 │   │
│  │ │ IP: 52.x.y.z  │    │ IP: 52.x.y.a │                 │   │
│  │ │ NSG: 53,80,22 │    │ NSG: 9999,22 │                 │   │
│  │ └──────────────┘    └──────────────┘                 │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Cost Considerations

Resources created (East US pricing as reference):

| Resource | Estimated Hourly Cost |
|----------|----------------------|
| Standard_B2s VM (2x) | ~$0.048/hr ($0.096/hr total) |
| Standard Public IP (2x) | ~$0.005/hr ($0.01/hr total) |
| Basic Data Transfers | Variable based on usage |

**Monthly estimate:** ~$70 for running 24/7
**Recommendation:** Use cleanup script when not actively testing

---

## Security Notes

- **Current**: NSG rules allow inbound traffic from any source (`*`)
- **Improvement**: Consider adding a parameter for `AllowedSourceIp` to restrict access
- **Best Practice**: Use Azure Managed Identity instead of Service Principal secrets in GitHub

---

## Roadmap

- [x] Provision Azure VMs using GitHub Actions + PowerShell
- [x] Add idempotency (skip existing resources)
- [x] Create `Invoke-AzureCleanup.ps1` to tear down infrastructure
- [x] Add input parameters via workflow_dispatch
- [ ] Restrict NSG rules to specific IP ranges
- [ ] Add Azure Policy compliance checks before provisioning
- [ ] Script deployment of Pi-hole on VM1
- [ ] Script deployment of Dynatrace on VM2
- [ ] Support for additional Azure regions

---

## License

MIT License - See LICENSE file for details

---

**Built with:** PowerShell, Azure CLI, GitHub Actions
