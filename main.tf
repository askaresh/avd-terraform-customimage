###############################################################################
# ROOT MODULE - MAIN ORCHESTRATION
###############################################################################
# End-to-end provisioning for an Azure Virtual Desktop (AVD) "golden image" using
# Azure VM Image Builder (AIB) and Azure Compute Gallery (ACG).
#
# High-level flow:
# 1) Prerequisites: RGs, Managed Identity, RBAC, script storage, optional VNet
# 2) Compute Gallery: Gallery + Image Definition
# 3) Upload scripts: PowerShell customizations uploaded to a private blob container
# 4) Image Builder: Image Template referencing the private scripts via File customizers
#    (and optionally auto-starting the build)
###############################################################################

###############################################################################
# LOCAL VARIABLES
###############################################################################

locals {
  # If not provided, create a date-based version (YYYY.MM.DD). You can override
  # this with an explicit semantic version via var.image_version.
  image_version = var.image_version != "" ? var.image_version : formatdate("YYYY.MM.DD", timestamp())

  # Name constraints: AIB image template names must be <= 64 chars
  image_template_name = substr("aib-${var.project_name}-${var.environment}", 0, 64)

  # Common tags merged with user-provided tags
  common_tags = merge(
    var.tags,
    {
      Project      = var.project_name
      Environment  = var.environment
      ManagedBy    = "Terraform"
      ImageVersion = local.image_version
      CreatedDate  = formatdate("YYYY-MM-DD", timestamp())
      CostCenter   = var.cost_center != "" ? var.cost_center : "N/A"
      Owner        = var.owner_email != "" ? var.owner_email : "N/A"
    }
  )

  # SHA256 checksums are used by AIB File customizers to validate downloaded scripts
  script_sha256 = {
    install_apps      = filesha256("${path.module}/scripts/install-apps.ps1")
    optimize_image    = filesha256("${path.module}/scripts/optimize-image.ps1")
    configure_fslogix = filesha256("${path.module}/scripts/configure-fslogix.ps1")
    finalize_image    = filesha256("${path.module}/scripts/finalize-image.ps1")
  }

  # Merge legacy boolean variables with new applications config
  # Legacy variables override the default applications config if set
  merged_applications = {
    for app_name, app_config in var.applications : app_name => merge(
      app_config,
      # Override enabled status from legacy variables if they are set (not null)
      app_name == "chrome" && var.install_chrome != null ? { enabled = var.install_chrome } : {},
      app_name == "adobe_reader" && var.install_adobe_reader != null ? { enabled = var.install_adobe_reader } : {},
      app_name == "seven_zip" && var.install_7zip != null ? { enabled = var.install_7zip } : {}
    )
  }
}

###############################################################################
# MODULE: PREREQUISITES
###############################################################################

module "prerequisites" {
  source = "./modules/prerequisites"

  project_name = var.project_name
  environment  = var.environment
  location     = var.location
  tags         = local.common_tags

  # Storage configuration
  custom_script_storage_account = var.custom_script_storage_account
  staging_resource_group        = var.staging_resource_group

  # Network configuration
  enable_private_network = var.enable_private_network
  vnet_resource_group    = var.vnet_resource_group
  vnet_name              = var.vnet_name
  subnet_name            = var.subnet_name
}

###############################################################################
# MODULE: SHARED IMAGE GALLERY
###############################################################################

module "shared_image_gallery" {
  source = "./modules/shared-image-gallery"

  resource_group_name = module.prerequisites.main_resource_group_name
  location            = var.location
  tags                = local.common_tags

  project_name = var.project_name
  environment  = var.environment

  # Image definition settings
  os_type            = "Windows"
  os_state           = "Generalized"
  hyper_v_generation = "V2"
  publisher          = "AVDGoldenImage"
  offer              = "Windows11-AVD"
  sku                = "win11-24h2-m365-optimized"

  depends_on = [module.prerequisites]
}

###############################################################################
# RESOURCE: UPLOAD SCRIPTS TO PRIVATE BLOB CONTAINER
###############################################################################
# These blobs remain private. The Image Builder managed identity is granted Blob
# Data Reader and the template uses AIB "File" customizers to fetch them.
###############################################################################

resource "azurerm_storage_blob" "install_apps_script" {
  name                   = "install-apps.ps1"
  storage_account_name   = module.prerequisites.storage_account_name
  storage_container_name = module.prerequisites.scripts_container_name
  type                   = "Block"
  source                 = "${path.module}/scripts/install-apps.ps1"
  content_type           = "text/plain"
  content_md5            = filemd5("${path.module}/scripts/install-apps.ps1")
}

resource "azurerm_storage_blob" "optimize_image_script" {
  name                   = "optimize-image.ps1"
  storage_account_name   = module.prerequisites.storage_account_name
  storage_container_name = module.prerequisites.scripts_container_name
  type                   = "Block"
  source                 = "${path.module}/scripts/optimize-image.ps1"
  content_type           = "text/plain"
  content_md5            = filemd5("${path.module}/scripts/optimize-image.ps1")
}

resource "azurerm_storage_blob" "configure_fslogix_script" {
  name                   = "configure-fslogix.ps1"
  storage_account_name   = module.prerequisites.storage_account_name
  storage_container_name = module.prerequisites.scripts_container_name
  type                   = "Block"
  source                 = "${path.module}/scripts/configure-fslogix.ps1"
  content_type           = "text/plain"
  content_md5            = filemd5("${path.module}/scripts/configure-fslogix.ps1")
}

resource "azurerm_storage_blob" "finalize_image_script" {
  name                   = "finalize-image.ps1"
  storage_account_name   = module.prerequisites.storage_account_name
  storage_container_name = module.prerequisites.scripts_container_name
  type                   = "Block"
  source                 = "${path.module}/scripts/finalize-image.ps1"
  content_type           = "text/plain"
  content_md5            = filemd5("${path.module}/scripts/finalize-image.ps1")
}

###############################################################################
# MODULE: IMAGE BUILDER TEMPLATE
###############################################################################
# If var.dry_run == false, we enable AIB autoRun so a build starts automatically
# when the template is created/updated. Terraform does not block until the build
# completes; use Azure Portal or "az image builder show-runs" to monitor.
###############################################################################

module "image_builder" {
  source = "./modules/image-builder"

  project_name = var.project_name
  environment  = var.environment

  resource_group_name       = module.prerequisites.main_resource_group_name
  staging_resource_group_id = module.prerequisites.staging_resource_group_id
  location                  = var.location
  tags                      = local.common_tags

  image_template_name = local.image_template_name
  auto_run            = var.dry_run ? false : true

  managed_identity_id = module.prerequisites.managed_identity_id

  # Source image
  source_image_publisher = var.source_image_publisher
  source_image_offer     = var.source_image_offer
  source_image_sku       = var.source_image_sku
  source_image_version   = var.source_image_version

  # Build VM configuration
  vm_size               = var.vm_size
  build_timeout_minutes = var.build_timeout_minutes
  os_disk_size_gb       = var.os_disk_size_gb

  # Network configuration
  enable_private_network = var.enable_private_network
  subnet_id              = module.prerequisites.subnet_id

  # Script URLs + integrity checks (private container + managed identity access)
  script_uris = {
    install_apps      = azurerm_storage_blob.install_apps_script.url
    optimize_image    = azurerm_storage_blob.optimize_image_script.url
    configure_fslogix = azurerm_storage_blob.configure_fslogix_script.url
    finalize_image    = azurerm_storage_blob.finalize_image_script.url
  }

  script_sha256 = local.script_sha256

  # Multi-strategy application configuration
  applications_config   = local.merged_applications
  scripts_container_url = module.prerequisites.scripts_container_url

  # Optimization settings
  run_windows_updates = var.run_windows_updates
  run_avd_optimizer   = var.run_avd_optimizer
  enable_fslogix      = var.enable_fslogix

  # Distribution targets
  gallery_image_id     = module.shared_image_gallery.image_definition_id
  image_version        = local.image_version
  exclude_from_latest  = var.exclude_from_latest
  replicate_regions    = var.replicate_regions
  replica_count        = var.replica_count
  storage_account_type = var.storage_account_type

  depends_on = [
    module.prerequisites,
    module.shared_image_gallery,
    azurerm_storage_blob.install_apps_script,
    azurerm_storage_blob.optimize_image_script,
    azurerm_storage_blob.configure_fslogix_script,
    azurerm_storage_blob.finalize_image_script
  ]
}
