import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:voidmusic/blocs/player_overlay/player_overlay_cubit.dart';
import 'package:voidmusic/blocs/mini_player/mini_player_cubit.dart';
import 'package:voidmusic/screens/widgets/player_overlay_wrapper.dart';
import 'package:voidmusic/screens/widgets/mini_player_widget.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:voidmusic/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';

class GlobalFooter extends StatelessWidget {
  const GlobalFooter({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

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
            overlayC.hidePlayer();
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
            value: SystemUiOverlayStyle(
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarIconBrightness:
                  Theme.of(context).brightness == Brightness.dark
                      ? Brightness.light
                      : Brightness.dark,
              statusBarColor: Colors.transparent,
              statusBarBrightness:
                  Theme.of(context).brightness == Brightness.dark
                      ? Brightness.dark
                      : Brightness.light,
              statusBarIconBrightness:
                  Theme.of(context).brightness == Brightness.dark
                      ? Brightness.light
                      : Brightness.dark,
            ),
            child: Scaffold(
              // Keep fully transparent so the BackdropFilter blur in the mini player
              // and nav bar can composite against whatever is painted below them.
              backgroundColor: Colors.transparent,
              drawerScrimColor: Colors.transparent,
              // extendBody=true allows the body ScrollView to paint under the
              // floating footer so content scrolls behind the glassmorphic blur.
              extendBody: true,
              extendBodyBehindAppBar: true,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Main navigation body ──
                  _FooterAwareBody(
                    isMobile: isMobile,
                    navigationShell: navigationShell,
                  ),
                  // ── Floating footer overlay ──
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
                      navigationShell: navigationShell,
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
      overlayC.hidePlayer();
      return;
    }

    if (navigationShell.currentIndex != 0) {
      navigationShell.goBranch(0);
      return;
    }

    if (context.mounted) {
      await SystemNavigator.pop();
    }
  }
}

// Heights of the floating overlay elements (in logical pixels).
// Mini player card height (64) + vertical padding (4+4) = 72.
// SizedBox gap between mini player and nav bar = 6.
// Nav bar item circle height + vertical padding = 56 + 5 + 5 = 66.
// Outer bottom padding on the Column = 6.
// Mobile total WITH mini player = 72 + 6 + 66 + 6 = 150.
// Mobile total WITHOUT mini player = 0 + 66 + 6 = 72.
// Desktop (no nav bar) WITH mini player = 72 + 6 = 78.
// Desktop (no nav bar) WITHOUT mini player = 6.
const double _kMiniPlayerHeight = 72.0; // card(64) + vertical padding(4+4)
const double _kMiniPlayerGap = 6.0;     // gap between mini player and nav bar
const double _kNavBarFooterHeight = 72.0; // gap(6) + navBar(66)
const double _kOuterBottomPadding = 6.0;

/// Wraps the navigation shell with a [MediaQuery] that adds extra bottom
/// padding equal to the height of the floating footer (mini player + nav bar).
/// Dynamically adjusts based on whether the mini player is visible so no
/// content is hidden behind the overlay.
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
                children: [
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

/// Renders the glass footer overlay (mini player + nav bar) with a
/// [BackdropFilter] that extends all the way to the true screen edge.
///
/// Instead of relying on [SafeArea] (which fills the inset region with the
/// scaffold background color creating a black strip), we:
///   1. Stretch the [ClipRRect] + [BackdropFilter] to cover the full height
///      including the system navigation bar inset.
///   2. Position the visible pills above that inset using [Padding].
///
/// This ensures the blur composites against whatever screen content is below
/// the footer, with zero opaque fill in either light or dark mode.
class _GlassFooterOverlay extends StatelessWidget {
  const _GlassFooterOverlay({
    required this.isMobile,
    required this.navigationShell,
  });

  final bool isMobile;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    // Bottom inset = device home indicator / gesture bar height.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MiniPlayerWidget(),
        if (isMobile) const SizedBox(height: 6),
        // The nav bar glass capsule extends below the visible pill area into
        // the system inset so the blur covers the black strip.
        if (isMobile)
          _BlurredNavBarArea(
            bottomInset: bottomInset,
            navigationShell: navigationShell,
          )
        else
          // On desktop there is no nav bar; just add a small spacer so
          // the mini player sits 6dp above the window edge.
          SizedBox(height: bottomInset + _kOuterBottomPadding),
      ],
    );
  }
}

/// The horizontal nav bar with no background - only individual pills on selected icons
class _BlurredNavBarArea extends StatelessWidget {
  const _BlurredNavBarArea({
    required this.bottomInset,
    required this.navigationShell,
  });

  final double bottomInset;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 0,
        bottom: bottomInset + _kOuterBottomPadding,
      ),
      child: HorizontalNavBar(navigationShell: navigationShell),
    );
  }
}

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

class VerticalNavBar extends StatelessWidget {
  const VerticalNavBar({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return NavigationRail(
      backgroundColor: Colors.transparent,
      destinations: [
        NavigationRailDestination(
            icon: const Icon(MingCute.home_4_fill), label: Text(l10n.navHome)),
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
      minWidth: 70,
      onDestinationSelected: navigationShell.goBranch,
      groupAlignment: 0.0,
      unselectedIconTheme:
          const IconThemeData(color: Default_Theme.primaryColor2),
      indicatorColor: isDark
          ? Colors.white.withValues(alpha: 0.2)
          : const Color(0xFF1C1C1E).withValues(alpha: 0.08),
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(15)),
      ),
    );
  }
}

class HorizontalNavBar extends StatelessWidget {
  const HorizontalNavBar({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentIndex = navigationShell.currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final glassColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final activeIconColor = isDark
        ? Colors.white
        : const Color(0xFF1C1C1E);
    final inactiveIconColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : const Color(0xFF8E8E93);
    final selectedCircleColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE5E5EA);
    final selectedCircleBorder = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : const Color(0xFFD1D1D6);

    final capsuleItems = [
      _NavItemData(branchIndex: 0, icon: MingCute.home_4_fill, label: l10n.navHome),
      _NavItemData(branchIndex: 1, icon: MingCute.book_5_fill, label: l10n.navLibrary),
      _NavItemData(branchIndex: 3, icon: MingCute.music_2_fill, label: l10n.navLocal),
      _NavItemData(branchIndex: 4, icon: MingCute.folder_download_fill, label: l10n.navOffline),
    ];

    final isSearchSelected = currentIndex == 2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: glassBorder,
              width: 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // ── Nav Items (Home, Library, Local, Offline) with pill on selected only ──
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: capsuleItems.map((item) {
                      final isSelected = currentIndex == item.branchIndex;
                      return _NavItemButton(
                        item: item,
                        isSelected: isSelected,
                        activeColor: activeIconColor,
                        inactiveColor: inactiveIconColor,
                        selectedCircleColor: selectedCircleColor,
                        selectedCircleBorder: selectedCircleBorder,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          navigationShell.goBranch(item.branchIndex);
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 10),

                // ── Search Button (Branch 2) with pill when selected ──
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    navigationShell.goBranch(2);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSearchSelected
                          ? selectedCircleColor
                          : Colors.transparent,
                      border: isSearchSelected
                          ? Border.all(
                              color: selectedCircleBorder,
                              width: 1.0,
                            )
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        MingCute.search_2_line,
                        size: 24,
                        color: isSearchSelected ? activeIconColor : inactiveIconColor,
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

/// Individual nav item with its own circular glass background (matching the reference image)
class _NavItemButton extends StatelessWidget {
  final _NavItemData item;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final Color selectedCircleColor;
  final Color selectedCircleBorder;
  final VoidCallback onTap;

  const _NavItemButton({
    required this.item,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.selectedCircleColor,
    required this.selectedCircleBorder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? selectedCircleColor : Colors.transparent,
            border: isSelected
                ? Border.all(
                    color: selectedCircleBorder,
                    width: 1.0,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 22,
                color: isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 9,
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w700,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
