###############################################################################
# PREREQUISITES MODULE - OUTPUTS
###############################################################################

output "main_resource_group_name" {
  description = "Name of the main resource group"
  value       = azurerm_resource_group.main.name
}

output "main_resource_group_id" {
  description = "ID of the main resource group"
  value       = azurerm_resource_group.main.id
}

output "staging_resource_group_name" {
  description = "Name of the staging resource group"
  value       = azurerm_resource_group.staging.name
}

output "staging_resource_group_id" {
  description = "ID of the staging resource group"
  value       = azurerm_resource_group.staging.id
}

output "scripts_resource_group_name" {
  description = "Name of the scripts resource group"
  value       = azurerm_resource_group.scripts.name
}

output "managed_identity_id" {
  description = "ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.image_builder.id
}

output "managed_identity_client_id" {
  description = "Client ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.image_builder.client_id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.image_builder.principal_id
}

output "storage_account_name" {
  description = "Name of the scripts storage account"
  value       = azurerm_storage_account.scripts.name
}

output "storage_account_id" {
  description = "ID of the scripts storage account"
  value       = azurerm_storage_account.scripts.id
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint of the scripts storage account"
  value       = azurerm_storage_account.scripts.primary_blob_endpoint
}

output "scripts_container_name" {
  description = "Name of the scripts container"
  value       = azurerm_storage_container.scripts.name
}

output "scripts_container_url" {
  description = "URL of the scripts container for file downloads"
  value       = "${azurerm_storage_account.scripts.primary_blob_endpoint}${azurerm_storage_container.scripts.name}"
}

output "subnet_id" {
  description = "ID of the subnet for Image Builder (if using private network)"
  value       = var.enable_private_network ? data.azurerm_subnet.image_builder[0].id : null
}

output "rbac_ready" {
  description = "Indicates that RBAC assignments are complete and ready"
  value       = time_sleep.wait_for_rbac.id
}
