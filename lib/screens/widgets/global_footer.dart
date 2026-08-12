import 'dart:async';
import 'dart:ui';
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
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:cupertino_native/cupertino_native.dart';
import 'package:motor/motor.dart';

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
// cupertino_native CNTabBar style:
//   LEFT  = small standalone search pill  (_kSearchPillW)
//   RIGHT = large nav pill (Home / Library / Offline / Local)
// This matches the pub.dev screenshot where the search pill sits on the
// left edge and the wider nav capsule fills the remaining width on the right.
const double _kNavBarH      = 58.0;
const double _kSearchPillW  = 58.0; // compact square-ish pill (matches screenshot)
const double _kPillGap      = 10.0; // horizontal gap between the two pills
const double _kFooterHPad   = 12.0; // outer horizontal padding

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
    // Match Muzo's desktop cutoff directly. The responsive-framework lookup
    // can classify a phone as desktop when the app is embedded in a window,
    // which suppresses the mobile footer entirely.
    final isMobile = MediaQuery.of(context).size.width <= 600;

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
                        FluentIcons.timer_24_filled,
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
                          FluentIcons.dismiss_circle_24_filled,
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
          );
        },
      );
    }

    // ── Mobile: animated collapse Stack layout with liquid glass ─────────────
    return BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
      builder: (context, miniState) {
        final hasMiniPlayer = miniState.isVisible;

        // Keep Void Music's legacy geometry, but use the existing expand/shrink
        // state. The previous implementation hard-coded this to false, which
        // made the long-press/collapsed glass affordance unreachable on mobile.
        final bool isCollapsed = isMiniMode;

        // ── Absolute positions (pixels from the bottom of the SizedBox) ──────
        // The SizedBox bottom edge == the screen bottom edge (Positioned bottom:0).
        final double navBottomAbs = bottomInset + _kOuterBottomPadding;

        // Mini-player positions
        final double miniNormalBottom =
            navBottomAbs + _kNavBarH + _kMiniPlayerGap;

        final double miniBottom = isCollapsed ? navBottomAbs : miniNormalBottom;

        // In collapsed mode the mini player is sandwiched between the two pills.
        // LEFT boundary = search pill (left edge) + search pill width + gap.
        // RIGHT boundary = collapsed nav circle (right edge) + circle width + gap.
        // Both pills are _kSearchPillW wide when collapsed, so geometry is symmetric.
        final double miniLeft = isCollapsed
            ? _kFooterHPad + _kSearchPillW + _kPillGap
            : _kFooterHPad;
        final double miniRight = isCollapsed
            ? _kFooterHPad + _kSearchPillW + _kPillGap
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

        // ── cupertino_native CNTabBar layout ─────────────────────────────
        // LEFT  = standalone search pill (_kSearchPillW), anchored to left edge.
        // RIGHT = large nav pill (Home / Library / Offline / Local), fills
        //         remaining width up to the right edge.
        // This matches the pub.dev CNTabBar screenshot exactly.
        final double screenW = MediaQuery.of(context).size.width;
        // Nav pill width = full width minus both outer pads, gap, and search pill.
        final double rightCapsuleFullW =
            screenW - _kFooterHPad * 2 - _kPillGap - _kSearchPillW;

        return SizedBox(
          height: sizedBoxH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
                // ── LEFT: standalone search pill ─────────────────────────
                // Anchored to the left edge; always visible, never animates.
                // Matches the single-icon search pill in the CNTabBar screenshot.
                Positioned(
                  left: _kFooterHPad,
                  bottom: navBottomAbs,
                  width: _kSearchPillW,
                  height: _kNavBarH,
                  child: _SearchPill(
                    navigationShell: navigationShell,
                  ),
                ),

                // ── RIGHT: collapsible nav capsule (Home|Library|Offline|Local)
                // Right-edge anchored at _kFooterHPad.
                // In mini-mode the capsule collapses to a single icon circle.
                Positioned(
                  right: _kFooterHPad,
                  bottom: navBottomAbs,
                  height: _kNavBarH,
                  child: _CollapsibleNavCapsule(
                    isMiniMode: isCollapsed,
                    navigationShell: navigationShell,
                    fullWidth: rightCapsuleFullW,
                    onTapCollapsed: () {
                      HapticFeedback.selectionClick();
                      onExpandFooter?.call();
                    },
                  ),
                ),

                // ── Mini player ────────────────────────────────────────────
                // Normal:    full-width pill floating above the nav bar.
                // Collapsed: narrow pill sandwiched between the two pills,
                //            left=searchPill+gap, right=collapsedNavCircle+gap.
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
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COLLAPSIBLE NAV CAPSULE (Muzo-exact Liquid Glass & Chromatic Aberration)
// ─────────────────────────────────────────────────────────────────────────────

/// Matrix transform for jelly squash and stretch physics
Matrix4 _buildJellyTransform({
  required Offset velocity,
  double maxDistortion = 0.7,
  double velocityScale = 1000.0,
}) {
  final speed = velocity.distance;
  final direction = speed > 0 ? velocity / speed : Offset.zero;
  final distortionFactor =
      (speed / velocityScale).clamp(0.0, 1.0) * maxDistortion;

  if (distortionFactor == 0) {
    return Matrix4.identity();
  }

  final squashX = 1.0 - (direction.dx.abs() * distortionFactor * 0.5);
  final squashY = 1.0 - (direction.dy.abs() * distortionFactor * 0.5);
  final stretchX = 1.0 + (direction.dy.abs() * distortionFactor * 0.3);
  final stretchY = 1.0 + (direction.dx.abs() * distortionFactor * 0.3);

  final scaleX = squashX * stretchX;
  final scaleY = squashY * stretchY;

  final matrix = Matrix4.identity();
  matrix.scaleByVector3(Vector3(scaleX, scaleY, 1.0));
  return matrix;
}

class _CollapsibleNavCapsule extends StatefulWidget {
  const _CollapsibleNavCapsule({
    required this.isMiniMode,
    required this.fullWidth,
    required this.navigationShell,
    this.onTapCollapsed,
  });

  final bool isMiniMode;
  final double fullWidth;
  final StatefulNavigationShell navigationShell;
  final VoidCallback? onTapCollapsed;

  @override
  State<_CollapsibleNavCapsule> createState() => _CollapsibleNavCapsuleState();
}

class _CollapsibleNavCapsuleState extends State<_CollapsibleNavCapsule>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _chipOverlay;
  Timer? _chipDismissTimer;

  @override
  void dispose() {
    _chipDismissTimer?.cancel();
    _chipOverlay?.remove();
    super.dispose();
  }

  void _removeSelectionChip() {
    _chipDismissTimer?.cancel();
    _chipOverlay?.remove();
    _chipOverlay = null;
  }

  void _showSelectionChip(BuildContext context, _NavItemData item) {
    _removeSelectionChip();
    HapticFeedback.mediumImpact();
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    final left = origin.dx + box.size.width / 2 - 64;
    final bottom = MediaQuery.of(context).size.height - origin.dy + 8;

    _chipOverlay = OverlayEntry(
      builder: (overlayContext) => Positioned(
        left: left.clamp(8.0, MediaQuery.of(overlayContext).size.width - 136),
        bottom: bottom,
        child: GlassChip(
          label: item.label,
          icon: Icon(item.icon, size: 16),
          useOwnLayer: true,
          quality: GlassQuality.standard,
          interactionScale: 1.08,
          stretch: 0.6,
          glowRadius: 1.2,
          anchorStretch: true,
          settings: const LiquidGlassSettings(
            blur: 3,
            thickness: 28,
            refractiveIndex: 1.45,
            lightIntensity: 0.18,
            ambientStrength: 0.18,
            saturation: 1.0,
            glassColor: Colors.transparent,
          ),
          onTap: _removeSelectionChip,
        ),
      ),
    );
    Overlay.of(context).insert(_chipOverlay!);
    _chipDismissTimer =
        Timer(const Duration(milliseconds: 2500), _removeSelectionChip);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentIndex = widget.navigationShell.currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeAccentColor = AppTheme.accentColor(context);

    // cupertino_native CNTabBar: 4-item nav pill — Search lives in its own
    // separate pill on the right, so it is intentionally excluded here.
    final items = [
      _NavItemData(
        branchIndex: 0,
        icon: FluentIcons.home_24_filled,
        label: l10n.navHome,
        symbol: const CNSymbol('house.fill'),
      ),
      _NavItemData(
        branchIndex: 1,
        icon: FluentIcons.library_24_filled,
        label: l10n.navLibrary,
        symbol: const CNSymbol('music.note.list'),
      ),
      _NavItemData(
        branchIndex: 4,
        icon: FluentIcons.arrow_download_24_filled,
        label: l10n.navOffline,
        symbol: const CNSymbol('arrow.down.circle.fill'),
      ),
      _NavItemData(
        branchIndex: 3,
        icon: MingCute.music_2_fill,
        label: l10n.navLocal,
        symbol: const CNSymbol('folder.fill'),
      ),
    ];

    final activeTabIndex = items.indexWhere((i) => i.branchIndex == currentIndex).clamp(0, items.length - 1);

    // ── Apple iOS 26 Liquid Glass reference settings ──────────────────────
    final glassSettings = LiquidGlassSettings(
      thickness: 32,
      blur: 4,
      chromaticAberration: 0.45,
      refractiveIndex: 1.68,
      saturation: 0.85,
      ambientStrength: 0.80,
      lightAngle: 0.75 * 3.141592653589793,
      lightIntensity: 0.85,
      glassColor: (isDark ? Colors.black : Colors.white)
          .withValues(alpha: isDark ? 0.35 : 0.52),
    );

    final pillShadow = BoxDecoration(
      borderRadius: BorderRadius.circular(29),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.14),
          blurRadius: 24,
          spreadRadius: -6,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
          blurRadius: 8,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ],
    );

    final surface = AnimatedContainer(
        duration: _kCollapseAnimDuration,
        curve: _kCollapseAnimCurve,
        // Collapses to a small circle (_kSearchPillW) matching the search pill width;
        // expands back to the full right-side capsule width.
        width: widget.isMiniMode ? _kSearchPillW : widget.fullWidth,
        height: _kNavBarH,
        decoration: pillShadow,
        child: widget.isMiniMode
            ? ClipRRect(
                borderRadius: BorderRadius.circular(29),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.black : Colors.white)
                          .withValues(alpha: isDark ? 0.25 : 0.42),
                      borderRadius: BorderRadius.circular(29),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: isDark ? 0.15 : 0.24,
                        ),
                        width: 0.75,
                      ),
                    ),
                    child: _CollapsedActiveIcon(
                      activeItem: items.firstWhere(
                          (item) => item.branchIndex == currentIndex,
                          orElse: () => items.first),
                      activeAccentColor: activeAccentColor,
                      onTap: widget.onTapCollapsed ?? () {},
                    ),
                  ),
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(29),
                child: LiquidGlassLayer(
                  settings: glassSettings,
                  child: LiquidGlassBlendGroup(
                    blend: 10,
                    child: AdaptiveGlass.grouped(
                      shape: const LiquidRoundedSuperellipse(borderRadius: 28),
                      child: Container(
                        height: _kNavBarH,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _TabIndicator(
                          tabIndex: activeTabIndex,
                          tabCount: items.length,
                          onTabChanged: (index) {
                            final targetBranch = items[index].branchIndex;
                            widget.navigationShell.goBranch(targetBranch);
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: items
                                .map(
                                  (item) => _MuzoNavItem(
                                    item: item,
                                    selected: currentIndex == item.branchIndex,
                                    onTap: () => widget.navigationShell
                                        .goBranch(item.branchIndex),
                                    onLongPress: () =>
                                        _showSelectionChip(context, item),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      );

    return surface;
  }
}

class _TabIndicator extends StatefulWidget {
  const _TabIndicator({
    required this.child,
    required this.tabIndex,
    required this.tabCount,
    required this.onTabChanged,
  });

  final int tabIndex;
  final int tabCount;
  final Widget child;
  final ValueChanged<int> onTabChanged;

  @override
  State<_TabIndicator> createState() => _TabIndicatorState();
}

class _TabIndicatorState extends State<_TabIndicator>
    with SingleTickerProviderStateMixin {
  bool _isDown = false;
  bool _isDragging = false;

  late double xAlign = computeXAlignmentForTab(widget.tabIndex);

  double computeXAlignmentForTab(int tabIndex) {
    final relativeTabIndex =
        (tabIndex / (widget.tabCount - 1)).clamp(0.0, 1.0);
    return (relativeTabIndex * 2) - 1; // -1 to 1
  }

  @override
  void didUpdateWidget(covariant _TabIndicator oldWidget) {
    if (oldWidget.tabIndex != widget.tabIndex ||
        oldWidget.tabCount != widget.tabCount) {
      setState(() {
        xAlign = computeXAlignmentForTab(widget.tabIndex);
      });
    }
    super.didUpdateWidget(oldWidget);
  }

  double _getAlignmentFromGlobalPosition(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return 0.0;
    final localPosition = box.globalToLocal(globalPosition);

    final indicatorWidth = 1.0 / widget.tabCount;
    final draggableRange = 1.0 - indicatorWidth;
    final padding = indicatorWidth / 2;

    final rawRelativeX = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
    final normalizedX = (rawRelativeX - padding) / draggableRange;

    final adjustedRelativeX = _applyRubberBandResistance(normalizedX);
    return (adjustedRelativeX * 2) - 1;
  }

  double _applyRubberBandResistance(double value) {
    const double resistance = 0.4;
    const double maxOverdrag = 0.3;

    if (value < 0) {
      final overdrag = -value;
      final resistedOverdrag = overdrag * resistance;
      return -resistedOverdrag.clamp(0.0, maxOverdrag);
    } else if (value > 1) {
      final overdrag = value - 1;
      final resistedOverdrag = overdrag * resistance;
      return 1 + resistedOverdrag.clamp(0.0, maxOverdrag);
    } else {
      return value;
    }
  }

  void _onDragDown(DragDownDetails details) {
    setState(() {
      _isDown = true;
      xAlign = _getAlignmentFromGlobalPosition(details.globalPosition);
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      xAlign = _getAlignmentFromGlobalPosition(details.globalPosition);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _isDown = false;
    });

    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final currentRelativeX = (xAlign + 1) / 2;
    final tabWidth = 1.0 / widget.tabCount;

    final indicatorWidth = 1.0 / widget.tabCount;
    final draggableRange = 1.0 - indicatorWidth;
    final velocityX =
        (details.velocity.pixelsPerSecond.dx / box.size.width) / draggableRange;

    int targetTabIndex;

    if (currentRelativeX < 0) {
      targetTabIndex = 0;
    } else if (currentRelativeX > 1) {
      targetTabIndex = widget.tabCount - 1;
    } else {
      const velocityThreshold = 0.5;
      if (velocityX.abs() > velocityThreshold) {
        final projectedX =
            (currentRelativeX + velocityX * 0.3).clamp(0.0, 1.0);
        targetTabIndex = (projectedX / tabWidth).round().clamp(
              0,
              widget.tabCount - 1,
            );

        final currentTabIndex =
            (currentRelativeX / tabWidth).round().clamp(
                  0,
                  widget.tabCount - 1,
                );
        if (velocityX > velocityThreshold &&
            targetTabIndex <= currentTabIndex &&
            currentTabIndex < widget.tabCount - 1) {
          targetTabIndex = currentTabIndex + 1;
        } else if (velocityX < -velocityThreshold &&
            targetTabIndex >= currentTabIndex &&
            currentTabIndex > 0) {
          targetTabIndex = currentTabIndex - 1;
        }
      } else {
        targetTabIndex = (currentRelativeX / tabWidth).round().clamp(
              0,
              widget.tabCount - 1,
            );
      }
    }
    xAlign = computeXAlignmentForTab(targetTabIndex);

    if (targetTabIndex != widget.tabIndex) {
      widget.onTabChanged(targetTabIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetAlignment = computeXAlignmentForTab(widget.tabIndex);

    return GestureDetector(
      onHorizontalDragDown: _onDragDown,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: () => setState(() {
        _isDragging = false;
        _isDown = false;
      }),
      child: VelocityMotionBuilder(
        converter: const SingleMotionConverter(),
        value: xAlign,
        motion: _isDragging
            ? const Motion.interactiveSpring(snapToEnd: true)
            : const Motion.bouncySpring(snapToEnd: true),
        builder: (context, value, velocity, child) {
          final alignment = Alignment(value, 0);
          return SingleMotionBuilder(
            motion: const Motion.snappySpring(
              snapToEnd: true,
              duration: Duration(milliseconds: 300),
            ),
            // Triggers dynamic appearance when dragging, swiping, or transitioning between tabs
            value: (_isDown || _isDragging || (alignment.x - targetAlignment).abs() > 0.04)
                ? 1.0
                : 0.0,
            builder: (context, thickness, child) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  _IndicatorTransform(
                    velocity: velocity,
                    tabCount: widget.tabCount,
                    alignment: alignment,
                    thickness: thickness,
                    child: AdaptiveGlass(
                      useOwnLayer: true,
                      settings: LiquidGlassSettings(
                        glassColor: (isDark ? Colors.white : Colors.white)
                            .withValues(alpha: isDark ? 0.28 : 0.45),
                        saturation: 1.5,
                        refractiveIndex: 1.45,
                        thickness: 24,
                        lightIntensity: 2.2,
                        chromaticAberration: 0.6,
                        blur: 0,
                      ),
                      shape: const LiquidRoundedSuperellipse(
                        borderRadius: 64,
                      ),
                      child: const GlassGlow(child: SizedBox.expand()),
                    ),
                  ),
                  child!,
                ],
              );
            },
            child: widget.child,
          );
        },
        child: widget.child,
      ),
    );
  }
}


class _IndicatorTransform extends StatelessWidget {
  const _IndicatorTransform({
    required this.velocity,
    required this.tabCount,
    required this.alignment,
    required this.thickness,
    required this.child,
  });

  final double velocity;
  final int tabCount;
  final Alignment alignment;
  final double thickness;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Apple iOS 26 dynamic gesture glass pill:
    // Lerps to a taller height (-14 top/bottom overflow) and narrower width (8 left/right padding)
    // when swiping/tapping, creating the "short in width but big in height" liquid glass morph.
    final rect = RelativeRect.lerp(
      RelativeRect.fill,
      const RelativeRect.fromLTRB(8, -14, 8, -14),
      thickness,
    );
    return Positioned.fill(
      left: 4,
      right: 4,
      top: 4,
      bottom: 4,
      child: FractionallySizedBox(
        widthFactor: 1 / tabCount,
        alignment: alignment,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fromRelativeRect(
              rect: rect!,
              child: Opacity(
                // Invisible when resting at a tab (thickness = 0.0); appears dynamically when swiping/tapping
                opacity: thickness.clamp(0.0, 1.0),
                child: SingleMotionBuilder(
                  motion: const Motion.bouncySpring(
                    duration: Duration(milliseconds: 600),
                  ),
                  value: velocity,
                  builder: (context, velocityVal, childWidget) {
                    return Transform(
                      alignment: Alignment.center,
                      transform: _buildJellyTransform(
                        velocity: Offset(velocityVal, 0),
                        maxDistortion: 0.8,
                        velocityScale: 10,
                      ),
                      child: childWidget,
                    );
                  },
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Nav capsule content ──────────────────────────────────────────────────────
/// Muzo's source-level tab treatment: quiet inactive tabs and a subtle radial
/// primary-color wash on the selected tab.
class _MuzoNavItem extends StatelessWidget {
  const _MuzoNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final _NavItemData item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final activeColor = Theme.of(context).primaryColor;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          onLongPress: onLongPress,
          child: SizedBox(
            height: 58,
            child: Center(
              child: AnimatedScale(
                // Apple iOS 26: unselected items scale down more noticeably (~92%)
                scale: selected ? 1.0 : 0.92,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  // Apple iOS 26: inactive icons at ~55% opacity for clear hierarchy
                  opacity: selected ? 1.0 : 0.55,
                  duration: const Duration(milliseconds: 180),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        color: selected ? activeColor : textColor,
                        size: selected ? 22 : 20,
                      ),
                      // ── Apple iOS 26: label ONLY for the selected tab ─────
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOutCubic,
                        child: selected
                            ? Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: activeColor,
                                    fontSize: 9,
                                    height: 1,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
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




class _CollapsedActiveIcon extends StatefulWidget {
  final _NavItemData activeItem;
  final Color activeAccentColor;
  final VoidCallback onTap;

  const _CollapsedActiveIcon({
    required this.activeItem,
    required this.activeAccentColor,
    required this.onTap,
  });

  @override
  State<_CollapsedActiveIcon> createState() => _CollapsedActiveIconState();
}

class _CollapsedActiveIconState extends State<_CollapsedActiveIcon>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _chipOverlay;
  Timer? _chipDismissTimer;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
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

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Offset globalPos = box.localToGlobal(Offset.zero);
    final Size boxSize = box.size;

    final double chipLeft = globalPos.dx + boxSize.width / 2 - 60;
    final double chipBottom =
        MediaQuery.of(context).size.height - globalPos.dy + 8;

    _bounceController.forward(from: 0.0);

    _chipOverlay = OverlayEntry(
      builder: (overlayContext) => Positioned(
        left: chipLeft.clamp(
            8.0, MediaQuery.of(overlayContext).size.width - 128),
        bottom: chipBottom,
        child: AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (_, child) => Transform.scale(
            scale: _bounceAnimation.value,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
          child: GlassChip(
            label: widget.activeItem.label,
            icon: Icon(widget.activeItem.icon, size: 16),
            useOwnLayer: true,
            quality: GlassQuality.standard,
            interactionScale: 1.08,
            stretch: 0.6,
            glowRadius: 1.2,
            anchorStretch: true,
            settings: const LiquidGlassSettings(
              blur: 3,
              thickness: 28,
              refractiveIndex: 1.45,
              lightIntensity: 0.18,
              ambientStrength: 0.18,
              saturation: 1.0,
              glassColor: Colors.transparent,
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

    _chipDismissTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _removeChipOverlay();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = GestureDetector(
      onTap: () {
        _removeChipOverlay();
        widget.onTap();
      },
      onLongPress: () => _showGlassChip(context),
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: Center(
          child: Icon(
            widget.activeItem.icon,
            size: 24,
            color: widget.activeAccentColor,
          ),
        ),
      ),
    );

    return item;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH PILL  (cupertino_native CNTabBar — right standalone pill)
// ─────────────────────────────────────────────────────────────────────────────

/// Standalone search pill matching the single-icon pill in the cupertino_native
/// CNTabBar screenshot.  Uses the same liquid-glass blur treatment as the main
/// nav capsule so both pills feel visually unified.
class _SearchPill extends StatefulWidget {
  const _SearchPill({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<_SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends State<_SearchPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;

  OverlayEntry? _chipOverlay;
  Timer? _chipDismissTimer;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
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
    final l10n = AppLocalizations.of(context)!;
    HapticFeedback.mediumImpact();
    _removeChipOverlay();
    _chipDismissTimer?.cancel();

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Offset globalPos = box.localToGlobal(Offset.zero);
    final Size boxSize = box.size;

    final double chipLeft = globalPos.dx + boxSize.width / 2 - 60;
    final double chipBottom =
        MediaQuery.of(context).size.height - globalPos.dy + 8;

    _bounceController.forward(from: 0.0);

    _chipOverlay = OverlayEntry(
      builder: (overlayContext) => Positioned(
        left: chipLeft.clamp(
            8.0, MediaQuery.of(overlayContext).size.width - 128),
        bottom: chipBottom,
        child: AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (_, child) => Transform.scale(
            scale: _bounceAnimation.value,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
          child: GlassChip(
            label: l10n.navSearch,
            icon: const Icon(MingCute.search_2_line, size: 16),
            useOwnLayer: true,
            quality: GlassQuality.standard,
            interactionScale: 1.08,
            stretch: 0.6,
            glowRadius: 1.2,
            anchorStretch: true,
            settings: const LiquidGlassSettings(
              blur: 3,
              thickness: 28,
              refractiveIndex: 1.45,
              lightIntensity: 0.18,
              ambientStrength: 0.18,
              saturation: 1.0,
              glassColor: Colors.transparent,
            ),
            onTap: () {
              _removeChipOverlay();
              widget.navigationShell.goBranch(2);
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_chipOverlay!);

    _chipDismissTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _removeChipOverlay();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentIndex = widget.navigationShell.currentIndex;
    final isSearchSelected = currentIndex == 2;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeAccentColor = AppTheme.accentColor(context);

    final iconColor = isSearchSelected
        ? activeAccentColor
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60);

    // Standalone search pill — LEFT side of the footer, matching the
    // cupertino_native CNTabBar screenshot (single-icon compact pill on left).
    // Uses identical glass recipe (BackdropFilter + translucent fill + border
    // + drop shadow) as the nav capsule so both pills feel visually unified.
    return GestureDetector(
      onTap: () {
        _removeChipOverlay();
        HapticFeedback.lightImpact();
        widget.navigationShell.goBranch(2);
      },
      onLongPress: () => _showGlassChip(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: _kSearchPillW,
        height: _kNavBarH,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(29),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.14),
              blurRadius: 24,
              spreadRadius: -6,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(29),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white)
                    .withValues(alpha: isDark ? 0.25 : 0.42),
                borderRadius: BorderRadius.circular(29),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: isDark ? 0.15 : 0.24,
                  ),
                  width: 0.75,
                ),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Column(
                    key: ValueKey<bool>(isSearchSelected),
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSearchSelected
                            ? FluentIcons.search_24_filled
                            : FluentIcons.search_24_regular,
                        size: isSearchSelected ? 22 : 20,
                        color: iconColor,
                      ),
                      if (isSearchSelected) ...[
                        const SizedBox(height: 2),
                        Text(
                          l10n.navSearch,
                          maxLines: 1,
                          style: TextStyle(
                            color: iconColor,
                            fontSize: 9,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
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


// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED PAGE VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedPageView extends StatefulWidget {
  const _AnimatedPageView({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  State<_AnimatedPageView> createState() => _AnimatedPageViewState();
}

/// Muzo-exact page transition: reverse-then-forward fade, 150 ms, easeInOut.
/// Matches Muzo's FadeIndexedStack (fade_indexed_stack.dart) exactly —
/// fades out the old page first, then fades in the new one.
class _AnimatedPageViewState extends State<_AnimatedPageView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.navigationShell.currentIndex;
    _controller = AnimationController(
      vsync: this,
      // Muzo-exact: 150 ms (FadeIndexedStack default duration)
      duration: const Duration(milliseconds: 150),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    // Start fully visible
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(_AnimatedPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newIndex = widget.navigationShell.currentIndex;
    if (newIndex != _activeIndex) {
      // Muzo-exact: reverse (fade out) → setState (swap page) → forward (fade in)
      _controller.reverse().then((_) {
        if (mounted) {
          setState(() => _activeIndex = newIndex);
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: widget.navigationShell,
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
// HORIZONTAL NAV BAR (legacy stub — not rendered on mobile)
// ─────────────────────────────────────────────────────────────────────────────

/// Legacy stub kept so any external import of [HorizontalNavBar] still
/// compiles.  The real mobile footer uses [_CollapsibleNavCapsule] (right
/// large pill) + [_SearchPill] (left compact pill) via [_GlassFooterOverlay].
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
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
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
                    color: (isDark ? Colors.black : Colors.white)
                        .withValues(alpha: isDark ? 0.20 : 0.35),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white
                          .withValues(alpha: isDark ? 0.12 : 0.20),
                      width: 0.75,
                    ),
                  ),
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
          ),
        ),
        const SizedBox(width: 10),

        // ── Separate Right Floating Circle Button (Branch 2) ──
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            navigationShell.goBranch(2);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 20,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white)
                        .withValues(alpha: isDark ? 0.20 : 0.35),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white
                          .withValues(alpha: isDark ? 0.12 : 0.20),
                      width: 0.75,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isSearchSelected
                          ? FluentIcons.home_24_regular
                          : FluentIcons.search_24_regular,
                      size: 20,
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
              lightIntensity: 0.18,
              ambientStrength: 0.18,
              saturation: 1.0,
              glassColor: Colors.transparent,
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
    final item = GestureDetector(
      onTap: () {
        _removeChipOverlay();
        widget.onTap();
      },
      onLongPress: () => _showGlassChip(context),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: _kCollapseAnimDuration,
        curve: _kCollapseAnimCurve,
        height: 48,
        alignment: Alignment.center,
        constraints: const BoxConstraints(minWidth: 58),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          // Muzo keeps the inactive items visually quiet and gives the active
          // item its own dark, raised glass island.
          color: widget.isSelected ? null : Colors.transparent,
          gradient: widget.isSelected
              ? RadialGradient(
                  colors: [
                    widget.activeColor.withValues(alpha: 0.22),
                    Colors.black.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.08),
                  ],
                  radius: 0.9,
                )
              : null,
          border: widget.isSelected
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.24),
                  width: 0.75,
                )
              : null,
          borderRadius: BorderRadius.circular(24),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: widget.activeColor.withValues(alpha: 0.18),
                    blurRadius: 14,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: SizedBox(
            height: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: const Offset(0, 1),
                  child: Icon(
                    widget.item.icon,
                    size: 18,
                    color: widget.isSelected
                        ? widget.activeColor
                        : widget.inactiveColor,
                  ),
                ),
                const SizedBox(height: 0.5),
                Text(
                  widget.item.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: widget.isSelected
                        ? widget.activeColor
                        : widget.inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return item;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV ITEM DATA
// ─────────────────────────────────────────────────────────────────────────────

class _NavItemData {
  final int branchIndex;
  final IconData icon;
  final String label;
  final CNSymbol? symbol;

  const _NavItemData({
    required this.branchIndex,
    required this.icon,
    required this.label,
    this.symbol,
  });
}
