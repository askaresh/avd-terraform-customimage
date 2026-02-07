# Azure Virtual Desktop (AVD) Golden Image Automation (Terraform)

This repository automates an **end-to-end**, **enterprise-friendly** Azure Virtual Desktop custom image pipeline using:

- **Azure VM Image Builder (AIB)** to build a custom image
- **Azure Compute Gallery (ACG)** (Shared Image Gallery) to version and replicate the image
- **Terraform** (>= 1.9.0) with **AzureRM Provider 4.x** (4.14.0 - 4.58.0+) to provision prerequisites, RBAC, image template, and to upload build scripts

> This repo implements the same concept as the Microsoft Learn guidance for creating custom image templates for AVD, but in Terraform and with enterprise RBAC + private artifact storage.

---

## What's Included in the Image

### Pre-installed on Source Image (`win11-24h2-avd-m365`):
- Microsoft 365 Apps (Word, Excel, PowerPoint, Outlook)
- Microsoft Teams (New Teams)
- OneDrive

### Additional Applications Installed by This Pipeline:
- Google Chrome Enterprise (via Winget with direct download fallback)
- Adobe Acrobat Reader DC (via Winget with direct download fallback)
- 7-Zip (via Winget with direct download fallback)

### Optimizations Applied:
- Windows Updates (latest security patches)
- Microsoft AVD Optimization Tool v1.1
- FSLogix Profile Containers configuration
- Image cleanup and finalization
- Trusted Launch support enabled
- Accelerated Networking support enabled

---

## What Gets Deployed

### 1) Prerequisites
- Resource groups: **main**, **staging**, and **scripts**
- **User-assigned managed identity** for Image Builder
- RBAC (custom role + assignments) for:
  - building and writing image versions to Azure Compute Gallery
  - reading scripts from private storage
  - optional VNet/subnet access if you use private networking
- Storage account + **private container** for build scripts

### 2) Azure Compute Gallery
- Gallery
- Image definition (Windows, Generalized, Gen2)

### 3) Image Builder Template
- Platform image source (Marketplace)
- **File customizers** to download scripts from private blob storage
- PowerShell customizers to:
  - install applications
  - run Windows Update (optional)
  - run AVD optimization tool (optional)
  - configure FSLogix (optional)
  - finalize image and cleanup

**Auto-run** is supported: when `dry_run = false`, the template is created/updated and AIB is configured to start a build automatically.

> Terraform does not block until the image build finishes. Use Azure Portal or `az image builder show-runs` to monitor.

---

## Repository Layout

```
.
├── main.tf                     # Orchestration: modules + script upload + image template
├── variables.tf                # All config toggles including multi-strategy apps
├── outputs.tf                  # IDs + helpful next steps
├── providers.tf                # Provider configuration (AzureRM 4.x)
├── terraform.tfvars.example    # Example configuration with all options
├── set-auth.ps1                # Authentication helper script
├── DEPLOYMENT_GUIDE.md         # Step-by-step deployment guide
├── .env.example                # Example environment file for SPN auth
├── scripts/
│   ├── install-apps.ps1        # Multi-strategy app installer (winget/direct/offline/psadt)
│   ├── optimize-image.ps1      # Runs Microsoft AVD Optimization Tool
│   ├── configure-fslogix.ps1   # Installs/configures FSLogix
│   └── finalize-image.ps1      # Cleanup and final hardening steps
└── modules/
    ├── prerequisites/          # Identity, RBAC, storage, optional VNet inputs
    ├── image-builder/          # AIB template creation via ARM deployment
    └── shared-image-gallery/   # Gallery + image definition (with security settings)
```

---

## Quick Start

### 1) Copy and edit the example variables:

```bash
cp terraform.tfvars.example terraform.tfvars
```

### 2) Set up authentication (choose one):

**Option A: Azure CLI (Interactive)**
```bash
az login
az account set -s <subscription_id>
```

**Option B: Service Principal with .env file (Recommended for local dev)**

Create a `.env` file in the project root (excluded from git):
```
ARM_CLIENT_ID=<your-spn-client-id>
ARM_CLIENT_SECRET=<your-spn-secret>
ARM_TENANT_ID=<your-tenant-id>
ARM_SUBSCRIPTION_ID=<your-subscription-id>
```

Then run the authentication script:
```powershell
.\set-auth.ps1
```

**Option C: CI/CD Pipeline**
Set environment variables `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID` in your pipeline.

### 3) Run Terraform:

```bash
terraform init
terraform plan
terraform apply
```

### 4) Monitor the build:

```bash
az image builder show-runs -g <main-rg> -n <template-name>
az image builder show -g <main-rg> -n <template-name> --query lastRunStatus
```

---

## Key Enterprise Design Choices

### Private Script Storage + Managed Identity Access
Scripts are uploaded to a **private** blob container. The Image Builder **user-assigned managed identity** is granted **Storage Blob Data Reader**, and the template uses **AIB File customizers** to download scripts.

This avoids:
- public URLs
- long-lived SAS tokens
- storing secrets in Terraform state

### Integrity Checks (SHA256)
Each script download uses a SHA256 checksum so the build fails if artifacts are tampered with in storage.

### Deterministic Image Versioning
By default, image versions publish as `YYYY.MM.DD`. You can override with `image_version = "1.2.3"`.

---

## Customizing Applications

This solution uses a **multi-strategy application installation framework** that supports multiple installation methods with automatic fallback:

### Installation Methods

| Method | Description | Use Case |
|--------|-------------|----------|
| `winget` | Windows Package Manager | Default for most apps, automatic updates |
| `direct` | Direct URL download + silent install | Fallback when winget unavailable |
| `offline` | Pre-staged packages from blob storage | Air-gapped or restricted environments |
| `psadt` | PSAppDeployToolkit packages | Complex enterprise apps |

### Configuration Example

Applications are configured in `terraform.tfvars` using a map structure:

```hcl
applications = {
  chrome = {
    enabled     = true
    method      = "winget"
    description = "Google Chrome Enterprise"
    
    winget_config = {
      package_id = "Google.Chrome"
      scope      = "machine"
    }
    
    # Fallback to direct download if winget fails
    fallback = {
      method = "direct"
      direct_config = {
        download_url = "https://dl.google.com/chrome/install/googlechromestandaloneenterprise64.msi"
        install_type = "msi"
        install_args = "/quiet /norestart"
      }
    }
    
    skip_if_installed = {
      check_type = "file"
      check_path = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
    }
  }
}
```

### Default Applications

| Application | Method | Fallback | Status |
|-------------|--------|----------|--------|
| Google Chrome | Winget | Direct | Enabled |
| Adobe Reader DC | Winget | Direct | Enabled |
| 7-Zip | Winget | Direct | Enabled |

> **Note**: Microsoft 365 and Teams are **pre-installed** on the M365 source image and are not included in the applications list.

### Adding Custom Applications

To add new applications, add entries to the `applications` map in `terraform.tfvars`. See `terraform.tfvars.example` for examples of all installation methods including PSADT and offline packages.

---

## Supported Regions

The solution supports all Azure regions with Azure VM Image Builder. Tested regions include:
- **Australia East** (australiaeast)
- **East US** (eastus)
- **West US 2** (westus2)
- **North Europe** (northeurope)
- **West Europe** (westeurope)

---

## Notes and Limitations

- **Build completion**: Terraform provisions the template; it does not wait for the build to finish. Use Azure Portal or `az image builder show-runs` to monitor.
- **Build duration**: Typical builds take 45-75 minutes depending on Windows Updates and application installations.
- **Marketplace image choice**: Validate the Marketplace source image (publisher/offer/sku) matches your compliance requirements and licensing.
- **Networking**: If you enable private networking, ensure outbound dependencies required for app installs/updates are reachable (proxy/NAT).
- **AVD session hosts**: This repo publishes an image version. Use that image version when creating AVD Session Hosts via your host pool automation.
- **Template updates**: Azure Image Builder does not support in-place template updates. See DEPLOYMENT_GUIDE.md for workaround.

---

## Security

### Credential Management
- **Never commit credentials** to version control
- Use `.env` file for local development (excluded via `.gitignore`)
- Use Azure Key Vault or CI/CD secrets for production pipelines
- The `set-auth.ps1` script loads credentials from `.env` as environment variables

### Files Excluded from Git
The `.gitignore` is configured to exclude:
- `.env` and `*.env` files (contain actual credentials)
- `.terraform/` directories
- `*.tfstate` files

### Files Safe to Commit
- `terraform.tfvars` - Contains configuration only, subscription ID loaded from env var
- `set-auth.ps1` - Only reads from `.env` file, contains no secrets

---

## Acknowledgments

This project uses the following open source components:

- **[AVD Golden Image Optimizer](https://github.com/DrazenNikolic/AVD-Golden-Image-Optimizer)** by [Drazen Nikolic](https://github.com/DrazenNikolic) - The image optimization script (v1.1) used for Windows 11 24H2/25H2+ AVD environments. This optimizer provides network stack tuning, system stability improvements, privacy controls, and Defender hardening specifically designed for Azure Virtual Desktop.

---

## Documentation

See **DEPLOYMENT_GUIDE.md** for a detailed walkthrough, prerequisites, and troubleshooting.
