# Void Music Uninstall Cleanup Script
# This script cleans up all Void Music data during uninstall

param(
    [string]$InstallDir = ""
)

Write-Host "Void Music Uninstall Cleanup" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

# Get app data paths
$localAppData = $env:LOCALAPPDATA
$roamingAppData = $env:APPDATA

# Define Void Music app data paths
$voidMusicPaths = @(
    "$localAppData\voidmusic",
    "$roamingAppData\voidmusic",
    "$localAppData\com.example.voidmusic",
    "$roamingAppData\com.example.voidmusic"
)

# Clean up app data directories
foreach ($path in $voidMusicPaths) {
    if (Test-Path $path) {
        Write-Host "Removing: $path" -ForegroundColor Yellow
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            Write-Host "Successfully removed: $path" -ForegroundColor Green
        } catch {
            Write-Host "Failed to remove $path: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Path not found (skipping): $path" -ForegroundColor Gray
    }
}

# Clean up registry entries (if any)
$registryPaths = @(
    "HKCU:\Software\VoidMusic",
    "HKCU:\Software\com.example.voidmusic"
)

foreach ($regPath in $registryPaths) {
    if (Test-Path $regPath) {
        Write-Host "Removing registry key: $regPath" -ForegroundColor Yellow
        try {
            Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
            Write-Host "Successfully removed registry key: $regPath" -ForegroundColor Green
        } catch {
            Write-Host "Failed to remove registry key $regPath: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Registry key not found (skipping): $regPath" -ForegroundColor Gray
    }
}

# Clean up installation directory if provided
if ($InstallDir -ne "" -and (Test-Path $InstallDir)) {
    Write-Host "Removing installation directory: $InstallDir" -ForegroundColor Yellow
    try {
        # Note: This will be called by the uninstaller, so we might need to handle this differently
        # For now, just log it
        Write-Host "Installation directory should be removed by uninstaller" -ForegroundColor Gray
    } catch {
        Write-Host "Failed to remove installation directory: $_" -ForegroundColor Red
    }
}

Write-Host "Cleanup completed!" -ForegroundColor Green
