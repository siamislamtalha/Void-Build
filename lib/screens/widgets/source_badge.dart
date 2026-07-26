import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:voidmusic/plugins/utils/media_id.dart';

/// Maps a plugin ID string to an SVG asset path.
/// Returns null if no known SVG is available.
String? _svgPathForPluginId(String pluginId) {
  final id = pluginId.toLowerCase();
  if (id.contains('ytvideo') || id == 'youtube') {
    return 'svg/youtube.svg';
  } else if (id.contains('ytmusic') || id.contains('youtube_music') || id.contains('youtubemusic')) {
    return 'svg/youtube_music.svg';
  } else if (id.contains('spotify')) {
    return 'svg/spotify.svg';
  } else if (id.contains('jiosaavn') || id.contains('jio')) {
    return 'svg/jiosaavn.svg';
  }
  return null;
}

/// A small inline badge that shows the source platform logo (e.g. YouTube,
/// YouTube Music, Spotify) for a given media ID.
///
/// Pass [mediaId] (the track / playlist composite ID) and the widget will
/// automatically parse out the plugin ID and render the right logo.
///
/// Returns [SizedBox.shrink] when no matching logo is found.
class SourceBadge extends StatelessWidget {
  /// The composite media ID (`pluginId::localId`).
  final String mediaId;

  /// Size of the badge icon. Defaults to 14.
  final double size;

  const SourceBadge({
    super.key,
    required this.mediaId,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    final parts = tryParseMediaId(mediaId);
    if (parts == null) return const SizedBox.shrink();
    final svgPath = _svgPathForPluginId(parts.pluginId);
    if (svgPath == null) return const SizedBox.shrink();

    return SvgPicture.asset(
      svgPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Allow SVG's own fill colors to show through
      colorFilter: null,
    );
  }
}

/// Convenience variant that accepts a [pluginId] directly (no parsing needed).
class SourceBadgeByPluginId extends StatelessWidget {
  final String pluginId;
  final double size;

  const SourceBadgeByPluginId({
    super.key,
    required this.pluginId,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    final svgPath = _svgPathForPluginId(pluginId);
    if (svgPath == null) return const SizedBox.shrink();

    return SvgPicture.asset(
      svgPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: null,
    );
  }
}
