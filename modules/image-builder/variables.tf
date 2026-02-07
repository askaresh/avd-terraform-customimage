###############################################################################
# IMAGE BUILDER MODULE - VARIABLES
###############################################################################

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "staging_resource_group_id" {
  type = string
}

variable "location" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "image_template_name" {
  type        = string
  description = "Name of the Image Builder template resource (must be <= 64 chars)"
}

variable "auto_run" {
  type        = bool
  description = "If true, Image Builder will automatically start a build when the template is created/updated."
  default     = true
}

variable "managed_identity_id" {
  type        = string
  description = "Resource ID of the user-assigned managed identity used by AIB"
}

###############################################################################
# SOURCE IMAGE
###############################################################################

variable "source_image_publisher" {
  type = string
}

variable "source_image_offer" {
  type = string
}

variable "source_image_sku" {
  type = string
}

variable "source_image_version" {
  type    = string
  default = "latest"
}

###############################################################################
# BUILD SETTINGS
###############################################################################

variable "vm_size" {
  type = string
}

variable "build_timeout_minutes" {
  type = number
}

variable "os_disk_size_gb" {
  type = number
}

variable "enable_private_network" {
  type    = bool
  default = false
}

variable "subnet_id" {
  type    = string
  default = null
}

###############################################################################
# BUILD ARTIFACTS (SCRIPTS)
###############################################################################

variable "script_uris" {
  type = object({
    install_apps      = string
    optimize_image    = string
    configure_fslogix = string
    finalize_image    = string
  })
}

variable "script_sha256" {
  type = object({
    install_apps      = string
    optimize_image    = string
    configure_fslogix = string
    finalize_image    = string
  })
}

###############################################################################
# APP & FEATURE FLAGS
###############################################################################

variable "applications_config" {
  type        = any
  description = "Application configuration map for multi-strategy installation"
  default     = {}
}

variable "scripts_container_url" {
  type        = string
  description = "URL of the scripts container for offline packages"
  default     = ""
}

# Legacy variables for backward compatibility
variable "install_chrome" {
  type    = bool
  default = null
}

variable "install_adobe_reader" {
  type    = bool
  default = null
}

variable "install_7zip" {
  type    = bool
  default = null
}

variable "run_windows_updates" {
  type    = bool
  default = true
}

variable "run_avd_optimizer" {
  type    = bool
  default = true
}

variable "enable_fslogix" {
  type    = bool
  default = true
}

###############################################################################
# AZURE COMPUTE GALLERY OUTPUT
###############################################################################

variable "gallery_image_id" {
  type        = string
  description = "Resource ID of the Azure Compute Gallery image definition"
}

variable "image_version" {
  type        = string
  description = "Version to publish into the Compute Gallery image definition (x.y.z)"
}

variable "exclude_from_latest" {
  type    = bool
  default = false
}

variable "replicate_regions" {
  type = list(string)
}

variable "replica_count" {
  type = number
}

variable "storage_account_type" {
  type = string
}
