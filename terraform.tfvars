# Terraform Variables - AVD Golden Image Multi-Strategy Test
# Australia East Region - Testing Winget + Direct Fallback

# Core variables
# Note: subscription_id is loaded from ARM_SUBSCRIPTION_ID env var (via .env file)
project_name    = "avdtest"
environment     = "dev"
location        = "australiaeast"

# Tagging
cost_center = "IT-AVD"
owner_email = "avd-team@company.com"

# Source image (Windows 11 24H2 with M365 Apps + Teams pre-installed)
source_image_publisher = "MicrosoftWindowsDesktop"
source_image_offer     = "office-365"
source_image_sku       = "win11-24h2-avd-m365"
source_image_version   = "latest"

# Build configuration
vm_size               = "Standard_D4s_v3"
build_timeout_minutes = 180
os_disk_size_gb       = 256

# Gallery configuration
replicate_regions    = ["australiaeast"]
replica_count        = 1
storage_account_type = "Standard_LRS"

###############################################################################
# MULTI-STRATEGY APPLICATION CONFIGURATION
###############################################################################
# Testing: Winget as primary method with Direct fallback

applications = {
  chrome = {
    enabled     = true
    method      = "winget"
    description = "Google Chrome Enterprise"
    
    winget_config = {
      package_id = "Google.Chrome"
      scope      = "machine"
    }
    
    # Fallback to direct download if winget fails
    fallback = {
      method = "direct"
      direct_config = {
        download_url = "https://dl.google.com/chrome/install/googlechromestandaloneenterprise64.msi"
        install_type = "msi"
        install_args = "/quiet /norestart"
      }
    }
    
    skip_if_installed = {
      check_type = "file"
      check_path = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
    }
  }

  adobe_reader = {
    enabled     = true
    method      = "winget"
    description = "Adobe Acrobat Reader DC"
    
    winget_config = {
      package_id = "Adobe.Acrobat.Reader.64-bit"
      scope      = "machine"
    }
    
    fallback = {
      method = "direct"
      direct_config = {
        download_url = "https://ardownload2.adobe.com/pub/adobe/acrobat/win/AcrobatDC/2400920063/AcroRdrDCx642400920063_MUI.exe"
        install_type = "exe"
        install_args = "/sAll /rs /msi EULA_ACCEPT=YES"
      }
    }
    
    skip_if_installed = {
      check_type = "file"
      check_path = "C:\\Program Files\\Adobe\\Acrobat DC\\Acrobat\\Acrobat.exe"
    }
  }

  seven_zip = {
    enabled     = true
    method      = "winget"
    description = "7-Zip file archiver"
    
    winget_config = {
      package_id = "7zip.7zip"
      scope      = "machine"
    }
    
    fallback = {
      method = "direct"
      direct_config = {
        download_url = "https://www.7-zip.org/a/7z2408-x64.msi"
        install_type = "msi"
        install_args = "/quiet /norestart"
      }
    }
    
    skip_if_installed = {
      check_type = "file"
      check_path = "C:\\Program Files\\7-Zip\\7z.exe"
    }
  }
}

# Optimization
run_windows_updates = true
run_avd_optimizer   = true
enable_fslogix      = true

# Network (using public endpoint)
enable_private_network = false

# Test mode - build actual image
dry_run = false
