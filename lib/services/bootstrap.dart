import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:voidmusic/core/constants/setting_keys.dart';
import 'package:voidmusic/core/di/service_locator.dart';
import 'package:voidmusic/services/car/android_auto_service.dart';
import 'package:voidmusic/services/cast/google_cast_service.dart';
import 'package:voidmusic/services/db/dao/settings_dao.dart';
import 'package:voidmusic/services/db/db_provider.dart';
import 'package:voidmusic/services/local_music_service.dart';
import 'package:voidmusic/services/network/proxy_service.dart';
import 'package:voidmusic/services/onboarding_service.dart';
import 'package:voidmusic/services/plugin_bootstrap_service.dart';
import 'package:voidmusic/services/display/high_refresh_rate_service.dart';
import 'package:voidmusic/services/bluetooth/bluetooth_codec_service.dart';
import 'package:voidmusic/services/widget/lock_screen_widget_service.dart';
import 'package:voidmusic/services/l10n/language_expansion_service.dart';
import 'package:voidmusic/src/rust/frb_generated.dart';

/// Application bootstrap — run once before [runApp].
///
/// Responsibilities:
/// - Initialize platform path constants.
/// - Open the Isar database via [DBProvider].
/// - Schedule periodic DB maintenance tasks.
/// - Wire the [ServiceLocator] and initialize the plugin system.
Future<void> bootstrapApp() async {
  // Initialize flutter_rust_bridge before any Rust API call.
  await RustLib.init();

  final String appDocPath = (await getApplicationDocumentsDirectory()).path;
  final String appSuppPath = (await getApplicationSupportDirectory()).path;

  // Open DB and schedule maintenance.
  await DBProvider.init(
      appSupportPath: appSuppPath, appDocumentsPath: appDocPath);
  DBProvider.scheduleMaintenance();

  // DI wiring (registers singletons).
  await ServiceLocator.setup();

  // Ensure hosted repositories are persisted in settings (idempotent).
  // Missing URLs are added, existing ones are left untouched.
  try {
    await PluginBootstrapService.ensureHostedRepositoriesPresent(
      repositoryService: ServiceLocator.pluginRepositoryService,
    );
  } catch (e) {
    log('Hosted repository reconciliation skipped',
        error: e, name: 'Bootstrap');
  }

  // Initialize plugin system:
  //   Creates Rust PluginManager → connects event bus →
  //   preloads storage from Isar → starts storage event handler.
  try {
    await ServiceLocator.initializePluginSystem();
    log('Plugin system initialized successfully', name: 'Bootstrap');
  } catch (e, stack) {
    // Plugin system failure is non-fatal — the app can still run
    // with degraded functionality (no plugin content).
    log('Plugin system initialization failed (non-fatal)',
        error: e, stackTrace: stack, name: 'Bootstrap');
  }

  // Auto-scan local music folders if enabled (fire-and-forget).
  try {
    final settingsDao = SettingsDAO(DBProvider.db);
    final autoScan =
        await settingsDao.getSettingBool(SettingKeys.localMusicAutoScan) ??
            true;
    if (autoScan) {
      unawaited(LocalMusicService.create().scanAndPersist());
    }
  } catch (e) {
    log('Local music auto-scan skipped', error: e, name: 'Bootstrap');
  }

  // Pre-load the plugin-bootstrap done-flag so that _MyAppState can check
  // it synchronously in initState() without an async call.
  try {
    final settingsDao = SettingsDAO(DBProvider.db);
    await OnboardingService.checkAndCacheDone(settingsDao);
    await PluginBootstrapService.checkAndCacheDone(settingsDao);
  } catch (e) {
    log('Could not load bootstrap flag (will re-run bootstrap)',
        error: e, name: 'Bootstrap');
  }

  // Initialize advanced feature services
  try {
    AndroidAutoService.instance.initialize();
    GoogleCastService.instance.initialize();
    ProxyService.instance.initialize();
    HighRefreshRateService.instance.initialize();
    BluetoothCodecService.instance.initialize();
    LockScreenWidgetService.instance;
    LanguageExpansionService.instance;
    debugPrint('Advanced feature services initialized successfully');
  } catch (e) {
    log('Advanced feature services initialization error: $e', name: 'Bootstrap');
  }
}
