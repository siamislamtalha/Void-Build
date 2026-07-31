# Desktop Cleanup Implementation

This document describes the desktop cleanup features implemented for Void Music.

## Features Implemented

### 1. System Tray Persistence (Windows/Linux/Mac)

The app now properly stays in the system tray when closed. Key changes:

- **Enhanced `DesktopSystemTrayService`**:
  - Added `_isHiddenToTray` flag to track tray state
  - Modified `onWindowClose()` to always hide to tray when `closeToTray` setting is enabled (regardless of playback state)
  - Added debug logging for troubleshooting
  - Improved error handling

- **Behavior**:
  - When user closes the window with X button, it hides to system tray
  - Clicking the tray icon shows the window again
  - Right-clicking the tray icon shows context menu with options
  - "Exit Void Music" from tray menu properly cleans up before exiting

### 2. Uninstall Cleanup

Scripts to clean up all app data when uninstalling:

#### Windows (`windows/uninstall_cleanup.ps1`)
- Cleans up `%LOCALAPPDATA%\voidmusic`
- Cleans up `%APPDATA%\voidmusic`
- Removes registry entries
- Can be called by NSIS installer

#### macOS (`macos/uninstall_cleanup.sh`)
- Cleans up `~/Library/Application Support/voidmusic`
- Cleans up `~/Library/Caches/voidmusic`
- Removes `~/Library/Preferences/voidmusic.plist`

#### Linux (`linux/uninstall_cleanup.sh`)
- Cleans up `~/.local/share/voidmusic`
- Cleans up `~/.config/voidmusic`
- Cleans up `~/.cache/voidmusic`
- Removes desktop entry and icons

#### NSIS Installer (`windows/installer.nsi`)
- Full installer script with proper uninstall integration
- Runs cleanup script during uninstall
- Creates desktop and start menu shortcuts
- Adds proper registry entries for uninstall

## Integration with App

### System Tray
The system tray service is already integrated in `main.dart`:
```dart
import 'package:voidmusic/services/desktop_system_tray_service.dart';
```

The service is initialized in the app startup sequence and handles:
- Window close events
- Tray icon clicks
- Context menu actions
- Proper cleanup on exit

### Uninstall Cleanup
The cleanup scripts are ready to be integrated with your build process:

**For Windows:**
1. Build the Flutter app: `flutter build windows --release`
2. Build NSIS installer: `makensis installer.nsi`
3. The installer will automatically run cleanup on uninstall

**For macOS:**
1. Build the Flutter app: `flutter build macos --release`
2. Package as .app bundle
3. Add cleanup script to the bundle
4. Reference in installer or provide separate uninstall script

**For Linux:**
1. Build the Flutter app: `flutter build linux --release`
2. Create .deb or .AppImage package
3. Add cleanup script to package
4. Reference in package post-uninstall script

## DesktopCleanupService

Added a new service class in `desktop_system_tray_service.dart`:

```dart
class DesktopCleanupService {
  static Future<void> cleanup() async {
    // Runtime cleanup (tray icon, etc.)
  }
  
  static Map<String, String> getAppDataPaths() {
    // Returns paths that should be cleaned on uninstall
  }
}
```

This service:
- Is called when user selects "Exit Void Music" from tray menu
- Cleans up runtime resources (tray icon)
- Provides path information for uninstaller scripts

## Testing

### System Tray
1. Run the app on Windows/Linux/Mac
2. Enable "Close to Tray" in settings
3. Close the window with X button
4. Verify the app stays in system tray
5. Click tray icon to restore window
6. Right-click tray icon and test menu options

### Uninstall Cleanup
1. Install the app using the NSIS installer (Windows)
2. Use the app to create some data (playlists, downloads, etc.)
3. Uninstall the app
4. Verify all app data is removed from:
   - `%LOCALAPPDATA%\voidmusic`
   - `%APPDATA%\voidmusic`
   - Registry

## Notes

- The cleanup scripts are designed to be safe - they only remove Void Music-specific directories
- On Windows, the uninstaller (NSIS) handles the main cleanup
- On macOS and Linux, the scripts can be run manually or integrated with package managers
- The `DesktopCleanupService.cleanup()` is called during app exit to clean runtime resources
- Actual file deletion happens during uninstall, not during app runtime (to avoid deleting user data accidentally)
