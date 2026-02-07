###############################################################################
# TERRAFORM STATE BACKEND CONFIGURATION
###############################################################################
# This file configures remote state storage in Azure Storage Account.
# Remote state enables team collaboration, locking, and state encryption.
#
# IMPORTANT: Before running terraform init:
# 1. Create Azure Storage Account manually or use setup script
# 2. Update the backend configuration with your values
# 3. Uncomment the backend block
#
# Setup Instructions:
# az storage account create \
#   --name <storage-account-name> \
#   --resource-group <rg-name> \
#   --location <location> \
#   --sku Standard_LRS \
#   --encryption-services blob
#
# az storage container create \
#   --name tfstate \
#   --account-name <storage-account-name>
###############################################################################

# OPTION 1: Azure Storage Backend (Recommended for Production)
# Uncomment and configure after creating storage account
/*
terraform {
  backend "azurerm" {
    # Storage account name - must be globally unique
    storage_account_name = "stavdtfstate${var.environment}"
    
    # Container name for state files
    container_name       = "tfstate"
    
    # State file name - use descriptive name
    # Pattern: <project>-<environment>-<component>.tfstate
    key                  = "avd-image-builder-${var.environment}.tfstate"
    
    # Resource group containing the storage account
    resource_group_name  = "rg-avd-tfstate-${var.environment}"
    
    # Enable state locking with blob lease
    use_azuread_auth     = true
    
    # Use managed identity or service principal for authentication
    # For local development, relies on Azure CLI authentication
    
    # Optional: Specify subscription if different from default
    # subscription_id      = "00000000-0000-0000-0000-000000000000"
    
    # Optional: Specify tenant ID for multi-tenant scenarios
    # tenant_id            = "00000000-0000-0000-0000-000000000000"
  }
}
*/

# OPTION 2: Local Backend (Development Only)
# Default if no backend block is specified
# State file stored locally as terraform.tfstate
# NOT recommended for production or team environments

###############################################################################
# BACKEND MIGRATION INSTRUCTIONS
###############################################################################
# To migrate from local to remote backend:
#
# 1. Ensure you have existing local state (terraform.tfstate)
# 2. Create Azure Storage Account and container (see setup instructions above)
# 3. Uncomment the backend block above and configure values
# 4. Run: terraform init -migrate-state
# 5. Confirm migration when prompted
# 6. Verify state in Azure Storage
# 7. Commit backend.tf changes to version control
#
# To migrate from remote to different remote backend:
# 1. Update backend configuration with new values
# 2. Run: terraform init -migrate-state
# 3. Confirm migration when prompted
###############################################################################

###############################################################################
# STATE LOCKING
###############################################################################
# Azure Storage backend provides automatic state locking using blob leases.
# This prevents concurrent modifications and state corruption.
#
# Lock behavior:
# - Automatically acquired when running terraform plan/apply
# - Released when operation completes
# - Timeout: 20 seconds (default)
# - Force unlock: terraform force-unlock <LOCK_ID>
#
# Best Practices:
# - Never manually edit remote state files
# - Use terraform state commands for state manipulation
# - Regularly backup state files
# - Enable soft delete on storage account
# - Enable versioning for state files
###############################################################################

###############################################################################
# STATE ENCRYPTION
###############################################################################
# Azure Storage encrypts all data at rest by default using Microsoft-managed keys.
# For enhanced security, you can use customer-managed keys (CMK) with Azure Key Vault.
#
# To enable CMK encryption:
# 1. Create Azure Key Vault
# 2. Create encryption key in Key Vault
# 3. Grant storage account access to Key Vault
# 4. Configure storage account to use CMK
#
# Example Azure CLI command:
# az storage account update \
#   --name <storage-account-name> \
#   --resource-group <rg-name> \
#   --encryption-key-source Microsoft.Keyvault \
#   --encryption-key-vault <key-vault-url> \
#   --encryption-key-name <key-name>
###############################################################################

###############################################################################
# WORKSPACE MANAGEMENT
###############################################################################
# Terraform workspaces allow multiple state files for the same configuration.
# Useful for managing multiple environments (dev, staging, prod).
#
# Commands:
# terraform workspace new dev
# terraform workspace new staging
# terraform workspace new prod
# terraform workspace select dev
# terraform workspace list
#
# State file naming with workspaces:
# Default workspace: <key>
# Named workspace: env:/<workspace-name>/<key>
#
# Example:
# Default: avd-image-builder-prod.tfstate
# Dev workspace: env:/dev/avd-image-builder-prod.tfstate
###############################################################################

###############################################################################
# DISASTER RECOVERY
###############################################################################
# Implement backup strategy for state files:
#
# 1. Enable soft delete on storage account (90 days retention)
#    az storage blob service-properties update \
#      --account-name <storage-account-name> \
#      --enable-delete-retention true \
#      --delete-retention-days 90
#
# 2. Enable versioning on storage account
#    az storage account blob-service-properties update \
#      --account-name <storage-account-name> \
#      --enable-versioning true
#
# 3. Configure geo-redundancy (GRS or GZRS)
#    az storage account update \
#      --name <storage-account-name> \
#      --sku Standard_GRS
#
# 4. Implement automated backups to secondary location
#    Use Azure Backup or custom scripts
#
# 5. Document recovery procedures
#    Test recovery process quarterly
###############################################################################

###############################################################################
# SECURITY BEST PRACTICES
###############################################################################
# 1. Network Security:
#    - Enable firewall rules on storage account
#    - Allow access only from trusted networks
#    - Use private endpoints for enhanced security
#
# 2. Access Control:
#    - Use Azure AD authentication (use_azuread_auth = true)
#    - Assign minimal required permissions
#    - Use managed identities for CI/CD pipelines
#    - Regularly audit access logs
#
# 3. Compliance:
#    - Enable Azure Policy for storage accounts
#    - Implement compliance standards (PCI, HIPAA, etc.)
#    - Regular security audits
#
# 4. Monitoring:
#    - Enable diagnostic logs on storage account
#    - Set up alerts for state modifications
#    - Monitor for unauthorized access attempts
###############################################################################
