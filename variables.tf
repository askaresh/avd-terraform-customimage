###############################################################################
# ROOT MODULE VARIABLES
###############################################################################
# This file defines all input variables for the AVD Golden Image infrastructure.
# Variables are organized by category with detailed descriptions and validation.
###############################################################################

###############################################################################
# CORE CONFIGURATION
###############################################################################

variable "subscription_id" {
  description = "Azure subscription ID where resources will be deployed. If not provided, uses ARM_SUBSCRIPTION_ID environment variable."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.subscription_id == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "Subscription ID must be a valid GUID format or null (to use ARM_SUBSCRIPTION_ID env var)."
  }
}

variable "project_name" {
  description = "Project name used for resource naming. Use lowercase alphanumeric characters only."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.project_name))
    error_message = "Project name must be 3-12 characters, lowercase alphanumeric only."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod). Used for resource naming and tagging."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Primary Azure region for resource deployment (e.g., eastus, westeurope)"
  type        = string
  default     = "eastus"

  validation {
    condition = contains([
      "eastus", "eastus2", "westus", "westus2", "westus3",
      "centralus", "northcentralus", "southcentralus",
      "westcentralus", "canadacentral", "canadaeast",
      "northeurope", "westeurope", "uksouth", "ukwest",
      "francecentral", "germanywestcentral", "switzerlandnorth",
      "norwayeast", "swedencentral", "australiaeast",
      "australiasoutheast", "southeastasia", "eastasia",
      "japaneast", "japanwest", "koreacentral", "koreasouth",
      "southafricanorth", "uaenorth", "brazilsouth",
      "centralindia", "southindia", "westindia"
    ], var.location)
    error_message = "Location must be a valid Azure region."
  }
}

###############################################################################
# TAGGING
###############################################################################

variable "tags" {
  description = "Common tags applied to all resources. Additional tags can be added per resource."
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Project     = "AVD-GoldenImage"
    CreatedDate = "2026-01-28"
  }
}

variable "cost_center" {
  description = "Cost center code for billing and chargeback"
  type        = string
  default     = ""
}

variable "owner_email" {
  description = "Email address of resource owner for notifications"
  type        = string
  default     = ""

  validation {
    condition     = var.owner_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner_email))
    error_message = "Owner email must be a valid email address or empty."
  }
}

###############################################################################
# SOURCE IMAGE CONFIGURATION
###############################################################################

variable "source_image_publisher" {
  description = "Publisher of the source marketplace image"
  type        = string
  default     = "MicrosoftWindowsDesktop"
}

variable "source_image_offer" {
  description = "Offer of the source marketplace image"
  type        = string
  default     = "office-365"
}

variable "source_image_sku" {
  description = "SKU of the source marketplace image. Use win11-24h2-avd-m365 for latest Windows 11 with M365"
  type        = string
  default     = "win11-24h2-avd-m365"

  validation {
    condition = contains([
      "win11-24h2-avd-m365",
      "win11-24h2-avd",
      "win11-23h2-avd-m365",
      "win11-23h2-avd",
      "win10-22h2-avd-m365",
      "win10-22h2-avd"
    ], var.source_image_sku)
    error_message = "Source image SKU must be a supported AVD image."
  }
}

variable "source_image_version" {
  description = "Version of the source image. Use 'latest' for most recent version."
  type        = string
  default     = "latest"
}

###############################################################################
# IMAGE BUILDER CONFIGURATION
###############################################################################

variable "vm_size" {
  description = "Size of the temporary build VM. Must match source image generation (Gen2 recommended)."
  type        = string
  default     = "Standard_D4s_v3"

  validation {
    condition = contains([
      "Standard_D2s_v3", "Standard_D4s_v3", "Standard_D8s_v3",
      "Standard_D2s_v4", "Standard_D4s_v4", "Standard_D8s_v4",
      "Standard_D2s_v5", "Standard_D4s_v5", "Standard_D8s_v5",
      "Standard_E2s_v3", "Standard_E4s_v3", "Standard_E8s_v3",
      "Standard_E2s_v4", "Standard_E4s_v4", "Standard_E8s_v4",
      "Standard_E2s_v5", "Standard_E4s_v5", "Standard_E8s_v5"
    ], var.vm_size)
    error_message = "VM size must be a supported Gen2 VM size for Image Builder."
  }
}

variable "build_timeout_minutes" {
  description = "Maximum build time in minutes. Increase for complex customizations or slow downloads."
  type        = number
  default     = 180

  validation {
    condition     = var.build_timeout_minutes >= 60 && var.build_timeout_minutes <= 960
    error_message = "Build timeout must be between 60 and 960 minutes."
  }
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB for build VM. Minimum 127 GB, recommended 256 GB for Office installations."
  type        = number
  default     = 256

  validation {
    condition     = var.os_disk_size_gb >= 127 && var.os_disk_size_gb <= 4095
    error_message = "OS disk size must be between 127 and 4095 GB."
  }
}

variable "image_version" {
  description = "Custom image version in semantic versioning format (e.g., 1.0.0). Auto-generated if empty."
  type        = string
  default     = ""

  validation {
    condition     = var.image_version == "" || can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.image_version))
    error_message = "Image version must be in semantic versioning format (X.Y.Z) or empty for auto-generation."
  }
}

###############################################################################
# COMPUTE GALLERY CONFIGURATION
###############################################################################

variable "replicate_regions" {
  description = "List of Azure regions to replicate the image to. Include primary location for best performance."
  type        = list(string)
  default     = ["eastus"]

  validation {
    condition     = length(var.replicate_regions) > 0 && length(var.replicate_regions) <= 15
    error_message = "Must specify 1-15 replication regions."
  }
}

variable "replica_count" {
  description = "Number of replicas per region. Higher count improves concurrent deployment performance."
  type        = number
  default     = 1

  validation {
    condition     = var.replica_count >= 1 && var.replica_count <= 10
    error_message = "Replica count must be between 1 and 10."
  }
}

variable "storage_account_type" {
  description = "Storage account type for image versions. Standard_LRS for cost optimization, Premium_LRS for performance."
  type        = string
  default     = "Standard_LRS"

  validation {
    condition     = contains(["Standard_LRS", "Standard_ZRS", "Premium_LRS"], var.storage_account_type)
    error_message = "Storage account type must be Standard_LRS, Standard_ZRS, or Premium_LRS."
  }
}

variable "exclude_from_latest" {
  description = "Exclude this image version from being used when specifying 'latest'. Useful for testing."
  type        = bool
  default     = false
}

###############################################################################
# APPLICATION INSTALLATION - MULTI-STRATEGY CONFIGURATION
###############################################################################
# Supports multiple installation methods: direct, winget, offline, psadt
# Each application can specify its preferred method and fallback options
###############################################################################

variable "default_install_method" {
  description = "Default installation method for applications (direct, winget, offline, psadt)"
  type        = string
  default     = "direct"

  validation {
    condition     = contains(["direct", "winget", "offline", "psadt"], var.default_install_method)
    error_message = "Default install method must be one of: direct, winget, offline, psadt"
  }
}

variable "applications" {
  description = "Application installation configuration with multi-strategy support"
  type = map(object({
    enabled     = bool
    method      = string # direct, winget, offline, psadt
    description = optional(string, "")

    # Direct download configuration
    direct_config = optional(object({
      download_url = string
      install_type = string # msi, exe, msix
      install_args = optional(string, "")
    }))

    # Winget configuration
    winget_config = optional(object({
      package_id = string
      version    = optional(string, "")
      scope      = optional(string, "machine")
    }))

    # Offline package configuration (from blob storage)
    offline_config = optional(object({
      blob_path    = string
      install_type = string # msi, exe, msix, appv
      install_args = optional(string, "")
      transform    = optional(string, "") # MST file path
    }))

    # PSAppDeployToolkit configuration
    psadt_config = optional(object({
      package_path = string # Path to PSADT package ZIP in blob storage
    }))

    # Fallback method if primary fails
    fallback = optional(object({
      method = string
      direct_config = optional(object({
        download_url = string
        install_type = string
        install_args = optional(string, "")
      }))
      winget_config = optional(object({
        package_id = string
        version    = optional(string, "")
      }))
    }))

    # Pre-installation check - skip if already installed
    skip_if_installed = optional(object({
      check_type = string # registry, file, appx
      check_path = string # Registry path, file path, or appx display name pattern
    }))
  }))

  default = {
    chrome = {
      enabled     = true
      method      = "winget"
      description = "Google Chrome Enterprise"
      winget_config = {
        package_id = "Google.Chrome"
        scope      = "machine"
      }
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

    adobe_reader = {
      enabled     = true
      method      = "winget"
      description = "Adobe Acrobat Reader DC"
      winget_config = {
        package_id = "Adobe.Acrobat.Reader.64-bit"
        scope      = "machine"
      }
      fallback = {
        method = "direct"
        direct_config = {
          download_url = "https://ardownload2.adobe.com/pub/adobe/acrobat/win/AcrobatDC/2400920063/AcroRdrDCx642400920063_MUI.exe"
          install_type = "exe"
          install_args = "/sAll /rs /msi EULA_ACCEPT=YES"
        }
      }
      skip_if_installed = {
        check_type = "file"
        check_path = "C:\\Program Files\\Adobe\\Acrobat DC\\Acrobat\\Acrobat.exe"
      }
    }

    seven_zip = {
      enabled     = true
      method      = "winget"
      description = "7-Zip file archiver"
      winget_config = {
        package_id = "7zip.7zip"
        scope      = "machine"
      }
      fallback = {
        method = "direct"
        direct_config = {
          download_url = "https://www.7-zip.org/a/7z2408-x64.msi"
          install_type = "msi"
          install_args = "/quiet /norestart"
        }
      }
      skip_if_installed = {
        check_type = "file"
        check_path = "C:\\Program Files\\7-Zip\\7z.exe"
      }
    }
  }
}

# Legacy variables for backward compatibility
variable "install_chrome" {
  description = "[DEPRECATED] Use applications variable instead. Install Google Chrome"
  type        = bool
  default     = null
}

variable "install_adobe_reader" {
  description = "[DEPRECATED] Use applications variable instead. Install Adobe Reader"
  type        = bool
  default     = null
}

variable "install_7zip" {
  description = "[DEPRECATED] Use applications variable instead. Install 7-Zip"
  type        = bool
  default     = null
}

###############################################################################
# OPTIMIZATION SETTINGS
###############################################################################

variable "run_windows_updates" {
  description = "Run Windows Update during image build. Increases build time but ensures latest patches."
  type        = bool
  default     = true
}

variable "run_avd_optimizer" {
  description = "Run AVD Golden Image Optimizer script (v1.1)"
  type        = bool
  default     = true
}

variable "enable_fslogix" {
  description = "Install and configure FSLogix for profile management"
  type        = bool
  default     = true
}

variable "fslogix_version" {
  description = "FSLogix version to install. Use 'latest' for most recent version."
  type        = string
  default     = "latest"
}

###############################################################################
# NETWORKING
###############################################################################

variable "enable_private_network" {
  description = "Use existing VNet for build VM (recommended for production). Requires VNet and subnet."
  type        = bool
  default     = false
}

variable "vnet_resource_group" {
  description = "Resource group containing existing VNet (required if enable_private_network = true)"
  type        = string
  default     = ""
}

variable "vnet_name" {
  description = "Name of existing VNet (required if enable_private_network = true)"
  type        = string
  default     = ""
}

variable "subnet_name" {
  description = "Name of subnet for build VM (required if enable_private_network = true)"
  type        = string
  default     = ""
}

###############################################################################
# SECURITY & COMPLIANCE
###############################################################################

variable "enable_encryption_at_host" {
  description = "Enable encryption at host for build VM (requires subscription feature)"
  type        = bool
  default     = false
}



variable "allowed_ip_ranges" {
  description = "List of IP ranges allowed to access build VM (CIDR notation). Empty = no restriction."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.allowed_ip_ranges : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", cidr))
    ])
    error_message = "IP ranges must be in valid CIDR notation (e.g., 10.0.0.0/16)."
  }
}

###############################################################################
# ADVANCED CONFIGURATION
###############################################################################

variable "staging_resource_group" {
  description = "Custom resource group name for Image Builder staging resources. Auto-generated if empty."
  type        = string
  default     = ""
}

variable "enable_build_vm_identity" {
  description = "Assign managed identity to build VM for authenticating with Azure services"
  type        = bool
  default     = false
}

variable "custom_script_storage_account" {
  description = "Existing storage account name for custom scripts. Auto-created if empty."
  type        = string
  default     = ""
}

variable "enable_auto_shutdown" {
  description = "Enable auto-shutdown for build VM if build exceeds timeout (safety mechanism)"
  type        = bool
  default     = true
}

variable "build_vm_priority" {
  description = "Priority for build VM allocation. Use 'Regular' for guaranteed capacity, 'Spot' for cost savings."
  type        = string
  default     = "Regular"

  validation {
    condition     = contains(["Regular", "Spot"], var.build_vm_priority)
    error_message = "Build VM priority must be Regular or Spot."
  }
}

###############################################################################
# FEATURE FLAGS
###############################################################################

variable "enable_telemetry" {
  description = "Enable anonymous telemetry for Terraform deployment (helps improve modules)"
  type        = bool
  default     = false
}

variable "enable_debug_mode" {
  description = "Enable debug mode with verbose logging and extended timeouts"
  type        = bool
  default     = false
}

variable "dry_run" {
  description = "Perform dry run without creating image (validates configuration only)"
  type        = bool
  default     = false
}

###############################################################################
# NOTIFICATIONS
###############################################################################

variable "enable_email_notifications" {
  description = "Send email notifications on build completion/failure"
  type        = bool
  default     = false
}

variable "notification_email" {
  description = "Email address for build notifications (required if enable_email_notifications = true)"
  type        = string
  default     = ""

  validation {
    condition     = var.notification_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "Notification email must be a valid email address or empty."
  }
}

###############################################################################
# LIFECYCLE MANAGEMENT
###############################################################################


variable "max_image_versions" {
  description = "Maximum number of image versions to keep per definition. Oldest versions deleted first."
  type        = number
  default     = 5

  validation {
    condition     = var.max_image_versions >= 1 && var.max_image_versions <= 50
    error_message = "Max image versions must be between 1 and 50."
  }
}

###############################################################################
# VALIDATION RULES
###############################################################################
# Additional cross-variable validation rules

locals {
  # Validate private network configuration
  private_network_validation = (
    var.enable_private_network ?
    (var.vnet_resource_group != "" && var.vnet_name != "" && var.subnet_name != "") :
    true
  )

  # Validate notification configuration
  notification_validation = (
    var.enable_email_notifications ?
    var.notification_email != "" :
    true
  )

  # Generate auto version if not provided
  auto_image_version = var.image_version != "" ? var.image_version : formatdate("YYYY.MM.DD", timestamp())
}

# Validation checks
check "private_network_config" {
  assert {
    condition     = local.private_network_validation
    error_message = "When enable_private_network is true, vnet_resource_group, vnet_name, and subnet_name must be provided."
  }
}

check "notification_config" {
  assert {
    condition     = local.notification_validation
    error_message = "When enable_email_notifications is true, notification_email must be provided."
  }
}
