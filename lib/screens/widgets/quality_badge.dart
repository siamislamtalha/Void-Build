import 'package:flutter/material.dart';
import 'package:voidmusic/core/models/exported.dart';
import 'package:voidmusic/services/audiophile_mode_service.dart';

/// A small badge shown beside song titles that displays the audio quality
/// format (FLAC, HD FLAC, DSD) when in Audiophile Mode or when the track
/// metadata explicitly signals a lossless format.
class QualityBadge extends StatelessWidget {
  final Track song;

  const QualityBadge({
    super.key,
    required this.song,
  });

  @override
  Widget build(BuildContext context) {
    final String? qualityLabel = _resolveQualityLabel(song);
    if (qualityLabel == null || qualityLabel.isEmpty) {
      return const SizedBox.shrink();
    }

    final isHd = qualityLabel.contains('HD') ||
        qualityLabel.contains('24') ||
        qualityLabel.contains('HI-RES') ||
        qualityLabel.contains('ATMOS') ||
        qualityLabel.contains('MASTER');

    final isDsd = qualityLabel.contains('DSD');
    final isAtmos = qualityLabel.contains('ATMOS');

    Color borderColor;
    Color textColor;

    if (isDsd) {
      borderColor = const Color(0xFF9D4EDD);
      textColor = const Color(0xFFE0AAFF);
    } else if (isAtmos) {
      borderColor = const Color(0xFF00B4D8);
      textColor = const Color(0xFF90E0EF);
    } else if (isHd) {
      borderColor = const Color(0xFFFFB703);
      textColor = const Color(0xFFFFD166);
    } else {
      borderColor = const Color(0xFF707070);
      textColor = const Color(0xFFC0C0C0);
    }

    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.6),
          width: 0.8,
        ),
      ),
      child: Text(
        qualityLabel,
        style: TextStyle(
          color: textColor,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
          height: 1.1,
        ),
      ),
    );
  }

  /// Resolves the quality label for a track.
  ///
  /// Priority order:
  /// 1. Explicit keywords in the track title (highest confidence)
  /// 2. Plugin source detection from track ID / URL
  /// 3. Audiophile mode fallback (show FLAC for all tracks in audiophile mode)
  static String? _resolveQualityLabel(Track song) {
    // 1. Check title for explicit format keywords (works in any mode)
    final titleUpper = song.title.toUpperCase();
    if (titleUpper.contains('DSD128') || titleUpper.contains('DSD256')) {
      return 'DSD128+';
    }
    if (titleUpper.contains('DSD64') || titleUpper.contains('DSD')) {
      return 'DSD';
    }
    if (titleUpper.contains('DOLBY ATMOS') || titleUpper.contains('ATMOS')) {
      return 'ATMOS';
    }
    if (titleUpper.contains('HD FLAC') || titleUpper.contains('HDFLAC')) {
      return 'HD FLAC';
    }
    if (titleUpper.contains('HI-RES') ||
        titleUpper.contains('HIRES') ||
        titleUpper.contains('24-BIT') ||
        titleUpper.contains('24BIT')) {
      return 'HD FLAC';
    }
    if (titleUpper.contains('FLAC')) {
      return 'FLAC';
    }

    // If not in audiophile mode, only show badges for explicit keywords
    if (!AudiophileModeService.isAudiophile) {
      return null;
    }

    // 2. Detect quality from source plugin ID embedded in the track ID
    // Plugin IDs follow the pattern: audiophile.voidfactory.<source>
    final trackId = song.id.toLowerCase();
    final trackUrl = (song.url ?? '').toLowerCase();

    // High-resolution sources (HD FLAC tier)
    if (_isHiResSource(trackId, trackUrl)) {
      return 'HD FLAC';
    }

    // Standard lossless sources (FLAC tier)
    if (_isLosslessSource(trackId, trackUrl)) {
      return 'FLAC';
    }

    // 3. In audiophile mode, every streamed track should show at least FLAC
    // because only lossless-capable plugins are loaded in this mode.
    return 'FLAC';
  }

  /// Returns true if the track appears to come from a Hi-Res (24-bit) source:
  /// Tidal (Master), Qobuz (Hi-Res), Amazon Music (Ultra HD), Apple Music (Lossless).
  static bool _isHiResSource(String trackId, String trackUrl) {
    // Tidal
    if (trackId.contains('tidal') ||
        trackUrl.contains('tidal.com') ||
        trackId.contains('audiophile.voidfactory.tidal')) {
      return true;
    }
    // Qobuz
    if (trackId.contains('qobuz') ||
        trackUrl.contains('qobuz.com') ||
        trackId.contains('audiophile.voidfactory.qobuz')) {
      return true;
    }
    // Amazon Music Ultra HD
    if (trackId.contains('amazon') ||
        trackUrl.contains('music.amazon') ||
        trackId.contains('audiophile.voidfactory.amazon')) {
      return true;
    }
    // Apple Music lossless
    if (trackId.contains('apple-music') ||
        trackUrl.contains('music.apple.com') ||
        trackId.contains('audiophile.voidfactory.apple')) {
      return true;
    }
    return false;
  }

  /// Returns true if the track appears to come from a standard lossless source:
  /// Deezer (FLAC), Spotify Web (FLAC extension), SoundCloud HQ, YouTube Music FLAC.
  static bool _isLosslessSource(String trackId, String trackUrl) {
    if (trackId.contains('deezer') ||
        trackUrl.contains('deezer.com') ||
        trackId.contains('audiophile.voidfactory.deezer')) {
      return true;
    }
    if (trackId.contains('spotify') ||
        trackUrl.contains('spotify.com') ||
        trackId.contains('audiophile.voidfactory.spotify')) {
      return true;
    }
    if (trackId.contains('soundcloud') ||
        trackUrl.contains('soundcloud.com') ||
        trackId.contains('audiophile.voidfactory.soundcloud')) {
      return true;
    }
    if (trackId.contains('ytmusic') ||
        trackId.contains('youtube') ||
        trackId.contains('audiophile.voidfactory.ytmusic')) {
      return true;
    }
    if (trackId.contains('pandora') ||
        trackUrl.contains('pandora.com') ||
        trackId.contains('audiophile.voidfactory.pandora')) {
      return true;
    }
    return false;
  }
}
