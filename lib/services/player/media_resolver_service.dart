import 'dart:async';
import 'dart:developer' as dev;

import 'package:voidmusic/core/events/global_event_bus.dart';
import 'package:voidmusic/core/constants/setting_keys.dart';
import 'package:voidmusic/core/models/exported.dart';
import 'package:voidmusic/plugins/errors/plugin_exceptions.dart';
import 'package:voidmusic/plugins/utils/media_id.dart';
import 'package:voidmusic/services/audiophile_mode_service.dart';
import 'package:voidmusic/services/db/dao/download_dao.dart';
import 'package:voidmusic/services/db/dao/playlist_dao.dart';
import 'package:voidmusic/services/db/dao/settings_dao.dart';
import 'package:voidmusic/services/db/dao/track_dao.dart';
import 'package:voidmusic/services/db/db_provider.dart';
import 'package:voidmusic/services/plugin/plugin_service.dart';
import 'package:voidmusic/services/player/stream_quality_selector.dart';
import 'package:voidmusic/src/rust/api/plugin/commands.dart';

class ResolvedMediaSource {
  final Uri uri;
  final bool isOffline;
  final Map<String, String>? headers;

  /// Lossless audio metadata — populated only when a lossless stream is
  /// resolved (Audiophile Mode). Null for standard streams.
  final int? bitDepth;
  final int? sampleRate;
  final String? format;

  const ResolvedMediaSource({
    required this.uri,
    required this.isOffline,
    this.headers,
    this.bitDepth,
    this.sampleRate,
    this.format,
  });

  /// Whether this source carries lossless / Hi-Res audio metadata.
  bool get isLossless => format != null || (bitDepth != null && bitDepth! >= 16);
}

/// Resolves a [Track] into a playable [Uri].
///
/// Resolution order:
/// 1. Local downloaded file (offline).
/// 2. Plugin system — asks the owning plugin for stream URIs via [GetStreams].
class MediaResolverService {
  final DownloadDAO _downloadDao;
  final SettingsDAO _settingsDao;
  final PluginService _pluginService;

  MediaResolverService({
    required DownloadDAO downloadDao,
    required SettingsDAO settingsDao,
    required PluginService pluginService,
  })  : _downloadDao = downloadDao,
        _settingsDao = settingsDao,
        _pluginService = pluginService;

  /// Factory that creates its own DAO instances from [DBProvider.db].
  factory MediaResolverService.create(PluginService pluginService) {
    final trackDao = TrackDAO(DBProvider.db);
    final playlistDao = PlaylistDAO(DBProvider.db, trackDao);
    return MediaResolverService(
      downloadDao: DownloadDAO(DBProvider.db, trackDao, playlistDao),
      settingsDao: SettingsDAO(DBProvider.db),
      pluginService: pluginService,
    );
  }

  /// Resolve [track] into a playable URI.
  Future<ResolvedMediaSource> resolve(Track track) async {
    // 1. Check for an offline/downloaded version.
    try {
      final down = await _downloadDao.getDownloadRecord(track.id);
      if (down != null) {
        dev.log('Playing Offline: ${track.title}', name: 'MediaResolverService');
        return ResolvedMediaSource(
          uri: Uri.file('${down.filePath}/${down.fileName}'),
          isOffline: true,
        );
      }
    } catch (e) {
      dev.log('Download check failed: $e', name: 'MediaResolverService');
      // Non-fatal — continue to online resolution
    }

    // 2. Plugin-based stream resolution.
    final parts = tryParseMediaId(track.id);
    if (parts == null) {
      GlobalEventBus.instance.emitError(
        AppError.malformedMediaId(rawId: track.id),
      );
      throw Exception(
        'Cannot resolve stream for "${track.title}" — '
        'malformed media ID: "${track.id}"',
      );
    }

    if (parts.pluginId == 'local') {
      throw Exception(
        'Local file not found for "${track.title}" — '
        'it may have been deleted or moved.',
      );
    }

    dev.log(
        'Resolving streams for "${track.title}" '
        '(plugin: ${parts.pluginId}, id: ${parts.localId})',
        name: 'MediaResolverService');

    PluginResponse response;
    try {
      response = await _pluginService
          .execute(
            pluginId: parts.pluginId,
            request: PluginRequest.contentResolver(
              ContentResolverCommand.getStreams(id: parts.localId),
            ),
          )
          .timeout(
            // Audiophile mode resolves lossless streams from slower CDNs;
            // give it more time than standard quality resolution.
            AudiophileModeService.isAudiophile
                ? const Duration(seconds: 20)
                : const Duration(seconds: 12),
          );
    } on TimeoutException catch (e) {
      dev.log('Stream resolution timeout for "${track.title}": $e', name: 'MediaResolverService');
      GlobalEventBus.instance.emitError(
        AppError.pluginError(
          pluginId: parts.pluginId,
          message: 'Stream resolution timed out. Please check your network connection.',
        ),
      );
      rethrow;
    } on PluginException catch (e) {
      if (e is PluginNotLoadedException) {
        GlobalEventBus.instance.emitError(
          AppError.pluginNotLoaded(pluginId: parts.pluginId, mediaId: track.id),
        );
      } else {
        GlobalEventBus.instance.emitError(
          AppError.pluginError(
            pluginId: parts.pluginId,
            message: e.message,
          ),
        );
      }
      rethrow;
    }

    return response.when(
      streams: (streams) async {
        if (streams.isEmpty) {
          throw Exception('No streams returned for "${track.title}"');
        }

        final storedQuality = await _settingsDao.getSettingStr(
          SettingKeys.strmQuality,
        );
        final normalizedQuality = normalizeStoredStreamQualityLabel(
          storedQuality,
          fallback: AudioStreamQualityPreference.high.label,
        );
        if (storedQuality != normalizedQuality) {
          await _settingsDao.putSettingStr(
            SettingKeys.strmQuality,
            normalizedQuality,
          );
        }

        // Audiophile Mode always uses the lossless-first preference;
        // normal mode reads the user's stored quality setting.
        final preference = AudiophileModeService.isAudiophile
            ? AudioStreamQualityPreference.lossless
            : AudioStreamQualityPreferenceX.fromStored(
                normalizedQuality,
              );

        dev.log(
          'Stream quality preference: ${preference.label}'
          '${AudiophileModeService.isAudiophile ? " (Audiophile / SpotiFLAC mode)" : ""}',
          name: 'MediaResolverService',
        );

        final selectedStream = StreamQualitySelector.selectPlaybackStream(
          streams,
          preference: preference,
        );
        final streamUrl = selectedStream?.url.trim();

        if (streamUrl == null || streamUrl.isEmpty) {
          throw Exception(
            'Streams returned for "${track.title}" contain no playable URL',
          );
        }

        final uri = Uri.tryParse(streamUrl);
        if (uri == null ||
            uri.scheme.isEmpty ||
            (uri.scheme != 'http' &&
                uri.scheme != 'https' &&
                uri.scheme != 'file')) {
          throw Exception(
            'Invalid stream URL for "${track.title}": $streamUrl',
          );
        }

        dev.log('Resolved stream: $streamUrl '
            '[quality=${selectedStream?.quality.name} '
            'format=${selectedStream?.format}]',
            name: 'MediaResolverService');

        // Derive lossless metadata from the stream format string so the
        // player UI can display quality badges (FLAC, Hi-Res, DSD, etc.).
        final resolvedFormat = selectedStream?.format;
        final losslessMeta = _parseLosslessMetadata(resolvedFormat);

        return ResolvedMediaSource(
          uri: uri,
          isOffline: false,
          headers: selectedStream == null
              ? null
              : streamHeadersToMap(selectedStream.headers),
          bitDepth: losslessMeta.$1,
          sampleRate: losslessMeta.$2,
          format: resolvedFormat?.isNotEmpty == true ? resolvedFormat : null,
        );
      },
      trackDetails: (_) =>
          throw Exception('Unexpected response type: trackDetails'),
      albumDetails: (_) =>
          throw Exception('Unexpected response type: albumDetails'),
      artistDetails: (_) =>
          throw Exception('Unexpected response type: artistDetails'),
      playlistDetails: (_) =>
          throw Exception('Unexpected response type: playlistDetails'),
      search: (_) => throw Exception('Unexpected response type: search'),
      moreTracks: (_) =>
          throw Exception('Unexpected response type: moreTracks'),
      moreAlbums: (_) =>
          throw Exception('Unexpected response type: moreAlbums'),
      homeSections: (_) =>
          throw Exception('Unexpected response type: homeSections'),
      loadMoreItems: (_) =>
          throw Exception('Unexpected response type: loadMoreItems'),
      charts: (_) => throw Exception('Unexpected response type: charts'),
      chartDetails: (_) =>
          throw Exception('Unexpected response type: chartDetails'),
      segments: (_) => throw Exception('Unexpected response type: segments'),
      lyricsResult: (_) =>
          throw Exception('Unexpected response type: lyricsResult'),
      lyricsSearchResults: (_) =>
          throw Exception('Unexpected response type: lyricsSearchResults'),
      lyricsById: (_, __) =>
          throw Exception('Unexpected response type: lyricsById'),
      suggestions: (_) =>
          throw Exception('Unexpected response type: suggestions'),
      canHandle: (_) => throw Exception('Unexpected response type: canHandle'),
      collectionInfo: (_) =>
          throw Exception('Unexpected response type: collectionInfo'),
      importTracks: (_) =>
          throw Exception('Unexpected response type: importTracks'),
      ack: () => throw Exception('Unexpected response type: ack'),
    );
  }
}

/// Parses a stream format string (e.g. "flac", "flac 24bit/96khz", "dsd64")
/// and returns (bitDepth, sampleRate). Returns (null, null) for unknown formats.
///
/// This is used to populate [ResolvedMediaSource.bitDepth] and
/// [ResolvedMediaSource.sampleRate] for Audiophile Mode UI display.
(int?, int?) _parseLosslessMetadata(String? format) {
  if (format == null || format.isEmpty) return (null, null);
  final f = format.toLowerCase().trim();

  // DSD formats — no conventional bit depth / sample rate
  if (f.contains('dsd')) return (1, f.contains('128') ? 5644800 : 2822400);

  // Explicit bit-depth / sample-rate patterns: "24bit/96khz", "24/96", etc.
  final hiResPattern = RegExp(r'(\d+)\s*(?:bit)?\s*/\s*(\d+)\s*(?:khz|k)?');
  final match = hiResPattern.firstMatch(f);
  if (match != null) {
    final bits = int.tryParse(match.group(1) ?? '');
    final kHz = int.tryParse(match.group(2) ?? '');
    return (bits, kHz != null ? kHz * 1000 : null);
  }

  // Known FLAC / lossless keywords — default to CD quality (16-bit / 44.1kHz)
  if (f.contains('flac') || f.contains('lossless') || f.contains('alac')) {
    return (16, 44100);
  }

  // Hi-Res without explicit spec — assume 24-bit / 96kHz
  if (f.contains('hires') || f.contains('hi-res') || f.contains('hd')) {
    return (24, 96000);
  }

  return (null, null);
}
