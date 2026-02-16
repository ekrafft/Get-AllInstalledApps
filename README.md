# Get-AllInstalledApps
This script inventories all installed applications from multiple sources: Windows Registry (32/64-bit and user installations), Microsoft Store apps (AppxPackage), Package managers: Scoop, Chocolatey.

# Get-AllInstalledApps

A comprehensive Windows application inventory tool that scans multiple sources to provide a complete picture of all installed software on a machine.

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)](https://github.com/PowerShell/PowerShell)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 📋 Overview

This PowerShell script inventories all installed applications from multiple sources:
- Windows Registry (32-bit, 64-bit, and per-user installations)
- Microsoft Store apps
- Package managers: Scoop, Chocolatey, and optional Winget support

**No administrative rights required!** The script runs in user context and generates comprehensive CSV reports.

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🔍 **Multi-Source Scanning** | Registry + Store + Package Managers |
| ⚡ **Performance Optimized** | Winget disabled by default (optional switch) |
| 📊 **CSV Export** | Easy to import into Excel or analysis tools |
| 📝 **Detailed Logging** | Execution log with timestamps and status |
| 🎯 **Duplicate Removal** | Smart deduplication of applications |
| 📈 **Summary Statistics** | Clear overview at end of scan |
| 🎨 **Color-Coded Output** | Easy-to-read console output |

## 🔧 Requirements

- Windows 7/8/10/11
- PowerShell 5.1 or higher
- No administrative privileges required
- Optional: Scoop, Chocolatey, or Winget (if installed)

## 📦 Installation

```bash
# Clone the repository
git clone https://github.com/ekrafft/Get-AllInstalledApps.git

# Navigate to folder
cd Get-AllInstalledApps

## 🚀 Usage
# Basic Scan (Recommended)
powershell
.\Get-AllInstalledApps.ps1
# Include Winget (Slower but more comprehensive)
powershell
.\Get-AllInstalledApps.ps1 -IncludeWinget
# With Execution Policy Bypass
powershell
powershell.exe -ExecutionPolicy Bypass -File .\Get-AllInstalledApps.ps1

📁 Output Files
The script creates two files in C:\temp\results\ (configurable):

| File	| Description  |
|-------|--------------|
| InstalledApps_COMPUTERNAME_TIMESTAMP.csv | Complete application inventory |
| AppInventoryLog_TIMESTAMP.txt | Detailed execution log |

##  Troubleshooting
| Issue	| Solution |
|-------|----------|
| No output directory |	Script creates it automatically |
| Scoop/Chocolatey not found | Package manager not installed - normal |
| Winget too slow	| Use without -IncludeWinget |
| Permission denied	| Script runs in user context - no admin needed |
| Empty results |	Check if applications are actually installed |


## 📝 Version History
| Version |	Date	| Changes |
|---------|-------|---------|
| 1.2.1 |	2026-02-16	| Fixed log extension, added SYNOPSIS, improved error handling 
| 1.2	| 2025-04-16	| Scoop & Chocolatey optimized |
| 1.1	| 2025-03-01 |	Added Microsoft Store support |
| 1.0	| 2025-02-xx	| Initial release |

