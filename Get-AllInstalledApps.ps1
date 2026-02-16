<#
.SYNOPSIS
    Get-AllInstalledApps - Comprehensive application inventory tool for Windows

.DESCRIPTION
    This script inventories all installed applications from multiple sources:
    - Windows Registry (32/64-bit and user installations)
    - Microsoft Store apps (AppxPackage)
    - Package managers: Scoop, Chocolatey (Winget optional)
    
    No administrative rights required. Outputs CSV files with application details
    and maintains a detailed execution log.

.NOTES
    File Name    : Get-AllInstalledApps.ps1
    Version      : 1.2.1
    Author       : EK
    Created      : 2025-04-16
    Last Updated : 2026-02-16
    
    Version History:
    1.2.1 - 2026-02-16 - Fixed log file extension (.txt instead of .csv)
                        - Added proper SYNOPSIS section
                        - Improved error handling
                        - Added progress indicators
    1.2   - 2025-04-16 - Scoop & Chocolatey optimized, Winget support commented out for performance
    1.1   - 2025-03-xx - Added Microsoft Store support
    1.0   - 2025-02-xx - Initial release (Registry only)

.PARAMETER IncludeWinget
    Switch parameter to enable Winget scanning (disabled by default due to performance)

.EXAMPLE
    .\Get-AllInstalledApps.ps1
    Runs the script with default settings (Registry, Store, Scoop, Chocolatey)

.EXAMPLE
    .\Get-AllInstalledApps.ps1 -IncludeWinget
    Includes Winget in the scan (slower but more comprehensive)

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Get-AllInstalledApps.ps1
    Recommended execution command with bypass policy

.INPUTS
    None. This script does not accept pipeline input.

.OUTPUTS
    Two files in the output directory:
    - InstalledApps_COMPUTERNAME_TIMESTAMP.csv (Application inventory)
    - AppInventoryLog_TIMESTAMP.txt (Execution log)

.NOTES
    Output path: C:\temp\results\ (configurable in script)
    Requires: PowerShell 5.1 or higher
#>

#requires -version 5.1

# --- Parameters ---
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$IncludeWinget  # Use -IncludeWinget to enable slow Winget scan
)

# --- Configurable Variables ---
$OutputPath = "C:\temp\results"  # Change this path as needed

# --- Initialize Logging ---
$LogTime = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile = Join-Path -Path $OutputPath -ChildPath "AppInventoryLog_$LogTime.txt"
$ExecutionLog = [System.Collections.Generic.List[object]]::new()
$scriptStartTime = Get-Date

function Write-Log {
    param (
        [string]$Message,
        [string]$Status = "INFO"
    )
    $LogEntry = [PSCustomObject]@{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Status    = $Status
        Message   = $Message
    }
    $ExecutionLog.Add($LogEntry)
    
    # Color coding for console output
    switch ($Status) {
        "ERROR"   { Write-Host "[$Status] $Message" -ForegroundColor Red }
        "WARNING" { Write-Host "[$Status] $Message" -ForegroundColor Yellow }
        "SUCCESS" { Write-Host "[$Status] $Message" -ForegroundColor Green }
        default   { Write-Host "[$Status] $Message" }
    }
}

# --- Helper Functions ---
function Convert-RegistryDate {
    param([string]$RegDate)
    if ($RegDate -match '^(\d{4})(\d{2})(\d{2})$') {
        try {
            return Get-Date -Year $matches[1] -Month $matches[2] -Day $matches[3] -Format "yyyy-MM-dd"
        }
        catch {
            return $RegDate
        }
    }
    return $RegDate
}

# --- Ensure Output Path Exists ---
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Get-AllInstalledApps v1.2.1" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path -Path $OutputPath)) {
    try {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-Log "Created output directory: $OutputPath" -Status "SUCCESS"
    }
    catch {
        Write-Log "Failed to create output path: $_" -Status "ERROR"
        exit 1
    }
}

# --- 1. Get Traditional Apps (Registry) ---
Write-Progress -Activity "Scanning installed applications" -Status "Registry scan" -PercentComplete 10
try {
    Write-Log "Scanning registry for installed apps..."
    
    $registryPaths = @(
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $RegistryApps = Get-ItemProperty $registryPaths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and $_.DisplayName -notlike '*{*' } |
        ForEach-Object {
            [PSCustomObject]@{
                AppName       = $_.DisplayName.Trim()
                Version       = $_.DisplayVersion
                Publisher     = $_.Publisher
                InstallDate   = Convert-RegistryDate -RegDate $_.InstallDate
                InstallSource = "Registry"
            }
        } | Sort-Object AppName -Unique
    
    Write-Log "Found $($RegistryApps.Count) registry apps." -Status "SUCCESS"
}
catch {
    Write-Log "Registry scan failed: $_" -Status "ERROR"
    $RegistryApps = @()
}

# --- 2. Get Microsoft Store Apps ---
Write-Progress -Activity "Scanning installed applications" -Status "Microsoft Store scan" -PercentComplete 30
try {
    Write-Log "Querying Microsoft Store apps..."
    
    $StoreApps = Get-AppxPackage -ErrorAction Stop | 
        Where-Object { $_.Name -notlike '*Microsoft.WindowsStore*' } |
        Select-Object Name, PackageFullName, PublisherId |
        ForEach-Object {
            [PSCustomObject]@{
                AppName       = $_.Name
                Version       = ($_.PackageFullName -split '_')[1]
                Publisher     = "Microsoft Store ($($_.PublisherId))"
                InstallDate   = $null
                InstallSource = "Microsoft Store"
            }
        } | Sort-Object AppName -Unique
    
    Write-Log "Found $($StoreApps.Count) Microsoft Store apps." -Status "SUCCESS"
}
catch {
    Write-Log "Store app query failed: $_" -Status "WARNING"
    $StoreApps = @()
}

# --- 3. Get Scoop Apps ---
Write-Progress -Activity "Scanning installed applications" -Status "Scoop package manager" -PercentComplete 50
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    try {
        Write-Log "Querying Scoop apps..."
        
        $scoopOutput = scoop list 2>$null
        $ScoopApps = $scoopOutput | Where-Object { $_ -match '^[a-zA-Z0-9]' } | ForEach-Object {
            $parts = $_ -split '\s+', 3
            if ($parts.Count -ge 2) {
                [PSCustomObject]@{
                    AppName       = $parts[0].Trim()
                    Version       = $parts[1].Trim()
                    Publisher     = "Scoop"
                    InstallDate   = $null
                    InstallSource = "Scoop"
                }
            }
        }
        
        Write-Log "Found $($ScoopApps.Count) Scoop apps." -Status "SUCCESS"
    }
    catch {
        Write-Log "Scoop app query failed: $_" -Status "WARNING"
        $ScoopApps = @()
    }
} else {
    Write-Log "Scoop is not installed or not in PATH." -Status "INFO"
    $ScoopApps = @()
}

# --- 4. Get Chocolatey Apps ---
Write-Progress -Activity "Scanning installed applications" -Status "Chocolatey package manager" -PercentComplete 70
if (Get-Command choco -ErrorAction SilentlyContinue) {
    try {
        Write-Log "Querying Chocolatey apps..."
        
        $chocoOutput = choco list --local-only --limit-output 2>$null
        $ChocoApps = $chocoOutput | Where-Object { $_ -match '^[^|]+\|[^|]+' } | ForEach-Object {
            $parts = $_ -split '\|'
            if ($parts.Count -ge 2) {
                [PSCustomObject]@{
                    AppName       = $parts[0].Trim()
                    Version       = $parts[1].Trim()
                    Publisher     = "Chocolatey"
                    InstallDate   = $null
                    InstallSource = "Chocolatey"
                }
            }
        }
        
        Write-Log "Found $($ChocoApps.Count) Chocolatey apps." -Status "SUCCESS"
    }
    catch {
        Write-Log "Chocolatey app query failed: $_" -Status "WARNING"
        $ChocoApps = @()
    }
} else {
    Write-Log "Chocolatey is not installed or not in PATH." -Status "INFO"
    $ChocoApps = @()
}

# --- 5. Get Winget Apps (OPTIONAL, disabled by default) ---
Write-Progress -Activity "Scanning installed applications" -Status "Winget package manager" -PercentComplete 85
$WingetApps = @()

if ($IncludeWinget) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            Write-Log "Querying Winget apps (this may take a moment)..."
            
            # Winget output parsing - simplified for performance
            $wingetOutput = winget list --accept-source-agreements 2>$null
            $WingetApps = $wingetOutput | Select-Object -Skip 2 | Where-Object { $_ -match '^\w' } | ForEach-Object {
                $parts = $_ -split '\s{2,}', 3
                if ($parts.Count -ge 2) {
                    [PSCustomObject]@{
                        AppName       = $parts[0].Trim()
                        Version       = $parts[1].Trim()
                        Publisher     = if ($parts.Count -ge 3) { $parts[2].Trim() } else { "Winget" }
                        InstallDate   = $null
                        InstallSource = "Winget"
                    }
                }
            }
            
            Write-Log "Found $($WingetApps.Count) Winget apps." -Status "SUCCESS"
        }
        catch {
            Write-Log "Winget app query failed: $_" -Status "WARNING"
            $WingetApps = @()
        }
    } else {
        Write-Log "Winget is not installed or not in PATH." -Status "INFO"
        $WingetApps = @()
    }
} else {
    Write-Log "Winget scan disabled (use -IncludeWinget to enable)" -Status "INFO"
}

# --- Merge Results ---
Write-Progress -Activity "Scanning installed applications" -Status "Merging results" -PercentComplete 95
$AllApps = $RegistryApps + $StoreApps + $ScoopApps + $ChocoApps + $WingetApps
$AllApps = $AllApps | Sort-Object AppName -Unique

# --- Export Apps to CSV ---
$DeviceName = $env:COMPUTERNAME
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$AppFile = Join-Path -Path $OutputPath -ChildPath "InstalledApps_${DeviceName}_${Timestamp}.csv"

try {
    $AllApps | Export-Csv -Path $AppFile -NoTypeInformation -Encoding UTF8 -Delimiter ";"
    Write-Log "Exported $($AllApps.Count) apps to: $AppFile" -Status "SUCCESS"
}
catch {
    Write-Log "Failed to export apps: $_" -Status "ERROR"
}

# --- Export Log File (as text) ---
try {
    $ExecutionLog | ForEach-Object {
        "$($_.Timestamp) [$($_.Status)] $($_.Message)"
    } | Out-File -FilePath $LogFile -Encoding UTF8
    Write-Log "Execution log saved to: $LogFile" -Status "SUCCESS"
}
catch {
    Write-Host "Failed to save log file: $_" -ForegroundColor Red
}

# --- Summary Statistics ---
Write-Progress -Activity "Scanning installed applications" -Completed
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " SCAN COMPLETE - SUMMARY" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$summary = @{
    Registry    = $RegistryApps.Count
    Store       = $StoreApps.Count
    Scoop       = $ScoopApps.Count
    Chocolatey  = $ChocoApps.Count
    Winget      = $WingetApps.Count
    Total       = $AllApps.Count
}

Write-Host "Registry apps    : $($summary.Registry)" -ForegroundColor White
Write-Host "Store apps       : $($summary.Store)" -ForegroundColor White
Write-Host "Scoop apps       : $($summary.Scoop)" -ForegroundColor White
Write-Host "Chocolatey apps  : $($summary.Chocolatey)" -ForegroundColor White
Write-Host "Winget apps      : $($summary.Winget)" -ForegroundColor White
Write-Host "-----------------------------"
Write-Host "TOTAL APPS       : $($summary.Total)" -ForegroundColor Green
Write-Host ""
Write-Host "Output files:" -ForegroundColor Yellow
Write-Host "  📄 Apps: $($AppFile)" -ForegroundColor Gray
Write-Host "  📋 Log:  $($LogFile)" -ForegroundColor Gray

# --- Script Duration ---
$scriptEndTime = Get-Date
$duration = $scriptEndTime - $scriptStartTime
Write-Host ""
Write-Host "Script completed in $($duration.ToString('mm\:ss')) minutes" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan