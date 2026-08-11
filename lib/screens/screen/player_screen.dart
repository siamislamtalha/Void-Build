import 'dart:async';

import 'package:voidmusic/blocs/downloader/cubit/downloader_cubit.dart';
import 'package:voidmusic/blocs/library/cubit/library_items_cubit.dart';
import 'package:voidmusic/blocs/player_overlay/player_overlay_cubit.dart';
import 'package:voidmusic/core/adapters/track_adapter.dart';
import 'package:voidmusic/screens/screen/home_views/timer_view.dart';
import 'package:voidmusic/screens/widgets/gradient_progress_bar.dart';
import 'package:voidmusic/screens/widgets/more_bottom_sheet.dart';
import 'package:voidmusic/screens/widgets/up_next_panel.dart';
import 'package:voidmusic/screens/widgets/volume_slider.dart';
import 'package:voidmusic/screens/widgets/media_metadata_links.dart';
import 'package:voidmusic/screens/screen/player_views/segments_sheet.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/player_setting.dart';
import 'package:voidmusic/services/voidmusic_player.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voidmusic/l10n/app_localizations.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:voidmusic/services/player/player_engine.dart';
import 'package:voidmusic/screens/widgets/like_widget.dart';
import 'package:voidmusic/screens/widgets/play_pause_widget.dart';
import 'package:voidmusic/screens/widgets/snackbar.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:voidmusic/utils/load_image.dart';
import 'package:voidmusic/utils/pallete_generator.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:voidmusic/screens/widgets/quality_badge.dart';
import 'package:voidmusic/services/cast/google_cast_service.dart' as cast_service;
import 'package:voidmusic/widgets/chromecast_icon.dart';
import '../../blocs/media_player/voidmusic_player_cubit.dart';
import '../../blocs/mini_player/mini_player_cubit.dart';
import 'player_views/fullscreen_lyrics_view.dart';

class AudioPlayerView extends StatefulWidget {
  const AudioPlayerView({super.key});

  @override
  State<AudioPlayerView> createState() => _AudioPlayerViewState();
}

class _AudioPlayerViewState extends State<AudioPlayerView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UpNextPanelController _upNextPanelController = UpNextPanelController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PlayerOverlayCubit>().registerUpNextPanelCollapse(
              () => _upNextPanelController.collapse(),
            );
      }
    });
  }

  @override
  void dispose() {
    context.read<PlayerOverlayCubit>().unregisterUpNextPanelCollapse();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final voidMusicPlayerCubit = context.read<VoidMusicPlayerCubit>();
    final musicPlayer = voidMusicPlayerCubit.voidMusicPlayer;
    final isMobile = ResponsiveBreakpoints.of(context).smallerOrEqualTo(TABLET);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = Theme.of(context).colorScheme.onSurface;
    final secondaryTextColor = isDark 
        ? Default_Theme.primaryColor2 
        : const Color(0xFF66666E);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : AppTheme.lightBg,
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF000000) : AppTheme.lightBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: iconColor,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(MingCute.down_line, size: 32, color: iconColor),
          onPressed: () {
            // Collapse Up Next panel if expanded, then always minimize the player.
            _upNextPanelController.collapse();
            context.read<PlayerOverlayCubit>().minimizePlayer();
          },
        ),
        actions: [
          IconButton(
            onPressed: () {
              final mi = musicPlayer.mediaItem.valueOrNull;
              if (mi != null) {
                showSegmentsSheet(
                  context,
                  trackId: mi.id,
                  trackDuration: mi.duration ?? Duration.zero,
                  onSeek: (pos) => musicPlayer.seek(pos),
                );
              }
            },
            icon: Icon(MingCute.list_check_3_line,
                size: 22, color: iconColor),
          ),
          _CastButton(iconColor: iconColor),
          IconButton(
            onPressed: () =>
                showMoreBottomSheet(context, musicPlayer.currentMedia),
            icon: Icon(MingCute.more_2_fill,
                size: 25, color: iconColor),
          )
        ],
        title: Column(
          children: [
            Text(
              l10n.playerEnjoyingFrom,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: iconColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ).merge(Default_Theme.secondoryTextStyle),
            ),
            StreamBuilder<String>(
              stream: musicPlayer.queueTitle,
              builder: (context, snapshot) {
                return Text(
                  snapshot.data ?? l10n.playerUnknownQueue,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 12,
                  ).merge(Default_Theme.secondoryTextStyle),
                );
              },
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(seconds: 1),
        child: isMobile
            ? LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned.fill(
                        child: _PlayerUI(
                          musicPlayer: musicPlayer,
                          tabController: _tabController,
                        ),
                      ),
                      UpNextPanel(
                        peekHeight: 60.0,
                        parentHeight: constraints.maxHeight,
                        controller: _upNextPanelController,
                      ),
                    ],
                  );
                },
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: 400,
                      maxWidth: MediaQuery.of(context).size.width * 0.60,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _PlayerUI(
                        musicPlayer: musicPlayer,
                        tabController: _tabController,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.8,
                        child: UpNextPanel(
                          peekHeight: 60,
                          parentHeight:
                              MediaQuery.of(context).size.height * 0.8,
                          isDesktopMode: true,
                          controller: _upNextPanelController,
                        ),
                      ),
                    ),
                  )
                ],
              ),
      ),
    );
  }
}

class _PlayerUI extends StatelessWidget {
  final VoidMusicPlayer musicPlayer;
  final TabController tabController;

  const _PlayerUI({
    required this.musicPlayer,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: tabController.animation!,
            builder: (context, child) {
              return Opacity(
                opacity: (1 - tabController.animation!.value),
                child: child,
              );
            },
            child: const RepaintBoundary(child: AmbientImgShadowWidget()),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              const SizedBox(height: 60),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: CoverImageVolSlider(),
                ),
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PlayerCtrlWidgets(musicPlayer: musicPlayer),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }
}

class CoverImageVolSlider extends StatelessWidget {
  const CoverImageVolSlider({super.key});

  @override
  Widget build(BuildContext context) {
    final voidMusicPlayerCubit = context.read<VoidMusicPlayerCubit>();

    return VolumeDragController(
      child: StreamBuilder<MediaItem?>(
        stream: voidMusicPlayerCubit.voidMusicPlayer.mediaItem,
        builder: (context, snapshot) {
          final currentTrack =
              voidMusicPlayerCubit.voidMusicPlayer.currentTrackInfo;
          final highResUrl =
              currentTrack.thumbnail.urlHigh ?? currentTrack.thumbnail.url;
          final lowResUrl =
              currentTrack.thumbnail.urlLow ?? currentTrack.thumbnail.url;

          return SizedBox.expand(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LoadImageCached(
                    imageUrl: highResUrl,
                    fallbackUrl: lowResUrl,
                    fit: BoxFit.cover,
                    maxMemCacheWidth: 2500, // High quality thumbnail
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class PlayerCtrlWidgets extends StatelessWidget {
  final VoidMusicPlayer musicPlayer;
  const PlayerCtrlWidgets({super.key, required this.musicPlayer});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SongInfoRow(),
        const SizedBox(height: 15),
        const _PlayerProgressBar(),
        const SizedBox(height: 25),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: _PlayerControlsRow(musicPlayer: musicPlayer),
        ),
      ],
    );
  }
}

class _SongInfoRow extends StatelessWidget {
  const _SongInfoRow();

  @override
  Widget build(BuildContext context) {
    final player = context.read<VoidMusicPlayerCubit>().voidMusicPlayer;
    final primaryTextColor = Theme.of(context).colorScheme.onSurface;
    final subtitleColor = Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
        : const Color(0xFF66666E);

    return Row(
      children: [
        Expanded(
          child: StreamBuilder<MediaItem?>(
            stream: player.mediaItem,
            builder: (context, snapshot) {
              final currentTrack = player.currentTrackInfo;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          currentTrack.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Default_Theme.secondoryTextStyle.merge(TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                          )),
                        ),
                      ),
                      QualityBadge(song: currentTrack),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TrackMetadataLinks(
                    track: currentTrack,
                    showAlbum: currentTrack.album != null,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Default_Theme.secondoryTextStyle.merge(TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: subtitleColor,
                    )),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        const _DownloadButton(),
        const _LikeButton(),
      ],
    );
  }
}

/// FIX M-05: Replaced FutureBuilder (re-queries DB on every stream event) with
/// a StatefulWidget that caches the download state and only re-queries when the
/// media item ID actually changes.
class _DownloadButton extends StatefulWidget {
  const _DownloadButton();

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  String? _lastTrackId;
  bool _isDownloaded = false;
  StreamSubscription? _mediaSub;

  @override
  void initState() {
    super.initState();
    final player = context.read<VoidMusicPlayerCubit>().voidMusicPlayer;
    _mediaSub = player.mediaItem.listen((mi) {
      if (mi?.id != _lastTrackId) {
        _lastTrackId = mi?.id;
        _queryDownloadState(mi);
      }
    });
    // Query immediately for the current track.
    _queryDownloadState(player.mediaItem.valueOrNull);
  }

  Future<void> _queryDownloadState(MediaItem? mi) async {
    if (mi == null) {
      if (mounted) setState(() => _isDownloaded = false);
      return;
    }
    try {
      final info = await context
          .read<DownloaderCubit>()
          .getDownloadInfo(mediaItemToTrack(mi));
      if (mounted) setState(() => _isDownloaded = info != null);
    } catch (_) {
      if (mounted) setState(() => _isDownloaded = false);
    }
  }

  @override
  void dispose() {
    _mediaSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDownloaded) return const SizedBox.shrink();
    final iconColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return Tooltip(
      message: AppLocalizations.of(context)!.tooltipAvailableOffline,
      child: IconButton(
        iconSize: 25,
        icon: Icon(
          Icons.offline_pin_rounded,
          color: iconColor,
        ),
        onPressed: () {},
      ),
    );
  }
}

/// FIX M-05: Replaced nested FutureBuilder+StreamBuilder+BlocBuilder with a
/// StatefulWidget that caches liked state and only re-queries when track ID changes.
class _LikeButton extends StatefulWidget {
  const _LikeButton();

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> {
  String? _lastTrackId;
  bool _isLiked = false;
  StreamSubscription? _mediaSub;

  @override
  void initState() {
    super.initState();
    final player = context.read<VoidMusicPlayerCubit>().voidMusicPlayer;
    _mediaSub = player.mediaItem.listen((mi) {
      if (mi?.id != _lastTrackId) {
        _lastTrackId = mi?.id;
        _queryLikedState(mi);
      }
    });
    _queryLikedState(player.mediaItem.valueOrNull);
  }

  Future<void> _queryLikedState(MediaItem? mi) async {
    if (mi == null) {
      if (mounted) setState(() => _isLiked = false);
      return;
    }
    try {
      final liked = await context
          .read<LibraryItemsCubit>()
          .isTrackLiked(mediaItemToTrack(mi));
      if (mounted) setState(() => _isLiked = liked);
    } catch (_) {
      if (mounted) setState(() => _isLiked = false);
    }
  }

  @override
  void dispose() {
    _mediaSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<VoidMusicPlayerCubit>().voidMusicPlayer;
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<bool>(
      stream: player.engine.playingStream,
      builder: (context, playingSnapshot) {
        final isPlaying = playingSnapshot.data ?? false;
        final currentMedia = player.mediaItem.valueOrNull;
        if (currentMedia == null) return const SizedBox.shrink();

        return LikeBtnWidget(
          isPlaying: isPlaying,
          isLiked: _isLiked,
          iconSize: 25,
          onLiked: () {
            context
                .read<LibraryItemsCubit>()
                .setTrackLiked(mediaItemToTrack(currentMedia), true);
            setState(() => _isLiked = true);
            SnackbarService.showMessage(l10n.playerLiked(currentMedia.title));
          },
          onDisliked: () {
            context
                .read<LibraryItemsCubit>()
                .setTrackLiked(mediaItemToTrack(currentMedia), false);
            setState(() => _isLiked = false);
            SnackbarService.showMessage(l10n.playerUnliked(currentMedia.title));
          },
        );
      },
    );
  }
}

class _PlayerProgressBar extends StatelessWidget {
  const _PlayerProgressBar();

  @override
  Widget build(BuildContext context) {
    final playerCubit = context.read<VoidMusicPlayerCubit>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeLabelColor = isDark
        ? Default_Theme.primaryColor1.withValues(alpha: 0.7)
        : const Color(0xFF66666E);
    return RepaintBoundary(
      child: StreamBuilder<ProgressBarStreams>(
        stream: playerCubit.progressStreams,
        builder: (context, snapshot) {
          final data = snapshot.data;
          return GradientProgressBar.fromAccentColors(
            progress: data?.position ?? Duration.zero,
            total: data?.duration ?? Duration.zero,
            buffered: data?.buffered ?? Duration.zero,
            onSeek: playerCubit.voidMusicPlayer.seek,
            isPlaying: data?.isPlaying ?? false,
            activeAccentColor: Default_Theme.accentColor1,
            inactiveAccentColor: AppTheme.accentColor(context),
            activeGradientStyle: GradientStyle.lightAndBreezy,
            inactiveGradientStyle: GradientStyle.warmAndRich,
            trackHeight: 6.0,
            thumbRadius: 8.0,
            timeLabelPadding: 5,
            timeLabelStyle: Default_Theme.secondoryTextStyle.merge(TextStyle(
              fontSize: 15,
              color: timeLabelColor,
            )),
            timeLabelLocation: TimeLabelLocation.above,
            inactiveTrackColor:
                isDark
                    ? Default_Theme.primaryColor2.withValues(alpha: 0.1)
                    : const Color(0xFF1C1C1E).withValues(alpha: 0.1),
            animationDuration: const Duration(milliseconds: 200),
            animationCurve: Curves.easeOutCubic,
          );
        },
      ),
    );
  }
}

class _PlayerControlsRow extends StatelessWidget {
  final VoidMusicPlayer musicPlayer;
  const _PlayerControlsRow({required this.musicPlayer});

  Widget _buildControlColumn({required Widget top, required Widget bottom}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 70, alignment: Alignment.center, child: top),
        SizedBox(height: 40, child: bottom),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Default_Theme.primaryColor1 : const Color(0xFF1C1C1E);
    final accentIconColor = isDark ? Default_Theme.accentColor1 : AppTheme.accentColor(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildControlColumn(
          top: IconButton(
            icon: Icon(MingCute.alarm_1_line,
                color: iconColor, size: 28),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const TimerView())),
          ),
          bottom: _LoopControl(iconColor: iconColor, accentColor: accentIconColor),
        ),
        _buildControlColumn(
          top: IconButton(
            icon: Icon(MingCute.skip_previous_fill,
                color: iconColor, size: 35),
            onPressed: musicPlayer.skipToPrevious,
          ),
          bottom: IconButton(
            icon: Icon(MingCute.align_center_line,
                color: iconColor, size: 24),
            onPressed: () {
              Navigator.of(context).push(PageRouteBuilder(
                pageBuilder: (_, __, ___) => const FullscreenLyricsView(),
                transitionsBuilder: (_, a, __, c) =>
                    FadeTransition(opacity: a, child: c),
                transitionDuration: const Duration(milliseconds: 300),
              ));
            },
          ),
        ),
        _buildControlColumn(
          top: _PlayPauseButton(isDark: isDark),
          bottom: const SizedBox(height: 40),
        ),
        _buildControlColumn(
          top: IconButton(
            icon: Icon(MingCute.skip_forward_fill,
                color: iconColor, size: 35),
            onPressed: musicPlayer.skipToNext,
          ),
          bottom: IconButton(
            icon: Icon(MingCute.settings_6_line,
                color: iconColor, size: 24),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PlayerSetting())),
          ),
        ),
        _buildControlColumn(
          top: _ShuffleControl(iconColor: iconColor, accentColor: accentIconColor),
          bottom: _ExternalLinkControl(iconColor: iconColor),
        ),
      ],
    );
  }
}

class _LoopControl extends StatelessWidget {
  final Color iconColor;
  final Color accentColor;
  const _LoopControl({required this.iconColor, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LoopMode>(
      stream: context.read<VoidMusicPlayerCubit>().voidMusicPlayer.loopMode,
      builder: (context, snapshot) {
        final loopMode = snapshot.data ?? LoopMode.off;
        final l10n = AppLocalizations.of(context)!;
        return PopupMenuButton(
          itemBuilder: (_) => [
            PopupMenuItem(value: 0, child: Text(l10n.playerLoopOff)),
            PopupMenuItem(value: 1, child: Text(l10n.playerLoopOne)),
            PopupMenuItem(value: 2, child: Text(l10n.playerLoopAll)),
          ],
          child: Icon(
            loopMode == LoopMode.off
                ? MingCute.repeat_line
                : loopMode == LoopMode.one
                    ? MingCute.repeat_one_line
                    : MingCute.repeat_fill,
            color: loopMode == LoopMode.off ? iconColor : accentColor,
            size: 24,
          ),
          onSelected: (value) {
            final player = context.read<VoidMusicPlayerCubit>().voidMusicPlayer;
            if (value == 0) player.setLoopMode(LoopMode.off);
            if (value == 1) player.setLoopMode(LoopMode.one);
            if (value == 2) player.setLoopMode(LoopMode.all);
          },
        );
      },
    );
  }
}

class _ShuffleControl extends StatelessWidget {
  final Color iconColor;
  final Color accentColor;
  const _ShuffleControl({required this.iconColor, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final player = context.read<VoidMusicPlayerCubit>().voidMusicPlayer;
    return StreamBuilder<bool>(
      stream: player.shuffleMode,
      builder: (context, snapshot) {
        final isShuffle = snapshot.data ?? false;
        return IconButton(
          icon: Icon(
            MingCute.shuffle_2_fill,
            color: isShuffle ? accentColor : iconColor,
            size: 28,
          ),
          onPressed: () => player.shuffle(!isShuffle),
        );
      },
    );
  }
}

class _ExternalLinkControl extends StatelessWidget {
  final Color iconColor;
  const _ExternalLinkControl({required this.iconColor});

  @override
  Widget build(BuildContext context) {
    final player = context.read<VoidMusicPlayerCubit>().voidMusicPlayer;
    return IconButton(
      icon: Icon(MingCute.external_link_line, color: iconColor, size: 24),
      onPressed: () async {
        final url = player.currentTrackInfo.url;
        if (url != null) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          SnackbarService.showMessage(
              AppLocalizations.of(context)!.snackbarCouldNotOpenLink);
        }
      },
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool isDark;
  const _PlayPauseButton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final musicPlayer = context.read<VoidMusicPlayerCubit>().voidMusicPlayer;
    // In dark mode: white button with black icon (original).
    // In light mode: dark button with white icon to match the theme inversion.
    final buttonColor = Theme.of(context).colorScheme.onSurface;
    final iconColor = Theme.of(context).colorScheme.surface;
    return BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
      builder: (context, state) {
        Widget child;
        Color activeButtonColor = buttonColor;

        if (state.isLoading || state.isResolving) {
          child = CircularProgressIndicator(
              strokeWidth: 3, color: iconColor);
          activeButtonColor = buttonColor;
        } else if (state.isCompleted) {
          child = Icon(FontAwesome.rotate_right_solid,
              color: iconColor, size: 32);
          activeButtonColor = buttonColor;
        } else if (state.hasError) {
          child = Icon(MingCute.warning_line,
              color: iconColor, size: 32);
        } else if (state.isVisible) {
          return PlayPauseButton(
            size: 70,
            onPause: musicPlayer.pause,
            onPlay: musicPlayer.play,
            isPlaying: state.isPlaying,
          );
        } else {
          child = const SizedBox();
        }

        return GestureDetector(
          onTap: () {
            if (state.isCompleted) {
              musicPlayer.seek(Duration.zero);
              musicPlayer.play();
            } else if (state.hasError) {
              musicPlayer.play();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activeButtonColor,
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Center(child: SizedBox(width: 32, height: 32, child: child)),
          ),
        );
      },
    );
  }
}

/// FIX M-06: Replaced async palette fetch inside build() with a proper
/// lifecycle-based approach using a stream subscription.
/// The fetch only triggers when the artUri CHANGES, not on every rebuild.
class AmbientImgShadowWidget extends StatefulWidget {
  const AmbientImgShadowWidget({super.key});

  @override
  State<AmbientImgShadowWidget> createState() => _AmbientImgShadowWidgetState();
}

class _AmbientImgShadowWidgetState extends State<AmbientImgShadowWidget> {
  Color? _cachedColor;
  String? _lastArtUri;
  StreamSubscription? _mediaSub;
  bool _fetchingPalette = false;

  @override
  void initState() {
    super.initState();
    final player = context.read<VoidMusicPlayerCubit>().voidMusicPlayer;
    _mediaSub = player.mediaItem.listen((mi) {
      final artUri = mi?.artUri?.toString();
      if (artUri != _lastArtUri) {
        _lastArtUri = artUri;
        _fetchPalette(artUri);
      }
    });
    // Initial fetch
    final current = player.mediaItem.valueOrNull;
    _lastArtUri = current?.artUri?.toString();
    _fetchPalette(_lastArtUri);
  }

  Future<void> _fetchPalette(String? artUri) async {
    if (artUri == null || artUri.isEmpty || _fetchingPalette) return;
    _fetchingPalette = true;
    try {
      final palette = await getPalleteFromImage(artUri);
      if (mounted) {
        setState(() => _cachedColor = palette.dominantColor?.color);
      }
    } catch (_) {
    } finally {
      _fetchingPalette = false;
    }
  }

  @override
  void dispose() {
    _mediaSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              (_cachedColor ?? const Color.fromARGB(255, 163, 44, 115))
                  .withValues(alpha: isDark ? 0.35 : 0.20),
              Colors.transparent,
            ],
            center: Alignment.center,
            radius: 0.70,
          ),
        ),
      ),
    );
  }
}

class _CastButton extends StatefulWidget {
  final Color iconColor;

  const _CastButton({required this.iconColor});

  @override
  State<_CastButton> createState() => _CastButtonState();
}

class _CastButtonState extends State<_CastButton> {
  final cast_service.GoogleCastService _castService = cast_service.GoogleCastService.instance;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCast();
  }

  Future<void> _initializeCast() async {
    await _castService.initialize();
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Default_Theme.primaryColor1 : Default_Theme.primaryColor2;

    return StreamBuilder<cast_service.CastState>(
      stream: _castService.stateStream,
      initialData: _castService.currentState,
      builder: (context, snapshot) {
        final castState = snapshot.data ?? cast_service.CastState.disconnected;
        final isCasting = castState == cast_service.CastState.connected;

        return IconButton(
          onPressed: () => _showCastDialog(),
          icon: Icon(
            isCasting ? MingCute.send_fill : MingCute.send_line,
            color: isCasting 
                ? AppTheme.accentColor(context) 
                : iconColor,
            size: 22,
          ),
        );
      },
    );
  }

  void _showCastDialog() {
    showDialog(
      context: context,
      builder: (context) => _CastDialog(castService: _castService),
    );
  }
}

class _CastDialog extends StatefulWidget {
  final cast_service.GoogleCastService castService;

  const _CastDialog({required this.castService});

  @override
  State<_CastDialog> createState() => _CastDialogState();
}

class _CastDialogState extends State<_CastDialog> {
  @override
  void initState() {
    super.initState();
    widget.castService.scanForDevices();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Default_Theme.primaryColor1 : Default_Theme.primaryColor2;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Default_Theme.cardBorderColor : const Color(0xFFE5E5EA);

    return StreamBuilder<cast_service.CastState>(
      stream: widget.castService.stateStream,
      initialData: widget.castService.currentState,
      builder: (context, stateSnapshot) {
        return StreamBuilder<List<cast_service.CastDevice>>(
          stream: widget.castService.devicesStream,
          initialData: widget.castService.availableDevices,
          builder: (context, devicesSnapshot) {
            final isCasting = widget.castService.isCasting;
            final isConnecting = stateSnapshot.data == cast_service.CastState.connecting;
            final devices = devicesSnapshot.data ?? [];

            return AlertDialog(
              backgroundColor: bgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const ChromecastIcon(size: 24, color: null),
                  const SizedBox(width: 12),
                  Text(
                    'Cast to Device',
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isConnecting) ...[
                    const Spacer(),
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accentColor(context),
                      ),
                    ),
                  ],
                ],
              ),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCasting) ...[
                      _buildCurrentDevice(iconColor),
                      Divider(color: borderColor),
                      const SizedBox(height: 8),
                    ],
                    _buildDeviceList(iconColor, devices),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: iconColor),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCurrentDevice(Color iconColor) {
    final device = widget.castService.currentDevice;
    if (device == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Currently Connected',
          style: TextStyle(
            color: iconColor.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(MingCute.device_line, color: iconColor),
          title: Text(
            device.name,
            style: TextStyle(color: iconColor),
          ),
          trailing: IconButton(
            icon: Icon(MingCute.unlink_line, color: iconColor),
            onPressed: () async {
              await widget.castService.disconnect();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceList(Color iconColor, List<cast_service.CastDevice> devices) {
    if (devices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Searching for devices...',
          style: TextStyle(
            color: iconColor.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Devices',
          style: TextStyle(
            color: iconColor.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ...devices.map((device) => ListTile(
          leading: Icon(MingCute.device_line, color: iconColor),
          title: Text(
            device.name,
            style: TextStyle(color: iconColor),
          ),
          onTap: () async {
            final success = await widget.castService.connectToDevice(device);
            if (success && mounted) {
              Navigator.pop(context);
            }
          },
        )),
      ],
    );
  }
}
