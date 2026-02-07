###############################################################################
# ROOT MODULE OUTPUTS
###############################################################################
# These outputs provide essential information about the deployed infrastructure
# and can be used by other Terraform configurations or CI/CD pipelines
###############################################################################

###############################################################################
# RESOURCE IDENTIFIERS
###############################################################################

output "subscription_id" {
  description = "Azure subscription ID where resources were deployed"
  value       = var.subscription_id
  sensitive   = true
}

output "resource_group_name" {
  description = "Name of the main resource group containing Image Builder resources"
  value       = module.prerequisites.main_resource_group_name
}

output "resource_group_id" {
  description = "Resource ID of the main resource group"
  value       = module.prerequisites.main_resource_group_id
}

output "location" {
  description = "Azure region where resources were deployed"
  value       = var.location
}

###############################################################################
# MANAGED IDENTITY
###############################################################################

output "managed_identity_id" {
  description = "Resource ID of the user-assigned managed identity used by Image Builder"
  value       = module.prerequisites.managed_identity_id
}

output "managed_identity_client_id" {
  description = "Client ID (Application ID) of the managed identity"
  value       = module.prerequisites.managed_identity_client_id
}

output "managed_identity_principal_id" {
  description = "Principal ID (Object ID) of the managed identity"
  value       = module.prerequisites.managed_identity_principal_id
  sensitive   = true
}

###############################################################################
# STORAGE
###############################################################################

output "storage_account_name" {
  description = "Name of the storage account containing customization scripts"
  value       = module.prerequisites.storage_account_name
}

output "storage_account_id" {
  description = "Resource ID of the scripts storage account"
  value       = module.prerequisites.storage_account_id
}

output "scripts_container_url" {
  description = "URL of the blob container containing customization scripts"
  value       = "${module.prerequisites.storage_account_primary_blob_endpoint}${module.prerequisites.scripts_container_name}"
}

###############################################################################
# COMPUTE GALLERY
###############################################################################

output "gallery_name" {
  description = "Name of the Azure Compute Gallery"
  value       = module.shared_image_gallery.gallery_name
}

output "gallery_id" {
  description = "Resource ID of the Azure Compute Gallery"
  value       = module.shared_image_gallery.gallery_id
}

output "image_definition_name" {
  description = "Name of the gallery image definition"
  value       = module.shared_image_gallery.image_definition_name
}

output "image_definition_id" {
  description = "Resource ID of the gallery image definition"
  value       = module.shared_image_gallery.image_definition_id
}

###############################################################################
# IMAGE BUILDER
###############################################################################

output "image_template_name" {
  description = "Name of the Image Builder template"
  value       = module.image_builder.image_template_name
}

output "image_template_id" {
  description = "Resource ID of the Image Builder template"
  value       = module.image_builder.image_template_id
}

output "image_version" {
  description = "Version number of the created image"
  value       = local.image_version
}

output "source_image" {
  description = "Source marketplace image used for the build"
  value = {
    publisher = var.source_image_publisher
    offer     = var.source_image_offer
    sku       = var.source_image_sku
    version   = var.source_image_version
  }
}

###############################################################################
# BUILD CONFIGURATION
###############################################################################

output "build_configuration" {
  description = "Configuration settings used for the image build"
  value = {
    vm_size               = var.vm_size
    build_timeout_minutes = var.build_timeout_minutes
    os_disk_size_gb       = var.os_disk_size_gb
    replicate_regions     = var.replicate_regions
    replica_count         = var.replica_count
  }
}

output "installed_applications" {
  description = "Map of applications and their enabled status"
  value = {
    for app_name, app_config in var.applications : app_name => app_config.enabled
  }
}

output "optimizations_enabled" {
  description = "Optimization features that were enabled"
  value = {
    windows_updates = var.run_windows_updates
    avd_optimizer   = var.run_avd_optimizer
    fslogix         = var.enable_fslogix
  }
}

###############################################################################
# DEPLOYMENT INFORMATION
###############################################################################

output "deployment_timestamp" {
  description = "Timestamp when the infrastructure was deployed"
  value       = timestamp()
}

output "tags" {
  description = "Tags applied to all resources"
  value       = local.common_tags
}

###############################################################################
# NEXT STEPS
###############################################################################

output "next_steps" {
  description = "Instructions for using the deployed infrastructure"
  value = <<-EOT

  ============================================================================
  DEPLOYMENT SUCCESSFUL
  ============================================================================

  Your AVD Golden Image infrastructure has been deployed successfully!

  IMAGE BUILDER:
  --------------

  Template name: ${module.image_builder.image_template_name}

  ${var.dry_run ? "Dry-run is enabled, so the image build has NOT been started automatically." : "Auto-run is enabled, so the image build should start automatically after the template is created/updated."}

  To manually start a build (only needed if dry_run = true), run:

    az image builder run \
      --name ${module.image_builder.image_template_name} \
      --resource-group ${module.prerequisites.main_resource_group_name}

  To monitor build status / run history, run:

    az image builder show \
      --name ${module.image_builder.image_template_name} \
      --resource-group ${module.prerequisites.main_resource_group_name} \
      --query lastRunStatus

    az image builder show-runs \
      --name ${module.image_builder.image_template_name} \
      --resource-group ${module.prerequisites.main_resource_group_name}

  GALLERY IMAGE:
  --------------

  Image definition:
    ${module.shared_image_gallery.image_definition_id}

  Version being published:
    ${local.image_version}

  After the build completes, the published image version resource ID is:

    ${module.shared_image_gallery.image_definition_id}/versions/${local.image_version}

  NEXT:
  -----

  Use the published image version when creating your AVD Session Hosts (via AVD
  host pool/session host automation). If you create VMs directly for testing,
  reference the Compute Gallery image version above.

EOT
}

###############################################################################
# PRIVATE OUTPUTS (for module development and debugging)
###############################################################################

output "_debug_info" {
  description = "Debug information (only visible with -json flag)"
  value = {
    terraform_version = "~> 1.9.0"
    azurerm_version   = "~> 4.14.0"
    image_version     = local.image_version
    dry_run_mode      = var.dry_run
  }
}
