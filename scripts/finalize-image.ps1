<#
.SYNOPSIS
    Final image preparation and cleanup

.DESCRIPTION
    Performs final steps before generalizing the image:
    - Cleans temporary files
    - Optimizes storage
    - Prepares for Sysprep
    - Creates validation markers

.NOTES
    Author: AVD Engineering Team
    Version: 1.0.0
    Last Updated: 2026-01-28
#>
#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'
$LogFile = "C:\Temp\finalize.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
}

Write-Log "==================================================================="
Write-Log "Image Finalization Starting"
Write-Log "==================================================================="

# Clean temp files
Write-Log "Cleaning temporary files..."
Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Temp\*" -Recurse -Force -Include "*.exe","*.msi","*.zip" -ErrorAction SilentlyContinue

# Clean Windows Update cache
Write-Log "Cleaning Windows Update cache..."
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue

# Disk cleanup
Write-Log "Running disk cleanup..."
Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue

# Defragment (if needed)
Write-Log "Optimizing drives..."
Optimize-Volume -DriveLetter C -Analyze -ErrorAction SilentlyContinue

# Create build info file
$BuildInfo = @{
    BuildDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    OSVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild
    ImageVersion = "1.0.0"
} | ConvertTo-Json

$BuildInfo | Out-File -FilePath "C:\BuildInfo.json" -Encoding utf8

Write-Log "==================================================================="
Write-Log "Image Finalization Complete"
Write-Log "==================================================================="

exit 0
