###############################################################################
# PREREQUISITES MODULE - MAIN CONFIGURATION
###############################################################################
# This module creates all required prerequisites for Azure Image Builder:
# 1. Resource providers registration
# 2. Resource groups
# 3. User-assigned managed identity
# 4. Custom RBAC role for Image Builder
# 5. Role assignments
# 6. Storage account for scripts and artifacts
# 7. Optional: Virtual network configuration
###############################################################################

###############################################################################
# DATA SOURCES
###############################################################################

# Get current Azure subscription details
data "azurerm_client_config" "current" {}

# Get current subscription
data "azurerm_subscription" "current" {}

###############################################################################
# RESOURCE PROVIDER REGISTRATION
###############################################################################
# Note: AzureRM provider 4.x automatically registers required resource providers
# No manual registration is needed

###############################################################################
# RANDOM SUFFIX FOR UNIQUE NAMING
###############################################################################
# Generate a random suffix to ensure globally unique resource names
# This is particularly important for storage accounts and managed identities

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
  numeric = true
}

###############################################################################
# RESOURCE GROUPS
###############################################################################

# Main resource group for Image Builder templates and managed images
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-imagebuilder-${var.environment}"
  location = var.location
  tags     = var.tags
}

# Staging resource group for Image Builder temporary resources
# This resource group is used during the build process and should be empty
resource "azurerm_resource_group" "staging" {
  name     = var.staging_resource_group != "" ? var.staging_resource_group : "rg-${var.project_name}-imagebuilder-staging-${var.environment}"
  location = var.location
  tags = merge(
    var.tags,
    {
      Purpose   = "Image Builder staging resources"
      Temporary = "true"
    }
  )
}

# Scripts resource group for storing customization scripts
resource "azurerm_resource_group" "scripts" {
  name     = "rg-${var.project_name}-scripts-${var.environment}"
  location = var.location
  tags = merge(
    var.tags,
    {
      Purpose = "Customization scripts storage"
    }
  )
}

###############################################################################
# USER-ASSIGNED MANAGED IDENTITY
###############################################################################
# This identity is used by Image Builder to authenticate and access resources
# No credentials are stored or managed - all authentication is handled by Azure

resource "azurerm_user_assigned_identity" "image_builder" {
  name                = "id-${var.project_name}-imagebuilder-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags = merge(
    var.tags,
    {
      Purpose = "Image Builder managed identity"
    }
  )
}

###############################################################################
# CUSTOM RBAC ROLE FOR IMAGE BUILDER
###############################################################################
# Create a custom role with minimum required permissions for Image Builder
# This follows the principle of least privilege

resource "azurerm_role_definition" "image_builder" {
  name        = "ImageBuilder-CustomRole-${var.project_name}-${var.environment}"
  scope       = data.azurerm_subscription.current.id
  description = "Custom role for Azure Image Builder with minimum required permissions"

  permissions {
    actions = [
      # Compute Gallery permissions
      "Microsoft.Compute/galleries/read",
      "Microsoft.Compute/galleries/images/read",
      "Microsoft.Compute/galleries/images/versions/read",
      "Microsoft.Compute/galleries/images/versions/write",
      
      # Managed Image permissions
      "Microsoft.Compute/images/write",
      "Microsoft.Compute/images/read",
      "Microsoft.Compute/images/delete",
      
      # Disk permissions (for temporary build disks)
      "Microsoft.Compute/disks/read",
      "Microsoft.Compute/disks/write",
      "Microsoft.Compute/disks/delete",
      
      # Snapshot permissions (for image creation)
      "Microsoft.Compute/snapshots/read",
      "Microsoft.Compute/snapshots/write",
      "Microsoft.Compute/snapshots/delete",
      
      # Storage permissions (for script access)
      "Microsoft.Storage/storageAccounts/blobServices/containers/read",
      "Microsoft.Storage/storageAccounts/blobServices/generateUserDelegationKey/action"
    ]

    not_actions = []

    data_actions = [
      # Blob data access for downloading scripts
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"
    ]

    not_data_actions = []
  }

  assignable_scopes = [
    azurerm_resource_group.main.id,
    azurerm_resource_group.scripts.id
  ]

  depends_on = [
    azurerm_resource_group.main,
    azurerm_resource_group.scripts
  ]
}

###############################################################################
# ROLE ASSIGNMENTS
###############################################################################

# Assign custom role to managed identity on main resource group
resource "azurerm_role_assignment" "image_builder_main" {
  scope                = azurerm_resource_group.main.id
  role_definition_id   = azurerm_role_definition.image_builder.role_definition_resource_id
  principal_id         = azurerm_user_assigned_identity.image_builder.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [
    azurerm_role_definition.image_builder
  ]
}

# Assign custom role to managed identity on scripts resource group
resource "azurerm_role_assignment" "image_builder_scripts" {
  scope                = azurerm_resource_group.scripts.id
  role_definition_id   = azurerm_role_definition.image_builder.role_definition_resource_id
  principal_id         = azurerm_user_assigned_identity.image_builder.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [
    azurerm_role_definition.image_builder
  ]
}

# Additional Contributor role for staging resource group
# This allows Image Builder to create and delete temporary resources
resource "azurerm_role_assignment" "image_builder_staging" {
  scope              = azurerm_resource_group.staging.id
  role_definition_name = "Contributor"
  principal_id       = azurerm_user_assigned_identity.image_builder.principal_id
  principal_type     = "ServicePrincipal"
}

# Storage Blob Data Reader role for script storage account (assigned after storage creation)
resource "azurerm_role_assignment" "storage_blob_reader" {
  scope                = azurerm_storage_account.scripts.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.image_builder.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [
    azurerm_storage_account.scripts
  ]
}

###############################################################################
# STORAGE ACCOUNT FOR SCRIPTS
###############################################################################
# This storage account holds customization scripts that run during image build
# Scripts are uploaded as blobs and accessed via SAS tokens or managed identity

resource "azurerm_storage_account" "scripts" {
  name                     = var.custom_script_storage_account != "" ? var.custom_script_storage_account : "st${var.project_name}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.scripts.name
  location                 = azurerm_resource_group.scripts.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # Locally redundant storage is sufficient for scripts
  account_kind             = "StorageV2"
  
  # Security settings
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true # Required for Image Builder access
  
  # Enable blob versioning for script history
  blob_properties {
    versioning_enabled = true
    
    delete_retention_policy {
      days = 30
    }
    
    container_delete_retention_policy {
      days = 30
    }
  }

  # Enable infrastructure encryption
  infrastructure_encryption_enabled = true

  tags = merge(
    var.tags,
    {
      Purpose = "Image Builder scripts storage"
    }
  )
}

# Container for customization scripts
resource "azurerm_storage_container" "scripts" {
  name                  = "scripts"
  storage_account_id    = azurerm_storage_account.scripts.id
  container_access_type = "private" # Private access - scripts accessed via managed identity
}

# Container for application installers (optional)
resource "azurerm_storage_container" "installers" {
  name                  = "installers"
  storage_account_id    = azurerm_storage_account.scripts.id
  container_access_type = "private"
}

# Container for logs and artifacts
resource "azurerm_storage_container" "logs" {
  name                  = "logs"
  storage_account_id    = azurerm_storage_account.scripts.id
  container_access_type = "private"
}

###############################################################################
# NETWORK CONFIGURATION (OPTIONAL)
###############################################################################
# If using an existing VNet, configure access for Image Builder

data "azurerm_subnet" "image_builder" {
  count = var.enable_private_network ? 1 : 0

  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.vnet_resource_group
}

# Assign Network Contributor role to managed identity on subnet (if using private network)
resource "azurerm_role_assignment" "subnet_network_contributor" {
  count = var.enable_private_network ? 1 : 0

  scope                = data.azurerm_subnet.image_builder[0].id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.image_builder.principal_id
  principal_type       = "ServicePrincipal"
}

###############################################################################
# TIME DELAY
###############################################################################
# Add a delay after role assignments to allow Azure AD replication
# This prevents "Principal not found" errors during Image Builder template creation

resource "time_sleep" "wait_for_rbac" {
  create_duration = "60s"

  depends_on = [
    azurerm_role_assignment.image_builder_main,
    azurerm_role_assignment.image_builder_scripts,
    azurerm_role_assignment.image_builder_staging,
    azurerm_role_assignment.storage_blob_reader
  ]
}

###############################################################################
# OUTPUTS
###############################################################################
# These outputs are used by other modules and provide essential resource IDs
