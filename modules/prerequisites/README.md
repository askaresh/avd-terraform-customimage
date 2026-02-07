# Module: prerequisites

Creates the baseline resources required to run Azure VM Image Builder (AIB) securely:

- Resource groups
  - **main**: holds the AIB template and supporting resources
  - **staging**: used by AIB to create temporary build resources
  - **scripts**: hosts the storage account for build artifacts (PowerShell scripts)

- User-assigned managed identity (UAMI) used by AIB
- RBAC assignments so AIB can:
  - read scripts from private blob storage
  - create/modify resources in the staging RG
  - write image versions to Azure Compute Gallery (via a custom role)

- Storage account + private container for scripts

Optional:
- If `enable_private_network = true`, accepts an existing VNet/subnet for AIB build VM placement.

## Outputs
See `outputs.tf` for IDs (identity IDs, RG names/IDs, storage account/container, subnet id, etc.).
