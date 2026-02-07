<#
.SYNOPSIS
    Configures FSLogix for Azure Virtual Desktop

.DESCRIPTION
    Downloads and installs FSLogix, then configures it for AVD environments
    with best practices for profile and Office container management.

.NOTES
    Author: AVD Engineering Team
    Version: 1.0.0
    Last Updated: 2026-01-28
#>
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$FSLogixVersion = "latest"
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$TempDir = "C:\Temp\FSLogix"
$LogFile = "C:\Temp\FSLogix\fslogix-config.log"
$DownloadUrl = "https://aka.ms/fslogix_download"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
}

Write-Log "==================================================================="
Write-Log "FSLogix Installation and Configuration"
Write-Log "==================================================================="

# Create temp directory
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
}

# Download FSLogix
try {
    Write-Log "Downloading FSLogix..."
    $ZipPath = Join-Path $TempDir "FSLogix.zip"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing
    Write-Log "Download complete"
    
    # Extract
    $ExtractPath = Join-Path $TempDir "FSLogix"
    Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force
    
    # Install
    $InstallerPath = Get-ChildItem -Path $ExtractPath -Filter "FSLogixAppsSetup.exe" -Recurse | Select-Object -First 1
    if ($InstallerPath) {
        Write-Log "Installing FSLogix..."
        Start-Process -FilePath $InstallerPath.FullName -ArgumentList "/install /quiet /norestart" -Wait
        Write-Log "FSLogix installed successfully" -Level "SUCCESS"
    }
}
catch {
    Write-Log "FSLogix installation error: $_" -Level "ERROR"
}

# Configure FSLogix
Write-Log "Configuring FSLogix..."

$FSLogixKey = "HKLM:\SOFTWARE\FSLogix\Profiles"
if (-not (Test-Path $FSLogixKey)) {
    New-Item -Path $FSLogixKey -Force | Out-Null
}

# Enable FSLogix
Set-ItemProperty -Path $FSLogixKey -Name "Enabled" -Value 1 -Type DWord
# Set VHD location (placeholder - should be configured per environment)
# Set-ItemProperty -Path $FSLogixKey -Name "VHDLocations" -Value "\\storage\profiles" -Type String
# Profile container settings
Set-ItemProperty -Path $FSLogixKey -Name "SizeInMBs" -Value 30000 -Type DWord
Set-ItemProperty -Path $FSLogixKey -Name "IsDynamic" -Value 1 -Type DWord
Set-ItemProperty -Path $FSLogixKey -Name "VolumeType" -Value "VHDX" -Type String

Write-Log "FSLogix configuration complete" -Level "SUCCESS"

exit 0
