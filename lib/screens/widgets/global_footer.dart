import 'dart:ui';
import 'package:voidmusic/blocs/player_overlay/player_overlay_cubit.dart';
import 'package:voidmusic/screens/widgets/player_overlay_wrapper.dart';
import 'package:voidmusic/screens/widgets/mini_player_widget.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:voidmusic/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          child: Scaffold(
            backgroundColor: Default_Theme.themeColor,
            drawerScrimColor: Default_Theme.themeColor,
            extendBody: true,
            body: Stack(
              children: [
                Positioned.fill(
                  child: isMobile
                      ? _AnimatedPageView(navigationShell: navigationShell)
                      : Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: VerticalNavBar(navigationShell: navigationShell),
                            ),
                            Expanded(
                              child:
                                  _AnimatedPageView(navigationShell: navigationShell),
                            ),
                          ],
                        ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const MiniPlayerWidget(),
                          if (isMobile) ...[
                            const SizedBox(height: 6),
                            HorizontalNavBar(navigationShell: navigationShell),
                          ],
                        ],
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

    return NavigationRail(
      backgroundColor: Default_Theme.themeColor.withValues(alpha: 0.3),
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
      indicatorColor: Colors.white.withValues(alpha: 0.2),
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

    final capsuleItems = [
      _NavItemData(branchIndex: 0, icon: MingCute.home_4_fill, label: l10n.navHome),
      _NavItemData(branchIndex: 1, icon: MingCute.book_5_fill, label: l10n.navLibrary),
      _NavItemData(branchIndex: 3, icon: MingCute.music_2_fill, label: l10n.navLocal),
      _NavItemData(branchIndex: 4, icon: MingCute.folder_download_fill, label: l10n.navOffline),
    ];

    final isSearchSelected = currentIndex == 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Main Glass Capsule (Home, Library, Local, Offline) ──
          ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  // Pure glass — no opaque black background
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: capsuleItems.map((item) {
                    final isSelected = currentIndex == item.branchIndex;
                    return _NavItemButton(
                      item: item,
                      isSelected: isSelected,
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
          const SizedBox(width: 10),

          // ── Right Glass Search Circle Button (Branch 2) ──
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              navigationShell.goBranch(2);
            },
            behavior: HitTestBehavior.opaque,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Pure glass — no opaque black background
                    color: isSearchSelected
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: isSearchSelected
                          ? Colors.white.withValues(alpha: 0.30)
                          : Colors.white.withValues(alpha: 0.18),
                      width: 0.8,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      MingCute.search_2_line,
                      size: 24,
                      color: isSearchSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.70),
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

/// Individual nav item with its own circular glass background (matching the reference image)
class _NavItemButton extends StatelessWidget {
  final _NavItemData item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItemButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Active item accent color (pinkish-red like reference)
    const activeColor = Color(0xFFFF4D6A);

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
            color: isSelected
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.10),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 22,
                color: isSelected
                    ? activeColor
                    : Colors.white.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 9,
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? activeColor
                      : Colors.white.withValues(alpha: 0.55),
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
