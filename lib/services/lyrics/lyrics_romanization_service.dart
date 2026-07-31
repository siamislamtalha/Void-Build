import 'package:flutter/foundation.dart';

enum RomanizationMode {
  off,
  auto,
  force,
}

enum SupportedLanguage {
  japanese,
  chinese,
  korean,
  cyrillic,
  arabic,
  hebrew,
  thai,
}

class LyricsRomanizationService {
  static LyricsRomanizationService? _instance;
  static LyricsRomanizationService get instance =>
      _instance ??= LyricsRomanizationService._();

  LyricsRomanizationService._();

  RomanizationMode _currentMode = RomanizationMode.auto;
  bool _isEnabled = false;
  final Map<String, String> _romanizationCache = {};
  final Set<SupportedLanguage> _enabledLanguages = {
    SupportedLanguage.japanese,
    SupportedLanguage.chinese,
    SupportedLanguage.korean,
    SupportedLanguage.cyrillic,
  };

  RomanizationMode get currentMode => _currentMode;
  bool get isEnabled => _isEnabled;
  Set<SupportedLanguage> get enabledLanguages => _enabledLanguages;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('Lyrics romanization ${enabled ? "enabled" : "disabled"}');
  }

  void setMode(RomanizationMode mode) {
    _currentMode = mode;
    debugPrint('Romanization mode set to: $mode');
  }

  void setLanguageEnabled(SupportedLanguage language, bool enabled) {
    if (enabled) {
      _enabledLanguages.add(language);
    } else {
      _enabledLanguages.remove(language);
    }
    debugPrint('Language $language ${enabled ? "enabled" : "disabled"} for romanization');
  }

  Future<String> romanize(String text, {String? sourceLanguage}) async {
    if (!_isEnabled || _currentMode == RomanizationMode.off) {
      return text;
    }

    final cacheKey = '${text}_$sourceLanguage';
    if (_romanizationCache.containsKey(cacheKey)) {
      return _romanizationCache[cacheKey]!;
    }

    String romanized = text;

    // Detect language if not provided
    final detectedLanguage = sourceLanguage ?? _detectLanguage(text);
    
    if (detectedLanguage != null) {
      romanized = _romanizeByLanguage(text, detectedLanguage);
    }

    _romanizationCache[cacheKey] = romanized;
    return romanized;
  }

  String? _detectLanguage(String text) {
    // Simple language detection based on character ranges
    for (final char in text.runes) {
      if (char >= 0x3040 && char <= 0x309F) {
        // Hiragana
        return 'japanese';
      } else if (char >= 0x30A0 && char <= 0x30FF) {
        // Katakana
        return 'japanese';
      } else if (char >= 0x4E00 && char <= 0x9FFF) {
        // CJK Unified Ideographs
        return 'chinese';
      } else if (char >= 0xAC00 && char <= 0xD7AF) {
        // Hangul Syllables
        return 'korean';
      } else if (char >= 0x0400 && char <= 0x04FF) {
        // Cyrillic
        return 'cyrillic';
      } else if (char >= 0x0600 && char <= 0x06FF) {
        // Arabic
        return 'arabic';
      } else if (char >= 0x0590 && char <= 0x05FF) {
        // Hebrew
        return 'hebrew';
      } else if (char >= 0x0E00 && char <= 0x0E7F) {
        // Thai
        return 'thai';
      }
    }
    return null;
  }

  String _romanizeByLanguage(String text, String language) {
    switch (language.toLowerCase()) {
      case 'japanese':
        return _romanizeJapanese(text);
      case 'chinese':
        return _romanizeChinese(text);
      case 'korean':
        return _romanizeKorean(text);
      case 'cyrillic':
        return _romanizeCyrillic(text);
      case 'arabic':
        return _romanizeArabic(text);
      case 'hebrew':
        return _romanizeHebrew(text);
      case 'thai':
        return _romanizeThai(text);
      default:
        return text;
    }
  }

  String _romanizeJapanese(String text) {
    // Basic Japanese romanization (simplified)
    // In a real implementation, use a library like 'kana_kit' or similar
    final hiraganaMap = {
      'あ': 'a', 'い': 'i', 'う': 'u', 'え': 'e', 'お': 'o',
      'か': 'ka', 'き': 'ki', 'く': 'ku', 'け': 'ke', 'こ': 'ko',
      'さ': 'sa', 'し': 'shi', 'す': 'su', 'せ': 'se', 'そ': 'so',
      'た': 'ta', 'ち': 'chi', 'つ': 'tsu', 'て': 'te', 'と': 'to',
      'な': 'na', 'に': 'ni', 'ぬ': 'nu', 'ね': 'ne', 'の': 'no',
      'は': 'ha', 'ひ': 'hi', 'ふ': 'fu', 'へ': 'he', 'ほ': 'ho',
      'ま': 'ma', 'み': 'mi', 'む': 'mu', 'め': 'me', 'も': 'mo',
      'や': 'ya', 'ゆ': 'yu', 'よ': 'yo',
      'ら': 'ra', 'り': 'ri', 'る': 'ru', 'れ': 're', 'ろ': 'ro',
      'わ': 'wa', 'を': 'wo', 'ん': 'n',
    };

    final katakanaMap = {
      'ア': 'a', 'イ': 'i', 'ウ': 'u', 'エ': 'e', 'オ': 'o',
      'カ': 'ka', 'キ': 'ki', 'ク': 'ku', 'ケ': 'ke', 'コ': 'ko',
      'サ': 'sa', 'シ': 'shi', 'ス': 'su', 'セ': 'se', 'ソ': 'so',
      'タ': 'ta', 'チ': 'chi', 'ツ': 'tsu', 'テ': 'te', 'ト': 'to',
      'ナ': 'na', 'ニ': 'ni', 'ヌ': 'nu', 'ネ': 'ne', 'ノ': 'no',
      'ハ': 'ha', 'ヒ': 'hi', 'フ': 'fu', 'ヘ': 'he', 'ホ': 'ho',
      'マ': 'ma', 'ミ': 'mi', 'ム': 'mu', 'メ': 'me', 'モ': 'mo',
      'ヤ': 'ya', 'ユ': 'yu', 'ヨ': 'yo',
      'ラ': 'ra', 'リ': 'ri', 'ル': 'ru', 'レ': 're', 'ロ': 'ro',
      'ワ': 'wa', 'ヲ': 'wo', 'ン': 'n',
    };

    String result = text;
    hiraganaMap.forEach((kana, roman) {
      result = result.replaceAll(kana, roman);
    });
    katakanaMap.forEach((kana, roman) {
      result = result.replaceAll(kana, roman);
    });

    return result;
  }

  String _romanizeChinese(String text) {
    // Basic Chinese romanization (pinyin placeholder)
    // In a real implementation, use a library like 'chinese_pinyin'
    // For now, return the original text as this requires complex mapping
    return text;
  }

  String _romanizeKorean(String text) {
    // Basic Korean romanization (simplified)
    // In a real implementation, use a library like 'korean_romanizer'
    final jamoMap = {
      '가': 'ga', '나': 'na', '다': 'da', '라': 'ra', '마': 'ma',
      '바': 'ba', '사': 'sa', '아': 'a', '자': 'ja', '차': 'cha',
      '카': 'ka', '타': 'ta', '파': 'pa', '하': 'ha',
    };

    String result = text;
    jamoMap.forEach((hangul, roman) {
      result = result.replaceAll(hangul, roman);
    });

    return result;
  }

  String _romanizeCyrillic(String text) {
    // Cyrillic to Latin transliteration
    final cyrillicMap = {
      'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Е': 'E', 'Ё': 'Yo',
      'Ж': 'Zh', 'З': 'Z', 'И': 'I', 'Й': 'Y', 'К': 'K', 'Л': 'L', 'М': 'M',
      'Н': 'N', 'О': 'O', 'П': 'P', 'Р': 'R', 'С': 'S', 'Т': 'T', 'У': 'U',
      'Ф': 'F', 'Х': 'Kh', 'Ц': 'Ts', 'Ч': 'Ch', 'Ш': 'Sh', 'Щ': 'Shch',
      'Ъ': '', 'Ы': 'Y', 'Ь': '', 'Э': 'E', 'Ю': 'Yu', 'Я': 'Ya',
      'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo',
      'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
      'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
      'ф': 'f', 'х': 'kh', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'shch',
      'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
    };

    String result = text;
    cyrillicMap.forEach((cyrillic, latin) {
      result = result.replaceAll(cyrillic, latin);
    });

    return result;
  }

  String _romanizeArabic(String text) {
    // Basic Arabic romanization (simplified)
    final arabicMap = {
      'ا': 'a', 'ب': 'b', 'ت': 't', 'ث': 'th', 'ج': 'j', 'ح': 'h',
      'خ': 'kh', 'د': 'd', 'ذ': 'dh', 'ر': 'r', 'ز': 'z', 'س': 's',
      'ش': 'sh', 'ص': 's', 'ض': 'd', 'ط': 't', 'ظ': 'z', 'ع': 'a',
      'غ': 'gh', 'ف': 'f', 'ق': 'q', 'ك': 'k', 'ل': 'l', 'م': 'm',
      'ن': 'n', 'ه': 'h', 'و': 'w', 'ي': 'y',
    };

    String result = text;
    arabicMap.forEach((arabic, latin) {
      result = result.replaceAll(arabic, latin);
    });

    return result;
  }

  String _romanizeHebrew(String text) {
    // Basic Hebrew romanization (simplified)
    final hebrewMap = {
      'א': '', 'ב': 'b', 'ג': 'g', 'ד': 'd', 'ה': 'h', 'ו': 'v',
      'ז': 'z', 'ח': 'h', 'ט': 't', 'י': 'y', 'כ': 'k', 'ל': 'l',
      'מ': 'm', 'נ': 'n', 'ס': 's', 'ע': '', 'פ': 'p', 'צ': 'ts',
      'ק': 'k', 'ר': 'r', 'ש': 'sh', 'ת': 't',
    };

    String result = text;
    hebrewMap.forEach((hebrew, latin) {
      result = result.replaceAll(hebrew, latin);
    });

    return result;
  }

  String _romanizeThai(String text) {
    // Basic Thai romanization (simplified)
    // In a real implementation, use a dedicated Thai romanization library
    // For now, return the original text
    return text;
  }

  void clearCache() {
    _romanizationCache.clear();
    debugPrint('Romanization cache cleared');
  }

  Future<void> saveCache() async {
    // Implementation for persisting cache
    debugPrint('Romanization cache saved');
  }

  Future<void> loadCache() async {
    // Implementation for loading cache
    debugPrint('Romanization cache loaded');
  }
}