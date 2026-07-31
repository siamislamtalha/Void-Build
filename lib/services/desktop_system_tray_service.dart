import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:voidmusic/blocs/media_player/voidmusic_player_cubit.dart';
import 'package:voidmusic/blocs/mini_player/mini_player_cubit.dart';
import 'package:voidmusic/blocs/settings_cubit/cubit/settings_cubit.dart';

/// Service to handle Desktop System Tray and background minimize-on-close functionality.
class DesktopSystemTrayService with WindowListener, TrayListener {
  static final DesktopSystemTrayService _instance =
      DesktopSystemTrayService._internal();
  factory DesktopSystemTrayService() => _instance;
  DesktopSystemTrayService._internal();

  VoidMusicPlayerCubit? _playerCubit;
  MiniPlayerCubit? _miniPlayerCubit;
  SettingsCubit? _settingsCubit;
  bool _initialized = false;
  bool _isHiddenToTray = false;

  static bool get isDesktop =>
      !kIsWeb &&
      (io.Platform.isWindows || io.Platform.isLinux || io.Platform.isMacOS);

  Future<void> init({
    required VoidMusicPlayerCubit playerCubit,
    required MiniPlayerCubit miniPlayerCubit,
    required SettingsCubit settingsCubit,
  }) async {
    if (!isDesktop || _initialized) return;
    _playerCubit = playerCubit;
    _miniPlayerCubit = miniPlayerCubit;
    _settingsCubit = settingsCubit;

    try {
      await windowManager.ensureInitialized();
      windowManager.addListener(this);
      await windowManager.setPreventClose(true);

      trayManager.addListener(this);

      await _initSystemTray();
      _initialized = true;
      debugPrint('DesktopSystemTrayService initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize DesktopSystemTrayService: $e');
    }
  }

  Future<void> _initSystemTray() async {
    try {
      final String iconPath = io.Platform.isWindows
          ? 'assets/icons/VoidMusicLogoFG.png'
          : 'assets/icons/voidmusic_new_logo_c.png';

      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip('Void Music');

      final Menu menu = Menu(
        items: [
          MenuItem(
            key: 'show_app',
            label: 'Show Void Music',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'play_pause',
            label: 'Play / Pause',
          ),
          MenuItem(
            key: 'next_track',
            label: 'Next Track',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'Exit Void Music',
          ),
        ],
      );

      await trayManager.setContextMenu(menu);
      debugPrint('System tray icon and menu set up successfully');
    } catch (e) {
      debugPrint('Failed to set up system tray icon/menu: $e');
    }
  }

  @override
  void onWindowClose() async {
    final closeToTray = _settingsCubit?.state.closeToTray ?? true;
    final isPlaying = _miniPlayerCubit?.state.isPlaying ?? false;
    final hasTrack = _miniPlayerCubit?.state.track != null;

    debugPrint('Window close requested - closeToTray: $closeToTray, isPlaying: $isPlaying, hasTrack: $hasTrack');

    // Always minimize to tray if closeToTray is enabled, regardless of playback state
    if (closeToTray) {
      await _hideToTray();
    } else {
      await windowManager.destroy();
    }
  }

  Future<void> _hideToTray() async {
    try {
      await windowManager.hide();
      _isHiddenToTray = true;
      debugPrint('Window hidden to system tray');
    } catch (e) {
      debugPrint('Failed to hide window to tray: $e');
    }
  }

  @override
  void onTrayIconMouseDown() async {
    await _showWindow();
  }

  @override
  void onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show_app':
        await _showWindow();
        break;
      case 'play_pause':
        final player = _playerCubit?.voidMusicPlayer;
        if (player != null) {
          if (_miniPlayerCubit?.state.isPlaying ?? false) {
            player.pause();
          } else {
            player.play();
          }
        }
        break;
      case 'next_track':
        _playerCubit?.voidMusicPlayer.skipToNext();
        break;
      case 'exit_app':
        await _exitApp();
        break;
    }
  }

  Future<void> _showWindow() async {
    try {
      final isMinimized = await windowManager.isMinimized();
      if (isMinimized) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
      _isHiddenToTray = false;
      debugPrint('Window shown from system tray');
    } catch (e) {
      debugPrint('Failed to show window from tray: $e');
    }
  }

  Future<void> _exitApp() async {
    try {
      // Clean up before exit
      await DesktopCleanupService.cleanup();
      await windowManager.destroy();
    } catch (e) {
      debugPrint('Failed to exit app: $e');
    }
  }

  void dispose() {
    if (!_initialized) return;
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    _initialized = false;
  }
}

/// Service to handle cleanup of app data on uninstall/exit
class DesktopCleanupService {
  static Future<void> cleanup() async {
    if (!kIsWeb && (io.Platform.isWindows || io.Platform.isLinux || io.Platform.isMacOS)) {
      try {
        debugPrint('Starting desktop cleanup...');
        
        // Clear tray icon
        try {
          await trayManager.destroy();
          debugPrint('Tray icon destroyed');
        } catch (e) {
          debugPrint('Failed to destroy tray icon: $e');
        }
        
        // Note: Actual deletion of app data directories should be handled by the uninstaller
        // This service is for cleanup that needs to happen during app runtime
        // For Windows, the uninstaller should handle registry and file cleanup
        
        debugPrint('Desktop cleanup completed');
      } catch (e) {
        debugPrint('Error during desktop cleanup: $e');
      }
    }
  }
  
  /// Get the paths that should be cleaned on uninstall
  static Map<String, String> getAppDataPaths() {
    if (!kIsWeb) {
      if (io.Platform.isWindows) {
        return {
          'appData': io.Platform.environment['APPDATA'] ?? '',
          'localAppData': io.Platform.environment['LOCALAPPDATA'] ?? '',
        };
      } else if (io.Platform.isMacOS) {
        return {
          'home': io.Platform.environment['HOME'] ?? '',
        };
      } else if (io.Platform.isLinux) {
        return {
          'home': io.Platform.environment['HOME'] ?? '',
          'xdgConfigHome': io.Platform.environment['XDG_CONFIG_HOME'] ?? '',
          'xdgDataHome': io.Platform.environment['XDG_DATA_HOME'] ?? '',
        };
      }
    }
    return {};
  }
}
