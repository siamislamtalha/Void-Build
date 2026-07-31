import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum LyricsSource {
  musixmatch,
  genius,
  lrcLib,
  spotify,
  google,
}

class LyricsData {
  final String text;
  final LyricsSource source;
  final bool isSynced;
  final String? language;
  
  LyricsData({
    required this.text,
    required this.source,
    this.isSynced = false,
    this.language,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'source': source.toString(),
    'isSynced': isSynced,
    'language': language,
  };

  factory LyricsData.fromJson(Map<String, dynamic> json) => LyricsData(
    text: json['text'] as String,
    source: LyricsSource.values.firstWhere(
      (e) => e.toString() == json['source'],
    ),
    isSynced: json['isSynced'] as bool? ?? false,
    language: json['language'] as String?,
  );
}

class MultiSourceLyricsService {
  static MultiSourceLyricsService? _instance;
  static MultiSourceLyricsService get instance => 
      _instance ??= MultiSourceLyricsService._();
  
  MultiSourceLyricsService._();

  final List<LyricsSource> _sourcePriority = [
    LyricsSource.musixmatch,
    LyricsSource.genius,
    LyricsSource.lrcLib,
    LyricsSource.spotify,
    LyricsSource.google,
  ];
  
  final Map<String, LyricsData> _lyricsCache = {};
  bool _isEnabled = true;
  bool _preferSynced = true;

  List<LyricsSource> get sourcePriority => List.unmodifiable(_sourcePriority);
  bool get isEnabled => _isEnabled;
  bool get preferSynced => _preferSynced;

  void setSourcePriority(List<LyricsSource> priority) {
    _sourcePriority.clear();
    _sourcePriority.addAll(priority);
    debugPrint('Lyrics source priority updated');
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('Multi-source lyrics ${enabled ? "enabled" : "disabled"}');
  }

  void setPreferSynced(bool prefer) {
    _preferSynced = prefer;
    debugPrint('Prefer synced lyrics: $prefer');
  }

  Future<LyricsData?> fetchLyrics({
    required String title,
    required String artist,
    String? album,
    Duration? duration,
  }) async {
    if (!_isEnabled) return null;

    final cacheKey = '${title.toLowerCase()}_${artist.toLowerCase()}';
    
    // Check cache first
    if (_lyricsCache.containsKey(cacheKey)) {
      debugPrint('Lyrics found in cache');
      return _lyricsCache[cacheKey];
    }

    // Try each source in priority order
    for (final source in _sourcePriority) {
      try {
        final lyrics = await _fetchFromSource(
          source,
          title: title,
          artist: artist,
          album: album,
          duration: duration,
        );

        if (lyrics != null) {
          // Cache the result
          _lyricsCache[cacheKey] = lyrics;
          debugPrint('Lyrics fetched from: $source');
          return lyrics;
        }
      } catch (e) {
        debugPrint('Error fetching from $source: $e');
        continue;
      }
    }

    debugPrint('No lyrics found from any source');
    return null;
  }

  Future<LyricsData?> _fetchFromSource(
    LyricsSource source, {
    required String title,
    required String artist,
    String? album,
    Duration? duration,
  }) async {
    switch (source) {
      case LyricsSource.musixmatch:
        return await _fetchFromMusixmatch(title, artist, album);
      case LyricsSource.genius:
        return await _fetchFromGenius(title, artist);
      case LyricsSource.lrcLib:
        return await _fetchFromLrcLib(title, artist, duration);
      case LyricsSource.spotify:
        return await _fetchFromSpotify(title, artist, album);
      case LyricsSource.google:
        return await _fetchFromGoogle(title, artist);
    }
  }

  Future<LyricsData?> _fetchFromMusixmatch(
    String title,
    String artist,
    String? album,
  ) async {
    // TODO: Implement Musixmatch API integration
    // This would require API authentication and proper endpoint usage
    
    // Placeholder implementation
    await Future.delayed(const Duration(milliseconds: 500));
    return null;
  }

  Future<LyricsData?> _fetchFromGenius(
    String title,
    String artist,
  ) async {
    // TODO: Implement Genius API integration
    // Genius has a public API that can be used
    
    // Placeholder implementation
    await Future.delayed(const Duration(milliseconds: 500));
    return null;
  }

  Future<LyricsData?> _fetchFromLrcLib(
    String title,
    String artist,
    Duration? duration,
  ) async {
    // LrcLib has a public API for synced lyrics
    try {
      final query = '$artist $title'.replaceAll(' ', '+');
      final response = await http.get(
        Uri.parse('https://lrclib.net/api/search?q=$query'),
      );

      if (response.statusCode == 200) {
        // Parse response and extract lyrics
        // TODO: Implement proper JSON parsing
        debugPrint('LrcLib response: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching from LrcLib: $e');
    }

    return null;
  }

  Future<LyricsData?> _fetchFromSpotify(
    String title,
    String artist,
    String? album,
  ) async {
    // TODO: Implement Spotify lyrics fetching
    // This would require Spotify API authentication
    
    // Placeholder implementation
    await Future.delayed(const Duration(milliseconds: 500));
    return null;
  }

  Future<LyricsData?> _fetchFromGoogle(
    String title,
    String artist,
  ) async {
    // Google search as fallback - search for lyrics
    try {
      final query = '${artist.replaceFirst(' ', '+')}+$title+lyrics'
          .replaceAll(' ', '+');
      final response = await http.get(
        Uri.parse('https://www.google.com/search?q=$query'),
      );

      if (response.statusCode == 200) {
        // Parse HTML to extract lyrics
        // TODO: Implement HTML parsing
        debugPrint('Google search completed');
      }
    } catch (e) {
      debugPrint('Error fetching from Google: $e');
    }

    return null;
  }

  void clearCache() {
    _lyricsCache.clear();
    debugPrint('Lyrics cache cleared');
  }

  void clearCachedLyrics(String title, String artist) {
    final cacheKey = '${title.toLowerCase()}_${artist.toLowerCase()}';
    _lyricsCache.remove(cacheKey);
  }

  Map<String, dynamic> getSettings() {
    return {
      'isEnabled': _isEnabled,
      'preferSynced': _preferSynced,
      'sourcePriority': _sourcePriority.map((s) => s.toString()).toList(),
      'cachedLyrics': _lyricsCache.length,
    };
  }
}