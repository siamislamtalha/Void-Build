import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum LyricsSource {
  lrcLib,
  netease,
  kugou,
  lyrist,
  musixmatch,
  genius,
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
      orElse: () => LyricsSource.lrcLib,
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
    LyricsSource.lrcLib,
    LyricsSource.spotify,
    LyricsSource.google, // JioSaavn / Web
    LyricsSource.netease,
    LyricsSource.kugou,
    LyricsSource.lyrist,
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

    final cleanT = _cleanTitle(title);
    final cleanA = _cleanArtist(artist);
    final cacheKey = '${cleanT.toLowerCase()}_${cleanA.toLowerCase()}';
    
    // Check cache first
    if (_lyricsCache.containsKey(cacheKey)) {
      debugPrint('Lyrics found in cache for: $cacheKey');
      return _lyricsCache[cacheKey];
    }

    final titleVariants = _generateTitleVariants(title, cleanT);
    final artistVariants = _generateArtistVariants(artist, cleanA);

    // Try each source in priority order
    for (final source in _sourcePriority) {
      for (final t in titleVariants) {
        for (final a in artistVariants) {
          try {
            final lyrics = await _fetchFromSource(
              source,
              title: t,
              artist: a,
              rawTitle: title,
              rawArtist: artist,
              album: album,
              duration: duration,
            );

            if (lyrics != null && lyrics.text.trim().isNotEmpty) {
              _lyricsCache[cacheKey] = lyrics;
              debugPrint('Lyrics fetched successfully from: ${source.name} using ($t - $a)');
              return lyrics;
            }
          } catch (e) {
            debugPrint('Error fetching lyrics from ${source.name}: $e');
            continue;
          }
        }
      }
    }

    debugPrint('No lyrics found from any online source for $title - $artist');
    return null;
  }

  List<String> _generateTitleVariants(String raw, String clean) {
    final list = <String>[];
    if (clean.isNotEmpty) list.add(clean);
    if (raw.isNotEmpty && raw != clean) list.add(raw);
    final noParen = raw.replaceAll(RegExp(r'\s*[\(\[\{].*?[\)\]\}]'), '').trim();
    if (noParen.isNotEmpty && !list.contains(noParen)) list.add(noParen);
    return list;
  }

  List<String> _generateArtistVariants(String raw, String clean) {
    final list = <String>[];
    if (clean.isNotEmpty) list.add(clean);
    if (raw.isNotEmpty && raw != clean) list.add(raw);
    return list;
  }

  Future<LyricsData?> _fetchFromSource(
    LyricsSource source, {
    required String title,
    required String artist,
    required String rawTitle,
    required String rawArtist,
    String? album,
    Duration? duration,
  }) async {
    switch (source) {
      case LyricsSource.lrcLib:
        return await _fetchFromLrcLib(title, artist, rawTitle, rawArtist, duration);
      case LyricsSource.spotify:
        return await _fetchFromSpotifyLyricApi(title, artist);
      case LyricsSource.google:
        return await _fetchFromSaavn(title, artist);
      case LyricsSource.netease:
        return await _fetchFromNetease(title, artist);
      case LyricsSource.kugou:
        return await _fetchFromKugou(title, artist);
      case LyricsSource.lyrist:
        return await _fetchFromLyrist(title, artist);
      default:
        return await _fetchFromLrcLib(title, artist, rawTitle, rawArtist, duration);
    }
  }

  Map<String, String> get _headers => {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };

  String _cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'\s*[\(\[\{].*?[\)\]\}]'), '')
        .replaceAll(RegExp(r'\b(official video|official audio|music video|lyric video|remastered|version|live|deluxe|bonus track|hd|4k|feat\.?|ft\.?|featuring)\b.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _cleanArtist(String artist) {
    return artist
        .split(RegExp(r'[,&/]| \b(feat\.?|ft\.?|featuring|vs\.?)\b', caseSensitive: false))
        .first
        .replaceAll(RegExp(r'\s*[\(\[\{].*?[\)\]\}]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // 1. LRCLIB Provider (Direct + Search fallback with duration matching)
  Future<LyricsData?> _fetchFromLrcLib(
    String title,
    String artist,
    String rawTitle,
    String rawArtist,
    Duration? duration,
  ) async {
    try {
      final durSec = duration != null ? (duration.inMilliseconds / 1000).round() : null;

      // Direct get attempt
      var getUrl = 'https://lrclib.net/api/get?track_name=${Uri.encodeComponent(title)}&artist_name=${Uri.encodeComponent(artist)}';
      if (durSec != null && durSec > 0) {
        getUrl += '&duration=$durSec';
      }

      final getResponse = await http.get(Uri.parse(getUrl), headers: _headers).timeout(const Duration(seconds: 4));
      if (getResponse.statusCode == 200) {
        final json = jsonDecode(getResponse.body) as Map<String, dynamic>;
        final synced = json['syncedLyrics'] as String?;
        final plain = json['plainLyrics'] as String?;
        if (synced != null && synced.trim().isNotEmpty) {
          return LyricsData(text: synced, source: LyricsSource.lrcLib, isSynced: true);
        } else if (plain != null && plain.trim().isNotEmpty) {
          return LyricsData(text: plain, source: LyricsSource.lrcLib, isSynced: false);
        }
      }

      // Search fallback attempt
      final searchUrl = 'https://lrclib.net/api/search?q=${Uri.encodeComponent("$artist $title")}';
      final searchResponse = await http.get(Uri.parse(searchUrl), headers: _headers).timeout(const Duration(seconds: 4));
      if (searchResponse.statusCode == 200) {
        final list = jsonDecode(searchResponse.body) as List<dynamic>;
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final synced = item['syncedLyrics'] as String?;
            final plain = item['plainLyrics'] as String?;
            if (synced != null && synced.trim().isNotEmpty) {
              return LyricsData(text: synced, source: LyricsSource.lrcLib, isSynced: true);
            } else if (plain != null && plain.trim().isNotEmpty) {
              return LyricsData(text: plain, source: LyricsSource.lrcLib, isSynced: false);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('LrcLib fetch error: $e');
    }

    return null;
  }

  // 2. Spotify Lyrics API Endpoint (Community Mirror)
  Future<LyricsData?> _fetchFromSpotifyLyricApi(String title, String artist) async {
    try {
      final query = Uri.encodeComponent('$title $artist');
      final searchUri = Uri.parse('https://spotify-lyric-api-984e7b4face0.herokuapp.com/?q=$query&format=lrc');
      final res = await http.get(searchUri, headers: _headers).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        if (json['error'] == false && json['lines'] is List) {
          final lines = json['lines'] as List<dynamic>;
          final isSynced = json['syncType'] == 'LINE_SYNCED';
          final lyricsStr = isSynced
              ? lines.map((e) => '[${e["timeTag"]}]${e["words"]}').join('\n')
              : lines.map((e) => e['words']).join('\n');
          if (lyricsStr.trim().isNotEmpty) {
            return LyricsData(text: lyricsStr, source: LyricsSource.spotify, isSynced: isSynced);
          }
        }
      }
    } catch (e) {
      debugPrint('Spotify Lyric API error: $e');
    }
    return null;
  }

  // 3. JioSaavn Lyrics API Provider
  Future<LyricsData?> _fetchFromSaavn(String title, String artist) async {
    try {
      final query = Uri.encodeComponent('$title $artist');
      final searchUri = Uri.parse('https://www.jiosaavn.com/api.php?__call=autocomplete.get&query=$query&ctx=web6dot0&_format=json&_marker=0');
      final searchRes = await http.get(searchUri, headers: _headers).timeout(const Duration(seconds: 4));
      if (searchRes.statusCode == 200) {
        final json = jsonDecode(searchRes.body) as Map<String, dynamic>;
        final songs = json['songs']?['data'] as List<dynamic>?;
        if (songs != null && songs.isNotEmpty) {
          final songId = songs.first['id'];
          if (songId != null) {
            final lyricUri = Uri.parse('https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&lyrics_id=$songId&ctx=web6dot0&api_version=4&_format=json');
            final lyricRes = await http.get(lyricUri, headers: _headers).timeout(const Duration(seconds: 4));
            if (lyricRes.statusCode == 200) {
              final rawBody = lyricRes.body;
              final split = rawBody.split('-->');
              final jsonStr = split.length > 1 ? split[1] : split[0];
              final lyricJson = jsonDecode(jsonStr) as Map<String, dynamic>;
              final lyricsStr = lyricJson['lyrics']?.toString().replaceAll('<br>', '\n');
              if (lyricsStr != null && lyricsStr.trim().isNotEmpty) {
                return LyricsData(
                  text: lyricsStr,
                  source: LyricsSource.google,
                  isSynced: lyricsStr.contains(RegExp(r'\[\d{2}:\d{2}')),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('JioSaavn lyrics error: $e');
    }
    return null;
  }

  // 4. NetEase 163 Cloud Music Provider (Massive LRC DB)
  Future<LyricsData?> _fetchFromNetease(String title, String artist) async {
    try {
      final query = Uri.encodeComponent('$artist $title');
      final searchUri = Uri.parse('https://music.163.com/api/search/get/web?csrf_token=&type=1&offset=0&total=true&limit=5&s=$query');
      
      final searchRes = await http.get(searchUri, headers: _headers).timeout(const Duration(seconds: 4));
      if (searchRes.statusCode == 200) {
        final json = jsonDecode(searchRes.body) as Map<String, dynamic>;
        final result = json['result'] as Map<String, dynamic>?;
        final songs = result?['songs'] as List<dynamic>?;
        if (songs != null && songs.isNotEmpty) {
          final songId = songs.first['id'];
          final lyricUri = Uri.parse('https://music.163.com/api/song/lyric?os=pc&id=$songId&lv=-1&kv=-1&tv=-1');
          final lyricRes = await http.get(lyricUri, headers: _headers).timeout(const Duration(seconds: 4));
          if (lyricRes.statusCode == 200) {
            final lyricJson = jsonDecode(lyricRes.body) as Map<String, dynamic>;
            final lrcObj = lyricJson['lrc'] as Map<String, dynamic>?;
            final lyricStr = lrcObj?['lyric'] as String?;
            if (lyricStr != null && lyricStr.trim().isNotEmpty) {
              final isSynced = lyricStr.contains(RegExp(r'\[\d{2}:\d{2}'));
              return LyricsData(
                text: lyricStr,
                source: LyricsSource.netease,
                isSynced: isSynced,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('NetEase lyrics error: $e');
    }
    return null;
  }

  // 5. KuGou Music Provider (High-quality synced LRC)
  Future<LyricsData?> _fetchFromKugou(String title, String artist) async {
    try {
      final keyword = Uri.encodeComponent('$artist - $title');
      final searchUri = Uri.parse('http://lyrics.kugou.com/search?ver=1&man=yes&client=pc&keyword=$keyword');
      
      final searchRes = await http.get(searchUri, headers: _headers).timeout(const Duration(seconds: 4));
      if (searchRes.statusCode == 200) {
        final json = jsonDecode(searchRes.body) as Map<String, dynamic>;
        final candidates = json['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final cand = candidates.first as Map<String, dynamic>;
          final id = cand['id'];
          final accessKey = cand['accesskey'];
          if (id != null && accessKey != null) {
            final dlUri = Uri.parse('http://lyrics.kugou.com/download?ver=1&client=pc&id=$id&accesskey=$accessKey&fmt=lrc&charset=utf8');
            final dlRes = await http.get(dlUri, headers: _headers).timeout(const Duration(seconds: 4));
            if (dlRes.statusCode == 200) {
              final dlJson = jsonDecode(dlRes.body) as Map<String, dynamic>;
              final base64Content = dlJson['content'] as String?;
              if (base64Content != null && base64Content.isNotEmpty) {
                final decoded = utf8.decode(base64.decode(base64Content));
                if (decoded.trim().isNotEmpty) {
                  return LyricsData(
                    text: decoded,
                    source: LyricsSource.kugou,
                    isSynced: decoded.contains(RegExp(r'\[\d{2}:\d{2}')),
                  );
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('KuGou lyrics error: $e');
    }
    return null;
  }

  // 6. Lyrist API Provider
  Future<LyricsData?> _fetchFromLyrist(String title, String artist) async {
    try {
      final uri = Uri.parse('https://lyrist.vercel.app/api/${Uri.encodeComponent(title)}/${Uri.encodeComponent(artist)}');
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final lyrics = json['lyrics'] as String?;
        if (lyrics != null && lyrics.trim().isNotEmpty) {
          final isSynced = lyrics.contains(RegExp(r'\[\d{2}:\d{2}'));
          return LyricsData(
            text: lyrics,
            source: LyricsSource.lyrist,
            isSynced: isSynced,
          );
        }
      }
    } catch (e) {
      debugPrint('Lyrist lyrics error: $e');
    }
    return null;
  }

  void clearCache() {
    _lyricsCache.clear();
    debugPrint('Lyrics cache cleared');
  }

  void clearCachedLyrics(String title, String artist) {
    final cleanT = _cleanTitle(title);
    final cleanA = _cleanArtist(artist);
    final cacheKey = '${cleanT.toLowerCase()}_${cleanA.toLowerCase()}';
    _lyricsCache.remove(cacheKey);
  }
}