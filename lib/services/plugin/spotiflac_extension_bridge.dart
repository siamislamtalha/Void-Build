import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:voidmusic/services/audiophile/audiophile_download_service.dart';
import 'package:voidmusic/services/audiophile/monochrome_api_client.dart';
import 'package:voidmusic/services/audiophile/zarz_moe_client.dart';
import 'package:voidmusic/src/rust/api/plugin/models.dart';
import 'package:voidmusic/src/rust/api/plugin/commands.dart';

/// Bridge for executing Audiophile & SpotiFLAC Extensions (.sflx, .spotiflac-ext, audiophile-*)
/// Fully integrated with MonochromeApiClient (Resonada backbone) & AudiophileDownloadService.
class SpotiFLACExtensionBridge {
  static final SpotiFLACExtensionBridge _instance =
      SpotiFLACExtensionBridge._internal();
  factory SpotiFLACExtensionBridge() => _instance;
  SpotiFLACExtensionBridge._internal();

  final MonochromeApiClient _monoClient = MonochromeApiClient();
  final AudiophileDownloadService _downloadService = AudiophileDownloadService();

  final Map<String, SpotiFLACLoadedExtension> _loadedExtensions = {};

  /// Check if plugin is a SpotiFLAC / Audiophile extension
  bool isSpotiFLACExtension(String pluginId) {
    final lower = pluginId.toLowerCase();
    return lower.startsWith('audiophile') ||
        lower.contains('spotiflac') ||
        lower.contains('deezer') ||
        lower.contains('qobuz') ||
        lower.contains('tidal') ||
        lower.contains('apple') ||
        lower.contains('amazon') ||
        lower.contains('pandora') ||
        lower.contains('soundcloud') ||
        lower.contains('spotify') ||
        lower.contains('ytmusic') ||
        lower.contains('lossless') ||
        _loadedExtensions.containsKey(pluginId);
  }

  /// Register / initialize plugin from directory
  Future<bool> registerExtensionFromDir(String pluginDir) async {
    try {
      final manifestFile = File(p.join(pluginDir, 'manifest.json'));
      if (!await manifestFile.exists()) return false;

      final str = await manifestFile.readAsString();
      final manifestJson = Map<String, dynamic>.from(jsonDecode(str) as Map);
      final String id = manifestJson['id'] ??
          manifestJson['name'] ??
          p.basename(pluginDir);
      final String name =
          manifestJson['displayName'] ?? manifestJson['name'] ?? id;

      _loadedExtensions[id] = SpotiFLACLoadedExtension(
        id: id,
        name: name,
        pluginDir: pluginDir,
        manifest: manifestJson,
      );

      log('Registered Audiophile plugin: $id ($name)',
          name: 'SpotiFLACExtensionBridge');
      return true;
    } catch (e) {
      log('Failed to register extension from $pluginDir: $e',
          name: 'SpotiFLACExtensionBridge');
      return false;
    }
  }

  /// Execute search for tracks, albums, artists, or playlists across Audiophile plugins
  Future<SpotiFLACSearchResult> search({
    required String pluginId,
    required String query,
    ContentSearchFilter filter = ContentSearchFilter.all,
    int limit = 20,
    int page = 1,
  }) async {
    try {
      final filterStr = filter == ContentSearchFilter.track
          ? 'track'
          : filter == ContentSearchFilter.album
              ? 'album'
              : filter == ContentSearchFilter.artist
                  ? 'artist'
                  : 'all';

      // Query MonochromeApiClient (public provider proxy from Resonada)
      final monoResult =
          await _monoClient.search(query, filter: filterStr, limit: limit);

      final tracks = monoResult.tracks
          .map((t) => Track(
                id: 'audiophile.${t.source}:${t.id}',
                title: t.title,
                artists: t.artists
                    .map((a) => ArtistSummary(
                          id: a.id,
                          name: a.name,
                          thumbnail: Artwork(
                            url: a.picture ?? t.thumbnailUrl,
                            layout: ImageLayout.circular,
                          ),
                        ))
                    .toList(),
                thumbnail: Artwork(
                  url: t.thumbnailUrl,
                  layout: ImageLayout.square,
                ),
                url: 'audiophile://${t.source}/${t.id}',
                durationMs: BigInt.from(t.durationMs),
                isExplicit: false,
              ))
          .toList();

      final albums = monoResult.albums
          .map((a) => AlbumSummary(
                id: 'audiophile.${a.id}',
                title: a.title,
                artists: a.artists
                    .map((ar) => ArtistSummary(id: ar.id, name: ar.name))
                    .toList(),
                thumbnail: Artwork(
                  url: a.coverBig ?? a.cover ?? '',
                  layout: ImageLayout.square,
                ),
                year: _parseYear(a.releaseDate),
              ))
          .toList();

      final artists = monoResult.artists
          .map((a) => ArtistSummary(
                id: 'audiophile.${a.id}',
                name: a.name,
                thumbnail: Artwork(
                  url: a.picture ?? '',
                  layout: ImageLayout.circular,
                ),
              ))
          .toList();

      return SpotiFLACSearchResult(
        tracks: PagedTracks(items: tracks),
        albums: PagedAlbums(items: albums),
        artists: artists,
        playlists: const [],
      );
    } catch (e) {
      log('Search failed for $pluginId: $e',
          name: 'SpotiFLACExtensionBridge');
      return SpotiFLACSearchResult(
        tracks: const PagedTracks(items: []),
        albums: const PagedAlbums(items: []),
        artists: const [],
        playlists: const [],
      );
    }
  }

  int? _parseYear(String? dateStr) {
    if (dateStr == null || dateStr.length < 4) return null;
    return int.tryParse(dateStr.substring(0, 4));
  }

  /// Get home feed sections for explore view from Audiophile extension
  Future<List<Section>> getHomeFeed(String pluginId) async {
    try {
      final homeSections =
          await _monoClient.getHomeSections(pluginId: pluginId);
      final sections = <Section>[];

      for (final s in homeSections) {
        final items = <MediaItem>[];

        for (final t in s.tracks) {
          items.add(MediaItem.track(Track(
            id: 'audiophile.${t.source}:${t.id}',
            title: t.title,
            artists: [
              ArtistSummary(
                id: 'artist_${t.id}',
                name: t.artistName,
                thumbnail: Artwork(
                  url: t.thumbnailUrl,
                  layout: ImageLayout.circular,
                ),
              )
            ],
            thumbnail: Artwork(
              url: t.thumbnailUrl,
              layout: ImageLayout.square,
            ),
            url: 'audiophile://${t.source}/${t.id}',
            durationMs: BigInt.from(t.durationMs),
            isExplicit: false,
          )));
        }

        for (final a in s.albums) {
          items.add(MediaItem.album(AlbumSummary(
            id: 'audiophile.${a.id}',
            title: a.title,
            artists: a.artists
                .map((ar) => ArtistSummary(id: ar.id, name: ar.name))
                .toList(),
            thumbnail: Artwork(
              url: a.coverBig ?? a.cover ?? '',
              layout: ImageLayout.square,
            ),
            year: _parseYear(a.releaseDate),
          )));
        }

        if (items.isNotEmpty) {
          sections.add(Section(
            id: s.id,
            title: s.title,
            subtitle: s.subtitle,
            cardType: s.albums.isNotEmpty ? CardType.grid : CardType.carousel,
            items: items,
          ));
        }
      }

      return sections;
    } catch (e) {
      log('Failed to get home feed for $pluginId: $e',
          name: 'SpotiFLACExtensionBridge');
      return [];
    }
  }

  /// Fetch search suggestions (autocomplete)
  Future<List<Suggestion>> getSearchSuggestions(
      String pluginId, String query) async {
    if (query.trim().isEmpty) return const [];
    try {
      final rawSuggestions = await _monoClient.getSearchSuggestions(query);
      return rawSuggestions.map((text) => Suggestion.query(text)).toList();
    } catch (e) {
      log('Failed search suggestions for $pluginId: $e',
          name: 'SpotiFLACExtensionBridge');
      return [
        Suggestion.query('$query FLAC'),
        Suggestion.query('$query Hi-Res 24-bit'),
        Suggestion.query('$query Lossless'),
      ];
    }
  }

  final ZarzMoeClient _zarzClient = ZarzMoeClient();

  /// Resolves highest quality FLAC stream URL for playback
  Future<StreamSource?> getHighQualityStreamSource(
      String trackId, String pluginId) async {
    try {
      final info = await _monoClient.getStreamUrl(trackId);
      if (info != null && info.url.isNotEmpty) {
        return StreamSource(
          url: info.url,
          quality: Quality.lossless,
          format: info.formatLabel.toLowerCase(),
          headers: const [
            ('User-Agent', 'SpotiFLAC-Mobile/5.0'),
            ('Accept', 'audio/flac, audio/*'),
          ],
        );
      }

      // Try ZarzMoeClient directly
      final provider = pluginId.replaceAll('audiophile.', '');
      final descriptor = await _zarzClient.getDownloadDescriptor(
        provider: provider,
        trackId: trackId,
      );

      if (descriptor.success && descriptor.downloadUrl.isNotEmpty) {
        return StreamSource(
          url: descriptor.downloadUrl,
          quality: Quality.lossless,
          format: descriptor.format,
          headers: const [
            ('User-Agent', 'SpotiFLAC-Mobile/5.0'),
            ('Accept', 'audio/flac, audio/*'),
          ],
        );
      }
    } catch (e) {
      log('Failed to resolve stream for $trackId ($pluginId): $e',
          name: 'SpotiFLACExtensionBridge');
    }
    return null;
  }

  /// Initiate FLAC track download
  Future<AudiophileDownloadTask?> startTrackDownload({
    required Track track,
    required String pluginId,
  }) async {
    final artistName =
        track.artists.isNotEmpty ? track.artists.first.name : 'Unknown Artist';
    final provider = pluginId.replaceAll('audiophile.', '');

    return _downloadService.enqueueDownload(
      trackId: track.id,
      title: track.title,
      artist: artistName,
      album: 'Lossless Master',
      thumbnailUrl: track.thumbnail.url,
      format: 'flac',
      quality: LosslessQuality.losslessFlac,
      provider: provider,
    );
  }
}

class SpotiFLACSearchResult {
  final PagedTracks tracks;
  final PagedAlbums albums;
  final List<ArtistSummary> artists;
  final List<PlaylistSummary> playlists;

  SpotiFLACSearchResult({
    required this.tracks,
    required this.albums,
    required this.artists,
    required this.playlists,
  });
}

class SpotiFLACLoadedExtension {
  final String id;
  final String name;
  final String pluginDir;
  final Map<String, dynamic> manifest;

  SpotiFLACLoadedExtension({
    required this.id,
    required this.name,
    required this.pluginDir,
    required this.manifest,
  });
}
