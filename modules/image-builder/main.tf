###############################################################################
# IMAGE BUILDER MODULE
# Creates an Azure VM Image Builder (AIB) Image Template that:
#  - pulls a base Marketplace (PlatformImage) image
#  - downloads build artifacts (scripts) using the AIB File customizer
#  - runs PowerShell customization steps (install apps, optimize, FSLogix, finalize)
#  - publishes a version to an Azure Compute Gallery (Shared Image)
#
# NOTE: We intentionally use the "File" customizer for scripts so the Storage
#       container can remain private and access is granted via the user-assigned
#       managed identity (recommended for enterprise environments).
###############################################################################

resource "azurerm_resource_group_template_deployment" "image_builder" {
  name                = local.deployment_name
  resource_group_name = var.resource_group_name
  deployment_mode     = "Incremental"

  template_content = jsonencode(local.arm_template)
}

locals {
  deployment_name = substr("aib-${var.project_name}-${var.environment}", 0, 64)

  script_dir = "c:\\avd-image\\scripts"

  # Build vm_profile - use jsondecode/jsonencode to work around Terraform type checking
  vm_profile = jsondecode(
    var.enable_private_network ? jsonencode({
      vmSize       = var.vm_size
      osDiskSizeGB = var.os_disk_size_gb
      vnetConfig = {
        subnetId = var.subnet_id
      }
    }) : jsonencode({
      vmSize       = var.vm_size
      osDiskSizeGB = var.os_disk_size_gb
    })
  )

  # Ensure directories exist first (File customizer requires destination path to exist)
  customize_prepare = [
    {
      type        = "PowerShell"
      name        = "PrepareBuildFolders"
      runElevated = true
      runAsSystem = true
      inline = [
        "New-Item -Path '${local.script_dir}' -ItemType Directory -Force | Out-Null",
        "New-Item -Path 'c:\\avd-image\\logs' -ItemType Directory -Force | Out-Null"
      ]
    }
  ]

  customize_download_scripts = [
    {
      type           = "File"
      name           = "DownloadInstallApps"
      sourceUri      = var.script_uris.install_apps
      destination    = "${local.script_dir}\\install-apps.ps1"
      sha256Checksum = var.script_sha256.install_apps
    },
    {
      type           = "File"
      name           = "DownloadOptimizeImage"
      sourceUri      = var.script_uris.optimize_image
      destination    = "${local.script_dir}\\optimize-image.ps1"
      sha256Checksum = var.script_sha256.optimize_image
    },
    {
      type           = "File"
      name           = "DownloadConfigureFSLogix"
      sourceUri      = var.script_uris.configure_fslogix
      destination    = "${local.script_dir}\\configure-fslogix.ps1"
      sha256Checksum = var.script_sha256.configure_fslogix
    },
    {
      type           = "File"
      name           = "DownloadFinalizeImage"
      sourceUri      = var.script_uris.finalize_image
      destination    = "${local.script_dir}\\finalize-image.ps1"
      sha256Checksum = var.script_sha256.finalize_image
    }
  ]

  # Convert applications config to base64 for PowerShell (avoids escaping issues)
  apps_config_json   = jsonencode(var.applications_config)
  apps_config_base64 = base64encode(local.apps_config_json)
  
  # Storage URL for offline packages (remove trailing slash if present)
  storage_url = trimsuffix(var.scripts_container_url, "/")

  customize_install_apps = [
    {
      type        = "PowerShell"
      name        = "WriteAppsConfig"
      runElevated = true
      runAsSystem = true
      inline = [
        "$configBase64 = '${local.apps_config_base64}'",
        "$configJson = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($configBase64))",
        "$configPath = '${local.script_dir}\\apps-config.json'",
        "Set-Content -Path $configPath -Value $configJson -Encoding UTF8"
      ]
    },
    {
      type        = "PowerShell"
      name        = "InstallCustomerApps"
      runElevated = true
      runAsSystem = true
      inline = [
        "powershell.exe -ExecutionPolicy Bypass -File ${local.script_dir}\\install-apps.ps1 -AppsConfigPath '${local.script_dir}\\apps-config.json' -StorageAccountUrl '${local.storage_url}'"
      ]
    }
  ]

  customize_windows_updates = var.run_windows_updates ? [
    {
      type           = "WindowsUpdate"
      searchCriteria = "IsInstalled=0"
      filters        = ["exclude:$_.Title -like '*Preview*'", "include:$true"]
      updateLimit    = 40
    }
  ] : []

  customize_optimize = var.run_avd_optimizer ? [
    {
      type        = "PowerShell"
      name        = "OptimizeForAVD"
      runElevated = true
      runAsSystem = true
      inline = [
        "powershell.exe -ExecutionPolicy Bypass -File ${local.script_dir}\\optimize-image.ps1"
      ]
    }
  ] : []

  customize_fslogix = var.enable_fslogix ? [
    {
      type        = "PowerShell"
      name        = "ConfigureFSLogix"
      runElevated = true
      runAsSystem = true
      inline = [
        "powershell.exe -ExecutionPolicy Bypass -File ${local.script_dir}\\configure-fslogix.ps1"
      ]
    }
  ] : []

  customize_finalize = [
    {
      type        = "PowerShell"
      name        = "FinalizeImage"
      runElevated = true
      runAsSystem = true
      inline = [
        "powershell.exe -ExecutionPolicy Bypass -File ${local.script_dir}\\finalize-image.ps1"
      ]
    }
  ]

  customize_steps = concat(
    local.customize_prepare,
    local.customize_download_scripts,
    local.customize_install_apps,
    local.customize_windows_updates,
    local.customize_optimize,
    local.customize_fslogix,
    local.customize_finalize
  )

  run_output_name = substr("sig-${var.project_name}-${var.environment}", 0, 64)

  gallery_image_version_id = "${var.gallery_image_id}/versions/${var.image_version}"

  distribute_steps = [
    {
      type              = "SharedImage"
      runOutputName     = local.run_output_name
      artifactTags      = merge(var.tags, { "aibTemplate" = var.image_template_name })
      excludeFromLatest = var.exclude_from_latest

      # NOTE: For deterministic versioning, we pass the Compute Gallery *version* resourceId.
      # If you prefer auto-versioning, remove /versions/<x.y.z> and set the "versioning" block.
      galleryImageId    = local.gallery_image_version_id

      targetRegions = [
        for region in var.replicate_regions : {
          name              = region
          replicaCount      = var.replica_count
          storageAccountType = var.storage_account_type
        }
      ]
    }
  ]

  arm_template = {
    "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    contentVersion = "1.0.0.0"
    resources = [
      {
        type       = "Microsoft.VirtualMachineImages/imageTemplates"
        apiVersion = "2024-02-01"
        name       = var.image_template_name
        location   = var.location
        tags       = var.tags

        identity = {
          type = "UserAssigned"
          userAssignedIdentities = {
            "${var.managed_identity_id}" = {}
          }
        }

        properties = {
          buildTimeoutInMinutes = var.build_timeout_minutes
          stagingResourceGroup  = var.staging_resource_group_id
          vmProfile             = local.vm_profile

          autoRun = {
            state = var.auto_run ? "Enabled" : "Disabled"
          }

          source = {
            type      = "PlatformImage"
            publisher = var.source_image_publisher
            offer     = var.source_image_offer
            sku       = var.source_image_sku
            version   = var.source_image_version
          }

          customize  = local.customize_steps
          distribute = local.distribute_steps
        }
      }
    ]
    outputs = {
      imageTemplateId = {
        type  = "string"
        value = "[resourceId('Microsoft.VirtualMachineImages/imageTemplates', '${var.image_template_name}')]"
      }
    }
  }
}
