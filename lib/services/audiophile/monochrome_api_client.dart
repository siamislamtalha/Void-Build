import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:voidmusic/services/audiophile/zarz_moe_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Monochrome API Client
// Based on lossless-unified/Resonada proxy.rs instance list and credentials.
// These are the same Monochrome API instances the Resonada / lossless-unified
// plugin uses to serve FLAC / ALAC / DSD streams with no user login required.
// ─────────────────────────────────────────────────────────────────────────────

/// Quality tier matching Resonada's Quality enum in types.rs
enum LosslessQuality {
  dolbyAtmos(6, 'DOLBY_ATMOS', 'Dolby Atmos', 4704),
  ultraHiRes(5, 'ULTRA_HI_RES', '24-bit / 192 kHz', 9408),
  hiRes(4, 'HI_RES', '24-bit / 96 kHz', 4704),
  losslessFlac(3, 'LOSSLESS_FLAC', 'FLAC 16-bit / 44.1 kHz', 1411),
  high(2, 'HIGH', '320 kbps', 320),
  normal(1, 'NORMAL', '128 kbps', 128),
  low(0, 'LOW', '64 kbps', 64);

  final int level;
  final String id;
  final String label;
  final int bitrate;

  const LosslessQuality(this.level, this.id, this.label, this.bitrate);

  bool get isLossless => level >= 3;

  static LosslessQuality fromString(String s) {
    final upper = s.toUpperCase();
    for (final q in LosslessQuality.values) {
      if (q.id == upper) return q;
    }
    return LosslessQuality.losslessFlac;
  }
}

/// Unified track from Monochrome / lossless-unified
class MonochromeTrack {
  final String id;
  final String title;
  final String artistName;
  final List<MonochromeArtist> artists;
  final MonochromeAlbum? album;
  final int durationMs;
  final String? audioQuality;
  final List<String>? audioModes;
  final String? streamUrl;
  final String source; // deezer | qobuz | tidal | soundcloud

  const MonochromeTrack({
    required this.id,
    required this.title,
    required this.artistName,
    required this.artists,
    this.album,
    required this.durationMs,
    this.audioQuality,
    this.audioModes,
    this.streamUrl,
    required this.source,
  });

  String get thumbnailUrl {
    final cover = album?.cover ?? album?.coverBig;
    if (cover != null && cover.isNotEmpty) return cover;
    return '';
  }

  bool get isHiRes {
    final q = (audioQuality ?? '').toUpperCase();
    return q.contains('HI_RES') || q.contains('ULTRA') || q.contains('DOLBY');
  }

  String get qualityBadge {
    final q = (audioQuality ?? '').toUpperCase();
    if (q.contains('DOLBY')) return 'DOLBY ATMOS';
    if (q.contains('ULTRA')) return 'ULTRA HI-RES';
    if (q.contains('HI_RES')) return 'HI-RES FLAC';
    if (q.contains('LOSSLESS') || q.contains('FLAC')) return 'FLAC';
    if (q.contains('MQA')) return 'MQA';
    return 'LOSSLESS';
  }

  factory MonochromeTrack.fromJson(Map<String, dynamic> json) {
    final rawArtists = json['artists'] as List? ?? [];
    final artists = rawArtists
        .map((a) => MonochromeArtist.fromJson(a as Map<String, dynamic>))
        .toList();

    final artistName = artists.isNotEmpty
        ? artists.map((a) => a.name).join(', ')
        : (json['artist']?['name'] ?? 'Unknown Artist').toString();

    final rawAlbum = json['album'];
    MonochromeAlbum? album;
    if (rawAlbum is Map<String, dynamic>) {
      album = MonochromeAlbum.fromJson(rawAlbum);
    }

    // Source detection from prefixed ID (e.g. "tidal:12345", "deezer:67890")
    final rawId = (json['id'] ?? '').toString();
    String source = 'deezer';
    String cleanId = rawId;
    if (rawId.contains(':')) {
      final parts = rawId.split(':');
      source = parts.first.toLowerCase();
      cleanId = parts.sublist(1).join(':');
    }

    final durationMs = _parseInt(json['duration_ms']) ??
        (_parseInt(json['duration'] as dynamic) != null
            ? _parseInt(json['duration'] as dynamic)! * 1000
            : 0);

    return MonochromeTrack(
      id: rawId.isNotEmpty ? rawId : cleanId,
      title: (json['title'] ?? 'Unknown Track').toString(),
      artistName: artistName,
      artists: artists,
      album: album,
      durationMs: durationMs,
      audioQuality: json['audio_quality']?.toString(),
      audioModes: (json['audio_modes'] as List?)?.map((e) => e.toString()).toList(),
      streamUrl: json['stream_url']?.toString(),
      source: source,
    );
  }
}

class MonochromeArtist {
  final String id;
  final String name;
  final String? picture;

  const MonochromeArtist({
    required this.id,
    required this.name,
    this.picture,
  });

  factory MonochromeArtist.fromJson(Map<String, dynamic> json) {
    return MonochromeArtist(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown Artist').toString(),
      picture: json['picture']?.toString(),
    );
  }
}

class MonochromeAlbum {
  final String id;
  final String title;
  final String? cover;
  final String? coverBig;
  final String? releaseDate;
  final int? trackCount;
  final List<MonochromeArtist> artists;

  const MonochromeAlbum({
    required this.id,
    required this.title,
    this.cover,
    this.coverBig,
    this.releaseDate,
    this.trackCount,
    this.artists = const [],
  });

  factory MonochromeAlbum.fromJson(Map<String, dynamic> json) {
    final rawArtists = json['artists'] as List? ?? [];
    final artists = rawArtists
        .map((a) => MonochromeArtist.fromJson(a as Map<String, dynamic>))
        .toList();
    return MonochromeAlbum(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Unknown Album').toString(),
      cover: json['cover']?.toString() ?? json['cover_small']?.toString(),
      coverBig: json['cover_big']?.toString() ?? json['cover']?.toString(),
      releaseDate: json['release_date']?.toString(),
      trackCount: _parseInt(json['track_count']),
      artists: artists,
    );
  }
}

class MonochromeStreamInfo {
  final String url;
  final LosslessQuality quality;
  final String codec;
  final int? bitrate;
  final int? sampleRate;
  final int? bitDepth;
  final String? encryptionKey;

  const MonochromeStreamInfo({
    required this.url,
    required this.quality,
    required this.codec,
    this.bitrate,
    this.sampleRate,
    this.bitDepth,
    this.encryptionKey,
  });

  bool get isLossless => quality.isLossless;

  String get formatLabel {
    final c = codec.toUpperCase();
    if (c.contains('FLAC')) return 'FLAC';
    if (c.contains('ALAC')) return 'ALAC';
    if (c.contains('DSD') || c.contains('DSF') || c.contains('DFF')) return 'DSD';
    if (c.contains('MQA')) return 'MQA';
    if (c.contains('EAC3') || c.contains('ATMOS')) return 'DOLBY ATMOS';
    if (c.contains('AAC') || c.contains('M4A')) return 'AAC';
    if (c.contains('OPUS')) return 'OPUS';
    if (c.contains('MP3')) return 'MP3';
    return codec.isNotEmpty ? codec : 'FLAC';
  }

  factory MonochromeStreamInfo.fromJson(Map<String, dynamic> json) {
    final qualityStr = json['quality']?.toString() ?? 'LOSSLESS_FLAC';
    return MonochromeStreamInfo(
      url: (json['url'] ?? json['stream_url'] ?? '').toString(),
      quality: LosslessQuality.fromString(qualityStr),
      codec: (json['codec'] ?? 'flac').toString(),
      bitrate: _parseInt(json['bitrate']),
      sampleRate: _parseInt(json['sample_rate']),
      bitDepth: _parseInt(json['bit_depth']),
      encryptionKey: json['encryption_key']?.toString(),
    );
  }
}

class MonochromeSearchResult {
  final List<MonochromeTrack> tracks;
  final List<MonochromeAlbum> albums;
  final List<MonochromeArtist> artists;
  final int total;

  const MonochromeSearchResult({
    required this.tracks,
    required this.albums,
    required this.artists,
    required this.total,
  });

  static const empty = MonochromeSearchResult(
    tracks: [],
    albums: [],
    artists: [],
    total: 0,
  );
}

class MonochromeHomeSection {
  final String id;
  final String title;
  final String? subtitle;
  final List<MonochromeTrack> tracks;
  final List<MonochromeAlbum> albums;
  final String source;
  final String sectionType; // Featured | NewReleases | Charts | Trending

  const MonochromeHomeSection({
    required this.id,
    required this.title,
    this.subtitle,
    this.tracks = const [],
    this.albums = const [],
    required this.source,
    required this.sectionType,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// The Client
// ─────────────────────────────────────────────────────────────────────────────

class MonochromeApiClient {
  static final MonochromeApiClient _instance = MonochromeApiClient._internal();
  factory MonochromeApiClient() => _instance;
  MonochromeApiClient._internal();

  // Monochrome API instances from lossless-unified/proxy.rs
  // These are public community Monochrome servers — no auth required for metadata.
  static const List<String> _instances = [
    'https://eu-central.monochrome.tf',
    'https://us-west.monochrome.tf',
    'https://api.monochrome.tf',
    'https://monochrome-api.samidy.com',
    'https://triton.squid.wtf',
    'https://wolf.qqdl.site',
    'https://maus.qqdl.site',
    'https://vogel.qqdl.site',
    'https://hund.qqdl.site',
    'https://tidal.kinoplus.online',
  ];

  // Unified Playback API from proxy.rs get_unified_api_credentials()
  static const String _unifiedApiToken =
      'amp_29b2lIr4mze4tK-P8QDOxfMZ9anCgJ9_uGTUks3nIyo';
  static const String _unifiedApiBaseUrl = 'https://music-api.geeked.wtf';

  // Public Deezer API — free, no auth needed for metadata
  static const String _deezerApiBase = 'https://api.deezer.com';

  // Public Tidal token from tidal-web plugin manifest
  static const String _tidalPublicToken = '49YxDN9a2aFV6RTG';
  static const String _tidalApiBase = 'https://listen.tidal.com/v1';

  final http.Client _http = http.Client();
  final ZarzMoeClient _zarzClient = ZarzMoeClient();

  // ──────────────────────────────────────────────────────────────────────────
  // Core: Fetch from Monochrome instances with fallback
  // ──────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _fetchMonochrome(String path,
      {Map<String, String>? params, Duration timeout = const Duration(seconds: 8)}) async {
    for (final base in _instances) {
      try {
        final uri = Uri.parse('$base$path').replace(queryParameters: params);
        final res = await _http.get(uri).timeout(timeout);
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          if (body is Map<String, dynamic>) return body;
        }
      } catch (e) {
        log('Monochrome instance $base failed: $e', name: 'MonochromeApiClient');
      }
    }
    return _fetchUnified(path, params: params);
  }

  Future<Map<String, dynamic>?> _fetchUnified(String path,
      {Map<String, String>? params}) async {
    try {
      final uri = Uri.parse('$_unifiedApiBaseUrl$path')
          .replace(queryParameters: params);
      final res = await _http
          .get(uri, headers: {'Authorization': 'Bearer $_unifiedApiToken'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic>) return body;
      }
    } catch (e) {
      log('UnifiedAPI failed $path: $e', name: 'MonochromeApiClient');
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Search — Deezer public (no auth) + Monochrome fallback
  // ──────────────────────────────────────────────────────────────────────────

  Future<MonochromeSearchResult> search(String query,
      {String filter = 'all', int limit = 25}) async {
    // Try Deezer public API first (100% free, no auth)
    final deezerResult = await _searchDeezer(query, filter: filter, limit: limit);

    // Also try Monochrome for cross-service results
    final monoResult = await _searchMonochrome(query, filter: filter, limit: limit);

    // Merge — deduplicate by title+artist
    final tracks = <MonochromeTrack>[...deezerResult.tracks];
    final seenIds = tracks.map((t) => t.id).toSet();
    for (final t in monoResult.tracks) {
      if (!seenIds.contains(t.id)) {
        tracks.add(t);
        seenIds.add(t.id);
      }
    }

    final albums = <MonochromeAlbum>[...deezerResult.albums, ...monoResult.albums];
    final artists = <MonochromeArtist>[...deezerResult.artists, ...monoResult.artists];

    return MonochromeSearchResult(
      tracks: tracks.take(limit).toList(),
      albums: albums.take(limit).toList(),
      artists: artists.take(limit).toList(),
      total: tracks.length + albums.length + artists.length,
    );
  }

  Future<MonochromeSearchResult> _searchDeezer(String query,
      {String filter = 'all', int limit = 25}) async {
    try {
      final tracks = <MonochromeTrack>[];
      final albums = <MonochromeAlbum>[];
      final artists = <MonochromeArtist>[];

      if (filter == 'all' || filter == 'track') {
        final uri = Uri.parse('$_deezerApiBase/search/track').replace(
            queryParameters: {'q': query, 'limit': limit.toString()});
        final res = await _http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final items = data['data'] as List? ?? [];
          tracks.addAll(items.map((item) => _parseDeezerTrack(item)).whereType<MonochromeTrack>());
        }
      }

      if (filter == 'all' || filter == 'album') {
        final uri = Uri.parse('$_deezerApiBase/search/album').replace(
            queryParameters: {'q': query, 'limit': '10'});
        final res = await _http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final items = data['data'] as List? ?? [];
          albums.addAll(items.map((item) => _parseDeezerAlbum(item)).whereType<MonochromeAlbum>());
        }
      }

      if (filter == 'all' || filter == 'artist') {
        final uri = Uri.parse('$_deezerApiBase/search/artist').replace(
            queryParameters: {'q': query, 'limit': '10'});
        final res = await _http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final items = data['data'] as List? ?? [];
          artists.addAll(items.map((item) => _parseDeezerArtist(item)).whereType<MonochromeArtist>());
        }
      }

      return MonochromeSearchResult(
        tracks: tracks,
        albums: albums,
        artists: artists,
        total: tracks.length + albums.length + artists.length,
      );
    } catch (e) {
      log('Deezer search failed: $e', name: 'MonochromeApiClient');
      return MonochromeSearchResult.empty;
    }
  }

  Future<MonochromeSearchResult> _searchMonochrome(String query,
      {String filter = 'all', int limit = 10}) async {
    try {
      // Try Monochrome /search endpoint
      final data = await _fetchMonochrome('/search', params: {
        'q': query,
        'type': filter == 'all' ? 'tracks' : filter,
        'limit': limit.toString(),
      });
      if (data == null) return MonochromeSearchResult.empty;

      final rawItems = data['data'] as List? ?? data['items'] as List? ?? [];
      final tracks = <MonochromeTrack>[];
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          try {
            final t = MonochromeTrack.fromJson(item);
            if (t.title.isNotEmpty) tracks.add(t);
          } catch (_) {}
        }
      }
      return MonochromeSearchResult(tracks: tracks, albums: [], artists: [], total: tracks.length);
    } catch (e) {
      log('Monochrome search failed: $e', name: 'MonochromeApiClient');
      return MonochromeSearchResult.empty;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Search Suggestions — Deezer autocomplete
  // ──────────────────────────────────────────────────────────────────────────

  Future<List<String>> getSearchSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      // Deezer search returns real music results, use top track names as suggestions
      final uri = Uri.parse('$_deezerApiBase/search/track').replace(
          queryParameters: {'q': query, 'limit': '8'});
      final res = await _http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = data['data'] as List? ?? [];
        final suggestions = <String>[];
        final seen = <String>{};
        for (final item in items) {
          if (item is Map) {
            final title = item['title']?.toString() ?? '';
            final artist = (item['artist'] as Map?)?['name']?.toString() ?? '';
            if (title.isNotEmpty) {
              final combined = artist.isNotEmpty ? '$title – $artist' : title;
              if (seen.add(combined)) {
                suggestions.add(combined);
              }
            }
          }
        }
        if (suggestions.isNotEmpty) return suggestions.take(6).toList();
      }
    } catch (e) {
      log('Search suggestions failed: $e', name: 'MonochromeApiClient');
    }

    // Fallback: lossless qualifiers
    return [
      '$query FLAC',
      '$query 24-bit HiRes',
      '$query Lossless',
    ];
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Home Feed — from multiple providers (like Resonada's fetch_home_sections)
  // ──────────────────────────────────────────────────────────────────────────

  Future<List<MonochromeHomeSection>> getHomeSections({String? pluginId}) async {
    final sections = <MonochromeHomeSection>[];

    // Determine which provider(s) to query
    final providers = _providersForPlugin(pluginId);

    // Run all providers in parallel
    final futures = providers.map((p) => _fetchProviderHomeSections(p));
    final results = await Future.wait(futures, eagerError: false);

    for (final providerSections in results) {
      sections.addAll(providerSections);
    }

    return sections;
  }

  List<String> _providersForPlugin(String? pluginId) {
    if (pluginId == null) return ['deezer', 'tidal', 'qobuz'];
    if (pluginId.contains('deezer')) return ['deezer'];
    if (pluginId.contains('qobuz')) return ['qobuz'];
    if (pluginId.contains('tidal')) return ['tidal'];
    if (pluginId.contains('ytmusic')) return ['deezer', 'tidal'];
    if (pluginId.contains('apple')) return ['qobuz', 'deezer'];
    if (pluginId.contains('amazon')) return ['qobuz'];
    if (pluginId.contains('soundcloud')) return ['deezer'];
    if (pluginId.contains('pandora')) return ['deezer'];
    if (pluginId.contains('spotify')) return ['deezer', 'qobuz'];
    return ['deezer', 'tidal', 'qobuz'];
  }

  Future<List<MonochromeHomeSection>> _fetchProviderHomeSections(String provider) async {
    switch (provider) {
      case 'deezer':
        return _fetchDeezerHomeSections();
      case 'tidal':
        return _fetchTidalHomeSections();
      case 'qobuz':
        return _fetchQobuzHomeSections();
      default:
        return _fetchDeezerHomeSections();
    }
  }

  Future<List<MonochromeHomeSection>> _fetchDeezerHomeSections() async {
    final sections = <MonochromeHomeSection>[];
    try {
      // Deezer Charts — public endpoint, no auth
      final chartRes = await _http
          .get(Uri.parse('$_deezerApiBase/chart/0/tracks?limit=20'))
          .timeout(const Duration(seconds: 8));
      if (chartRes.statusCode == 200) {
        final data = jsonDecode(chartRes.body) as Map<String, dynamic>;
        final items = data['data'] as List? ?? [];
        final tracks = items
            .map((item) => _parseDeezerTrack(item))
            .whereType<MonochromeTrack>()
            .toList();
        if (tracks.isNotEmpty) {
          sections.add(MonochromeHomeSection(
            id: 'deezer_charts',
            title: 'Deezer • Top Charts',
            subtitle: 'FLAC 16-bit / 44.1 kHz',
            tracks: tracks,
            source: 'deezer',
            sectionType: 'Charts',
          ));
        }
      }

      // Deezer New Releases (editorial playlists)
      final newRes = await _http
          .get(Uri.parse('$_deezerApiBase/chart/0/albums?limit=20'))
          .timeout(const Duration(seconds: 8));
      if (newRes.statusCode == 200) {
        final data = jsonDecode(newRes.body) as Map<String, dynamic>;
        final items = data['data'] as List? ?? [];
        final albums = items
            .map((item) => _parseDeezerAlbum(item))
            .whereType<MonochromeAlbum>()
            .toList();
        if (albums.isNotEmpty) {
          sections.add(MonochromeHomeSection(
            id: 'deezer_new_releases',
            title: 'Deezer • New Releases',
            subtitle: 'Latest Lossless Albums',
            albums: albums,
            source: 'deezer',
            sectionType: 'NewReleases',
          ));
        }
      }
    } catch (e) {
      log('Deezer home sections failed: $e', name: 'MonochromeApiClient');
    }
    return sections;
  }

  Future<List<MonochromeHomeSection>> _fetchTidalHomeSections() async {
    final sections = <MonochromeHomeSection>[];
    try {
      // Tidal public featured/charts via public token from manifest
      final uri = Uri.parse('$_tidalApiBase/featured?limit=20').replace(queryParameters: {
        'limit': '20',
        'countryCode': 'US',
        'deviceType': 'BROWSER',
      });
      final res = await _http.get(uri, headers: {
        'X-Tidal-Token': _tidalPublicToken,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = data['items'] as List? ?? [];
        final albums = <MonochromeAlbum>[];
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final album = item['album'] ?? item;
            if (album is Map<String, dynamic> && album['id'] != null) {
              albums.add(MonochromeAlbum(
                id: 'tidal:${album['id']}',
                title: (album['title'] ?? '').toString(),
                coverBig: _tidalCoverUrl(album['cover']?.toString(), 1280),
                cover: _tidalCoverUrl(album['cover']?.toString(), 640),
                artists: [(MonochromeArtist(
                  id: 'tidal:${album['artist']?['id'] ?? ''}',
                  name: (album['artist']?['name'] ?? 'Unknown').toString(),
                ))],
              ));
            }
          }
        }
        if (albums.isNotEmpty) {
          sections.add(MonochromeHomeSection(
            id: 'tidal_featured',
            title: 'Tidal • HiRes FLAC',
            subtitle: '24-bit / 96 kHz Lossless',
            albums: albums,
            source: 'tidal',
            sectionType: 'Featured',
          ));
        }
      }

      // Fallback: Tidal new releases via Monochrome
      if (sections.isEmpty) {
        final monoData = await _fetchMonochrome('/tidal/new-releases', params: {
          'limit': '20',
        });
        if (monoData != null) {
          final items = monoData['items'] as List? ?? monoData['data'] as List? ?? [];
          final tracks = items
              .whereType<Map<String, dynamic>>()
              .map((item) {
                try {
                  return MonochromeTrack.fromJson({'source': 'tidal', ...item});
                } catch (_) {
                  return null;
                }
              })
              .whereType<MonochromeTrack>()
              .toList();
          if (tracks.isNotEmpty) {
            sections.add(MonochromeHomeSection(
              id: 'tidal_new_lossless',
              title: 'Tidal • New HiRes Releases',
              subtitle: 'Master Quality Authenticated',
              tracks: tracks,
              source: 'tidal',
              sectionType: 'NewReleases',
            ));
          }
        }
      }
    } catch (e) {
      log('Tidal home sections failed: $e', name: 'MonochromeApiClient');
    }
    return sections;
  }

  Future<List<MonochromeHomeSection>> _fetchQobuzHomeSections() async {
    final sections = <MonochromeHomeSection>[];
    try {
      // Qobuz new releases via zarz proxy (from qobuz-web manifest settings)
      // apiBaseUrl default: https://api.zarz.moe/v1/qbz
      final uri = Uri.parse('https://api.zarz.moe/v1/qbz/featured')
          .replace(queryParameters: {
        'type': 'new-releases',
        'limit': '20',
        'country': 'US',
        'app_id': '798273057', // from manifest
      });
      final res = await _http.get(uri, headers: {
        'User-Agent': 'SpotiFLAC-Mobile/5.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = data['albums']?['items'] as List? ??
            data['items'] as List? ??
            data['data'] as List? ??
            [];
        final albums = <MonochromeAlbum>[];
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            albums.add(MonochromeAlbum(
              id: 'qobuz:${item['id'] ?? ''}',
              title: (item['title'] ?? '').toString(),
              coverBig: item['image']?['large']?.toString() ?? item['cover_big']?.toString(),
              cover: item['image']?['small']?.toString() ?? item['cover']?.toString(),
              artists: [(MonochromeArtist(
                id: 'qobuz:${item['artist']?['id'] ?? ''}',
                name: (item['artist']?['name'] ?? 'Unknown').toString(),
              ))],
            ));
          }
        }
        if (albums.isNotEmpty) {
          sections.add(MonochromeHomeSection(
            id: 'qobuz_new_releases',
            title: 'Qobuz • Studio Masters',
            subtitle: '24-bit / 192 kHz Ultra Hi-Res',
            albums: albums,
            source: 'qobuz',
            sectionType: 'NewReleases',
          ));
        }
      }
    } catch (e) {
      log('Qobuz home sections failed: $e', name: 'MonochromeApiClient');
    }

    // Fallback: Monochrome /qobuz/featured
    if (sections.isEmpty) {
      try {
        final monoData = await _fetchMonochrome('/qobuz/featured');
        if (monoData != null) {
          final items = monoData['albums']?['items'] as List? ??
              monoData['items'] as List? ??
              monoData['data'] as List? ??
              [];
          final albums = items
              .whereType<Map<String, dynamic>>()
              .map((item) {
                try {
                  return MonochromeAlbum.fromJson({'id': 'qobuz:${item['id'] ?? ''}', ...item});
                } catch (_) {
                  return null;
                }
              })
              .whereType<MonochromeAlbum>()
              .toList();
          if (albums.isNotEmpty) {
            sections.add(MonochromeHomeSection(
              id: 'qobuz_featured',
              title: 'Qobuz • Hi-Res Picks',
              subtitle: '24-bit FLAC',
              albums: albums,
              source: 'qobuz',
              sectionType: 'Featured',
            ));
          }
        }
      } catch (e) {
        log('Qobuz Monochrome fallback failed: $e', name: 'MonochromeApiClient');
      }
    }

    return sections;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Stream URL Resolution
  // Priority: DolbyAtmos > UltraHiRes > HiRes > LosslessFlac (never MP3/Opus)
  // ──────────────────────────────────────────────────────────────────────────

  /// Get FLAC stream URL. Falls back chain:
  /// 1. Monochrome community instances (/stream endpoint)
  /// 2. ZarzMoeClient (api.zarz.moe /dl/dzr)
  /// 3. Returns null — never returns an MP3/lossy URL
  Future<MonochromeStreamInfo?> getStreamUrl(String trackId,
      {LosslessQuality minQuality = LosslessQuality.losslessFlac}) async {
    // Parse source from ID prefix (e.g. "deezer:12345")
    final source = trackId.contains(':')
        ? trackId.split(':').first.toLowerCase()
        : 'deezer';

    // Quality cascade: DolbyAtmos > UltraHiRes > HiRes > LosslessFlac
    final qualityOrder = [
      LosslessQuality.dolbyAtmos,
      LosslessQuality.ultraHiRes,
      LosslessQuality.hiRes,
      LosslessQuality.losslessFlac,
    ].where((q) => q.level >= minQuality.level).toList();

    // 1) Try Monochrome instances first
    for (final q in qualityOrder) {
      final result = await _tryMonochromeStream(trackId, q);
      if (result != null && result.url.isNotEmpty && result.isLossless) {
        return result;
      }
    }

    // 2) Fallback: ZarzMoeClient (api.zarz.moe — real FLAC)
    try {
      final descriptor = await _zarzClient.getDownloadDescriptor(
        provider: source,
        trackId: trackId,
      );
      if (descriptor.success && descriptor.downloadUrl.isNotEmpty && descriptor.isLossless) {
        return MonochromeStreamInfo(
          url: descriptor.downloadUrl,
          quality: LosslessQuality.losslessFlac,
          codec: descriptor.format.isNotEmpty ? descriptor.format : 'flac',
          bitrate: descriptor.bitrateKbps,
          sampleRate: descriptor.sampleRate,
          bitDepth: descriptor.bitDepth,
          encryptionKey: descriptor.encryptionKey,
        );
      }
    } catch (e) {
      log('ZarzMoe stream fallback failed for $trackId: $e',
          name: 'MonochromeApiClient');
    }

    // Never return a lossy/preview URL — audiophile mode is strict
    return null;
  }


  Future<MonochromeStreamInfo?> _tryMonochromeStream(
      String trackId, LosslessQuality quality) async {
    for (final base in _instances) {
      try {
        final uri = Uri.parse('$base/stream').replace(queryParameters: {
          'id': trackId,
          'quality': quality.id,
        });
        final res = await _http.get(uri).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final url = (data['url'] ?? data['stream_url'] ?? '').toString();
          if (url.isNotEmpty) {
            return MonochromeStreamInfo.fromJson(data);
          }
        }
      } catch (_) {}
    }
    return null;
  }



  // ──────────────────────────────────────────────────────────────────────────
  // Track Details
  // ──────────────────────────────────────────────────────────────────────────

  Future<MonochromeTrack?> getTrack(String trackId) async {
    // Try Monochrome /info first
    for (final base in _instances) {
      try {
        final uri = Uri.parse('$base/info/').replace(queryParameters: {'id': trackId});
        final res = await _http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          if (data['id'] != null) {
            return MonochromeTrack.fromJson(data);
          }
        }
      } catch (_) {}
    }

    // Fallback: Deezer public
    try {
      final cleanId = trackId.replaceAll('deezer:', '');
      final res = await _http
          .get(Uri.parse('$_deezerApiBase/track/$cleanId'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return _parseDeezerTrack(jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Parsers — Deezer public API → unified types
  // ──────────────────────────────────────────────────────────────────────────

  MonochromeTrack? _parseDeezerTrack(Map<String, dynamic> item) {
    try {
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty) return null;

      final artistData = item['artist'] as Map<String, dynamic>?;
      final albumData = item['album'] as Map<String, dynamic>?;
      final albumCover = albumData?['cover_xl']?.toString() ??
          albumData?['cover_big']?.toString() ??
          albumData?['cover_medium']?.toString() ??
          albumData?['cover']?.toString() ??
          '';

      final artistName = artistData?['name']?.toString() ?? 'Unknown Artist';
      final artists = [
        MonochromeArtist(
          id: 'deezer:${artistData?['id'] ?? ''}',
          name: artistName,
          picture: artistData?['picture_xl']?.toString() ??
              artistData?['picture']?.toString(),
        )
      ];

      MonochromeAlbum? album;
      if (albumData != null) {
        album = MonochromeAlbum(
          id: 'deezer:${albumData['id'] ?? ''}',
          title: (albumData['title'] ?? 'Unknown Album').toString(),
          cover: albumData['cover_medium']?.toString() ?? albumCover,
          coverBig: albumCover,
          artists: artists,
        );
      }

      final duration = _parseInt(item['duration']);
      return MonochromeTrack(
        id: 'deezer:$id',
        title: (item['title'] ?? 'Unknown Track').toString(),
        artistName: artistName,
        artists: artists,
        album: album,
        durationMs: (duration ?? 200) * 1000,
        audioQuality: 'LOSSLESS_FLAC',
        source: 'deezer',
      );
    } catch (e) {
      return null;
    }
  }

  MonochromeAlbum? _parseDeezerAlbum(Map<String, dynamic> item) {
    try {
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty) return null;

      final artistData = item['artist'] as Map<String, dynamic>?;
      return MonochromeAlbum(
        id: 'deezer:$id',
        title: (item['title'] ?? 'Unknown Album').toString(),
        cover: item['cover_medium']?.toString() ?? item['cover']?.toString(),
        coverBig: item['cover_xl']?.toString() ??
            item['cover_big']?.toString() ??
            item['cover']?.toString(),
        releaseDate: item['release_date']?.toString(),
        trackCount: _parseInt(item['nb_tracks']),
        artists: artistData != null
            ? [
                MonochromeArtist(
                  id: 'deezer:${artistData['id'] ?? ''}',
                  name: (artistData['name'] ?? 'Unknown').toString(),
                )
              ]
            : [],
      );
    } catch (_) {
      return null;
    }
  }

  MonochromeArtist? _parseDeezerArtist(Map<String, dynamic> item) {
    try {
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty) return null;
      return MonochromeArtist(
        id: 'deezer:$id',
        name: (item['name'] ?? 'Unknown Artist').toString(),
        picture: item['picture_xl']?.toString() ??
            item['picture_big']?.toString() ??
            item['picture']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────

  String? _tidalCoverUrl(String? coverId, int size) {
    if (coverId == null || coverId.isEmpty) return null;
    final uuid = coverId.replaceAll('-', '/');
    return 'https://resources.tidal.com/images/$uuid/${size}x$size.jpg';
  }
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
