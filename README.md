# Pi-hole and Dynatrace Deployment (Dev Branch)

**Status:** 🚧 Work in Progress  

---

## 📖 Overview
This **dev branch** is a backup of the latest `main` branch, which includes code to provision Azure VMs and install **Pi-hole** and **Dynatrace**.  

⚠️ The installation is incomplete due to an issue where the **`pihole-FTL` service fails to start**.

---

## 📂 Files
- **Invoke-AzureProvisioning.ps1** → Provisions Azure VMs  
- **provision-pihole-dynatrace.ps1** → Installs Pi-hole and Dynatrace (work in progress)  
- **main.yaml** → GitHub Actions workflow for provisioning and installing applications  

---

## ❗ Current Issue
- The `pihole-FTL` service does not run after Pi-hole installation.  
- This causes the workflow to fail during the **"Verify Pi-hole installation"** step.  

---

## ▶️ Running the Workflow

1. Switch to the dev branch:
   ```bash
   git checkout dev
   ```
---

2. Ensure GitHub Secrets are set:
- AZURE_CREDENTIALS
- SSH_PRIVATE_KEY
- SSH_PUBLIC_KEY
- DYNATRACE_API_TOKEN
- DYNATRACE_ENV_URL

3. Trigger the workflow in GitHub Actions under "Pi-hole & Dynatrace Deployment on Azure"
   
4. Check logs for errors in:
- **Install Pi-hole**
- **Verify Pi-hole installation**

---

## Next Steps
- [ ] Debug the pihole-FTL service failure
- [ ] Consider using Bash scripts for installation
- [ ] Verify VM resources and network settings (e.g., ports 53 and 80)
