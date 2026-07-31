import 'dart:convert';
import 'package:flutter/foundation.dart';

class SupportedLanguageItem {
  final String code;
  final String englishName;
  final String nativeName;
  final bool isRtl;

  const SupportedLanguageItem({
    required this.code,
    required this.englishName,
    required this.nativeName,
    this.isRtl = false,
  });
}

class LanguageExpansionService {
  static LanguageExpansionService? _instance;
  static LanguageExpansionService get instance =>
      _instance ??= LanguageExpansionService._();

  LanguageExpansionService._();

  String _currentLanguageCode = 'en';
  bool _communityTranslationsEnabled = true;
  final Map<String, String> _customOverrides = {};

  static const List<SupportedLanguageItem> supportedLanguages = [
    SupportedLanguageItem(code: 'en', englishName: 'English', nativeName: 'English'),
    SupportedLanguageItem(code: 'hi', englishName: 'Hindi', nativeName: 'हिन्दी'),
    SupportedLanguageItem(code: 'es', englishName: 'Spanish', nativeName: 'Español'),
    SupportedLanguageItem(code: 'de', englishName: 'German', nativeName: 'Deutsch'),
    SupportedLanguageItem(code: 'ko', englishName: 'Korean', nativeName: '한국어'),
    SupportedLanguageItem(code: 'ja', englishName: 'Japanese', nativeName: '日本語'),
    SupportedLanguageItem(code: 'fr', englishName: 'French', nativeName: 'Français'),
    SupportedLanguageItem(code: 'it', englishName: 'Italian', nativeName: 'Italiano'),
    SupportedLanguageItem(code: 'pt', englishName: 'Portuguese', nativeName: 'Português'),
    SupportedLanguageItem(code: 'ru', englishName: 'Russian', nativeName: 'Русский'),
    SupportedLanguageItem(code: 'zh', englishName: 'Chinese (Simplified)', nativeName: '简体中文'),
    SupportedLanguageItem(code: 'ar', englishName: 'Arabic', nativeName: 'العربية', isRtl: true),
    SupportedLanguageItem(code: 'tr', englishName: 'Turkish', nativeName: 'Türkçe'),
    SupportedLanguageItem(code: 'nl', englishName: 'Dutch', nativeName: 'Nederlands'),
    SupportedLanguageItem(code: 'pl', englishName: 'Polish', nativeName: 'Polski'),
    SupportedLanguageItem(code: 'sv', englishName: 'Swedish', nativeName: 'Svenska'),
    SupportedLanguageItem(code: 'da', englishName: 'Danish', nativeName: 'Dansk'),
    SupportedLanguageItem(code: 'no', englishName: 'Norwegian', nativeName: 'Norsk'),
    SupportedLanguageItem(code: 'fi', englishName: 'Finnish', nativeName: 'Suomi'),
    SupportedLanguageItem(code: 'el', englishName: 'Greek', nativeName: 'Ελληνικά'),
    SupportedLanguageItem(code: 'he', englishName: 'Hebrew', nativeName: 'עברית', isRtl: true),
    SupportedLanguageItem(code: 'th', englishName: 'Thai', nativeName: 'ไทย'),
    SupportedLanguageItem(code: 'vi', englishName: 'Vietnamese', nativeName: 'Tiếng Việt'),
    SupportedLanguageItem(code: 'id', englishName: 'Indonesian', nativeName: 'Bahasa Indonesia'),
    SupportedLanguageItem(code: 'ms', englishName: 'Malay', nativeName: 'Bahasa Melayu'),
    SupportedLanguageItem(code: 'uk', englishName: 'Ukrainian', nativeName: 'Українська'),
    SupportedLanguageItem(code: 'cs', englishName: 'Czech', nativeName: 'Čeština'),
    SupportedLanguageItem(code: 'ro', englishName: 'Romanian', nativeName: 'Română'),
    SupportedLanguageItem(code: 'hu', englishName: 'Hungarian', nativeName: 'Magyar'),
    SupportedLanguageItem(code: 'bn', englishName: 'Bengali', nativeName: 'বাংলা'),
    SupportedLanguageItem(code: 'fil', englishName: 'Filipino', nativeName: 'Tagalog'),
  ];

  String get currentLanguageCode => _currentLanguageCode;
  bool get communityTranslationsEnabled => _communityTranslationsEnabled;
  Map<String, String> get customOverrides => Map.unmodifiable(_customOverrides);

  void setLanguage(String code) {
    _currentLanguageCode = code;
    debugPrint('Language set to: $code');
  }

  void setCommunityTranslationsEnabled(bool enabled) {
    _communityTranslationsEnabled = enabled;
    debugPrint('Community translations ${enabled ? "enabled" : "disabled"}');
  }

  bool importCommunityTranslationsJson(String jsonString) {
    try {
      final parsed = jsonDecode(jsonString) as Map<String, dynamic>;
      parsed.forEach((key, value) {
        if (value is String) {
          _customOverrides[key] = value;
        }
      });
      debugPrint('Imported ${_customOverrides.length} community translation keys');
      return true;
    } catch (e) {
      debugPrint('Error importing community translations: $e');
      return false;
    }
  }

  String exportCommunityTranslationsJson() {
    return const JsonEncoder.withIndent('  ').convert(_customOverrides);
  }

  void clearCustomOverrides() {
    _customOverrides.clear();
    debugPrint('Cleared custom translation overrides');
  }

  String translateKey(String key, {String? defaultFallback}) {
    if (_communityTranslationsEnabled && _customOverrides.containsKey(key)) {
      return _customOverrides[key]!;
    }
    return defaultFallback ?? key;
  }

  Map<String, dynamic> getSettings() {
    return {
      'currentLanguageCode': _currentLanguageCode,
      'communityTranslationsEnabled': _communityTranslationsEnabled,
      'customOverridesCount': _customOverrides.length,
      'supportedLanguagesCount': supportedLanguages.length,
    };
  }
}
