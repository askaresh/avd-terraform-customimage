###############################################################################
# PREREQUISITES MODULE - VARIABLES
###############################################################################

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "staging_resource_group" {
  description = "Custom name for staging resource group"
  type        = string
  default     = ""
}

variable "custom_script_storage_account" {
  description = "Existing storage account name for scripts"
  type        = string
  default     = ""
}

variable "enable_private_network" {
  description = "Use existing VNet for build VM"
  type        = bool
  default     = false
}

variable "vnet_resource_group" {
  description = "Resource group containing existing VNet"
  type        = string
  default     = ""
}

variable "vnet_name" {
  description = "Name of existing VNet"
  type        = string
  default     = ""
}

variable "subnet_name" {
  description = "Name of subnet for build VM"
  type        = string
  default     = ""
}
