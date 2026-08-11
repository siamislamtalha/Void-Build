# Void Music Uninstall Cleanup Script
# This script cleans up all Void Music data during uninstall
#
# Real data paths (Flutter path_provider_windows uses CompanyName\ProductName):
#   %APPDATA%\SilentCode.CO\Void Music\   <-- Isar DB, settings, playlists, library
#   %LOCALAPPDATA%\SilentCode.CO\Void Music\  <-- cache data
#   %USERPROFILE%\Documents\dbv3.isar (and backups) <-- Auto-backups restored by DBProvider

param(
    [string]$InstallDir = "",
    [switch]$Silent = $false
)

Write-Host "Void Music Uninstall Cleanup" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

$localAppData   = $env:LOCALAPPDATA
$roamingAppData = $env:APPDATA
$userDocs       = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments)
if (-not $userDocs -or -not (Test-Path $userDocs)) {
    $userDocs = "$env:USERPROFILE\Documents"
}

# ----------------------------------------------------------------
# Primary paths - these are the REAL paths Flutter path_provider
# creates on Windows: %APPDATA%\<CompanyName>\<ProductName>
# CompanyName = "SilentCode.CO", ProductName = "Void Music"
# ----------------------------------------------------------------
$primaryPaths = @(
    "$roamingAppData\SilentCode.CO\Void Music",
    "$localAppData\SilentCode.CO\Void Music",
    "$roamingAppData\SilentCode.CO\VOID Music",
    "$localAppData\SilentCode.CO\VOID Music"
)

# Documents backup & legacy DB paths (Restored automatically by DBProvider on startup if left behind)
$documentsPaths = @(
    "$userDocs\dbv3.isar",
    "$userDocs\voidmusic_backup_dbv3.isar",
    "$userDocs\voidmusicBackup",
    "$userDocs\default.isar",
    "$userDocs\default.isar.db",
    "$userDocs\default.db",
    "$userDocs\voidmusic_migration_state.json"
)

# Legacy / fallback paths (older builds or debug runs)
$legacyPaths = @(
    "$localAppData\voidmusic",
    "$roamingAppData\voidmusic",
    "$localAppData\VOID Music",
    "$roamingAppData\VOID Music",
    "$localAppData\VoidMusic",
    "$roamingAppData\VoidMusic",
    "$localAppData\com.example.voidmusic",
    "$roamingAppData\com.example.voidmusic",
    "$localAppData\VoidMusic-Setup"
)

# Temp cache paths
$tempPaths = @(
    "$localAppData\Temp\voidmusic_downloads",
    "$localAppData\Temp\voidmusic*"
)

$allPaths = $primaryPaths + $documentsPaths + $legacyPaths + $tempPaths

# Ask user if they want to delete data (unless running silently)
$deleteData = $true
if (-not $Silent) {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Do you want to delete ALL Void Music data?`n(Library, playlists, settings, download history, and backups in Documents)`n`nChoose YES for a completely fresh install next time.`nChoose NO to keep your library and settings.",
            "Void Music Uninstall",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        $deleteData = ($result -eq [System.Windows.Forms.DialogResult]::Yes)
    } catch {
        # Fallback if Windows Forms fails to load
        Write-Host "Non-interactive or headless environment detected. Proceeding with data cleanup." -ForegroundColor Yellow
        $deleteData = $true
    }
}

if ($deleteData) {
    Write-Host "Removing all Void Music app data, documents backups, and caches..." -ForegroundColor Yellow

    foreach ($path in $allPaths) {
        if (Test-Path $path) {
            Write-Host "Removing: $path" -ForegroundColor Yellow
            try {
                Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                Write-Host "  Removed: $path" -ForegroundColor Green
            } catch {
                Write-Host "  Failed to remove $path : $_" -ForegroundColor Red
            }
        } else {
            Write-Host "  Not found (skipping): $path" -ForegroundColor Gray
        }
    }

    # Clean up parent SilentCode.CO folder if now empty
    foreach ($parent in @("$roamingAppData\SilentCode.CO", "$localAppData\SilentCode.CO")) {
        if (Test-Path $parent) {
            $children = Get-ChildItem $parent -ErrorAction SilentlyContinue
            if ($null -eq $children -or $children.Count -eq 0) {
                Remove-Item $parent -Force -ErrorAction SilentlyContinue
                Write-Host "  Removed empty folder: $parent" -ForegroundColor Green
            }
        }
    }

    Write-Host "App data cleanup completed." -ForegroundColor Green
} else {
    Write-Host "User chose to keep app data. Skipping data cleanup." -ForegroundColor Cyan
}

# Clean up registry entries
$registryPaths = @(
    "HKCU:\Software\SilentCode.CO",
    "HKCU:\Software\Void Music",
    "HKCU:\Software\VOID Music",
    "HKCU:\Software\VoidMusic",
    "HKCU:\Software\voidmusic",
    "HKCU:\Software\com.example.voidmusic",
    "HKLM:\Software\Void Music",
    "HKLM:\Software\VOID Music",
    "HKLM:\Software\VoidMusic"
)

foreach ($regPath in $registryPaths) {
    if (Test-Path $regPath) {
        Write-Host "Removing registry key: $regPath" -ForegroundColor Yellow
        try {
            Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
            Write-Host "  Removed: $regPath" -ForegroundColor Green
        } catch {
            Write-Host "  Failed to remove $regPath : $_" -ForegroundColor Red
        }
    }
}

Write-Host "Cleanup completed!" -ForegroundColor Green

