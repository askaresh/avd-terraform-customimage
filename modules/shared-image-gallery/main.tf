###############################################################################
# SHARED IMAGE GALLERY MODULE - MAIN
###############################################################################
# Creates Azure Compute Gallery and image definition for AVD golden images
###############################################################################

# Azure Compute Gallery
resource "azurerm_shared_image_gallery" "main" {
  name                = "gal${var.project_name}${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  description         = "Azure Compute Gallery for ${var.project_name} ${var.environment} AVD images"
  
  tags = var.tags
}

# Image Definition
resource "azurerm_shared_image" "avd" {
  name                = "avd-win11-m365-optimized"
  gallery_name        = azurerm_shared_image_gallery.main.name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = var.os_type
  hyper_v_generation  = var.hyper_v_generation

  # Security settings (recommended for AVD)
  trusted_launch_supported            = var.trusted_launch_supported
  accelerated_network_support_enabled = var.accelerated_network_support_enabled

  identifier {
    publisher = var.publisher
    offer     = var.offer
    sku       = var.sku
  }

  tags = merge(
    var.tags,
    {
      ImageType = "AVD-GoldenImage"
    }
  )
}
