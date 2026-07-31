import 'dart:async';
import 'dart:convert';
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

  Map<String, String> get _headers => {
    'User-Agent': 'VoidMusic/1.0 (https://github.com/voidmusic)',
    'Accept': 'application/json',
  };

  String _cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'\s*[\(\[\{].*?[\)\]\}]'), '')
        .replaceAll(RegExp(r'\b(feat\.?|ft\.?|featuring|remastered|version|live|deluxe)\b.*$', caseSensitive: false), '')
        .trim();
  }

  String _cleanArtist(String artist) {
    return artist
        .split(RegExp(r'[,&/]| \b(feat\.?|ft\.?|featuring)\b', caseSensitive: false))
        .first
        .trim();
  }

  Future<LyricsData?> _fetchFromMusixmatch(
    String title,
    String artist,
    String? album,
  ) async {
    return _fetchFromLrcLib(title, artist, null);
  }

  Future<LyricsData?> _fetchFromGenius(
    String title,
    String artist,
  ) async {
    return _fetchFromGoogle(title, artist);
  }

  Future<LyricsData?> _fetchFromLrcLib(
    String title,
    String artist,
    Duration? duration,
  ) async {
    try {
      final cleanT = _cleanTitle(title);
      final cleanA = _cleanArtist(artist);

      // Direct get attempt
      final getUri = Uri.parse(
        'https://lrclib.net/api/get?track_name=${Uri.encodeComponent(cleanT)}&artist_name=${Uri.encodeComponent(cleanA)}',
      );
      final getResponse = await http.get(getUri, headers: _headers).timeout(const Duration(seconds: 4));

      if (getResponse.statusCode == 200) {
        final json = jsonDecode(getResponse.body) as Map<String, dynamic>;
        final synced = json['syncedLyrics'] as String?;
        final plain = json['plainLyrics'] as String?;
        if (synced != null && synced.trim().isNotEmpty) {
          return LyricsData(
            text: synced,
            source: LyricsSource.lrcLib,
            isSynced: true,
          );
        } else if (plain != null && plain.trim().isNotEmpty) {
          return LyricsData(
            text: plain,
            source: LyricsSource.lrcLib,
            isSynced: false,
          );
        }
      }

      // Fallback search attempt
      final searchUri = Uri.parse(
        'https://lrclib.net/api/search?q=${Uri.encodeComponent("$cleanA $cleanT")}',
      );
      final searchResponse = await http.get(searchUri, headers: _headers).timeout(const Duration(seconds: 4));

      if (searchResponse.statusCode == 200) {
        final list = jsonDecode(searchResponse.body) as List<dynamic>;
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final synced = item['syncedLyrics'] as String?;
            final plain = item['plainLyrics'] as String?;
            if (synced != null && synced.trim().isNotEmpty) {
              return LyricsData(
                text: synced,
                source: LyricsSource.lrcLib,
                isSynced: true,
              );
            } else if (plain != null && plain.trim().isNotEmpty) {
              return LyricsData(
                text: plain,
                source: LyricsSource.lrcLib,
                isSynced: false,
              );
            }
          }
        }
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
    return _fetchFromLrcLib(title, artist, null);
  }

  Future<LyricsData?> _fetchFromGoogle(
    String title,
    String artist,
  ) async {
    try {
      final cleanT = _cleanTitle(title);
      final cleanA = _cleanArtist(artist);
      final uri = Uri.parse(
        'https://lyrist.vercel.app/api/${Uri.encodeComponent(cleanT)}/${Uri.encodeComponent(cleanA)}',
      );
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final lyrics = json['lyrics'] as String?;
        if (lyrics != null && lyrics.trim().isNotEmpty) {
          return LyricsData(
            text: lyrics,
            source: LyricsSource.google,
            isSynced: false,
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching lyrics from online provider: $e');
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