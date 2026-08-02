import 'dart:async';
import 'dart:ui';
import 'package:flutter/rendering.dart';
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
  bool _onScrollNotification(ScrollNotification notification) {
    final metrics = notification.metrics;

    // 1. Axis filter — ignore horizontal carousels, PageViews, etc.
    if (metrics.axis != Axis.vertical) return false;

    // 2. UserScrollNotification gate.
    //    UserScrollNotification fires ONLY for real user gestures (drag +
    //    subsequent ballistic fling). It is NOT fired for programmatic
    //    animateTo() / jumpTo() calls, so billboard auto-scroll is ignored.
    if (notification is UserScrollNotification) {
      _userScrollActive = notification.direction != ScrollDirection.idle;
      return false;
    }

    // Only act on scroll-update events while user is actively scrolling.
    if (notification is! ScrollUpdateNotification) return false;
    if (!_userScrollActive) return false;

    final double pixels = metrics.pixels;

    // Hysteresis: collapse at > 50 px, expand only when back below 25 px.
    final bool targetMini = _isMiniMode ? pixels >= 25.0 : pixels > 50.0;
    if (targetMini == _isMiniMode) {
      _debounceTimer?.cancel();
      return false;
    }

    // 3. 100 ms debounce — cancel if direction reverses before timer fires.
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      setState(() => _isMiniMode = targetMini);
      if (targetMini) {
        _collapseController.forward();
      } else {
        _collapseController.reverse();
      }
    });

    return false; // do not absorb — let the notification continue bubbling
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
                  // We skip SafeArea and instead manually add the device bottom
                  // inset so the glass pills sit just above the home indicator /
                  // gesture bar, while the BackdropFilter blur visually extends
                  // all the way to the true screen edge (no opaque black strip).
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _GlassFooterOverlay(
                      isMobile: isMobile,
                      collapseAnimation: _collapseAnimation,
                      navigationShell: widget.navigationShell,
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
    required this.collapseAnimation,
    required this.navigationShell,
  });

  final bool isMobile;
  final Animation<double> collapseAnimation;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    // Bottom inset = device home indicator / gesture bar height.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    if (!isMobile) {
      // ── Desktop layout: mini player in footer connected to sidebar ────────
      // Completely unchanged from original implementation.
      return Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          bottom: bottomInset + _kOuterBottomPadding,
        ),
        child: Row(
          children: [
            // Spacer for sidebar width (keeps footer connected to sidebar visually)
            const SizedBox(width: _kDesktopSidebarWidth + 4),
            // Mini player content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: MiniPlayerWidget(
                    currentPageIndex: navigationShell.currentIndex),
              ),
            ),
          ],
        ),
      );
    }

    // ── Mobile: single AnimatedBuilder drives ALL positions from one `t` ─────
    //
    // This exactly matches the Apple Music iOS 26 reference architecture:
    //   • A single AnimationController (collapseAnimation, 0→1) drives every
    //     measurement — nav capsule width, mini-player position, and opacity
    //     cross-fades are all derived from the same `t` in one AnimatedBuilder.
    //   • lerpDouble() gives smooth, continuous interpolation on EVERY frame tick.
    //   • No independent AnimatedContainer / AnimatedPositioned timers that
    //     can drift apart at different frame rates.
    //
    // On scroll down (>50 px) → controller.forward() → t: 0→1 (collapse)
    // On scroll up  (<25 px) → controller.reverse() → t: 1→0 (expand)
    return AnimatedBuilder(
      animation: collapseAnimation,
      builder: (context, _) {
        return BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
          builder: (context, miniState) {
            final hasMiniPlayer = miniState.isVisible;

            // Only collapse when a track is present. Without a mini player
            // the footer always stays expanded regardless of scroll position.
            final double t = hasMiniPlayer ? collapseAnimation.value : 0.0;

            // ── Absolute base positions ──────────────────────────────────────
            // All measured in logical pixels from the bottom of the SizedBox.
            // The SizedBox bottom edge == the screen bottom edge (Positioned bottom:0).
            final double navBottomAbs = bottomInset + _kOuterBottomPadding;

            // ── Continuously interpolated mini-player positions ───────────────
            // t = 0 → full-width pill floating above the nav bar (expanded)
            // t = 1 → narrow pill inline between the two circle pills (collapsed)
            final double miniNormalBottom =
                navBottomAbs + _kNavBarH + _kMiniPlayerGap;

            // Vertical: pill descends from above nav bar down to nav bar level.
            final double miniBottom =
                lerpDouble(miniNormalBottom, navBottomAbs, t)!;

            // Horizontal: both edges move inward so the pill narrows to fill
            // exactly the center slot between the left and right circle pills.
            final double miniLeft = lerpDouble(
                _kFooterHPad,
                _kFooterHPad + _kSearchCircleW + _kPillGap,
                t)!;
            final double miniRight = lerpDouble(
                _kFooterHPad,
                _kFooterHPad + _kSearchCircleW + _kPillGap,
                t)!;

            // Height: full card → nav bar height.
            final double miniHeight =
                lerpDouble(_kMiniPlayerHeight, _kNavBarH, t)!;

            // ── Nav capsule: left-anchored, right side moves in ──────────────
            // Full width → _kSearchCircleW as t goes 0→1.
            // The left edge is fixed by the parent Positioned.
            final double screenW = MediaQuery.of(context).size.width;
            final double leftCapsuleFullW =
                screenW - _kFooterHPad * 2 - _kPillGap - _kSearchCircleW;
            final double navCapsuleWidth =
                lerpDouble(leftCapsuleFullW, _kSearchCircleW, t)!;

            // SizedBox always allocates the maximum possible height to prevent
            // layout re-flows when the mini player appears / disappears.
            final double sizedBoxH = navBottomAbs +
                _kNavBarH +
                (hasMiniPlayer ? _kMiniPlayerGap + _kMiniPlayerHeight : 0.0);

            return SizedBox(
              height: sizedBoxH,
              child: Stack(
                // Clip.none: Positioned widgets paint outside the SizedBox
                // bounds during the transition without visual clipping.
                clipBehavior: Clip.none,
                children: [
                  // ── Left nav capsule ──────────────────────────────────────
                  // Left-edge is fixed at _kFooterHPad by this Positioned.
                  // Width shrinks continuously from fullWidth → _kSearchCircleW.
                  Positioned(
                    left: _kFooterHPad,
                    bottom: navBottomAbs,
                    height: _kNavBarH,
                    child: _CollapsibleNavCapsule(
                      t: t,
                      navCapsuleWidth: navCapsuleWidth,
                      navigationShell: navigationShell,
                      onTapCollapsed: () {
                        HapticFeedback.selectionClick();
                        // Reverse the animation and reset mini-mode state.
                        context
                            .findAncestorStateOfType<_GlobalFooterState>()
                            ?._expandFooter();
                      },
                    ),
                  ),

                  // ── Search circle (right-anchored, never moves) ───────────
                  Positioned(
                    right: _kFooterHPad,
                    bottom: navBottomAbs,
                    width: _kSearchCircleW,
                    height: _kNavBarH,
                    child: _SearchCircleButton(
                        navigationShell: navigationShell),
                  ),

                  // ── Mini player ───────────────────────────────────────────
                  // Plain Positioned (not AnimatedPositioned) — the parent
                  // AnimatedBuilder already rebuilds on every controller tick,
                  // so the position updates are driven by `t` directly.
                  if (hasMiniPlayer)
                    Positioned(
                      left: miniLeft,
                      right: miniRight,
                      bottom: miniBottom,
                      height: miniHeight,
                      child: MiniPlayerWidget(
                        currentPageIndex: navigationShell.currentIndex,
                        // Switch to compact layout at the midpoint so the
                        // size transition and content swap are concurrent.
                        isCompact: t > 0.5,
                      ),
                    ),
                ],
              ),
            );
          },
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
/// [t] is the collapse progress (0.0 = expanded, 1.0 = collapsed), driven by
/// the parent [AnimatedBuilder] in [_GlassFooterOverlay]. Using a continuous
/// [t] instead of a bool means all transitions are perfectly in sync with the
/// nav capsule width change — no independent [AnimatedContainer] timers.
///
/// Staggered opacity intervals (iOS 26 feel):
///   • Full nav row exits over t ∈ [0.0, 0.5] — items disappear before the
///     pill has fully shrunk (content empties first, then shape collapses).
///   • Collapsed single-icon enters over t ∈ [0.35, 0.85] — icon fades in
///     as the pill nears its final small-circle size.
///
/// LEFT edge always stays anchored (parent [Positioned] fixes it).
/// Width is pre-computed by the parent and passed as [navCapsuleWidth].
class _CollapsibleNavCapsule extends StatelessWidget {
  const _CollapsibleNavCapsule({
    required this.t,
    required this.navCapsuleWidth,
    required this.navigationShell,
    this.onTapCollapsed,
  });

  /// Collapse progress: 0.0 = fully expanded, 1.0 = fully collapsed.
  final double t;

  /// Pre-computed capsule width (lerped from fullWidth → _kSearchCircleW).
  final double navCapsuleWidth;
  final StatefulNavigationShell navigationShell;
  final VoidCallback? onTapCollapsed;

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

    final activeItem = capsuleItems.firstWhere(
      (item) => item.branchIndex == currentIndex,
      orElse: () => capsuleItems[0],
    );

    // Staggered opacity — nav items exit early so the pill “empties” before
    // it fully collapses (matching the iOS 26 morph feel).
    final double itemsOpacity =
        (1.0 - const Interval(0.0, 0.5, curve: Curves.easeIn).transform(t))
            .clamp(0.0, 1.0);
    // Collapsed icon enters late — fades in as the pill nears circle size.
    final double iconOpacity =
        const Interval(0.35, 0.85, curve: Curves.easeOut).transform(t)
            .clamp(0.0, 1.0);

    return SizedBox(
      width: navCapsuleWidth,
      height: _kNavBarH,
      // ClipRRect: as width shrinks, overflow nav items are clipped cleanly
      // at the pill's rounded edge without any layout thrashing.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: glassBorder, width: 1.0),
            ),
            child: Stack(
              children: [
                // ── Full nav row (fades out as t → 0.5) ────────────────
                Opacity(
                  opacity: itemsOpacity,
                  child: IgnorePointer(
                    ignoring: t > 0.4,
                    child: SizedBox.expand(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: capsuleItems.map((item) {
                            final isSelected =
                                currentIndex == item.branchIndex;
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

                // ── Collapsed: single active-tab icon (fades in as t → 0.85) ──
                Opacity(
                  opacity: iconOpacity,
                  child: IgnorePointer(
                    ignoring: t < 0.4,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTapCollapsed?.call();
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

    return GestureDetector(
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
            width: _kSearchCircleW,
            height: _kNavBarH,
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

/// Individual nav item with its own oval-pill glass background (matching the
/// desired reference image — wider than tall, like a stadium capsule).
class _NavItemButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        // Selected: wider oval (72 px) gives a clear stadium/capsule pill.
        // Unselected: narrower to not crowd items.
        width: isSelected ? 72 : 54,
        height: 48,
        decoration: BoxDecoration(
          // borderRadius = half of height → perfect stadium pill (fully rounded ends)
          borderRadius: BorderRadius.circular(24),
          color: isSelected ? selectedPillColor : Colors.transparent,
          border: isSelected
              ? Border.all(
                  color: selectedPillBorder,
                  width: 1.0,
                )
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: 20,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 9.5,
                fontFamily: 'Gilroy',
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
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
