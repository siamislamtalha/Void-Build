import 'dart:math';
import 'dart:ui' show lerpDouble, ImageFilter;

import 'package:voidmusic/blocs/media_player/voidmusic_player_cubit.dart';
import 'package:voidmusic/blocs/mini_player/mini_player_cubit.dart';
import 'package:voidmusic/blocs/player_overlay/player_overlay_cubit.dart';
import 'package:voidmusic/core/models/exported.dart';
import 'package:voidmusic/screens/widgets/media_metadata_links.dart';
import 'package:voidmusic/screens/widgets/quality_badge.dart';
import 'package:voidmusic/utils/load_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';

class MiniPlayerWidget extends StatelessWidget {
  /// The navigation branch index currently active in the shell.
  /// Passed through to [PlayerOverlayCubit.showPlayer] so the down-arrow
  /// button on the full-screen player can return the user to this page.
  final int? currentPageIndex;

  /// Whether the player is collapsed into the center pill of the 3-pill row on mobile.
  final bool isCompact;

  const MiniPlayerWidget({
    Key? key,
    this.currentPageIndex,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
      builder: (context, state) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1.5),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: state.isVisible
              ? MiniPlayerCard(
                  key: const ValueKey('mini_player'),
                  state: state,
                  currentPageIndex: currentPageIndex,
                  isCompact: isCompact,
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        );
      },
    );
  }
}

class MiniPlayerCard extends StatefulWidget {
  final MiniPlayerState state;
  final int? currentPageIndex;
  final bool isCompact;

  const MiniPlayerCard({
    super.key,
    required this.state,
    this.currentPageIndex,
    this.isCompact = false,
  });

  @override
  State<MiniPlayerCard> createState() => _MiniPlayerCardState();
}

class _MiniPlayerCardState extends State<MiniPlayerCard>
    with TickerProviderStateMixin {
  double _dragOffset = 0;
  double _snapStartOffset = 0;
  late final AnimationController _snapController;
  late final AnimationController _waveController;

  static const double _artworkSize = 46;
  static const double _swipeThreshold = 80;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(_onSnapTick);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _syncAnimations();
  }

  @override
  void didUpdateWidget(covariant MiniPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.isPlaying != widget.state.isPlaying) {
      _syncAnimations();
    }
  }

  void _syncAnimations() {
    if (widget.state.isPlaying) {
      _waveController.repeat();
    } else {
      _waveController.stop();
    }
  }

  void _onSnapTick() {
    setState(() {
      _dragOffset = lerpDouble(
        _snapStartOffset,
        0,
        Curves.easeOutCubic.transform(_snapController.value),
      )!;
    });
  }

  @override
  void dispose() {
    _snapController
      ..removeListener(_onSnapTick)
      ..dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_snapController.isAnimating) _snapController.stop();
    setState(() {
      _dragOffset += details.delta.dx * 0.85;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final player = context.read<VoidMusicPlayerCubit>().voidMusicPlayer;

    if (_dragOffset < -_swipeThreshold || velocity < -600) {
      HapticFeedback.mediumImpact();
      player.skipToNext();
    } else if (_dragOffset > _swipeThreshold || velocity > 600) {
      HapticFeedback.mediumImpact();
      player.skipToPrevious();
    }

    _snapStartOffset = _dragOffset;
    _snapController.forward(from: 0);
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if ((details.primaryVelocity ?? 0) < -200) {
      HapticFeedback.lightImpact();
      context.read<PlayerOverlayCubit>().showPlayer(
            fromPageIndex: widget.currentPageIndex,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.state.track!;
    final isDesktop = ResponsiveBreakpoints.of(context).isDesktop;
    final thumbUrl = song.thumbnail.urlLow ?? song.thumbnail.url;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.read<PlayerOverlayCubit>().showPlayer(
              fromPageIndex: widget.currentPageIndex,
            );
      },
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: Transform.translate(
        offset: Offset(_dragOffset, 0),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutQuart,
          padding: EdgeInsets.symmetric(
            // Desktop: outer _GlassFooterOverlay container handles all
            // horizontal spacing. Inner padding removed to avoid double-inset.
            horizontal: 0,
            vertical: widget.isCompact ? 0 : 4,
          ),
          child: isDesktop
              ? Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.35 : 0.12),
                        blurRadius: 20,
                        spreadRadius: -4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOutQuart,
                        height: widget.isCompact ? 58 : double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white
                                .withValues(alpha: isDark ? 0.15 : 0.25),
                            width: 0.75,
                          ),
                        ),
                        child: Stack(
                          children: [
                            AnimatedPadding(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOutQuart,
                              padding: EdgeInsets.only(
                                left: widget.isCompact ? 8 : 10,
                                right: widget.isCompact ? 4 : 6,
                              ),
                              child: Row(
                                children: [
                                  // ── Album Art ──
                                  _Artwork(
                                    imageUrl: thumbUrl,
                                    fallbackUrl: song.thumbnail.url,
                                    size: widget.isCompact ? 36 : _artworkSize,
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeInOutQuart,
                                    width: widget.isCompact ? 6 : 10,
                                  ),
                                  // ── Song Info ──
                                  Expanded(
                                    child: _TrackInfo(
                                      song: song,
                                      waveController: _waveController,
                                      isPlaying: widget.state.isPlaying,
                                      isDark: isDark,
                                      isCompact: widget.isCompact,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // ── Controls ──
                                  _ControlsCapsule(
                                    state: widget.state,
                                    isDesktop: isDesktop,
                                    song: song,
                                    isDark: isDark,
                                    isCompact: widget.isCompact,
                                  ),
                                  // ── Close Button ──
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeInOutQuart,
                                    width: widget.isCompact ? 0 : 34,
                                    child: AnimatedOpacity(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOutQuart,
                                      opacity: widget.isCompact ? 0.0 : 1.0,
                                      child: ClipRRect(
                                        child: OverflowBox(
                                          maxWidth: 34,
                                          child: _CloseButton(isDark: isDark),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!widget.state.isCompleted)
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOutQuart,
                                opacity: widget.isCompact ? 0.0 : 1.0,
                                child: _GlowingProgressBar(isDark: isDark),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.35 : 0.12),
                        blurRadius: 20,
                        spreadRadius: -4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOutQuart,
                        height: widget.isCompact ? 58 : double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white
                                .withValues(alpha: isDark ? 0.15 : 0.25),
                            width: 0.75,
                          ),
                        ),
                        child: Stack(
                          children: [
                            AnimatedPadding(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOutQuart,
                              padding: EdgeInsets.only(
                                left: widget.isCompact ? 8 : 10,
                                right: widget.isCompact ? 4 : 6,
                              ),
                              child: Row(
                                children: [
                                  // ── Album Art ──
                                  _Artwork(
                                    imageUrl: thumbUrl,
                                    fallbackUrl: song.thumbnail.url,
                                    size: widget.isCompact ? 36 : _artworkSize,
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeInOutQuart,
                                    width: widget.isCompact ? 6 : 10,
                                  ),
                                  // ── Song Info ──
                                  Expanded(
                                    child: _TrackInfo(
                                      song: song,
                                      waveController: _waveController,
                                      isPlaying: widget.state.isPlaying,
                                      isDark: isDark,
                                      isCompact: widget.isCompact,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // ── Controls ──
                                  _ControlsCapsule(
                                    state: widget.state,
                                    isDesktop: isDesktop,
                                    song: song,
                                    isDark: isDark,
                                    isCompact: widget.isCompact,
                                  ),
                                  // ── Close Button ──
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeInOutQuart,
                                    width: widget.isCompact ? 0 : 34,
                                    child: AnimatedOpacity(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOutQuart,
                                      opacity: widget.isCompact ? 0.0 : 1.0,
                                      child: ClipRRect(
                                        child: OverflowBox(
                                          maxWidth: 34,
                                          child: _CloseButton(isDark: isDark),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!widget.state.isCompleted)
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOutQuart,
                                opacity: widget.isCompact ? 0.0 : 1.0,
                                child: _GlowingProgressBar(isDark: isDark),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Glass capsule containing play/pause + skip controls (like the reference image)
class _ControlsCapsule extends StatelessWidget {
  final MiniPlayerState state;
  final bool isDesktop;
  final dynamic song;
  final bool isDark;
  final bool isCompact;

  const _ControlsCapsule({
    required this.state,
    required this.isDesktop,
    required this.song,
    required this.isDark,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final capsuleColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
    final capsuleBorder = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.10);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 2 : 4,
          vertical: isCompact ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: isCompact ? Colors.transparent : capsuleColor,
          borderRadius: BorderRadius.circular(28),
          border: isCompact
              ? null
              : Border.all(
                  color: capsuleBorder,
                  width: 1.0,
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDesktop)
              _ControlButton(
                icon: FontAwesome.backward_step_solid,
                size: 16,
                isDark: isDark,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context
                      .read<VoidMusicPlayerCubit>()
                      .voidMusicPlayer
                      .skipToPrevious();
                },
              ),
            _PlayPauseButton(state: state, isDark: isDark),
            _ControlButton(
              icon: FontAwesome.forward_step_solid,
              size: isCompact ? 14 : 16,
              isDark: isDark,
              onPressed: () {
                HapticFeedback.lightImpact();
                context
                    .read<VoidMusicPlayerCubit>()
                    .voidMusicPlayer
                    .skipToNext();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  final String imageUrl;
  final String fallbackUrl;
  final double size;

  const _Artwork({
    required this.imageUrl,
    required this.fallbackUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LoadImageCached(
          imageUrl: imageUrl,
          fallbackUrl: fallbackUrl,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  final dynamic song;
  final AnimationController waveController;
  final bool isPlaying;
  final bool isDark;
  final bool isCompact;

  const _TrackInfo({
    required this.song,
    required this.waveController,
    required this.isPlaying,
    required this.isDark,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).colorScheme.onSurface;
    final subtitleColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isPlaying) ...[
              _NowPlayingWave(controller: waveController, color: titleColor),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeInOutCubic,
                style: TextStyle(
                  fontFamily: 'Unageo',
                  fontSize: isCompact ? 12.5 : 14,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                  letterSpacing: 0.2,
                ),
                child: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (song is Track) QualityBadge(song: song as Track),
          ],
        ),
        const SizedBox(height: 2),
        TrackMetadataLinks(
          track: song,
          style: TextStyle(
            fontFamily: 'Unageo',
            fontWeight: FontWeight.w600,
            fontSize: isCompact ? 10.5 : 11.5,
            color: subtitleColor,
            letterSpacing: 0.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _NowPlayingWave extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  const _NowPlayingWave({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(18, 14),
          painter: _WavePainter(
            progress: controller.value,
            color: color,
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final Color color;

  _WavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const barCount = 4;
    final spacing = size.width / barCount;

    for (int i = 0; i < barCount; i++) {
      final phase = i * 0.8;
      final amplitude = size.height * 0.4;
      final wave = sin((progress * 2 * pi) + phase);
      final barHeight = (amplitude * (wave + 1) / 2) + (size.height * 0.15);

      final x = (i * spacing) + spacing / 2;
      final top = (size.height - barHeight) / 2;
      final bottom = top + barHeight;

      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _PlayPauseButton extends StatelessWidget {
  final MiniPlayerState state;
  final bool isDark;
  const _PlayPauseButton({required this.state, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).colorScheme.onSurface;
    if (state.isLoading || state.isResolving) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: iconColor,
          ),
        ),
      );
    }

    if (state.isCompleted) {
      return _ControlButton(
        icon: FontAwesome.rotate_right_solid,
        size: 18,
        isDark: isDark,
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.read<VoidMusicPlayerCubit>().voidMusicPlayer.rewind();
        },
      );
    }

    return _ControlButton(
      icon: state.isPlaying ? FontAwesome.pause_solid : FontAwesome.play_solid,
      size: 18,
      isDark: isDark,
      onPressed: () {
        HapticFeedback.lightImpact();
        state.isPlaying
            ? context.read<VoidMusicPlayerCubit>().voidMusicPlayer.pause()
            : context.read<VoidMusicPlayerCubit>().voidMusicPlayer.play();
      },
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;
  final bool isDark;

  const _ControlButton({
    required this.icon,
    required this.size,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: size, color: iconColor),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final bool isDark;
  const _CloseButton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          context.read<MiniPlayerCubit>().dismiss();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Icon(MingCute.close_line, size: 18, color: iconColor),
        ),
      ),
    );
  }
}

class _GlowingProgressBar extends StatelessWidget {
  final bool isDark;
  const _GlowingProgressBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final barColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    final glowColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : const Color(0xFF1C1C1E).withValues(alpha: 0.15);
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 3,
      child: StreamBuilder<ProgressBarStreams>(
        stream: context.watch<VoidMusicPlayerCubit>().progressStreams,
        builder: (context, snapshot) {
          double fraction = 0;
          if (snapshot.hasData && snapshot.data!.duration != Duration.zero) {
            fraction = (snapshot.data!.position.inMilliseconds /
                    snapshot.data!.duration.inMilliseconds)
                .clamp(0.0, 1.0);
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth * fraction;
              return Stack(
                children: [
                  Positioned(
                    bottom: 0,
                    left: 0,
                    width: width,
                    height: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: glowColor,
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    height: 3,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: width,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(2),
                        ),
                        gradient: LinearGradient(colors: [
                          barColor,
                          barColor.withValues(alpha: isDark ? 0.6 : 0.5),
                        ]),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
