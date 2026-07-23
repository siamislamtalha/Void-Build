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
            body: isMobile
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
            bottomNavigationBar: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MiniPlayerWidget(),
                  if (isMobile)
                    Container(
                      color: Colors.transparent,
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      child: HorizontalNavBar(navigationShell: navigationShell),
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
      indicatorColor: Default_Theme.accentColor2,
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

    final navItems = [
      _NavItemData(branchIndex: 0, icon: MingCute.home_4_fill, label: l10n.navHome),
      _NavItemData(branchIndex: 1, icon: MingCute.book_5_fill, label: l10n.navLibrary),
      _NavItemData(branchIndex: 3, icon: MingCute.music_2_fill, label: l10n.navLocal),
      _NavItemData(branchIndex: 4, icon: MingCute.folder_download_fill, label: l10n.navOffline),
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6, top: 4, bottom: 6),
      child: Row(
        children: [
          // Left Liquid Glass Floating Capsule Bar
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: navItems.map((item) {
                      final isSelected = currentIndex == item.branchIndex;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          navigationShell.goBranch(item.branchIndex);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            horizontal: isSelected ? 12 : 8,
                            vertical: 6,
                          ),
                          decoration: isSelected
                              ? BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 0.8,
                                  ),
                                )
                              : const BoxDecoration(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                size: 22,
                                color: isSelected
                                    ? Default_Theme.accentColor2
                                    : Colors.white.withValues(alpha: 0.65),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Default_Theme.accentColor2
                                      : Colors.white.withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Right Circular Liquid Glass Search Button
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              navigationShell.goBranch(2);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: currentIndex == 2
                        ? Colors.white.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.38),
                    border: Border.all(
                      color: currentIndex == 2
                          ? Colors.white.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.24),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      MingCute.search_2_fill,
                      size: 24,
                      color: currentIndex == 2
                          ? Default_Theme.accentColor2
                          : Colors.white.withValues(alpha: 0.9),
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
