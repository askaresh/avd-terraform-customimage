###############################################################################
# SHARED IMAGE GALLERY MODULE - VARIABLES
###############################################################################

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "os_type" {
  description = "OS type"
  type        = string
  default     = "Windows"
}

variable "os_state" {
  description = "OS state"
  type        = string
  default     = "Generalized"
}

variable "hyper_v_generation" {
  description = "Hyper-V generation"
  type        = string
  default     = "V2"
}

variable "publisher" {
  description = "Image publisher"
  type        = string
  default     = "AVDGoldenImage"
}

variable "offer" {
  description = "Image offer"
  type        = string
  default     = "Windows11-AVD"
}

variable "sku" {
  description = "Image SKU"
  type        = string
  default     = "win11-24h2-m365-optimized"
}

variable "trusted_launch_supported" {
  description = "Specifies if supports creation of both Trusted Launch VMs and Gen2 VMs with standard security"
  type        = bool
  default     = true
}

variable "accelerated_network_support_enabled" {
  description = "Specifies if the Shared Image supports Accelerated Network"
  type        = bool
  default     = true
}
