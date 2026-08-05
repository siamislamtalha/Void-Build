import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:voidmusic/blocs/player_overlay/player_overlay_cubit.dart';
import 'package:voidmusic/blocs/mini_player/mini_player_cubit.dart';
import 'package:voidmusic/blocs/timer/timer_bloc.dart';
import 'package:voidmusic/screens/widgets/player_overlay_wrapper.dart';
import 'package:voidmusic/screens/widgets/mini_player_widget.dart';
import 'package:voidmusic/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:flutter/rendering.dart';
import 'package:native_glass_navbar/native_glass_navbar.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart' as lgr;

// ─── Collapse animation ──────────────────────────────────────────────────────
// Matches the Apple Music iOS 26 reference exactly.
// Longer duration + easeInOutQuart gives a noticeably smoother morph.
const Duration _kCollapseAnimDuration = Duration(milliseconds: 500);
const Curve _kCollapseAnimCurve = Curves.easeInOutQuart;

// ─── Layout constants ────────────────────────────────────────────────────────
// Heights of the floating overlay elements (in logical pixels).
// Mini player card height (64) + vertical padding (4+4) = 72.
// SizedBox gap between mini player and nav bar = 6.
// Nav bar item circle height + vertical padding = 56 + 5 + 5 = 66.
// Outer bottom padding on the Column = 6.
// Mobile total WITH mini player = 72 + 6 + 66 + 6 = 150.
// Mobile total WITHOUT mini player = 0 + 66 + 6 = 72.
// Desktop: mini player in footer connected to sidebar (no nav bar, no sidebar mini player).
const double _kMiniPlayerHeight = 72.0; // card(64) + vertical padding(4+4)
const double _kMiniPlayerGap = 6.0; // gap between mini player and nav bar
const double _kNavBarFooterHeight = 72.0; // gap(6) + navBar(66)
const double _kOuterBottomPadding = 6.0;
// Width of the desktop sidebar (including its border).
const double _kDesktopSidebarWidth = 80.0;

// Mobile footer element sizes
const double _kNavBarH = 58.0; // height of the nav bar capsule
const double _kSearchCircleW = 58.0; // width = height of the search circle
const double _kPillGap = 10.0; // gap between left pill and search circle
const double _kFooterHPad = 12.0; // horizontal padding for the whole footer

class GlobalFooter extends StatefulWidget {
  const GlobalFooter({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  State<GlobalFooter> createState() => _GlobalFooterState();
}

class _GlobalFooterState extends State<GlobalFooter>
    with SingleTickerProviderStateMixin {
  /// true when the active scroll view has been pulled down past 50 px.
  /// Only used on mobile — drives the collapse animation on the footer pills.
  bool _isMiniMode = false;

  /// Debounce timer — prevents rapid scroll direction changes from jittering.
  Timer? _debounceTimer;

  /// Set true by [UserScrollNotification]; false when scroll goes idle.
  /// Filters out programmatic animateTo() calls (billboard, carousel, etc.)
  /// so only genuine user gestures trigger the footer collapse.
  bool _userScrollActive = false;

  /// Single animation controller driving the entire collapse morph.
  /// All child measurements derive from [_collapseAnimation.value] inside
  /// [AnimatedBuilder], so nav capsule width, mini-player position, and
  /// opacity fades are perfectly in sync — no independent timers that drift.
  late final AnimationController _collapseController;
  late final Animation<double> _collapseAnimation;

  @override
  void initState() {
    super.initState();
    _collapseController = AnimationController(
      vsync: this,
      duration: _kCollapseAnimDuration,
    );
    _collapseAnimation = CurvedAnimation(
      parent: _collapseController,
      curve: _kCollapseAnimCurve,
    );
    // Register the shell-navigation callback so the full-screen player's
    // down-arrow button can return the user to the last visited tab.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PlayerOverlayCubit>().registerNavigateToBranch(
              widget.navigationShell.goBranch,
            );
      }
    });
  }

  @override
  void didUpdateWidget(GlobalFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-register if the shell instance changes.
    if (oldWidget.navigationShell != widget.navigationShell) {
      context.read<PlayerOverlayCubit>().registerNavigateToBranch(
            widget.navigationShell.goBranch,
          );
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _collapseController.dispose();
    context.read<PlayerOverlayCubit>().unregisterNavigateToBranch();
    super.dispose();
  }

  /// Called by the collapsed nav pill to expand the footer back.
  /// Reverses the animation controller; [_onScrollNotification] will confirm
  /// [_isMiniMode = false] once the user scrolls back up past the 25 px mark.
  void _expandFooter() {
    if (!mounted) return;
    _debounceTimer?.cancel();
    setState(() => _isMiniMode = false);
    _collapseController.reverse();
  }

  /// Intercepts [ScrollNotification]s that bubble up from any tab's scrollable.
  /// Returns false so notifications continue to propagate upward.
  ///
  /// Three-layer filter to only react to genuine user vertical scrolls:
  ///   1. **Axis filter** — ignores horizontal carousels / PageViews.
  ///   2. **[UserScrollNotification] gate** — this notification type is NEVER
  ///      fired by programmatic [ScrollController.animateTo] calls, so billboard
  ///      auto-scroll, carousel timers, and any other code-driven scroll is
  ///      completely transparent to the footer collapse logic.
  ///   3. **100 ms debounce** — only commits the new state after the scroll
  ///      direction has been stable for 100 ms, eliminating jitter on rapid
  ///      direction reversals without waiting for a full animation cycle.
  ///
  ///   Pixel hysteresis (collapse > 50 px, expand < 25 px) is preserved on
  ///   top of all three filters to prevent oscillation near the threshold.
  double _scrollDeltaAccum = 0.0;
  // ── Sweet-spot thresholds ────────────────────────────────────────────────
  // Collapse: 20 px of intentional downward scroll triggers shrink.
  // Expand  : 25 px of upward scroll anywhere on page triggers grow-back.
  // Expand is fractionally longer than shrink as requested.
  static const double _kCollapseDeltaThreshold = 20.0;
  static const double _kExpandDeltaThreshold = 25.0;

  bool _onScrollNotification(ScrollNotification notification) {
    final metrics = notification.metrics;

    if (metrics.axis != Axis.vertical) return false;

    if (notification is UserScrollNotification) {
      _userScrollActive = notification.direction != ScrollDirection.idle;
      if (!_userScrollActive) {
        _scrollDeltaAccum = 0.0;
      }
      return false;
    }

    if (notification is! ScrollUpdateNotification) return false;
    if (!_userScrollActive) return false;

    final double delta = notification.scrollDelta ?? 0.0;
    if (delta == 0.0) return false;

    // Reset accumulated delta if scroll direction reverses
    if ((delta > 0 && _scrollDeltaAccum < 0) ||
        (delta < 0 && _scrollDeltaAccum > 0)) {
      _scrollDeltaAccum = 0.0;
    }

    _scrollDeltaAccum += delta;

    bool? targetMini;
    if (!_isMiniMode && _scrollDeltaAccum > _kCollapseDeltaThreshold) {
      targetMini = true;
    } else if (_isMiniMode && _scrollDeltaAccum < -_kExpandDeltaThreshold) {
      targetMini = false;
    }

    if (targetMini == null || targetMini == _isMiniMode) {
      return false;
    }

    final bool shouldCollapse = targetMini;
    _scrollDeltaAccum = 0.0;
    _debounceTimer?.cancel();
    if (mounted) {
      setState(() => _isMiniMode = shouldCollapse);
      if (shouldCollapse) {
        _collapseController.forward();
      } else {
        _collapseController.reverse();
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<PlayerOverlayCubit>();
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return PlayerOverlayWrapper(
      child: BackButtonListener(
        onBackButtonPressed: () async {
          final overlayC = context.read<PlayerOverlayCubit>();
          final router = GoRouter.of(context);

          if (router.canPop()) {
            router.pop();
            return true;
          }

          if (overlayC.state && overlayC.collapseUpNextPanel()) {
            return true;
          }

          if (overlayC.state) {
            overlayC.minimizePlayer();
            return true;
          }

          return false;
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            await _handleHardwareBackPress(context);
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            // Force the system navigation bar to be fully transparent so
            // the glass footer can visually extend to the true screen edge.
            // statusBarBrightness is iOS-only and omitted here to avoid
            // conflicting with main.dart's SystemChrome call on Android.
            value: SystemUiOverlayStyle(
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarIconBrightness:
                  Theme.of(context).brightness == Brightness.dark
                      ? Brightness.light
                      : Brightness.dark,
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  Theme.of(context).brightness == Brightness.dark
                      ? Brightness.light
                      : Brightness.dark,
            ),
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              drawerScrimColor: Colors.transparent,
              // extendBody=true allows the body ScrollView to paint under the
              // floating footer so content scrolls behind the glassmorphic blur.
              extendBody: true,
              extendBodyBehindAppBar: true,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Layer 1: Main navigation body ───────────────────────
                  // NotificationListener intercepts scroll events from any
                  // active tab without touching individual screens.
                  // On desktop it is a no-op (returns false always).
                  NotificationListener<ScrollNotification>(
                    onNotification:
                        isMobile ? _onScrollNotification : (_) => false,
                    child: _FooterAwareBody(
                      isMobile: isMobile,
                      navigationShell: widget.navigationShell,
                    ),
                  ),
                  // ── Layer 2: Full-screen loading overlay (Muzo-exact) ───
                  // Shown when the mini-player engine is loading/buffering.
                  // Sits above page content but below all floating pills.
                  _buildLoadingOverlay(context),
                  // ── Layer 3: Floating footer overlay ────────────────────
                  // Fixed position at bottom to prevent subtle movement
                  // Using Transform.translate for absolute positioning
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Transform.translate(
                      offset: Offset.zero,
                      child: _GlassFooterOverlay(
                        isMobile: isMobile,
                        isMiniMode: _isMiniMode,
                        collapseAnimation: _collapseAnimation,
                        navigationShell: widget.navigationShell,
                        onExpandFooter: _expandFooter,
                      ),
                    ),
                  ),
                  // ── Layer 5: Floating sleep timer chip (Muzo-exact) ─────
                  // Draggable glassmorphic chip shown only when timer is
                  // running. Sits above everything, including the nav pill.
                  const _FloatingSleepTimer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // LAYER 2 — LOADING OVERLAY (Muzo-exact)
  // Muzo: ValueListenableBuilder on isLoadingStream + isLoadingNotifier.
  // Void:  BlocBuilder on MiniPlayerCubit.isLoading (same semantic signal).
  // Shows a semi-transparent scrim + white spinner while audio is loading.
  // Returns SizedBox.shrink() when idle so the overlay has zero paint cost.
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildLoadingOverlay(BuildContext context) {
    return BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
      builder: (context, miniState) {
        if (!miniState.isLoading && !miniState.isResolving) {
          return const SizedBox.shrink();
        }
        return Container(
          color: Theme.of(context)
              .scaffoldBackgroundColor
              .withValues(alpha: 0.5),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      },
    );
  }

  Future<void> _handleHardwareBackPress(BuildContext context) async {
    final overlayC = context.read<PlayerOverlayCubit>();
    final router = GoRouter.of(context);

    if (router.canPop()) {
      router.pop();
      return;
    }

    if (overlayC.state && overlayC.collapseUpNextPanel()) return;

    if (overlayC.state) {
      overlayC.minimizePlayer();
      return;
    }

    if (widget.navigationShell.currentIndex != 0) {
      widget.navigationShell.goBranch(0);
      return;
    }

    if (context.mounted) {
      await SystemNavigator.pop();
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────────
// LAYER 5 — FLOATING SLEEP TIMER CHIP (Muzo-exact)
// ───────────────────────────────────────────────────────────────────────────────

/// Muzo-exact draggable sleep-timer chip.
///
/// Glass recipe: blur 8×8, black@0.55 / white@0.70, border 0.5 px.
/// Shown only while [TimerBloc] is in [TimerRunInProgress] state.
/// User can drag it anywhere on-screen; position is clamped to stay visible.
/// Tapping the chip opens [TimerView] via the Settings tab (branch 3).
/// Tapping ✕ cancels the timer (emits [TimerStopped]).
class _FloatingSleepTimer extends StatefulWidget {
  const _FloatingSleepTimer();

  @override
  State<_FloatingSleepTimer> createState() => _FloatingSleepTimerState();
}

class _FloatingSleepTimerState extends State<_FloatingSleepTimer> {
  // Initial position matches Muzo: Offset(20, 100).
  Offset _position = const Offset(20, 100);

  /// Formats seconds into MM:SS or H:MM:SS, same as Muzo.
  String _formatDuration(int totalSeconds) {
    final d = Duration(seconds: totalSeconds);
    final minutes =
        d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimerBloc, TimerState>(
      builder: (context, timerState) {
        // Only show the chip while the timer is actively counting down.
        if (timerState is! TimerRunInProgress) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final screenSize = MediaQuery.of(context).size;

        // Muzo-exact: clamp position to screen bounds so chip never goes off-screen.
        final clampedX = _position.dx.clamp(0.0, screenSize.width - 140);
        final clampedY = _position.dy.clamp(
          MediaQuery.of(context).padding.top + 8,
          screenSize.height - 200,
        );

        return Positioned(
          left: clampedX,
          top: clampedY,
          child: GestureDetector(
            // Dragging updates position in real-time (Muzo-exact).
            onPanUpdate: (details) {
              setState(() {
                _position = Offset(
                  _position.dx + details.delta.dx,
                  _position.dy + details.delta.dy,
                );
              });
            },
            // Tap chip body → nothing (Muzo opens SleepTimerDialog;
            // Void's dialog lives in Settings > timer_view which the user
            // navigates to naturally. No tap action keeps it non-blocking).
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                // Muzo-exact: blur 8×8 (softer than the nav pill).
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    // Muzo-exact fill: black@0.55 dark / white@0.70 light
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(24),
                    // Muzo-exact border: 0.5 px, white/black @ 0.12
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.12),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Muzo-exact: timer_24_filled icon, size 18
                      Icon(
                        MingCute.alarm_2_fill,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      // Muzo-exact: fontSize 15, w700, tabular figures
                      Text(
                        _formatDuration(timerState.duration),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Muzo-exact: dismiss_circle icon, size 18, opacity 0.4
                      GestureDetector(
                        onTap: () {
                          context
                              .read<TimerBloc>()
                              .add(const TimerStopped());
                        },
                        child: Icon(
                          MingCute.close_circle_fill,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
// Injects extra bottom padding into MediaQuery so scrollable children
// automatically add bottom padding to avoid content being hidden behind
// the floating footer. Unchanged from original.
// ─────────────────────────────────────────────────────────────────────────────

class _FooterAwareBody extends StatelessWidget {
  const _FooterAwareBody({
    required this.isMobile,
    required this.navigationShell,
  });

  final bool isMobile;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
      builder: (context, miniState) {
        final mq = MediaQuery.of(context);
        final hasMiniPlayer = miniState.isVisible;

        // Calculate dynamic footer height:
        // Nav bar (mobile only) + optional mini player
        // On desktop mini player is in footer only (no sidebar mini player)
        double footerExtra = _kOuterBottomPadding;
        if (isMobile) footerExtra += _kNavBarFooterHeight;
        if (hasMiniPlayer) footerExtra += _kMiniPlayerHeight + _kMiniPlayerGap;

        // Inject footer height into MediaQuery so scrollable children
        // automatically add bottom padding to avoid content being hidden
        // behind the floating footer. We add it to viewPadding.bottom so
        // that screens using SafeArea or MediaQuery.padding.bottom
        // see the correct safe area.
        final updatedMq = mq.copyWith(
          padding: mq.padding.copyWith(
            bottom: (mq.padding.bottom + footerExtra)
                .clamp(0.0, double.infinity),
          ),
          viewPadding: mq.viewPadding.copyWith(
            bottom: (mq.viewPadding.bottom + footerExtra)
                .clamp(0.0, double.infinity),
          ),
        );

        final body = isMobile
            ? _AnimatedPageView(navigationShell: navigationShell)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sidebar navigation
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: VerticalNavBar(navigationShell: navigationShell),
                  ),
                  Expanded(
                    child: _AnimatedPageView(navigationShell: navigationShell),
                  ),
                ],
              );

        return MediaQuery(data: updatedMq, child: body);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS FOOTER OVERLAY
// ─────────────────────────────────────────────────────────────────────────────

/// Renders the glass footer overlay (mini player + nav bar).
///
/// **Mobile collapse architecture** (iOS 26 / Apple Music reference):
///
///   A single [AnimationController] in [_GlobalFooterState] drives
///   [collapseAnimation] (0.0 = expanded, 1.0 = collapsed). Every measurement
///   is derived from the same `t` value inside [AnimatedBuilder], so the nav
///   capsule width, mini-player position, and opacity cross-fades are all
///   perfectly in sync — no independent [AnimatedContainer] / [AnimatedPositioned]
///   timers that can drift apart.
///
///   On scroll (> 50 px), controller runs forward (0 → 1):
///   • Nav capsule right-edge moves in; left-edge stays fixed.
///   • Mini player drops to nav-bar level + narrows to fill the gap.
///   • Nav-item labels fade out first; collapsed icon fades in after.
///
///   On scroll back (< 25 px), controller reverses (1 → 0).
class _GlassFooterOverlay extends StatelessWidget {
  const _GlassFooterOverlay({
    required this.isMobile,
    required this.isMiniMode,
    required this.collapseAnimation,
    required this.navigationShell,
    this.onExpandFooter,
  });

  final bool isMobile;
  final bool isMiniMode;
  final Animation<double> collapseAnimation;
  final StatefulNavigationShell navigationShell;
  final VoidCallback? onExpandFooter;

  @override
  Widget build(BuildContext context) {
    // Bottom inset = device home indicator / gesture bar height.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isMobile) {
      // ── Desktop layout: mini player floating above content ────────────────
      // Enhanced with liquid glass renderer for Muzo-like refraction and distortion
      return BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
        builder: (context, miniState) {
          if (!miniState.isVisible) return const SizedBox.shrink();

          return Padding(
            padding: EdgeInsets.only(
              left: _kDesktopSidebarWidth + 8.0,
              right: 8.0,
              bottom: bottomInset + _kOuterBottomPadding,
            ),
            child: SizedBox(
              height: 64,
              child: RepaintBoundary(
                child: lgr.LiquidGlassLayer(
                  settings: lgr.LiquidGlassSettings(
                    refractiveIndex: 1.28,
                    thickness: 35,
                    blur: 10,
                    saturation: 1.6,
                    lightIntensity: isDark ? 0.8 : 1.2,
                    ambientStrength: isDark ? 0.3 : 0.6,
                    lightAngle: math.pi / 4,
                    glassColor: isDark
                        ? Colors.black.withValues(alpha: 0.40)
                        : Colors.black.withValues(alpha: 0.50),
                  ),
                  child: lgr.LiquidGlassBlendGroup(
                    blend: 10,
                    child: lgr.LiquidGlass.grouped(
                      shape: const lgr.LiquidRoundedSuperellipse(borderRadius: 28),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
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
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.10)
                                    : Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white
                                      .withValues(alpha: isDark ? 0.15 : 0.25),
                                  width: 0.75,
                                ),
                              ),
                              child: MiniPlayerWidget(
                                currentPageIndex: navigationShell.currentIndex,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    // ── Mobile: animated collapse Stack layout with liquid glass ─────────────
    return BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
      builder: (context, miniState) {
        final hasMiniPlayer = miniState.isVisible;

        // Collapse only when a track is playing AND the user has scrolled down.
        final bool isCollapsed = isMiniMode && hasMiniPlayer;

        // ── Absolute positions (pixels from the bottom of the SizedBox) ──────
        // The SizedBox bottom edge == the screen bottom edge (Positioned bottom:0).
        final double navBottomAbs = bottomInset + _kOuterBottomPadding;

        // Mini-player positions
        final double miniNormalBottom =
            navBottomAbs + _kNavBarH + _kMiniPlayerGap;

        final double miniBottom = isCollapsed ? navBottomAbs : miniNormalBottom;

        // In collapsed mode the mini player is sandwiched between the two circles.
        final double miniLeft = isCollapsed
            ? _kFooterHPad + _kSearchCircleW + _kPillGap
            : _kFooterHPad;
        final double miniRight = isCollapsed
            ? _kFooterHPad + _kSearchCircleW + _kPillGap
            : _kFooterHPad;

        // Height matches nav bar when collapsed; full card+padding otherwise.
        final double miniHeight =
            isCollapsed ? _kNavBarH : _kMiniPlayerHeight;

        // SizedBox height always allocates the maximum possible height to
        // prevent the Positioned wrapper from triggering layout re-flows when
        // mini player appears / disappears.
        final double sizedBoxH = navBottomAbs +
            _kNavBarH +
            (hasMiniPlayer ? _kMiniPlayerGap + _kMiniPlayerHeight : 0.0);



        // ── Reference-exact: LiquidGlassLayer & NativeGlassNavBar Integration ──
        // Enhanced liquid glass settings to match native_glass_navbar reference
        // with proper liquid glass refraction, distortion, and raised effect
        final activeAccentColor = AppTheme.accentColor(context);
        final l10n = AppLocalizations.of(context)!;

        // Map branch index to native navbar item index (excluding search which is action button)
        int mappedNativeIndex = 0;
        if (navigationShell.currentIndex == 1) mappedNativeIndex = 1;
        if (navigationShell.currentIndex == 3) mappedNativeIndex = 2;
        if (navigationShell.currentIndex == 4) mappedNativeIndex = 3;

        final customFallbackNav = SizedBox(
          height: sizedBoxH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Liquid Glass Footer - Reference Exact Settings ─────────────
              Positioned(
                left: _kFooterHPad,
                right: _kFooterHPad,
                bottom: navBottomAbs,
                height: _kNavBarH,
                child: lgr.LiquidGlassLayer(
                  settings: lgr.LiquidGlassSettings(
                    // Enhanced refraction for liquid glass effect
                    refractiveIndex: 1.52,
                    thickness: 40,
                    blur: 12,
                    saturation: 1.8,
                    // Dynamic lighting for raised liquid effect
                    lightIntensity: isDark ? 0.9 : 1.3,
                    ambientStrength: isDark ? 0.4 : 0.7,
                    lightAngle: math.pi / 3.5,
                    // Glass color matching reference
                    glassColor: isDark
                        ? Colors.black.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.45),
                  ),
                  child: lgr.LiquidGlassBlendGroup(
                    blend: 15,
                    child: Row(
                      children: [
                        // ── Main Long Pill (Navigation Items) ─────────────────────
                        AnimatedContainer(
                          duration: _kCollapseAnimDuration,
                          curve: _kCollapseAnimCurve,
                          width: isCollapsed ? _kSearchCircleW : double.infinity,
                          child: Transform.translate(
                            offset: Offset(0, isCollapsed ? -2 : 0), // Slight rise when collapsed
                            child: lgr.LiquidGlass.grouped(
                              clipBehavior: Clip.none,
                              shape: const lgr.LiquidRoundedSuperellipse(borderRadius: 32),
                              child: _LiquidGlassNavPillContent(
                                navigationShell: navigationShell,
                                isMiniMode: isCollapsed,
                                onTapCollapsed: () {
                                  HapticFeedback.selectionClick();
                                  onExpandFooter?.call();
                                },
                              ),
                            ),
                          ),
                        ),
                        // ── Gap between pills with liquid merge effect ───────────────
                        // Small point that merges and demerges with search circle (reference exact)
                        AnimatedContainer(
                          duration: _kCollapseAnimDuration,
                          curve: _kCollapseAnimCurve,
                          width: isCollapsed ? 0 : _kPillGap,
                          child: AnimatedOpacity(
                            duration: _kCollapseAnimDuration,
                            curve: _kCollapseAnimCurve,
                            opacity: isCollapsed ? 0.0 : 1.0,
                            child: Center(
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: isDark ? 0.25 : 0.15),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // ── Search Circle Pill (Action Button) ─────────────────────
                        AnimatedOpacity(
                          duration: _kCollapseAnimDuration,
                          curve: _kCollapseAnimCurve,
                          opacity: isCollapsed ? 0.0 : 1.0,
                          child: IgnorePointer(
                            ignoring: isCollapsed,
                            child: Transform.translate(
                              offset: Offset(0, isCollapsed ? -2 : 0), // Slight rise when collapsed
                              child: lgr.LiquidGlass.grouped(
                                clipBehavior: Clip.none,
                                shape: const lgr.LiquidRoundedSuperellipse(borderRadius: 32),
                                child: _LiquidGlassSearchCircle(
                                  navigationShell: navigationShell,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Mini player ────────────────────────────────────────────
              if (hasMiniPlayer)
                AnimatedPositioned(
                  duration: _kCollapseAnimDuration,
                  curve: _kCollapseAnimCurve,
                  left: miniLeft,
                  right: miniRight,
                  bottom: miniBottom,
                  height: miniHeight,
                  child: RepaintBoundary(
                    child: MiniPlayerWidget(
                      currentPageIndex: navigationShell.currentIndex,
                      isCompact: isCollapsed,
                    ),
                  ),
                ),
            ],
          ),
        );

        return NativeGlassNavBar(
          tabs: [
            NativeGlassNavBarItem(label: l10n.navHome, symbol: 'house.fill'),
            NativeGlassNavBarItem(label: l10n.navLibrary, symbol: 'books.vertical.fill'),
            NativeGlassNavBarItem(label: l10n.navLocal, symbol: 'music.note'),
            NativeGlassNavBarItem(label: l10n.navOffline, symbol: 'arrow.down.circle.fill'),
          ],
          actionButton: TabBarActionButton(
            symbol: 'magnifyingglass',
            onTap: () {
              HapticFeedback.lightImpact();
              navigationShell.goBranch(2);
            },
          ),
          currentIndex: mappedNativeIndex,
          onTap: (index) {
            final branchTargets = [0, 1, 3, 4];
            if (index >= 0 && index < branchTargets.length) {
              HapticFeedback.selectionClick();
              navigationShell.goBranch(branchTargets[index]);
            }
          },
          tintColor: activeAccentColor,
          fallback: customFallbackNav,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OLD COLLAPSIBLE NAV CAPSULE (Removed - replaced with liquid glass implementation)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED PAGE VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedPageView extends StatefulWidget {
  const _AnimatedPageView({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  State<_AnimatedPageView> createState() => _AnimatedPageViewState();
}

class _AnimatedPageViewState extends State<_AnimatedPageView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.navigationShell.currentIndex;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(_AnimatedPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex != _previousIndex) {
      _previousIndex = widget.navigationShell.currentIndex;
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.navigationShell,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────

/// Full-height desktop sidebar that contains the navigation rail.
/// It appears as one continuous frosted-glass bar from the very top to the
/// very bottom of the screen, matching the aesthetic of the header.
class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final inactiveColor =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF66666E);

    final glassColor = AppTheme.glassColor(context);
    final glassBorder = AppTheme.glassBorder(context);

    // Right-side border only — the sidebar is flush against the left edge.
    final borderColor = glassBorder;

    return Container(
      width: _kDesktopSidebarWidth,
      decoration: BoxDecoration(
        color: glassColor,
        border: Border(
          right: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: NavigationRail(
        backgroundColor: Colors.transparent,
        destinations: [
          NavigationRailDestination(
              icon: const Icon(MingCute.home_4_fill),
              label: Text(l10n.navHome)),
          NavigationRailDestination(
              icon: const Icon(MingCute.book_5_fill),
              label: Text(l10n.navLibrary)),
          NavigationRailDestination(
              icon: const Icon(MingCute.search_2_fill),
              label: Text(l10n.navSearch)),
          NavigationRailDestination(
              icon: const Icon(MingCute.music_2_fill),
              label: Text(l10n.navLocal)),
          NavigationRailDestination(
              icon: const Icon(MingCute.folder_download_fill),
              label: Text(l10n.navOffline)),
        ],
        selectedIndex: navigationShell.currentIndex,
        minWidth: _kDesktopSidebarWidth,
        onDestinationSelected: navigationShell.goBranch,
        groupAlignment: 0.0,
        selectedIconTheme: IconThemeData(color: activeColor),
        unselectedIconTheme: IconThemeData(color: inactiveColor),
        indicatorColor: isDark
            ? Colors.white.withValues(alpha: 0.2)
            : const Color(0xFF1C1C1E).withValues(alpha: 0.08),
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VERTICAL NAV BAR (backward-compat alias)
// ─────────────────────────────────────────────────────────────────────────────

/// Kept for backward-compat but no longer used on desktop.
class VerticalNavBar extends StatelessWidget {
  const VerticalNavBar({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) =>
      DesktopSidebar(navigationShell: navigationShell);
}

// ─────────────────────────────────────────────────────────────────────────────
// HORIZONTAL NAV BAR (preserved for backward-compat / external references)
// ─────────────────────────────────────────────────────────────────────────────

/// Original horizontal nav bar widget.
/// No longer used in the mobile footer path — the mobile footer now uses the
/// animated [_CollapsibleNavCapsule] + [_SearchCircleButton] Stack layout.
/// Preserved here so any external code that references [HorizontalNavBar]
/// continues to compile unchanged.
class HorizontalNavBar extends StatelessWidget {
  const HorizontalNavBar({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentIndex = navigationShell.currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeAccentColor = AppTheme.accentColor(context);
    final inactiveIconColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF1C1C1E).withValues(alpha: 0.85);

    final selectedPillColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.06);
    final selectedPillBorder = isDark
        ? Colors.white.withValues(alpha: 0.26)
        : Colors.black.withValues(alpha: 0.12);

    final capsuleItems = [
      _NavItemData(
          branchIndex: 0, icon: MingCute.home_4_fill, label: l10n.navHome),
      _NavItemData(
          branchIndex: 1, icon: MingCute.book_5_fill, label: l10n.navLibrary),
      _NavItemData(
          branchIndex: 3, icon: MingCute.music_2_fill, label: l10n.navLocal),
      _NavItemData(
          branchIndex: 4,
          icon: MingCute.folder_download_fill,
          label: l10n.navOffline),
    ];

    final isSearchSelected = currentIndex == 2;

    return Row(
      children: [
        // ── Main Left Nav Capsule (Home, Library, Local, Offline) ──
        Expanded(
          child: lgr.LiquidGlass.withOwnLayer(
            settings: const lgr.LiquidGlassSettings(
              blur: 4,
              ambientStrength: 2,
              lightAngle: 0.4 * math.pi,
              glassColor: Colors.black12,
              thickness: 30,
            ),
            shape: const lgr.LiquidRoundedSuperellipse(
              borderRadius: 40,
            ),
            glassContainsChild: false,
            child: SizedBox(
              height: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: capsuleItems.map((item) {
                    final isSelected = currentIndex == item.branchIndex;
                    return _NavItemButton(
                      item: item,
                      isSelected: isSelected,
                      activeColor: activeAccentColor,
                      inactiveColor: inactiveIconColor,
                      selectedPillColor: selectedPillColor,
                      selectedPillBorder: selectedPillBorder,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        navigationShell.goBranch(item.branchIndex);
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // ── Separate Right Floating Circle Button (Branch 2) ──
        // Exact profile-circle structure from liquid_glass_demo dashboard_page.dart:
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            navigationShell.goBranch(2);
          },
          behavior: HitTestBehavior.opaque,
          child: Hero(
            tag: 'profile_button',
            child: Material(
              type: MaterialType.transparency,
              child: lgr.LiquidGlass.withOwnLayer(
                settings: const lgr.LiquidGlassSettings(
                  blur: 3,
                  ambientStrength: 0.5,
                  lightAngle: 0.2 * math.pi,
                  glassColor: Colors.white12,
                ),
                shape: const lgr.LiquidRoundedSuperellipse(
                  borderRadius: 40,
                ),
                glassContainsChild: false,
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Icon(
                        MingCute.search_2_line,
                        size: 24,
                        color: isSearchSelected
                            ? activeAccentColor
                            : inactiveIconColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED NAV ITEM BUTTON
// ─────────────────────────────────────────────────────────────────────────────

/// Individual nav item with its own oval-pill glass background (matching the
/// desired reference image — wider than tall, like a stadium capsule).
/// Long-press shows a Muzo-style GlassChip with jello physics from liquid_glass_widgets.
class _NavItemButton extends StatefulWidget {
  final _NavItemData item;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final Color selectedPillColor;
  final Color selectedPillBorder;
  final VoidCallback onTap;

  const _NavItemButton({
    required this.item,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.selectedPillColor,
    required this.selectedPillBorder,
    required this.onTap,
  });

  @override
  State<_NavItemButton> createState() => _NavItemButtonState();
}

class _NavItemButtonState extends State<_NavItemButton>
    with SingleTickerProviderStateMixin {
  // Overlay entry for the Muzo-style long-press GlassChip
  OverlayEntry? _chipOverlay;
  Timer? _chipDismissTimer;

  // Bounce/jello animation controller for the chip appearance
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Elastic bounce curve — jello effect like Muzo
    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _chipDismissTimer?.cancel();
    _removeChipOverlay();
    _bounceController.dispose();
    super.dispose();
  }

  void _removeChipOverlay() {
    _chipOverlay?.remove();
    _chipOverlay = null;
  }

  void _showGlassChip(BuildContext context) {
    HapticFeedback.mediumImpact();
    _removeChipOverlay();
    _chipDismissTimer?.cancel();

    // Find the render box of this button to position the chip above it
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Offset globalPos = box.localToGlobal(Offset.zero);
    final Size boxSize = box.size;

    // Chip appears centered above the icon
    final double chipLeft = globalPos.dx + boxSize.width / 2 - 60;
    final double chipBottom = MediaQuery.of(context).size.height - globalPos.dy + 8;

    _bounceController.forward(from: 0.0);

    _chipOverlay = OverlayEntry(
      builder: (overlayContext) => Positioned(
        left: chipLeft.clamp(8.0, MediaQuery.of(overlayContext).size.width - 128),
        bottom: chipBottom,
        child: AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (_, child) => Transform.scale(
            scale: _bounceAnimation.value,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
          // GlassChip from liquid_glass_widgets with jello stretch physics
          child: GlassChip(
            label: widget.item.label,
            icon: Icon(widget.item.icon, size: 16),
            useOwnLayer: true,
            quality: GlassQuality.standard,
            // Jello physics: high stretch + elastic scale
            interactionScale: 1.08,
            stretch: 0.6,
            glowRadius: 1.2,
            anchorStretch: true,
            settings: const LiquidGlassSettings(
              blur: 3,
              thickness: 28,
              refractiveIndex: 1.45,
              lightIntensity: 0.25,
              saturation: 1.1,
            ),
            onTap: () {
              _removeChipOverlay();
              widget.onTap();
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_chipOverlay!);

    // Auto-dismiss after 2.5 seconds (Muzo behaviour)
    _chipDismissTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _removeChipOverlay();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _removeChipOverlay();
        widget.onTap();
      },
      onLongPress: () => _showGlassChip(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        constraints: const BoxConstraints(minWidth: 58),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          // Muzo: RadialGradient glow when selected, nothing when not.
          gradient: widget.isSelected
              ? RadialGradient(
                  colors: [
                    widget.activeColor.withValues(alpha: 0.15),
                    widget.activeColor.withValues(alpha: 0.0),
                  ],
                  radius: 0.85,
                )
              : null,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.item.icon,
              size: 18,
              color: widget.isSelected ? widget.activeColor : widget.inactiveColor,
            ),
            const SizedBox(height: 0.5),
            Text(
              widget.item.label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 8.5,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.bold,
                color: widget.isSelected ? widget.activeColor : widget.inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIQUID GLASS NAV PILL (Main Navigation)
// ─────────────────────────────────────────────────────────────────────────────

class _LiquidGlassNavPillContent extends StatefulWidget {
  const _LiquidGlassNavPillContent({
    required this.navigationShell,
    required this.isMiniMode,
    required this.onTapCollapsed,
  });

  final StatefulNavigationShell navigationShell;
  final bool isMiniMode;
  final VoidCallback? onTapCollapsed;

  @override
  State<_LiquidGlassNavPillContent> createState() => _LiquidGlassNavPillContentState();
}

class _LiquidGlassNavPillContentState extends State<_LiquidGlassNavPillContent> {
  List<_NavItemData> get capsuleItems {
    final l10n = AppLocalizations.of(context)!;
    return [
        _NavItemData(
            branchIndex: 0, icon: MingCute.home_4_fill, label: l10n.navHome),
        _NavItemData(
            branchIndex: 1, icon: MingCute.book_5_fill, label: l10n.navLibrary),
        _NavItemData(
            branchIndex: 3, icon: MingCute.music_2_fill, label: l10n.navLocal),
        _NavItemData(
            branchIndex: 4,
            icon: MingCute.folder_download_fill,
            label: l10n.navOffline),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeAccentColor = AppTheme.accentColor(context);
    final inactiveIconColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF1C1C1E).withValues(alpha: 0.85);

    // Calculate which index is selected for the indicator
    final activeIndex = capsuleItems.indexWhere((item) => item.branchIndex == currentIndex);
    final isTabActive = activeIndex != -1;
    final activeItem = capsuleItems.firstWhere(
      (item) => item.branchIndex == currentIndex,
      orElse: () => capsuleItems[0],
    );

    return AnimatedContainer(
      duration: _kCollapseAnimDuration,
      curve: _kCollapseAnimCurve,
      width: widget.isMiniMode ? _kSearchCircleW : double.infinity,
      height: _kNavBarH,
      child: Stack(
        children: [
          // ── Expanded nav content ────────────────────────────────────────────
          AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            opacity: widget.isMiniMode ? 0.0 : 1.0,
            child: IgnorePointer(
              ignoring: widget.isMiniMode,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalW = constraints.maxWidth;
                  final itemCount = capsuleItems.length;
                  final itemW = itemCount > 0 ? totalW / itemCount : 0.0;
                  final indicatorW = math.max(0.0, itemW - 8.0);
                  final indicatorLeft = isTabActive ? (activeIndex * itemW) + 4.0 : 4.0;

                  return Stack(
                    children: [
                      // ── Animated Liquid Glass Selection Indicator Pill ──────
                      // Liquid glass component that raises a bit and slides smoothly between tabs
                      // Reference exact: Icon selector transparent glass that behaves like liquid and raises a bit
                      if (isTabActive)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutBack,
                          left: indicatorLeft,
                          top: 4,
                          width: indicatorW,
                          height: _kNavBarH - 8,
                              child: lgr.LiquidGlass.withOwnLayer(
                                settings: lgr.LiquidGlassSettings(
                                  // Enhanced liquid glass settings for raised icon selector
                                  refractiveIndex: 1.52,
                                  thickness: 40,
                                  blur: 12,
                                  saturation: 1.8,
                                  lightIntensity: isDark ? 0.9 : 1.3,
                                  ambientStrength: isDark ? 0.4 : 0.7,
                                  lightAngle: math.pi / 3.5,
                                  glassColor: isDark
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : Colors.black.withValues(alpha: 0.12),
                                ),
                                shape: const lgr.LiquidRoundedSuperellipse(
                                  borderRadius: 22,
                                ),
                                glassContainsChild: false,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: (isDark ? Colors.white : Colors.black)
                                          .withValues(alpha: isDark ? 0.35 : 0.20),
                                      width: 1.2,
                                    ),
                                    // Enhanced shadow for raised liquid glass effect
                                    boxShadow: [
                                      // Main shadow for depth
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: isDark ? 0.60 : 0.25,
                                        ),
                                        blurRadius: 20,
                                        spreadRadius: -4,
                                        offset: const Offset(0, 8),
                                      ),
                                      // Inner glow for liquid effect
                                      BoxShadow(
                                        color: (isDark ? Colors.white : Colors.black)
                                            .withValues(alpha: isDark ? 0.20 : 0.10),
                                        blurRadius: 12,
                                        spreadRadius: -3,
                                        offset: const Offset(0, -3),
                                      ),
                                      // Ambient glow
                                      BoxShadow(
                                        color: activeAccentColor.withValues(alpha: 0.15),
                                        blurRadius: 15,
                                        spreadRadius: -2,
                                        offset: Offset.zero,
                                      ),
                                    ],
                                  ),
                                ),
                          ),
                        ),

                      // ── Buttons Row ─────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        height: _kNavBarH,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            for (var i = 0; i < capsuleItems.length; i++)
                              Expanded(
                                child: _LiquidGlassNavItem(
                                  tab: capsuleItems[i],
                                  selected: currentIndex == capsuleItems[i].branchIndex,
                                  activeColor: activeAccentColor,
                                  inactiveColor: inactiveIconColor,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    widget.navigationShell.goBranch(capsuleItems[i].branchIndex);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // ── Collapsed single active icon ────────────────────────────────────
          AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            opacity: widget.isMiniMode ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !widget.isMiniMode,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onTapCollapsed?.call();
                  widget.navigationShell.goBranch(currentIndex);
                },
                behavior: HitTestBehavior.opaque,
                child: SizedBox.expand(
                  child: Center(
                    child: Icon(
                      activeItem.icon,
                      size: 24,
                      color: activeAccentColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidGlassNavItem extends StatelessWidget {
  const _LiquidGlassNavItem({
    required this.tab,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final _NavItemData tab;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: tab.label,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                transformAlignment: Alignment.center,
                curve: Curves.easeOutCirc,
                transform: selected
                    ? Matrix4.identity()
                    : (Matrix4.identity()
                      // ignore: deprecated_member_use
                        ..scale(0.9)),
                child: Icon(
                  tab.icon,
                  size: 20,
                  color: selected ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: selected ? 1.0 : 0.6,
                child: Text(
                  tab.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: selected ? activeColor : inactiveColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIQUID GLASS SEARCH CIRCLE (Action Button)
// ─────────────────────────────────────────────────────────────────────────────

class _LiquidGlassSearchCircle extends StatelessWidget {
  const _LiquidGlassSearchCircle({
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentIndex = navigationShell.currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSearchSelected = currentIndex == 2;
    final activeAccentColor = AppTheme.accentColor(context);

    return lgr.LiquidGlass.grouped(
      clipBehavior: Clip.none,
      shape: const lgr.LiquidRoundedSuperellipse(borderRadius: 32),
      child: lgr.LiquidGlassLayer(
        settings: lgr.LiquidGlassSettings(
          // Enhanced liquid glass settings for the search circle
          refractiveIndex: 1.52,
          thickness: 40,
          blur: 12,
          saturation: 1.8,
          lightIntensity: isDark ? 0.9 : 1.3,
          ambientStrength: isDark ? 0.4 : 0.7,
          lightAngle: math.pi / 3.5,
          glassColor: isDark
              ? Colors.black.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.45),
        ),
        child: lgr.LiquidGlassBlendGroup(
          blend: 15,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              navigationShell.goBranch(2);
            },
            behavior: HitTestBehavior.opaque,
            child: Semantics(
              button: true,
              label: l10n.navSearch,
              child: Container(
                width: _kSearchCircleW,
                height: _kNavBarH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: isSearchSelected
                      ? RadialGradient(
                          colors: [
                            activeAccentColor.withValues(alpha: 0.15),
                            activeAccentColor.withValues(alpha: 0.0),
                          ],
                          radius: 0.85,
                        )
                      : null,
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    transformAlignment: Alignment.center,
                    curve: Curves.easeOutCirc,
                    transform: isSearchSelected
                        ? Matrix4.identity()
                        : (Matrix4.identity()
                          // ignore: deprecated_member_use
                            ..scale(0.9)),
                    child: Icon(
                      MingCute.search_2_fill,
                      size: 22,
                      color: isSearchSelected ? activeAccentColor : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.85),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// NAV ITEM DATA
// ─────────────────────────────────────────────────────────────────────────────

class _NavItemData {
  final int branchIndex;
  final IconData icon;
  final String label;

  const _NavItemData({
    required this.branchIndex,
    required this.icon,
    required this.label,
  });
}
