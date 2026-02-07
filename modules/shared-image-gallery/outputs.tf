###############################################################################
# SHARED IMAGE GALLERY MODULE - OUTPUTS
###############################################################################

output "gallery_name" {
  description = "Name of the Compute Gallery"
  value       = azurerm_shared_image_gallery.main.name
}

output "gallery_id" {
  description = "ID of the Compute Gallery"
  value       = azurerm_shared_image_gallery.main.id
}

output "image_definition_name" {
  description = "Name of the image definition"
  value       = azurerm_shared_image.avd.name
}

output "image_definition_id" {
  description = "ID of the image definition"
  value       = azurerm_shared_image.avd.id
}
