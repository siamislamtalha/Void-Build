import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart';

class LyricsTranslationService {
  static LyricsTranslationService? _instance;
  static LyricsTranslationService get instance => 
      _instance ??= LyricsTranslationService._();
  
  LyricsTranslationService._();

  final GoogleTranslator _translator = GoogleTranslator();
  final Map<String, String> _translationCache = {};
  bool _isEnabled = true;
  String _targetLanguage = 'en'; // Default to English

  bool get isEnabled => _isEnabled;
  String get targetLanguage => _targetLanguage;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('Lyrics translation ${enabled ? "enabled" : "disabled"}');
  }

  void setTargetLanguage(String languageCode) {
    _targetLanguage = languageCode;
    debugPrint('Target language set to: $languageCode');
  }

  Future<String> translateLyrics(
    String originalText,
    String sourceLanguage,
  ) async {
    if (!_isEnabled) return originalText;

    final cacheKey = '${originalText.hashCode}_$sourceLanguage$_targetLanguage';
    
    // Check cache first
    if (_translationCache.containsKey(cacheKey)) {
      debugPrint('Translation found in cache');
      return _translationCache[cacheKey]!;
    }

    try {
      // Translate the lyrics using the translator package
      final translation = await _translator.translate(
        originalText,
        from: sourceLanguage,
        to: _targetLanguage,
      );

      // Cache the result
      _translationCache[cacheKey] = translation.text;
      
      debugPrint('Lyrics translated successfully');
      return translation.text;
    } catch (e) {
      debugPrint('Error translating lyrics: $e');
      return originalText; // Return original on error
    }
  }

  Future<String> detectLanguage(String text) async {
    try {
      // Use auto-detection by not specifying source language
      await _translator.translate(text, to: _targetLanguage);
      // Return the detected language or default to auto
      return 'auto';
    } catch (e) {
      debugPrint('Error detecting language: $e');
      return 'auto';
    }
  }

  void clearCache() {
    _translationCache.clear();
    debugPrint('Translation cache cleared');
  }

  Map<String, dynamic> getSettings() {
    return {
      'isEnabled': _isEnabled,
      'targetLanguage': _targetLanguage,
      'cachedTranslations': _translationCache.length,
    };
  }

  // Get supported languages
  Map<String, String> getSupportedLanguages() {
    return {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
      'ar': 'Arabic',
      'hi': 'Hindi',
      'tr': 'Turkish',
      'nl': 'Dutch',
      'pl': 'Polish',
      'sv': 'Swedish',
      'da': 'Danish',
      'no': 'Norwegian',
      'fi': 'Finnish',
      'el': 'Greek',
      'he': 'Hebrew',
      'th': 'Thai',
      'vi': 'Vietnamese',
      'id': 'Indonesian',
      'ms': 'Malay',
      'uk': 'Ukrainian',
      'cs': 'Czech',
      'ro': 'Romanian',
      'hu': 'Hungarian',
    };
  }
}