import 'package:voidmusic/blocs/player_overlay/player_overlay_cubit.dart';
import 'package:voidmusic/screens/screen/player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A persistent player overlay that stays mounted in the widget tree.
/// This widget wraps the main content and overlays the full player on top
/// with a slide-up animation when visible, similar to modern media apps.
class PlayerOverlayWrapper extends StatefulWidget {
  final Widget child;

  const PlayerOverlayWrapper({
    super.key,
    required this.child,
  });

  @override
  State<PlayerOverlayWrapper> createState() => _PlayerOverlayWrapperState();
}

class _PlayerOverlayWrapperState extends State<PlayerOverlayWrapper>
    with TickerProviderStateMixin {
  // ── Show controller ─────────────────────────────────────────────────────────
  // Slightly longer with an elastic-style ease for a premium "spring up" feel.
  late final AnimationController _showController;
  late final Animation<Offset> _slideInAnimation;
  late final Animation<double> _fadeInAnimation;

  // ── Dismiss controller ───────────────────────────────────────────────────────
  // Shorter and snappier. Combines slide-down + scale-shrink + fade-out so the
  // player feels like it "collapses" down toward the mini-player bar.
  late final AnimationController _dismissController;
  late final Animation<Offset> _slideOutAnimation;
  late final Animation<double> _scaleOutAnimation;
  late final Animation<double> _fadeOutAnimation;

  /// Track if the player has ever been shown so we can keep it mounted.
  bool _hasBeenShown = false;

  /// True while the dismiss animation is playing so we can gate visibility.
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    // ── Show animation ──────────────────────────────────────────────────────
    _showController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _slideInAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _showController,
      // Slight overshoot feel — settles naturally like iOS player.
      curve: const Cubic(0.22, 1.0, 0.36, 1.0),
    ));

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _showController,
        // Fade-in completes well before the slide finishes.
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
      ),
    );

    // ── Dismiss animation ────────────────────────────────────────────────────
    _dismissController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // Slide down with an acceleration curve (feels purposeful, not sluggish).
    _slideOutAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, 1.0),
    ).animate(CurvedAnimation(
      parent: _dismissController,
      curve: const Cubic(0.55, 0.0, 1.0, 0.45),
    ));

    // Subtle vertical scale-down: player "shrinks inward" as it exits.
    _scaleOutAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(
        parent: _dismissController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeInCubic),
      ),
    );

    // Fade out accelerates toward the end for a crisp vanish.
    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _dismissController,
        curve: const Interval(0.35, 1.0, curve: Curves.easeIn),
      ),
    );

    _dismissController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() => _isDismissing = false);
          _dismissController.reset();
        }
      }
    });
  }

  @override
  void dispose() {
    _showController.dispose();
    _dismissController.dispose();
    super.dispose();
  }

  void _onPlayerVisibilityChanged(bool isVisible) {
    if (isVisible) {
      _hasBeenShown = true;
      _isDismissing = false;
      // Dismiss animation resets before the show starts.
      _dismissController.reset();
      FocusManager.instance.primaryFocus?.unfocus();
      _showController.forward(from: 0.0);
    } else {
      // Play the premium dismiss animation.
      setState(() => _isDismissing = true);
      _showController.reset();
      _dismissController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PlayerOverlayCubit, bool>(
      listener: (context, isVisible) {
        _onPlayerVisibilityChanged(isVisible);
      },
      child: Stack(
        children: [
          // Main content (always visible).
          widget.child,

          // Player overlay — once shown, stays mounted for instant reopening.
          BlocBuilder<PlayerOverlayCubit, bool>(
            buildWhen: (previous, current) {
              // Only rebuild to first-mount the player widget.
              // After that, animations drive visibility — no rebuilds needed.
              return !_hasBeenShown && current;
            },
            builder: (context, isVisible) {
              if (!_hasBeenShown && !isVisible) {
                return const SizedBox.shrink();
              }

              if (isVisible && !_hasBeenShown) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _hasBeenShown = true);
                });
              }

              return AnimatedBuilder(
                animation: Listenable.merge([_showController, _dismissController]),
                builder: (context, child) {
                  // Visible while showing OR while dismissing.
                  final isShowVisible = _showController.value > 0;
                  final visible = isShowVisible || _isDismissing;

                  // During dismiss: apply the collapse transform stack.
                  // During show: apply the slide-in + fade-in.
                  if (_isDismissing) {
                    return Visibility(
                      visible: visible,
                      maintainState: true,
                      child: FadeTransition(
                        opacity: _fadeOutAnimation,
                        child: SlideTransition(
                          position: _slideOutAnimation,
                          child: ScaleTransition(
                            scale: _scaleOutAnimation,
                            alignment: Alignment.bottomCenter,
                            child: child!,
                          ),
                        ),
                      ),
                    );
                  }

                  return Visibility(
                    visible: visible,
                    maintainState: true,
                    child: SlideTransition(
                      position: _slideInAnimation,
                      child: FadeTransition(
                        opacity: _fadeInAnimation,
                        child: child!,
                      ),
                    ),
                  );
                },
                child: const _PersistentPlayerView(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The persistent player view that stays mounted.
class _PersistentPlayerView extends StatelessWidget {
  const _PersistentPlayerView();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Colors.transparent,
      child: AudioPlayerView(),
    );
  }
}
