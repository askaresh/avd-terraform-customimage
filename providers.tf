###############################################################################
# TERRAFORM PROVIDERS CONFIGURATION
###############################################################################
# This file configures the required providers and their versions for the
# AVD Golden Image infrastructure. We use the latest stable versions with
# version constraints to ensure compatibility while allowing minor updates.
###############################################################################

terraform {
  # Require Terraform 1.9.0 or higher for latest features and stability
  required_version = ">= 1.9.0"

  required_providers {
    # Azure Resource Manager Provider - Latest stable version
    # Used for managing all Azure resources
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.14.0, < 5.0.0"
    }

    # Azure Active Directory Provider - Latest stable version
    # Used for managing Azure AD resources (managed identities, service principals)
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0.2"
    }

    # Random Provider - For generating unique names and IDs
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.3"
    }

    # Time Provider - For managing time-based resources and delays
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12.1"
    }

    # Null Provider - For running provisioners and local-exec commands
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.3"
    }

    # HTTP Provider - For fetching external scripts and resources
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4.5"
    }
  }
}

###############################################################################
# AZURERM PROVIDER CONFIGURATION
###############################################################################
# The AzureRM provider is configured with features that optimize for
# Azure Virtual Desktop and Image Builder workloads
###############################################################################

provider "azurerm" {
  # Enable all features - required for Image Builder
  features {
    # Resource Group features
    resource_group {
      # Prevent accidental deletion of resource groups containing Image Builder
      prevent_deletion_if_contains_resources = true
    }

    # Key Vault features - for future secret management
    key_vault {
      # Purge soft-deleted Key Vaults on destroy (dev/test only)
      purge_soft_delete_on_destroy    = var.environment != "prod"
      recover_soft_deleted_key_vaults = true
    }

    # Virtual Machine features
    virtual_machine {
      # Delete OS disk when VM is deleted (important for Image Builder cleanup)
      delete_os_disk_on_deletion = true
      # Graceful shutdown before deletion
      graceful_shutdown = true
      # Skip shutdown for forced deletion scenarios
      skip_shutdown_and_force_delete = false
    }

  }

  # Set subscription context
  # If var.subscription_id is null, the provider uses ARM_SUBSCRIPTION_ID env var
  subscription_id = var.subscription_id

  # Authentication: Uses environment variables set by set-auth.ps1 (from .env file)
  # Required env vars: ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
}

###############################################################################
# AZUREAD PROVIDER CONFIGURATION
###############################################################################
# Azure Active Directory provider for managing identities and RBAC
###############################################################################

provider "azuread" {
  # Automatically inherits tenant from Azure CLI context
  # Can be overridden with tenant_id if needed
}

###############################################################################
# PROVIDER VERSION NOTES
###############################################################################
# Version Strategy:
# - azurerm uses ">= 4.14.0, < 5.0.0" to allow all 4.x versions
# - Other providers use "~>" (pessimistic constraint) for minor updates
# - Major version is locked to prevent breaking changes
# - Review and update quarterly for security patches and new features
#
# Minimum/Tested Versions as of 2026-02-06:
# - azurerm: 4.14.0+ (supports Image Builder v2, tested up to 4.58.0)
# - azuread: 3.0.2 (latest stable with managed identity improvements)
# - random: 3.6.3 (cryptographically secure randomness)
# - time: 0.12.1 (improved time handling)
# - null: 3.2.3 (stable, no breaking changes expected)
# - http: 3.4.5 (TLS 1.3 support)
###############################################################################
