# Deployment Guide — AVD Golden Image (Terraform + Azure VM Image Builder)

This guide walks you through deploying the infrastructure and running an Azure VM Image Builder (AIB) build that publishes a versioned image to Azure Compute Gallery for Azure Virtual Desktop.

---

## 0) Prerequisites

### Tools
- **Terraform** >= 1.9.0
- **Azure CLI** (`az`) for interactive login, or Service Principal for automation
- **PowerShell** 5.1+ (for running `set-auth.ps1` on Windows)

### Azure Requirements
- **AzureRM Provider 4.x** (4.14.0 - 4.58.0+) - resource providers are automatically registered
- Sufficient quota in the target region for the build VM size (e.g., `Standard_D4s_v3`)
- Service Principal with the following permissions (if using SPN auth):
  - Contributor on the subscription (or specific resource groups)
  - User Access Administrator (for RBAC assignments)

### Tested Configurations
- Windows 11 24H2 with M365 Apps (`win11-24h2-avd-m365`)
- Australia East region
- AzureRM Provider 4.14.0 - 4.58.0

---

## 1) Configure variables

Copy the example file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit the key settings:

### Core Configuration
- `subscription_id` - (Optional) Loaded from `ARM_SUBSCRIPTION_ID` env var via `.env` file
- `project_name` - Short name for resource naming (3-12 chars, lowercase alphanumeric)
- `environment` - Environment name (dev, staging, prod)
- `location` - Azure region (e.g., `australiaeast`, `eastus`)

### Source Image
- `source_image_publisher` - Default: `MicrosoftWindowsDesktop`
- `source_image_offer` - Default: `office-365`
- `source_image_sku` - Default: `win11-24h2-avd-m365` (includes M365 + Teams pre-installed)

### Application Installation (Multi-Strategy)

Configure applications using the `applications` map. Each application supports:
- **method**: `winget`, `direct`, `offline`, or `psadt`
- **fallback**: Alternative method if primary fails
- **skip_if_installed**: Pre-installation check

Example:
```hcl
applications = {
  chrome = {
    enabled     = true
    method      = "winget"
    winget_config = { package_id = "Google.Chrome", scope = "machine" }
    fallback = {
      method = "direct"
      direct_config = { download_url = "...", install_type = "msi" }
    }
  }
}
```

### Build Configuration
- `dry_run`:
  - `false` = AIB auto-run enabled (build starts automatically)
  - `true` = AIB auto-run disabled (manual build trigger required)
- `build_timeout_minutes` - Default: 180 (increase for large updates)
- `vm_size` - Build VM size (default: `Standard_D4s_v3`)

---

## 2) Authenticate

### Option A: Azure CLI (Interactive)

```bash
az login
az account set -s <subscription_id>
```

### Option B: Service Principal with .env File (Recommended)

1. Create a `.env` file in the project root:

```
ARM_CLIENT_ID=<your-spn-client-id>
ARM_CLIENT_SECRET=<your-spn-secret>
ARM_TENANT_ID=<your-tenant-id>
ARM_SUBSCRIPTION_ID=<your-subscription-id>
```

2. Run the authentication script (PowerShell):

```powershell
.\set-auth.ps1
```

This loads the credentials as environment variables for the current session.

> **Security Note**: The `.env` file is excluded from git via `.gitignore`. Never commit credentials to version control.

### Option C: CI/CD Pipeline

Set these environment variables in your pipeline:
- `ARM_CLIENT_ID`
- `ARM_CLIENT_SECRET`
- `ARM_TENANT_ID`
- `ARM_SUBSCRIPTION_ID`

---

## 3) Deploy with Terraform

```bash
terraform init
terraform plan
terraform apply
```

Terraform will:
1) Create the prerequisite resource groups, identity, RBAC, and storage
2) Create the Compute Gallery + image definition
3) Upload build scripts into a **private** blob container
4) Create the Image Builder template

If `dry_run = false`, the template is created/updated with `autoRun = Enabled`, so AIB should start building automatically.

---

## 4) Monitor the image build

### Build Phases

The image build goes through these phases:
1. **Building** (45-60 min) - VM provisioning, customization scripts
2. **Distributing** (10-20 min) - Image capture and gallery replication

Total build time: ~60-80 minutes depending on Windows Updates and application count.

### Show run history

```bash
az image builder show-runs -g <main-rg> -n <template-name>
```

### Show last run status

```bash
az image builder show -g <main-rg> -n <template-name> --query lastRunStatus
```

### PowerShell monitoring (using REST API)

```powershell
# Get template status
$templateName = "aib-<project>-<env>"
$rgName = "rg-<project>-imagebuilder-<env>"
az rest --method get \
  --uri "/subscriptions/<sub>/resourceGroups/$rgName/providers/Microsoft.VirtualMachineImages/imageTemplates/$templateName?api-version=2024-02-01" \
  --query "properties.lastRunStatus"
```

### If dry_run = true, start the build manually

```bash
az image builder run -g <main-rg> -n <template-name>
```

---

## 5) Use the image in Azure Virtual Desktop

When the build completes, you will have a Compute Gallery image version:

```
<image-definition-id>/versions/<image_version>
```

Use this image version in your AVD session host deployment automation (host pool/session hosts). The exact mechanics depend on your chosen AVD provisioning approach.

---

## Troubleshooting

### Build VM cannot download scripts
This project uses **AIB File customizers** to download scripts from a **private** blob container. Ensure:
- The managed identity has **Storage Blob Data Reader** on the storage account or container
- The blob URLs in the template are correct

### Image build fails during app installation
Check the AIB run output for the failing step:
- `WriteAppsConfig` - Configuration file creation
- `InstallCustomerApps` - Application installation
- `OptimizeForAVD` - AVD optimization
- `ConfigureFSLogix` - FSLogix configuration
- `FinalizeImage` - Image cleanup

Common causes and solutions:
- **Winget not available**: The fallback method (direct download) will be used automatically
- **Network restrictions**: Consider using `offline` method with pre-staged packages
- **Transient download issues**: Re-run the build; downloads are retried automatically

### Winget installation fails
Winget may not be available in all image configurations. The multi-strategy installer automatically falls back to the configured alternative method (usually `direct` download). To force direct download:

```hcl
applications = {
  chrome = {
    enabled = true
    method  = "direct"  # Skip winget, use direct download
    direct_config = { ... }
  }
}
```

### Windows Update step takes too long
Disable it by setting:

```hcl
run_windows_updates = false
```

Or increase:

```hcl
build_timeout_minutes = 240
```

### Image template update fails with "Update/Upgrade not supported"

Azure Image Builder does not support in-place updates to image templates. To modify a template:

1. Delete the existing template via Azure Portal or CLI:
```bash
az image builder delete -g <resource-group> -n <template-name>
```

2. Remove from Terraform state:
```bash
terraform state rm "module.image_builder.azurerm_resource_group_template_deployment.image_builder"
```

3. Re-apply Terraform:
```bash
terraform apply
```

### Cannot delete image definition (nested resources exist)

Delete all image versions first:
```bash
az sig image-version delete \
  -g <resource-group> \
  --gallery-name <gallery-name> \
  --gallery-image-definition <image-name> \
  --gallery-image-version <version>
```

### Application download fails with 404

Some application download URLs may become outdated. Check and update URLs in `scripts/install-apps.ps1`:
- Adobe Reader: Visit Adobe's download page for latest version
- 7-Zip: Check 7-zip.org for current version

---

## Clean up

```bash
terraform destroy
```

> Note: If a build is running, cancel it first:
>
> `az image builder cancel -g <main-rg> -n <template-name>`

---

## Security Features

This solution includes several security best practices:

### Image Security
- **Trusted Launch Support**: Images are configured to support Trusted Launch VMs
- **Accelerated Networking**: Enabled for better network performance
- **Gen2 VMs**: Uses Hyper-V Generation 2 for improved security

### Credential Management
- Service Principal credentials stored in `.env` file (excluded from git)
- Managed Identity for Image Builder (no stored secrets)
- Storage Blob Data Reader via RBAC (no SAS tokens)

### Script Integrity
- SHA256 checksums for all downloaded scripts
- Private blob storage (no public URLs)
- Managed Identity authentication for blob access

---

## Provider Compatibility

| Provider | Minimum Version | Tested Version |
|----------|-----------------|----------------|
| azurerm | 4.14.0 | 4.58.0 |
| azuread | 3.0.2 | 3.0.2 |
| random | 3.6.3 | 3.6.3 |
| time | 0.12.1 | 0.12.1 |
| terraform | 1.9.0 | 1.9.0+ |
