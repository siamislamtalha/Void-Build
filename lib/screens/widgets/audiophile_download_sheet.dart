import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:voidmusic/blocs/downloader/cubit/downloader_cubit.dart';
import 'package:voidmusic/core/di/service_locator.dart';
import 'package:voidmusic/core/models/exported.dart';
import 'package:voidmusic/screens/widgets/snackbar.dart';
import 'package:voidmusic/screens/widgets/song_tile.dart';

void showAudiophileDownloadSheet(BuildContext context, Track song) {
  final downloaderCubit = context.read<DownloaderCubit>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (sheetContext) {
      return BlocProvider.value(
        value: downloaderCubit,
        child: _AudiophileDownloadBottomSheet(song: song),
      );
    },
  );
}

/// Source entry — describes a lossless audio source.
class _SourceEntry {
  final String name;
  final String shortDesc;
  final String qualityBadge;
  final Color badgeColor;
  final IconData icon;

  const _SourceEntry({
    required this.name,
    required this.shortDesc,
    required this.qualityBadge,
    required this.badgeColor,
    required this.icon,
  });
}

/// Quality tier entry — describes a download quality level.
class _QualityEntry {
  final String label;
  final String detail;
  final String value;
  final String tag;
  final Color tagColor;

  const _QualityEntry({
    required this.label,
    required this.detail,
    required this.value,
    required this.tag,
    required this.tagColor,
  });
}

class _AudiophileDownloadBottomSheet extends StatefulWidget {
  final Track song;

  const _AudiophileDownloadBottomSheet({required this.song});

  @override
  State<_AudiophileDownloadBottomSheet> createState() =>
      __AudiophileDownloadBottomSheetState();
}

class __AudiophileDownloadBottomSheetState
    extends State<_AudiophileDownloadBottomSheet> {
  static const _audiophileGold = Color(0xFFFFB703);
  static const _tidalBlue = Color(0xFF00B4D8);
  static const _qobuzPurple = Color(0xFF9D4EDD);
  static const _deezerPink = Color(0xFFFF6B9D);
  static const _amazonOrange = Color(0xFFFF9900);
  static const _spotifyGreen = Color(0xFF1DB954);
  static const _ytmusicRed = Color(0xFFFF0000);

  static const List<_SourceEntry> _defaultSources = [
    _SourceEntry(
      name: 'Tidal',
      shortDesc: 'Master Quality Lossless',
      qualityBadge: 'MASTER',
      badgeColor: _tidalBlue,
      icon: MingCute.music_2_fill,
    ),
    _SourceEntry(
      name: 'Qobuz',
      shortDesc: '24-bit Hi-Res Audio',
      qualityBadge: 'HI-RES',
      badgeColor: _qobuzPurple,
      icon: MingCute.headphone_line,
    ),
    _SourceEntry(
      name: 'Deezer',
      shortDesc: '16-bit / 44.1kHz FLAC',
      qualityBadge: 'FLAC',
      badgeColor: _deezerPink,
      icon: MingCute.music_3_fill,
    ),
    _SourceEntry(
      name: 'Amazon Music',
      shortDesc: 'Ultra HD & Dolby Atmos',
      qualityBadge: 'ULTRA HD',
      badgeColor: _amazonOrange,
      icon: MingCute.shopping_bag_2_line,
    ),
    _SourceEntry(
      name: 'Spotify Web',
      shortDesc: 'High-Bitrate Extension',
      qualityBadge: 'EXT',
      badgeColor: _spotifyGreen,
      icon: MingCute.horn_line,
    ),
    _SourceEntry(
      name: 'YouTube Music',
      shortDesc: 'HQ FLAC Remux',
      qualityBadge: 'FLAC',
      badgeColor: _ytmusicRed,
      icon: MingCute.youtube_fill,
    ),
  ];

  List<_SourceEntry> _sources = _defaultSources;

  @override
  void initState() {
    super.initState();
    _loadDynamicSources();
  }

  static const _appleRed = Color(0xFFFA243C);
  static const _soundcloudOrange = Color(0xFFFF5500);
  static const _pandoraBlue = Color(0xFF224099);

  Future<void> _loadDynamicSources() async {
    try {
      final available = await ServiceLocator.pluginService.getAvailablePlugins();
      final audiophilePlugins = available.where((p) {
        final id = p.manifest.id.toLowerCase();
        return id.startsWith('audiophile.');
      }).toList();

      if (audiophilePlugins.isNotEmpty) {
        final dynamicSources = <_SourceEntry>[];
        for (final p in audiophilePlugins) {
          final id = p.manifest.id.toLowerCase();
          final name = p.manifest.name;
          Color color = _audiophileGold;
          String badge = 'FLAC';
          IconData icon = MingCute.disc_fill;

          if (id.contains('tidal')) {
            color = _tidalBlue;
            badge = 'MASTER';
            icon = MingCute.music_2_fill;
          } else if (id.contains('qobuz')) {
            color = _qobuzPurple;
            badge = 'HI-RES';
            icon = MingCute.headphone_line;
          } else if (id.contains('deezer')) {
            color = _deezerPink;
            badge = 'FLAC';
            icon = MingCute.music_3_fill;
          } else if (id.contains('amazon')) {
            color = _amazonOrange;
            badge = 'ULTRA HD';
            icon = MingCute.shopping_bag_2_line;
          } else if (id.contains('spotify')) {
            color = _spotifyGreen;
            badge = 'EXT';
            icon = MingCute.horn_line;
          } else if (id.contains('ytmusic')) {
            color = _ytmusicRed;
            badge = 'FLAC';
            icon = MingCute.youtube_fill;
          } else if (id.contains('apple')) {
            color = _appleRed;
            badge = 'LOSSLESS';
            icon = MingCute.apple_fill;
          } else if (id.contains('soundcloud')) {
            color = _soundcloudOrange;
            badge = 'HQ';
            icon = MingCute.cloud_fill;
          } else if (id.contains('pandora')) {
            color = _pandoraBlue;
            badge = 'FLAC';
            icon = MingCute.radio_line;
          }

          dynamicSources.add(_SourceEntry(
            name: name,
            shortDesc: p.manifest.description,
            qualityBadge: badge,
            badgeColor: color,
            icon: icon,
          ));
        }

        if (dynamicSources.isNotEmpty && mounted) {
          setState(() {
            _sources = dynamicSources;
            _selectedSource = dynamicSources.first.name;
          });
        }
      }
    } catch (_) {}
  }

  static const List<_QualityEntry> _qualities = [
    _QualityEntry(
      label: 'CD Quality',
      detail: 'FLAC 16-bit / 44.1kHz',
      value: 'FLAC_16BIT',
      tag: 'FLAC',
      tagColor: Color(0xFF707070),
    ),
    _QualityEntry(
      label: 'Hi-Res Audio',
      detail: 'FLAC 24-bit / 96kHz',
      value: 'FLAC_24BIT_96KHZ',
      tag: 'HD FLAC',
      tagColor: _audiophileGold,
    ),
    _QualityEntry(
      label: 'Ultra Hi-Res',
      detail: 'FLAC 24-bit / 192kHz',
      value: 'FLAC_24BIT_192KHZ',
      tag: 'HD FLAC',
      tagColor: _audiophileGold,
    ),
    _QualityEntry(
      label: 'DSD64',
      detail: '2.8 MHz Direct Stream Digital',
      value: 'DSD64',
      tag: 'DSD',
      tagColor: _qobuzPurple,
    ),
  ];

  String _selectedSource = 'Tidal';
  String _selectedQualityValue = 'FLAC_24BIT_96KHZ';

  _QualityEntry get _currentQuality =>
      _qualities.firstWhere((q) => q.value == _selectedQualityValue,
          orElse: () => _qualities[1]);

  void _startDownload() {
    context.read<DownloaderCubit>().downloadSong(widget.song);
    Navigator.pop(context);
    final q = _currentQuality;
    SnackbarService.showMessage(
      'Downloading ${widget.song.title} • $_selectedSource • ${q.tag}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF14101A) : const Color(0xFFF2F2F7);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        10,
        0,
        10,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: surfaceColor.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.13),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 32,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Drag handle ──
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Header row ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _audiophileGold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _audiophileGold.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        MingCute.headphone_line,
                        color: _audiophileGold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audiophile Download',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                        ),
                        Text(
                          'Select source & lossless quality',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(MingCute.close_line, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Song card ──
                SongCardWidget(
                  song: widget.song,
                  showOptions: false,
                  showCopyBtn: false,
                ),
                const SizedBox(height: 18),

                // ── Source section ──
                _SectionLabel(
                  text: 'SELECT SOURCE',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 68,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _sources.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final src = _sources[index];
                      final isSelected = _selectedSource == src.name;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedSource = src.name);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? src.badgeColor.withValues(alpha: 0.15)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.04)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? src.badgeColor.withValues(alpha: 0.7)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                src.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? src.badgeColor
                                      : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: src.badgeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  src.qualityBadge,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: src.badgeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),

                // ── Quality section ──
                _SectionLabel(text: 'SELECT AUDIO QUALITY', isDark: isDark),
                const SizedBox(height: 10),
                Column(
                  children: _qualities.map((q) {
                    final isSelected = _selectedQualityValue == q.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: InkWell(
                        onTap: () {
                          setState(() => _selectedQualityValue = q.value);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? q.tagColor.withValues(alpha: 0.12)
                                : isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? q.tagColor.withValues(alpha: 0.75)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? MingCute.check_circle_fill
                                    : Icons.circle_outlined,
                                size: 18,
                                color: isSelected
                                    ? q.tagColor
                                    : (isDark ? Colors.white38 : Colors.black38),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      q.label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    Text(
                                      q.detail,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: q.tagColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  q.tag,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: q.tagColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // ── Download button ──
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _startDownload,
                    icon: const Icon(MingCute.download_2_line,
                        color: Colors.black),
                    label: Text(
                      'Download  •  $_selectedSource  •  ${_currentQuality.tag}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _audiophileGold,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;

  const _SectionLabel({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: isDark ? Colors.white54 : Colors.black54,
      ),
    );
  }
}
