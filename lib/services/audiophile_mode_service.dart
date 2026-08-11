import 'package:voidmusic/core/constants/setting_keys.dart';
import 'package:voidmusic/services/db/dao/settings_dao.dart';

class QualityModeValues {
  static const String normal = 'normal';
  static const String audiophile = 'audiophile';
}

class AudiophileModeService {
  static String _mode = QualityModeValues.normal;

  static String get mode => _mode;
  static bool get isAudiophile => _mode == QualityModeValues.audiophile;

  static Future<void> checkAndCache(SettingsDAO settingsDao) async {
    final stored = await settingsDao.getSettingStr(SettingKeys.appQualityMode);
    if (stored != null && stored.isNotEmpty) {
      _mode = stored;
    } else {
      _mode = QualityModeValues.normal;
    }
  }

  static Future<void> setMode(SettingsDAO settingsDao, String newMode) async {
    await settingsDao.putSettingStr(SettingKeys.appQualityMode, newMode);
    _mode = newMode;
  }
}
