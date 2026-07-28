import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:voidmusic/blocs/media_player/bloomee_player_cubit.dart';
import 'package:voidmusic/blocs/mini_player/mini_player_cubit.dart';
import 'package:voidmusic/blocs/settings_cubit/cubit/settings_cubit.dart';

/// Service to handle Desktop System Tray and background minimize-on-close functionality.
class DesktopSystemTrayService with WindowListener, TrayListener {
  static final DesktopSystemTrayService _instance =
      DesktopSystemTrayService._internal();
  factory DesktopSystemTrayService() => _instance;
  DesktopSystemTrayService._internal();

  BloomeePlayerCubit? _playerCubit;
  MiniPlayerCubit? _miniPlayerCubit;
  SettingsCubit? _settingsCubit;
  bool _initialized = false;

  static bool get isDesktop =>
      !kIsWeb &&
      (io.Platform.isWindows || io.Platform.isLinux || io.Platform.isMacOS);

  Future<void> init({
    required BloomeePlayerCubit playerCubit,
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
    } catch (e) {
      debugPrint('Failed to initialize DesktopSystemTrayService: $e');
    }
  }

  Future<void> _initSystemTray() async {
    try {
      final String iconPath = io.Platform.isWindows
          ? 'assets/icons/BloomeeLogoFG.png'
          : 'assets/icons/bloomee_new_logo_c.png';

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
    } catch (e) {
      debugPrint('Failed to set up system tray icon/menu: $e');
    }
  }

  @override
  void onWindowClose() async {
    final closeToTray = _settingsCubit?.state.closeToTray ?? true;
    final isPlaying = _miniPlayerCubit?.state.isPlaying ?? false;
    final hasTrack = _miniPlayerCubit?.state.track != null;

    // Minimize/hide to system tray if setting enabled and a track is playing/loaded
    if (closeToTray && (isPlaying || hasTrack)) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
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
        final player = _playerCubit?.bloomeePlayer;
        if (player != null) {
          if (_miniPlayerCubit?.state.isPlaying ?? false) {
            player.pause();
          } else {
            player.play();
          }
        }
        break;
      case 'next_track':
        _playerCubit?.bloomeePlayer.skipToNext();
        break;
      case 'exit_app':
        await windowManager.destroy();
        break;
    }
  }

  Future<void> _showWindow() async {
    final isMinimized = await windowManager.isMinimized();
    if (isMinimized) {
      await windowManager.restore();
    }
    await windowManager.show();
    await windowManager.focus();
  }

  void dispose() {
    if (!_initialized) return;
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    _initialized = false;
  }
}
