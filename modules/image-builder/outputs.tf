###############################################################################
# IMAGE BUILDER MODULE - OUTPUTS
###############################################################################

output "image_template_id" {
  description = "Resource ID of the Image Builder template"
  value       = jsondecode(azurerm_resource_group_template_deployment.image_builder.output_content).imageTemplateId.value
}

output "image_template_name" {
  description = "Name of the Image Builder template"
  value       = var.image_template_name
}

output "deployment_id" {
  description = "ARM deployment ID"
  value       = azurerm_resource_group_template_deployment.image_builder.id
}
