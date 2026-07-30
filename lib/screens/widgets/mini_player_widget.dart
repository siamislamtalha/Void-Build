import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:voidmusic/blocs/media_player/voidmusic_player_cubit.dart';
import 'package:voidmusic/blocs/mini_player/mini_player_cubit.dart';
import 'package:voidmusic/blocs/player_overlay/player_overlay_cubit.dart';
import 'package:voidmusic/screens/widgets/media_metadata_links.dart';
import 'package:voidmusic/utils/load_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:voidmusic/core/theme/app_theme.dart';

class MiniPlayerWidget extends StatelessWidget {
  /// The navigation branch index currently active in the shell.
  /// Passed through to [PlayerOverlayCubit.showPlayer] so the down-arrow
  /// button on the full-screen player can return the user to this page.
  final int? currentPageIndex;
  const MiniPlayerWidget({Key? key, this.currentPageIndex}) : super(key: key);

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
  const MiniPlayerCard({super.key, required this.state, this.currentPageIndex});

  @override
  State<MiniPlayerCard> createState() => _MiniPlayerCardState();
}

class _MiniPlayerCardState extends State<MiniPlayerCard>
    with TickerProviderStateMixin {
  double _dragOffset = 0;
  double _snapStartOffset = 0;
  late final AnimationController _snapController;
  late final AnimationController _waveController;

  static const double _cardHeight = 64;
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

    final glassColor = AppTheme.glassColor(context);
    final glassBorder = AppTheme.glassBorder(context);

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
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 0, vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: AppTheme.glassBlur,
              child: Container(
                height: _cardHeight,
                width: isDesktop ? double.infinity : null,
                decoration: BoxDecoration(
                  color: glassColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: glassBorder,
                    width: 1.0,
                  ),
                ),
                child: Stack(
                  children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10, right: 6),
                  child: Row(
                    children: [
                      // ── Album Art ──
                      _Artwork(
                        imageUrl: thumbUrl,
                        fallbackUrl: song.thumbnail.url,
                        size: _artworkSize,
                      ),
                      const SizedBox(width: 10),
                      // ── Song Info ──
                      Expanded(
                        child: _TrackInfo(
                          song: song,
                          waveController: _waveController,
                          isPlaying: widget.state.isPlaying,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // ── Controls ──
                      _ControlsCapsule(
                        state: widget.state,
                        isDesktop: isDesktop,
                        song: song,
                        isDark: isDark,
                      ),
                      // ── Close Button ──
                      _CloseButton(isDark: isDark),
                    ],
                  ),
                ),
                if (!widget.state.isCompleted)
                  _GlowingProgressBar(isDark: isDark),
              ],
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

  const _ControlsCapsule({
    required this.state,
    required this.isDesktop,
    required this.song,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Controls capsule: frosted glass without BackdropFilter for same reason
    // as the footer nav bar — reliability across all screens.
    final capsuleColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
    final capsuleBorder = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.10);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: capsuleColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
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
              size: 16,
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
    return Container(
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

  const _TrackInfo({
    required this.song,
    required this.waveController,
    required this.isPlaying,
    required this.isDark,
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
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Text(
                song.title,
                style: TextStyle(
                  fontFamily: 'Unageo',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        TrackMetadataLinks(
          track: song,
          style: TextStyle(
            fontFamily: 'Unageo',
            fontWeight: FontWeight.w600,
            fontSize: 11.5,
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
          child: Icon(Icons.close_rounded, size: 18, color: iconColor),
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
