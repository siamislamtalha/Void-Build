import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/services.dart';
import 'package:voidmusic/blocs/player_overlay/player_overlay_cubit.dart';
import 'package:voidmusic/blocs/mini_player/mini_player_cubit.dart';
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
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

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
                  // ── Main navigation body ────────────────────────────────
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
                  // ── Floating footer overlay ─────────────────────────────
                  // Desktop: precisely positioned over content area (right of
                  // sidebar) with exact height so MiniPlayerWidget gets bounded.
                  // Mobile: full-width anchor at bottom:0 for the animated
                  // pill Stack layout.
                  if (isMobile)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _GlassFooterOverlay(
                        isMobile: isMobile,
                        isMiniMode: _isMiniMode,
                        collapseAnimation: _collapseAnimation,
                        navigationShell: widget.navigationShell,
                        onExpandFooter: _expandFooter,
                      ),
                    )
                  else
                    Positioned(
                      left: _kDesktopSidebarWidth + 8.0,
                      right: 8.0,
                      bottom: MediaQuery.of(context).viewPadding.bottom +
                          _kOuterBottomPadding,
                      height: 64,
                      child: _GlassFooterOverlay(
                        isMobile: isMobile,
                        isMiniMode: _isMiniMode,
                        collapseAnimation: _collapseAnimation,
                        navigationShell: widget.navigationShell,
                        onExpandFooter: _expandFooter,
                      ),
                    ),
                ],
              ),

            ),
          ),
        ),
      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// BODY WRAPPER
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

    if (!isMobile) {
      // ── Desktop layout: mini player floating above content ────────────────
      //
      // IMPORTANT: This widget is returned as the child of a Positioned in the
      // main Stack (in GlobalFooter.build). Do NOT wrap in another Positioned
      // here — the outer Positioned already handles left/right/bottom/height.
      //
      // The RepaintBoundary is placed OUTSIDE BackdropFilter so the GPU blur
      // texture is cached by the compositor and never re-sampled. The fallback
      // scaffoldFill color ensures BackdropFilter always has pixels to sample
      // (prevents the white flash when content behind is transparent).
      return BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
        builder: (context, miniState) {
          if (!miniState.isVisible) return const SizedBox.shrink();

          final isDark = Theme.of(context).brightness == Brightness.dark;
          // Solid fallback so BackdropFilter never samples an empty buffer.
          final scaffoldFill = Theme.of(context).scaffoldBackgroundColor;

          return SizedBox(
            height: 64,
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  // Opaque fallback BEHIND blur — prevents white flash.
                  color: scaffoldFill,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isDark ? 0.35 : 0.14),
                      blurRadius: 20,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: GlassContainer(
                    useOwnLayer: true,
                    settings: LiquidGlassSettings(
                      thickness: 30,
                      blur: 25,
                      glassColor: (isDark ? Colors.black : Colors.white)
                          .withValues(alpha: isDark ? 0.20 : 0.35),
                      ambientRim: 0.2,
                      fresnelStrength: 1.0,
                      specularSharpness: GlassSpecularSharpness.medium,
                    ),
                    shape: LiquidRoundedSuperellipse(borderRadius: 28),
                    child: MiniPlayerWidget(
                      currentPageIndex: navigationShell.currentIndex,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    // ── Mobile: animated collapse Stack layout ──────────────────────────────
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

        // Full width of the left nav capsule (expanded state).
        final double screenW = MediaQuery.of(context).size.width;
        final double leftCapsuleFullW =
            screenW - _kFooterHPad * 2 - _kPillGap - _kSearchCircleW;

        return SizedBox(
          height: sizedBoxH,
          child: Stack(
            // Clip.none lets the AnimatedPositioned animate out of the SizedBox
            // bounds without visual clipping during the transition.
            clipBehavior: Clip.none,
            children: [
              // ── Left nav capsule ────────────────────────────────────────
              // Left-edge is anchored at _kFooterHPad.
              // Width shrinks from fullWidth → _kSearchCircleW (right side moves in).
              // RepaintBoundary freezes the BackdropFilter blur texture so the
              // compositor does not re-sample it on every AnimatedContainer frame.
              Positioned(
                left: _kFooterHPad,
                bottom: navBottomAbs,
                height: _kNavBarH,
                child: RepaintBoundary(
                  child: _CollapsibleNavCapsule(
                    isMiniMode: isCollapsed,
                    navigationShell: navigationShell,
                    fullWidth: leftCapsuleFullW,
                    onTapCollapsed: () {
                      HapticFeedback.selectionClick();
                      onExpandFooter?.call();
                    },
                  ),
                ),
              ),

              // ── Search circle ────────────────────────────────────────────
              // Right-edge is anchored at _kFooterHPad. Never moves.
              // RepaintBoundary caches the blur so it never re-samples.
              Positioned(
                right: _kFooterHPad,
                bottom: navBottomAbs,
                width: _kSearchCircleW,
                height: _kNavBarH,
                child: RepaintBoundary(
                  child: _SearchCircleButton(navigationShell: navigationShell),
                ),
              ),

              // ── Mini player with advanced liquid glass effects ─────────────
              // Architecture for blur stability:
              //
              //   AnimatedPositioned (changes position/size)
              //     └─ RepaintBoundary (compositor caches this subtree)
              //          └─ Container (shadow, borderRadius)
              //               └─ ClipRRect (static, never re-clips)
              //                    └─ GlassContainer (advanced liquid glass)
              //                         └─ MiniPlayerWidget (content only)
              //
              // The GlassContainer is OUTSIDE AnimatedPositioned's animated
              // dimension, so the GPU blur texture is never invalidated — no
              // flicker during expand/collapse/reposition.
              if (hasMiniPlayer)
                AnimatedPositioned(
                  duration: _kCollapseAnimDuration,
                  curve: _kCollapseAnimCurve,
                  left: miniLeft,
                  right: miniRight,
                  bottom: miniBottom,
                  height: miniHeight,
                  child: RepaintBoundary(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                                alpha:
                                    Theme.of(context).brightness == Brightness.dark
                                        ? 0.35
                                        : 0.12),
                            blurRadius: 20,
                            spreadRadius: -4,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: GlassContainer(
                          useOwnLayer: true,
                          settings: LiquidGlassSettings(
                            thickness: 30,
                            blur: 25,
                            glassColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.black.withValues(alpha: 0.20)
                                : Colors.white.withValues(alpha: 0.35),
                            ambientRim: 0.2,
                            fresnelStrength: 1.0,
                            specularSharpness: GlassSpecularSharpness.medium,
                          ),
                          shape: LiquidRoundedSuperellipse(borderRadius: 30),
                          child: MiniPlayerWidget(
                            currentPageIndex: navigationShell.currentIndex,
                            isCompact: isCollapsed,
                          ),
                        ),
                      ),
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
// COLLAPSIBLE NAV CAPSULE
// ─────────────────────────────────────────────────────────────────────────────

/// The left navigation pill that collapses from full-width to a single-icon circle.
///
/// When [isMiniMode] is false the full nav row is shown.
/// When [isMiniMode] is true the pill shrinks to [_kSearchCircleW] and only the
/// active-tab icon is shown.
///
/// Left edge is anchored by the parent [Positioned]; only the right edge (width)
/// changes so the pill collapses inward from the right.
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
  // ── Drag / press tracking ──────────────────────────────────────────────────
  double? _dragPositionX;
  bool _isDragging = false;
  bool _isPressing = false;

  // Spring controller for press-expand animation on the pill
  late final AnimationController _pressController;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _pressAnim = CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  int _getNearestIndex(double dx, int itemCount, double slotWidth) {
    return (dx / slotWidth).floor().clamp(0, itemCount - 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentIndex = widget.navigationShell.currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeAccentColor = AppTheme.accentColor(context);
    final inactiveIconColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF1C1C1E).withValues(alpha: 0.85);
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

    final activeItem = capsuleItems.firstWhere(
      (item) => item.branchIndex == currentIndex,
      orElse: () => capsuleItems[0],
    );

    final activeItemIndex = capsuleItems.indexWhere(
      (item) => item.branchIndex == currentIndex,
    );
    final selectedIndex = activeItemIndex >= 0 ? activeItemIndex : 0;

    // ── BLUR-STABLE CAPSULE ─────────────────────────────────────────────────
    // The blur texture must NEVER be invalidated while the collapse animation
    // runs. We achieve this by keeping ClipRRect+BackdropFilter in a STATIC
    // SizedBox(width: fullWidth) that never changes size.
    //
    // Only an inner AnimatedContainer changes width (using a transparent bg
    // for the hidden region). The BackdropFilter samples its texture once and
    // the compositor caches it — no flicker, no re-sample.
    //
    // Shadow is on the outer SizedBox so it also doesn't re-paint.
    return SizedBox(
      width: widget.fullWidth,
      height: _kNavBarH,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Static glass layer with advanced liquid glass effects ──
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                    blurRadius: 20,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: GlassContainer(
                    useOwnLayer: true,
                    settings: LiquidGlassSettings(
                      thickness: 30,
                      blur: 25,
                      glassColor: (isDark ? Colors.black : Colors.white)
                          .withValues(alpha: isDark ? 0.20 : 0.35),
                      ambientRim: 0.2,
                      fresnelStrength: 1.0,
                      specularSharpness: GlassSpecularSharpness.medium,
                    ),
                    shape: LiquidRoundedSuperellipse(borderRadius: 30),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Animated clipping mask: hides the right portion when collapsing ──
          // This is a plain color rect that slides in from the right. No blur
          // is involved — it's just an opaque overlay on the transparent area
          // so the "invisible" part truly disappears.
          AnimatedPositioned(
            duration: _kCollapseAnimDuration,
            curve: _kCollapseAnimCurve,
            left: widget.isMiniMode ? _kSearchCircleW : widget.fullWidth,
            top: 0,
            bottom: 0,
            right: 0,
            child: const SizedBox.shrink(),
          ),

          // ── Animated visible content area ──────────────────────────────────
          // The ClipRect here clips the CONTENT (icons/pill) to the animated
          // width, but never touches the BackdropFilter above.
          AnimatedPositioned(
            duration: _kCollapseAnimDuration,
            curve: _kCollapseAnimCurve,
            left: 0,
            top: 0,
            bottom: 0,
            width: widget.isMiniMode ? _kSearchCircleW : widget.fullWidth,
            child: ClipRect(
              child: Stack(
                children: [
                  // ── Expanded nav content ──────────────────────────────────
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: widget.isMiniMode ? 0.0 : 1.0,
                    child: IgnorePointer(
                      ignoring: widget.isMiniMode,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // constraints.maxWidth tracks the animated width
                          final availableW = constraints.maxWidth - 12;
                          final slotW = availableW / capsuleItems.length;
                          const double basePillW = 68.0;
                          const double pressedPillW = 80.0;

                          final targetLeft =
                              6 + (selectedIndex * slotW) + (slotW - basePillW) / 2;

                          return GestureDetector(
                            onLongPressStart: (details) {
                              HapticFeedback.selectionClick();
                              setState(() => _isPressing = true);
                              _pressController.forward();
                            },
                            onLongPressEnd: (_) {
                              setState(() => _isPressing = false);
                              _pressController.reverse();
                            },
                            onLongPressCancel: () {
                              setState(() => _isPressing = false);
                              _pressController.reverse();
                            },
                            onHorizontalDragStart: (details) {
                              setState(() {
                                _isDragging = true;
                                _dragPositionX = details.localPosition.dx;
                              });
                              _pressController.forward();
                            },
                            onHorizontalDragUpdate: (details) {
                              final newDx = details.localPosition.dx;
                              final oldIdx = _dragPositionX != null
                                  ? _getNearestIndex(
                                      _dragPositionX! - 6,
                                      capsuleItems.length,
                                      slotW)
                                  : selectedIndex;
                              final newIdx = _getNearestIndex(
                                  newDx - 6, capsuleItems.length, slotW);
                              if (newIdx != oldIdx) {
                                HapticFeedback.selectionClick();
                              }
                              setState(() => _dragPositionX = newDx);
                            },
                            onHorizontalDragEnd: (details) {
                              if (_dragPositionX != null) {
                                final idx = _getNearestIndex(
                                    _dragPositionX! - 6,
                                    capsuleItems.length,
                                    slotW);
                                HapticFeedback.selectionClick();
                                widget.navigationShell
                                    .goBranch(capsuleItems[idx].branchIndex);
                              }
                              setState(() {
                                _isDragging = false;
                                _isPressing = false;
                                _dragPositionX = null;
                              });
                              _pressController.reverse();
                            },
                            child: AnimatedBuilder(
                              animation: _pressAnim,
                              builder: (context, _) {
                                double animPillW;
                                double animLeft;
                                if (_isDragging && _dragPositionX != null) {
                                  animPillW = basePillW +
                                      (pressedPillW - basePillW) *
                                          _pressAnim.value;
                                  animLeft = (_dragPositionX! - animPillW / 2)
                                      .clamp(6.0,
                                          constraints.maxWidth - 6 - animPillW);
                                } else if (_isPressing) {
                                  animPillW = basePillW +
                                      (pressedPillW - basePillW) *
                                          _pressAnim.value;
                                  animLeft = 6 +
                                      (selectedIndex * slotW) +
                                      (slotW - animPillW) / 2;
                                } else {
                                  animPillW = basePillW;
                                  animLeft = targetLeft;
                                }

                                return Stack(
                                  children: [
                                    // ── Liquid glass highlight pill ────────
                                    AnimatedPositioned(
                                      duration: _isDragging
                                          ? Duration.zero
                                          : const Duration(milliseconds: 380),
                                      curve: _isDragging
                                          ? Curves.linear
                                          : Curves.easeOutBack,
                                      left: animLeft,
                                      top: 5,
                                      width: animPillW,
                                      height: 48,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          // Muzo-style RadialGradient: accent
                                          // color at center → transparent at edge
                                          gradient: RadialGradient(
                                            center: Alignment.center,
                                            radius: 0.85,
                                            colors: [
                                              activeAccentColor.withValues(
                                                  alpha: isDark ? 0.28 : 0.18),
                                              activeAccentColor.withValues(
                                                  alpha: 0.0),
                                            ],
                                          ),
                                          border: Border.all(
                                            color: activeAccentColor.withValues(
                                                alpha: isDark ? 0.38 : 0.26),
                                            width: 1.0,
                                          ),
                                          boxShadow: [
                                            // Accent-tinted glow (Muzo)
                                            BoxShadow(
                                              color: activeAccentColor.withValues(
                                                  alpha: isDark ? 0.22 : 0.12),
                                              blurRadius: 16,
                                              spreadRadius: -2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // ── Icons row ────────────────────────
                                    SizedBox.expand(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: capsuleItems.map((item) {
                                            final isSelected = currentIndex ==
                                                item.branchIndex;
                                            return _NavItemButton(
                                              item: item,
                                              isSelected: isSelected,
                                              activeColor: activeAccentColor,
                                              inactiveColor: inactiveIconColor,
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                widget.navigationShell.goBranch(
                                                    item.branchIndex);
                                              },
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // ── Collapsed mode: single active icon ─────────────────────
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
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
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH CIRCLE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

/// Standalone search circle pill — extracted from [HorizontalNavBar] so it
/// can be placed as an independent [Positioned] element in the animated Stack.
/// Visual appearance, glass style, and behaviour are identical to the original.
class _SearchCircleButton extends StatelessWidget {
  const _SearchCircleButton({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;
    final isSearchSelected = currentIndex == 2;
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

    return Container(
      width: _kSearchCircleW,
      height: _kNavBarH,
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
        child: RepaintBoundary(
          child: GlassContainer(
            useOwnLayer: true,
            settings: LiquidGlassSettings(
              thickness: 30,
              blur: 25,
              glassColor: (isDark ? Colors.black : Colors.white)
                  .withValues(alpha: isDark ? 0.20 : 0.35),
              ambientRim: isSearchSelected ? 0.3 : 0.2,
              fresnelStrength: 1.0,
              specularSharpness: GlassSpecularSharpness.medium,
            ),
            shape: LiquidOval(),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                navigationShell.goBranch(2);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: _kSearchCircleW,
                height: _kNavBarH,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: isSearchSelected ? 48 : 42,
                    height: isSearchSelected ? 48 : 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSearchSelected
                          ? selectedPillColor
                          : Colors.transparent,
                      border: isSearchSelected
                          ? Border.all(color: selectedPillBorder, width: 1.0)
                          : null,
                    ),
                    child: Center(
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

    final glassColor = AppTheme.glassColor(context);
    final glassBorder = AppTheme.glassBorder(context);

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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  color: glassColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: glassBorder, width: 1.0),
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
        const SizedBox(width: 10),

        // ── Separate Right Floating Search Circle Button (Branch 2) ──
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            navigationShell.goBranch(2);
          },
          behavior: HitTestBehavior.opaque,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(29),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: glassColor,
                  border: Border.all(
                    color: isSearchSelected ? selectedPillBorder : glassBorder,
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: isSearchSelected ? 48 : 42,
                    height: isSearchSelected ? 48 : 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSearchSelected
                          ? selectedPillColor
                          : Colors.transparent,
                      border: isSearchSelected
                          ? Border.all(
                              color: selectedPillBorder,
                              width: 1.0,
                            )
                          : null,
                    ),
                    child: Center(
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

/// Nav item button — icon only, color animated by shared sliding pill.
/// The shared RadialGradient pill (AnimatedPositioned in _CollapsibleNavCapsule)
/// handles all selection indication; this widget just renders the icon.
class _NavItemButton extends StatelessWidget {
  final _NavItemData item;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItemButton({
    required this.item,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // The shared sliding RadialGradient pill in _CollapsibleNavCapsule is
    // the sole selection indicator. _NavItemButton renders ONLY the icon
    // (and label) with animated color — no per-item background or border.
    // This removes the double-pill z-fighting of the old design.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        // Fixed slot width — pill sizing is handled by the parent AnimatedPositioned
        width: 54,
        height: 48,
        child: Center(
          child: AnimatedScale(
            // Subtle micro-scale: selected icon pops 8% larger (Muzo feel)
            scale: isSelected ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: Icon(
              item.icon,
              size: 22,
              color: isSelected ? activeColor : inactiveColor,
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
