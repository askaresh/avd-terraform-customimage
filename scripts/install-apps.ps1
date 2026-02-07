<#
.SYNOPSIS
    Multi-strategy application installer for Azure Virtual Desktop golden images.

.DESCRIPTION
    This script supports multiple installation methods:
    - DIRECT: Download and install from URL
    - WINGET: Install via Windows Package Manager
    - OFFLINE: Install from pre-staged packages in blob storage
    - PSADT: Install using PSAppDeployToolkit packages

    Configuration is passed as JSON, allowing per-application method selection
    with fallback support.

.PARAMETER AppsConfigJson
    JSON string containing application configuration

.PARAMETER StorageAccountUrl
    Base URL for blob storage (for offline/PSADT packages)

.NOTES
    Author: AVD Engineering Team
    Version: 2.0.1
    Last Updated: 2026-02-05
    Compatible with: PowerShell 5.1+
#>
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$AppsConfigJson = "",

    [Parameter(Mandatory = $false)]
    [string]$AppsConfigPath = "",

    [Parameter(Mandatory = $false)]
    [string]$StorageAccountUrl = ""
)

###############################################################################
# CONFIGURATION
###############################################################################

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# Paths
$TempDir = "C:\Temp\AppInstalls"
$LogFile = "C:\Temp\AppInstalls\install-apps.log"
$WingetDir = "C:\Temp\Winget"

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
    
    $Color = switch ($Level) {
        "ERROR"   { "Red" }
        "WARN"    { "Yellow" }
        "SUCCESS" { "Green" }
        "DEBUG"   { "Cyan" }
        default   { "White" }
    }
    
    Write-Host $LogMessage -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
}

###############################################################################
# HELPER - Convert PSCustomObject to Hashtable (PS 5.1 compatible)
###############################################################################

function ConvertTo-Hashtable {
    param(
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )
    
    process {
        if ($null -eq $InputObject) { return $null }
        
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(
                foreach ($object in $InputObject) { ConvertTo-Hashtable -InputObject $object }
            )
            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject]) {
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
            }
            $hash
        }
        else {
            $InputObject
        }
    }
}

###############################################################################
# INITIALIZATION
###############################################################################

Write-Log "=================================================================="
Write-Log "Multi-Strategy Application Installer v2.0.1"
Write-Log "=================================================================="

# Create directories
foreach ($dir in @($TempDir, $WingetDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Log "Created directory: $dir"
    }
}

# Parse configuration
try {
    # Read from file if path provided, otherwise use JSON string
    if ($AppsConfigPath -and (Test-Path $AppsConfigPath)) {
        Write-Log "Reading configuration from file: $AppsConfigPath"
        $AppsConfigJson = Get-Content -Path $AppsConfigPath -Raw -Encoding UTF8
    }
    
    if (-not $AppsConfigJson) {
        Write-Log "No configuration provided (AppsConfigJson empty and AppsConfigPath not found)" -Level "ERROR"
        exit 1
    }
    
    $JsonObj = $AppsConfigJson | ConvertFrom-Json
    $Applications = ConvertTo-Hashtable -InputObject $JsonObj
    Write-Log "Loaded configuration for $($Applications.Count) applications"
}
catch {
    Write-Log "Failed to parse applications config: $_" -Level "ERROR"
    exit 1
}

###############################################################################
# HELPER FUNCTIONS
###############################################################################

function Download-File {
    param(
        [string]$Url,
        [string]$OutFile
    )
    
    try {
        Write-Log "Downloading: $Url"
        
        # Try BITS transfer first (more reliable)
        try {
            Start-BitsTransfer -Source $Url -Destination $OutFile -ErrorAction Stop
        }
        catch {
            # Fallback to Invoke-WebRequest
            Write-Log "BITS failed, using WebRequest..." -Level "DEBUG"
            Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
        }
        
        if (Test-Path $OutFile) {
            $Size = (Get-Item $OutFile).Length / 1MB
            Write-Log "Downloaded: $OutFile ($([math]::Round($Size, 2)) MB)" -Level "SUCCESS"
            return $true
        }
        return $false
    }
    catch {
        Write-Log "Download failed: $_" -Level "ERROR"
        return $false
    }
}

function Get-PropertyValue {
    param(
        $Object,
        [string]$PropertyName,
        $Default = $null
    )
    
    if ($null -eq $Object) { return $Default }
    
    if ($Object -is [hashtable]) {
        if ($Object.ContainsKey($PropertyName)) {
            return $Object[$PropertyName]
        }
        return $Default
    }
    
    if ($Object.PSObject.Properties.Name -contains $PropertyName) {
        $value = $Object.$PropertyName
        if ($null -ne $value -and $value -ne "") {
            return $value
        }
    }
    return $Default
}

function Test-AlreadyInstalled {
    param($CheckConfig)
    
    if ($null -eq $CheckConfig) { return $false }
    
    $checkType = Get-PropertyValue -Object $CheckConfig -PropertyName "check_type"
    $checkPath = Get-PropertyValue -Object $CheckConfig -PropertyName "check_path"
    
    if (-not $checkType -or -not $checkPath) { return $false }
    
    try {
        switch ($checkType) {
            "file" {
                $result = Test-Path $checkPath
                if ($result) { Write-Log "Pre-check: File exists at $checkPath" -Level "DEBUG" }
                return $result
            }
            "registry" {
                $result = Test-Path $checkPath
                if ($result) { Write-Log "Pre-check: Registry key exists at $checkPath" -Level "DEBUG" }
                return $result
            }
            "appx" {
                $app = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $checkPath }
                if ($app) { Write-Log "Pre-check: AppX package found: $($app.DisplayName)" -Level "DEBUG" }
                return ($null -ne $app)
            }
            default {
                return $false
            }
        }
    }
    catch {
        Write-Log "Pre-check failed: $_" -Level "WARN"
        return $false
    }
}

function Test-InstallSuccess {
    param(
        [int]$ExitCode,
        [string]$AppName
    )
    
    $SuccessCodes = @(0, 3010, 1641) # Success, Soft reboot, Hard reboot
    
    if ($ExitCode -in $SuccessCodes) {
        Write-Log "[$AppName] Exit code $ExitCode - SUCCESS" -Level "SUCCESS"
        return $true
    }
    else {
        Write-Log "[$AppName] Exit code $ExitCode - FAILED" -Level "ERROR"
        return $false
    }
}

###############################################################################
# WINGET INSTALLATION
###############################################################################

function Initialize-Winget {
    Write-Log "Initializing Winget..." -Level "DEBUG"
    
    # Check if winget is already available
    $WingetPath = Get-Command winget -ErrorAction SilentlyContinue
    if ($WingetPath) {
        Write-Log "Winget found at: $($WingetPath.Source)" -Level "DEBUG"
        return $WingetPath.Source
    }
    
    # Try to find winget in WindowsApps
    $WingetExe = Get-ChildItem "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | 
                 Sort-Object LastWriteTime -Descending | 
                 Select-Object -First 1
    
    if ($WingetExe) {
        Write-Log "Winget found at: $($WingetExe.FullName)" -Level "DEBUG"
        return $WingetExe.FullName
    }
    
    # Install winget and dependencies
    Write-Log "Winget not found, installing..." -Level "WARN"
    
    try {
        # Download dependencies
        $VCLibsUrl = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
        $UIXamlUrl = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx"
        $WingetUrl = "https://aka.ms/getwinget"
        
        $VCLibsPath = Join-Path $WingetDir "Microsoft.VCLibs.x64.14.00.Desktop.appx"
        $UIXamlPath = Join-Path $WingetDir "Microsoft.UI.Xaml.2.8.x64.appx"
        $WingetPkgPath = Join-Path $WingetDir "Microsoft.DesktopAppInstaller.msixbundle"
        
        # Download packages
        Download-File -Url $VCLibsUrl -OutFile $VCLibsPath
        Download-File -Url $UIXamlUrl -OutFile $UIXamlPath
        Download-File -Url $WingetUrl -OutFile $WingetPkgPath
        
        # Install packages
        Write-Log "Installing VCLibs..." -Level "DEBUG"
        Add-AppxProvisionedPackage -Online -PackagePath $VCLibsPath -SkipLicense -ErrorAction SilentlyContinue
        
        Write-Log "Installing UI.Xaml..." -Level "DEBUG"
        Add-AppxProvisionedPackage -Online -PackagePath $UIXamlPath -SkipLicense -ErrorAction SilentlyContinue
        
        Write-Log "Installing Winget..." -Level "DEBUG"
        Add-AppxProvisionedPackage -Online -PackagePath $WingetPkgPath -SkipLicense -ErrorAction SilentlyContinue
        
        # Find the installed winget
        Start-Sleep -Seconds 5
        $WingetExe = Get-ChildItem "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | 
                     Sort-Object LastWriteTime -Descending | 
                     Select-Object -First 1
        
        if ($WingetExe) {
            Write-Log "Winget installed successfully" -Level "SUCCESS"
            return $WingetExe.FullName
        }
    }
    catch {
        Write-Log "Failed to install Winget: $_" -Level "ERROR"
    }
    
    return $null
}

###############################################################################
# INSTALLATION METHODS
###############################################################################

function Install-Direct {
    param(
        [string]$AppName,
        $Config
    )
    
    Write-Log "[$AppName] Method: DIRECT"
    
    if ($null -eq $Config) {
        Write-Log "[$AppName] No direct_config provided" -Level "ERROR"
        return $false
    }
    
    $downloadUrl = Get-PropertyValue -Object $Config -PropertyName "download_url"
    $installType = Get-PropertyValue -Object $Config -PropertyName "install_type"
    $installArgs = Get-PropertyValue -Object $Config -PropertyName "install_args" -Default ""
    
    if (-not $downloadUrl) {
        Write-Log "[$AppName] No download_url in config" -Level "ERROR"
        return $false
    }
    
    $FileName = Split-Path $downloadUrl -Leaf
    # Clean up URL parameters from filename
    if ($FileName -match '\?') {
        $FileName = $FileName.Split('?')[0]
    }
    if (-not $FileName -or $FileName.Length -lt 3) {
        $FileName = "$AppName.$installType"
    }
    
    $LocalPath = Join-Path $TempDir $FileName
    
    if (-not (Download-File -Url $downloadUrl -OutFile $LocalPath)) {
        return $false
    }
    
    Write-Log "[$AppName] Installing ($installType)..."
    
    try {
        switch ($installType.ToLower()) {
            "msi" {
                $Args = "/i `"$LocalPath`" $installArgs"
                if ($installArgs -notmatch '/quiet|/qn') {
                    $Args += " /quiet /norestart"
                }
                $Process = Start-Process "msiexec.exe" -ArgumentList $Args -Wait -PassThru -NoNewWindow
                return (Test-InstallSuccess -ExitCode $Process.ExitCode -AppName $AppName)
            }
            "exe" {
                $Process = Start-Process $LocalPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
                return (Test-InstallSuccess -ExitCode $Process.ExitCode -AppName $AppName)
            }
            "msix" {
                Add-AppxProvisionedPackage -Online -PackagePath $LocalPath -SkipLicense
                Write-Log "[$AppName] MSIX provisioned" -Level "SUCCESS"
                return $true
            }
            default {
                Write-Log "[$AppName] Unknown install type: $installType" -Level "ERROR"
                return $false
            }
        }
    }
    catch {
        Write-Log "[$AppName] Installation error: $_" -Level "ERROR"
        return $false
    }
}

function Install-Winget {
    param(
        [string]$AppName,
        $Config
    )
    
    Write-Log "[$AppName] Method: WINGET"
    
    if ($null -eq $Config) {
        Write-Log "[$AppName] No winget_config provided" -Level "ERROR"
        return $false
    }
    
    $WingetExe = Initialize-Winget
    
    if (-not $WingetExe) {
        Write-Log "[$AppName] Winget not available" -Level "ERROR"
        return $false
    }
    
    $packageId = Get-PropertyValue -Object $Config -PropertyName "package_id"
    $scope = Get-PropertyValue -Object $Config -PropertyName "scope" -Default "machine"
    $version = Get-PropertyValue -Object $Config -PropertyName "version"
    
    if (-not $packageId) {
        Write-Log "[$AppName] No package_id in config" -Level "ERROR"
        return $false
    }
    
    Write-Log "[$AppName] Installing: $packageId"
    
    $Args = @(
        "install"
        "--id", $packageId
        "--scope", $scope
        "--silent"
        "--accept-package-agreements"
        "--accept-source-agreements"
        "--disable-interactivity"
    )
    
    if ($version -and $version -ne "") {
        $Args += @("--version", $version)
    }
    
    try {
        $Process = Start-Process $WingetExe -ArgumentList $Args -Wait -PassThru -NoNewWindow
        return (Test-InstallSuccess -ExitCode $Process.ExitCode -AppName $AppName)
    }
    catch {
        Write-Log "[$AppName] Winget error: $_" -Level "ERROR"
        return $false
    }
}

function Install-Offline {
    param(
        [string]$AppName,
        $Config,
        [string]$StorageUrl
    )
    
    Write-Log "[$AppName] Method: OFFLINE"
    
    if ($null -eq $Config) {
        Write-Log "[$AppName] No offline_config provided" -Level "ERROR"
        return $false
    }
    
    if (-not $StorageUrl) {
        Write-Log "[$AppName] StorageAccountUrl not provided for offline install" -Level "ERROR"
        return $false
    }
    
    $blobPath = Get-PropertyValue -Object $Config -PropertyName "blob_path"
    $installType = Get-PropertyValue -Object $Config -PropertyName "install_type"
    $installArgs = Get-PropertyValue -Object $Config -PropertyName "install_args" -Default ""
    $transform = Get-PropertyValue -Object $Config -PropertyName "transform"
    
    $FileName = Split-Path $blobPath -Leaf
    $LocalPath = Join-Path $TempDir $FileName
    $BlobUrl = "$StorageUrl/$blobPath"
    
    if (-not (Download-File -Url $BlobUrl -OutFile $LocalPath)) {
        return $false
    }
    
    # Download transform if specified
    $TransformArg = ""
    if ($transform -and $transform -ne "") {
        $TransformFile = Split-Path $transform -Leaf
        $TransformPath = Join-Path $TempDir $TransformFile
        $TransformUrl = "$StorageUrl/$transform"
        
        if (Download-File -Url $TransformUrl -OutFile $TransformPath) {
            $TransformArg = " TRANSFORMS=`"$TransformPath`""
        }
    }
    
    Write-Log "[$AppName] Installing ($installType)..."
    
    try {
        switch ($installType.ToLower()) {
            "msi" {
                $Args = "/i `"$LocalPath`" $installArgs$TransformArg"
                if ($installArgs -notmatch '/quiet|/qn') {
                    $Args += " /quiet /norestart"
                }
                $Process = Start-Process "msiexec.exe" -ArgumentList $Args -Wait -PassThru -NoNewWindow
                return (Test-InstallSuccess -ExitCode $Process.ExitCode -AppName $AppName)
            }
            "exe" {
                $Process = Start-Process $LocalPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
                return (Test-InstallSuccess -ExitCode $Process.ExitCode -AppName $AppName)
            }
            "msix" {
                Add-AppxProvisionedPackage -Online -PackagePath $LocalPath -SkipLicense
                Write-Log "[$AppName] MSIX provisioned" -Level "SUCCESS"
                return $true
            }
            "appv" {
                Import-Module AppvClient -ErrorAction Stop
                Add-AppvClientPackage -Path $LocalPath | Publish-AppvClientPackage -Global
                Write-Log "[$AppName] App-V package published" -Level "SUCCESS"
                return $true
            }
            default {
                Write-Log "[$AppName] Unknown install type: $installType" -Level "ERROR"
                return $false
            }
        }
    }
    catch {
        Write-Log "[$AppName] Installation error: $_" -Level "ERROR"
        return $false
    }
}

function Install-PSADT {
    param(
        [string]$AppName,
        $Config,
        [string]$StorageUrl
    )
    
    Write-Log "[$AppName] Method: PSADT"
    
    if ($null -eq $Config) {
        Write-Log "[$AppName] No psadt_config provided" -Level "ERROR"
        return $false
    }
    
    if (-not $StorageUrl) {
        Write-Log "[$AppName] StorageAccountUrl not provided for PSADT install" -Level "ERROR"
        return $false
    }
    
    $packagePath = Get-PropertyValue -Object $Config -PropertyName "package_path"
    
    $PackageDir = Join-Path $TempDir "PSADT\$AppName"
    $ZipPath = Join-Path $TempDir "$AppName-psadt.zip"
    $BlobUrl = "$StorageUrl/$packagePath"
    
    # Download package
    if (-not (Download-File -Url $BlobUrl -OutFile $ZipPath)) {
        return $false
    }
    
    # Extract
    try {
        if (Test-Path $PackageDir) {
            Remove-Item $PackageDir -Recurse -Force
        }
        Expand-Archive -Path $ZipPath -DestinationPath $PackageDir -Force
        Write-Log "[$AppName] Extracted PSADT package"
    }
    catch {
        Write-Log "[$AppName] Failed to extract package: $_" -Level "ERROR"
        return $false
    }
    
    # Find Deploy-Application.ps1
    $DeployScript = Get-ChildItem -Path $PackageDir -Filter "Deploy-Application.ps1" -Recurse | 
                    Select-Object -First 1
    
    if (-not $DeployScript) {
        Write-Log "[$AppName] Deploy-Application.ps1 not found in package" -Level "ERROR"
        return $false
    }
    
    Write-Log "[$AppName] Executing PSADT: $($DeployScript.FullName)"
    
    try {
        $Process = Start-Process "powershell.exe" -ArgumentList @(
            "-ExecutionPolicy", "Bypass"
            "-NoProfile"
            "-File", $DeployScript.FullName
            "-DeploymentType", "Install"
            "-DeployMode", "NonInteractive"
            "-AllowRebootPassThru"
        ) -Wait -PassThru -NoNewWindow
        
        # PSADT exit codes
        $SuccessCodes = @(0, 1641, 3010)
        
        if ($Process.ExitCode -in $SuccessCodes) {
            Write-Log "[$AppName] PSADT installation succeeded" -Level "SUCCESS"
            return $true
        }
        else {
            Write-Log "[$AppName] PSADT exit code: $($Process.ExitCode)" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "[$AppName] PSADT error: $_" -Level "ERROR"
        return $false
    }
}

###############################################################################
# MAIN INSTALLATION LOGIC
###############################################################################

function Install-Application {
    param(
        [string]$AppName,
        $AppConfig,
        [string]$StorageUrl
    )
    
    $description = Get-PropertyValue -Object $AppConfig -PropertyName "description" -Default $AppName
    $method = Get-PropertyValue -Object $AppConfig -PropertyName "method" -Default "direct"
    $skipIfInstalled = Get-PropertyValue -Object $AppConfig -PropertyName "skip_if_installed"
    $fallback = Get-PropertyValue -Object $AppConfig -PropertyName "fallback"
    
    Write-Log "------------------------------------------------------------------"
    Write-Log "[$AppName] Starting installation"
    Write-Log "[$AppName] Description: $description"
    Write-Log "[$AppName] Primary method: $method"
    
    # Check if already installed
    if ($skipIfInstalled -and (Test-AlreadyInstalled -CheckConfig $skipIfInstalled)) {
        Write-Log "[$AppName] Already installed - SKIPPING" -Level "SUCCESS"
        return @{ Success = $true; Method = "skipped"; Skipped = $true }
    }
    
    # Get config for primary method
    $directConfig = Get-PropertyValue -Object $AppConfig -PropertyName "direct_config"
    $wingetConfig = Get-PropertyValue -Object $AppConfig -PropertyName "winget_config"
    $offlineConfig = Get-PropertyValue -Object $AppConfig -PropertyName "offline_config"
    $psadtConfig = Get-PropertyValue -Object $AppConfig -PropertyName "psadt_config"
    
    # Try primary method
    $Success = switch ($method.ToLower()) {
        "direct"  { Install-Direct  -AppName $AppName -Config $directConfig }
        "winget"  { Install-Winget  -AppName $AppName -Config $wingetConfig }
        "offline" { Install-Offline -AppName $AppName -Config $offlineConfig -StorageUrl $StorageUrl }
        "psadt"   { Install-PSADT   -AppName $AppName -Config $psadtConfig -StorageUrl $StorageUrl }
        default   { 
            Write-Log "[$AppName] Unknown method: $method" -Level "ERROR"
            $false 
        }
    }
    
    # Try fallback if primary failed
    if (-not $Success -and $fallback) {
        $fallbackMethod = Get-PropertyValue -Object $fallback -PropertyName "method"
        Write-Log "[$AppName] Primary method failed, trying fallback: $fallbackMethod" -Level "WARN"
        
        $fallbackDirectConfig = Get-PropertyValue -Object $fallback -PropertyName "direct_config"
        $fallbackWingetConfig = Get-PropertyValue -Object $fallback -PropertyName "winget_config"
        
        $Success = switch ($fallbackMethod.ToLower()) {
            "direct"  { Install-Direct  -AppName $AppName -Config $fallbackDirectConfig }
            "winget"  { Install-Winget  -AppName $AppName -Config $fallbackWingetConfig }
            default   { $false }
        }
        
        if ($Success) {
            return @{ Success = $true; Method = "fallback:$fallbackMethod"; Skipped = $false }
        }
    }
    
    if ($Success) {
        return @{ Success = $true; Method = $method; Skipped = $false }
    }
    else {
        return @{ Success = $false; Method = $method; Skipped = $false }
    }
}

###############################################################################
# MAIN EXECUTION
###############################################################################

$Results = @{}

# Get enabled applications
$EnabledApps = @()
foreach ($key in $Applications.Keys) {
    $appConfig = $Applications[$key]
    $enabled = Get-PropertyValue -Object $appConfig -PropertyName "enabled" -Default $false
    if ($enabled -eq $true) {
        $EnabledApps += @{ Name = $key; Config = $appConfig }
    }
}

Write-Log "=================================================================="
Write-Log "Processing $($EnabledApps.Count) enabled applications"
Write-Log "=================================================================="

foreach ($app in $EnabledApps) {
    $AppName = $app.Name
    $AppConfig = $app.Config
    
    try {
        $Result = Install-Application -AppName $AppName -AppConfig $AppConfig -StorageUrl $StorageAccountUrl
        $Results[$AppName] = $Result
    }
    catch {
        Write-Log "[$AppName] Unexpected error: $_" -Level "ERROR"
        $Results[$AppName] = @{ Success = $false; Method = "error"; Skipped = $false }
    }
}

###############################################################################
# POST-INSTALLATION CONFIGURATION
###############################################################################

Write-Log "=================================================================="
Write-Log "Post-Installation Configuration"
Write-Log "=================================================================="

# Disable Chrome auto-updates (if installed)
if ($Results.ContainsKey("chrome") -and $Results["chrome"].Success) {
    try {
        $ChromeKeyPath = "HKLM:\SOFTWARE\Policies\Google\Update"
        if (-not (Test-Path $ChromeKeyPath)) {
            New-Item -Path $ChromeKeyPath -Force | Out-Null
        }
        Set-ItemProperty -Path $ChromeKeyPath -Name "AutoUpdateCheckPeriodMinutes" -Value 0 -Type DWord
        Set-ItemProperty -Path $ChromeKeyPath -Name "DisableAutoUpdateChecksCheckboxValue" -Value 1 -Type DWord
        Write-Log "Disabled Chrome auto-updates" -Level "SUCCESS"
    }
    catch {
        Write-Log "Failed to configure Chrome updates: $_" -Level "WARN"
    }
}

# Disable Adobe Reader auto-updates (if installed)
if ($Results.ContainsKey("adobe_reader") -and $Results["adobe_reader"].Success) {
    try {
        $AdobeKeyPath = "HKLM:\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown"
        if (-not (Test-Path $AdobeKeyPath)) {
            New-Item -Path $AdobeKeyPath -Force | Out-Null
        }
        Set-ItemProperty -Path $AdobeKeyPath -Name "bUpdater" -Value 0 -Type DWord
        Write-Log "Disabled Adobe Reader auto-updates" -Level "SUCCESS"
    }
    catch {
        Write-Log "Failed to configure Adobe updates: $_" -Level "WARN"
    }
}

###############################################################################
# CLEANUP
###############################################################################

Write-Log "=================================================================="
Write-Log "Cleanup"
Write-Log "=================================================================="

try {
    # Remove installers but keep logs
    Get-ChildItem -Path $TempDir -Exclude "*.log" -File -ErrorAction SilentlyContinue | 
        Remove-Item -Force -ErrorAction SilentlyContinue
    
    # Remove PSADT extracted folders
    $PSADTDir = Join-Path $TempDir "PSADT"
    if (Test-Path $PSADTDir) {
        Remove-Item $PSADTDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-Log "Cleaned up temporary files"
}
catch {
    Write-Log "Cleanup warning: $_" -Level "WARN"
}

###############################################################################
# SUMMARY
###############################################################################

Write-Log "=================================================================="
Write-Log "Installation Summary"
Write-Log "=================================================================="

$Succeeded = @($Results.Values | Where-Object { $_.Success -eq $true }).Count
$Failed = @($Results.Values | Where-Object { $_.Success -eq $false }).Count
$Skipped = @($Results.Values | Where-Object { $_.Skipped -eq $true }).Count

Write-Log "Total: $($Results.Count) | Succeeded: $Succeeded | Failed: $Failed | Skipped: $Skipped"
Write-Log "------------------------------------------------------------------"

foreach ($Result in $Results.GetEnumerator()) {
    $Status = if ($Result.Value.Skipped) { 
        "SKIPPED (already installed)" 
    } elseif ($Result.Value.Success) { 
        "OK via $($Result.Value.Method)" 
    } else { 
        "FAILED" 
    }
    Write-Log "  $($Result.Key): $Status"
}

Write-Log "=================================================================="
Write-Log "Application Installation Complete"
Write-Log "=================================================================="
Write-Log "Log file: $LogFile"

# Exit with success even if some apps failed (to allow image to complete)
# The summary above indicates which apps failed for troubleshooting
exit 0
