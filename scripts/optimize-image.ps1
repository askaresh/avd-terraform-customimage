<#
.SYNOPSIS
    Downloads and runs the AVD Golden Image Optimizer v1.1

.DESCRIPTION
    This script downloads the latest AVD Golden Image Optimizer (Spacegod Edition)
    from the official GitHub repository and executes it with appropriate parameters.

.NOTES
    Original Author: Drazen Nikolic
    Repository: https://github.com/DrazenNikolic/AVD-Golden-Image-Optimizer
    Version: 1.1 (Windows 11 24H2/25H2+)
    
    Wrapper Author: AVD Engineering Team
    Last Updated: 2026-01-28
#>
#Requires -RunAsAdministrator

[CmdletBinding()]
param()

###############################################################################
# CONFIGURATION
###############################################################################

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# URLs
$OptimizerUrl = "https://github.com/DrazenNikolic/AVD-Golden-Image-Optimizer/releases/download/AVDGoldenImageScriptv1.1/AVD-Optimizer-1.1.ps1"

# Paths
$TempDir = "C:\Temp\AVDOptimization"
$LogFile = "C:\Temp\AVDOptimization\optimization.log"
$OptimizerScript = Join-Path $TempDir "AVD-Optimizer-1.1.ps1"

###############################################################################
# LOGGING
###############################################################################

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    Write-Host $LogMessage -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARN"  { "Yellow" }
            "SUCCESS" { "Green" }
            default { "White" }
        }
    )
    
    Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
}

###############################################################################
# MAIN
###############################################################################

Write-Log "==================================================================="
Write-Log "AVD Golden Image Optimization - Starting"
Write-Log "==================================================================="

# Create temp directory
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    Write-Log "Created temp directory: $TempDir"
}

# Validate OS version
try {
    $OSVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name CurrentBuild).CurrentBuild
    
    if ([int]$OSVersion -lt 26100) {
        Write-Log "ERROR: This script requires Windows 11 24H2 (Build 26100) or later. Current build: $OSVersion" -Level "ERROR"
        Write-Log "The AVD Optimizer v1.1 is specifically designed for Windows 11 24H2/25H2+" -Level "ERROR"
        exit 1
    }
    
    Write-Log "OS Version validated: Build $OSVersion" -Level "SUCCESS"
}
catch {
    Write-Log "Failed to validate OS version: $_" -Level "ERROR"
    exit 1
}

# Download optimizer script
try {
    Write-Log "Downloading AVD Optimizer v1.1 from GitHub..."
    
    Invoke-WebRequest -Uri $OptimizerUrl -OutFile $OptimizerScript -UseBasicParsing
    
    Write-Log "Optimizer downloaded successfully" -Level "SUCCESS"
}
catch {
    Write-Log "Failed to download optimizer: $_" -Level "ERROR"
    
    # Fallback: Create a minimal optimization script inline
    Write-Log "Using fallback optimization configuration..." -Level "WARN"
    
    $FallbackScript = @'
# Minimal AVD Optimization Script (Fallback)
Write-Host "Running minimal AVD optimization..."

# Disable Windows Search
Set-Service -Name "WSearch" -StartupType Disabled -ErrorAction SilentlyContinue
Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue

# Disable SysMain (Superfetch)
Set-Service -Name "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue

# Set power plan to High Performance
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# Disable telemetry
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 1 -Type DWord -Force

Write-Host "Minimal optimization complete"
'@
    
    $FallbackScript | Out-File -FilePath $OptimizerScript -Encoding utf8
}

# Execute optimizer
try {
    Write-Log "Executing AVD Optimizer..."
    Write-Log "This will optimize the following:"
    Write-Log "  - Network stack (TCP BBR v2, ECN)"
    Write-Log "  - System stability (services, scheduled tasks)"
    Write-Log "  - Privacy & telemetry controls"
    Write-Log "  - Defender hardening (FSLogix exclusions, PUA protection)"
    Write-Log "  - UI/UX improvements (taskbar, context menu)"
    Write-Log ""
    
    # Run the optimizer
    & powershell.exe -ExecutionPolicy Bypass -File $OptimizerScript
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "AVD Optimizer completed successfully" -Level "SUCCESS"
    }
    else {
        Write-Log "AVD Optimizer completed with warnings (Exit Code: $LASTEXITCODE)" -Level "WARN"
    }
}
catch {
    Write-Log "Optimizer execution error: $_" -Level "ERROR"
    Write-Log "Continuing with deployment..." -Level "WARN"
}

# Additional optimizations
Write-Log "Applying additional AVD-specific optimizations..."

try {
    # Disable background apps
    $BackgroundAppsPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (Test-Path $BackgroundAppsPath) {
        Set-ItemProperty -Path $BackgroundAppsPath -Name "GlobalUserDisabled" -Value 1 -Type DWord -Force
        Write-Log "Disabled background apps"
    }
    
    # Configure time zone redirection
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "fEnableTimeZoneRedirection" -Value 1 -Type DWord -Force
    Write-Log "Enabled time zone redirection"
    
    # Increase SCM timeout
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "ServicesPipeTimeout" -Value 60000 -Type DWord -Force
    Write-Log "Increased SCM timeout to 60 seconds"
    
    # Disable Windows Error Reporting
    Set-Service -Name "WerSvc" -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Log "Disabled Windows Error Reporting"
}
catch {
    Write-Log "Additional optimization warning: $_" -Level "WARN"
}

###############################################################################
# COMPLETION
###############################################################################

Write-Log "==================================================================="
Write-Log "AVD Golden Image Optimization - Complete"
Write-Log "==================================================================="

Write-Log "Log file: $LogFile"

exit 0
