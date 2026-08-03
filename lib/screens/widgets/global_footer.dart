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
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

// ─── Layout constants ────────────────────────────────────────────────────────
const double _kMiniPlayerHeight = 72.0; // card(64) + vertical padding(4+4)
const double _kMiniPlayerGap = 6.0;
const double _kNavBarFooterHeight = 72.0; // gap(6) + navBar(66)
const double _kOuterBottomPadding = 6.0;
const double _kDesktopSidebarWidth = 80.0;

// Mobile footer element sizes — matches Muzo-main exactly
const double _kNavBarH = 56.0;

// Search branch index
const int _kSearchBranchIndex = 2;

class GlobalFooter extends StatefulWidget {
  const GlobalFooter({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  State<GlobalFooter> createState() => _GlobalFooterState();
}

class _GlobalFooterState extends State<GlobalFooter>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
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
    if (oldWidget.navigationShell != widget.navigationShell) {
      context.read<PlayerOverlayCubit>().registerNavigateToBranch(
            widget.navigationShell.goBranch,
          );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    context.read<PlayerOverlayCubit>().unregisterNavigateToBranch();
    super.dispose();
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
              extendBody: true,
              extendBodyBehindAppBar: true,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Main navigation body ────────────────────────────────
                  _FooterAwareBody(
                    isMobile: isMobile,
                    navigationShell: widget.navigationShell,
                  ),
                  // ── Floating footer overlay ─────────────────────────────
                  if (isMobile)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _MuzoFooterOverlay(
                        navigationShell: widget.navigationShell,
                        searchController: _searchController,
                        searchFocusNode: _searchFocusNode,
                      ),
                    )
                  else
                    Positioned(
                      left: _kDesktopSidebarWidth + 8.0,
                      right: 8.0,
                      bottom: MediaQuery.of(context).viewPadding.bottom +
                          _kOuterBottomPadding,
                      height: 64,
                      child: _DesktopMiniPlayerFooter(
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

        double footerExtra = _kOuterBottomPadding;
        if (isMobile) footerExtra += _kNavBarFooterHeight;
        if (hasMiniPlayer) footerExtra += _kMiniPlayerHeight + _kMiniPlayerGap;

        final updatedMq = mq.copyWith(
          padding: mq.padding.copyWith(
            bottom: (mq.padding.bottom + footerExtra).clamp(0.0, double.infinity),
          ),
          viewPadding: mq.viewPadding.copyWith(
            bottom: (mq.viewPadding.bottom + footerExtra).clamp(0.0, double.infinity),
          ),
        );

        final body = isMobile
            ? _AnimatedPageView(navigationShell: navigationShell)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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

// ─────────────────────────────────────────────────────────────────────────────
// MUZO-STYLE MOBILE FOOTER OVERLAY
// Direct copy from Muzo-main's _buildBottomNavBar + _buildMiniPlayerPositioned.
// ─────────────────────────────────────────────────────────────────────────────

class _MuzoFooterOverlay extends StatelessWidget {
  const _MuzoFooterOverlay({
    required this.navigationShell,
    required this.searchController,
    required this.searchFocusNode,
  });

  final StatefulNavigationShell navigationShell;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final floatBottom = 12.0 + bottomPadding;
    final currentIndex = navigationShell.currentIndex;
    final isSearchActive = currentIndex == _kSearchBranchIndex;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final showNavBar = !keyboardVisible || isSearchActive;

    return BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
      builder: (context, miniState) {
        final hasMiniPlayer = miniState.isVisible;

        // Muzo: mini player sits at navBar height + gap above nav bar bottom
        final double miniPlayerBottom = floatBottom + _kNavBarH + _kMiniPlayerGap;

        // Total SizedBox height to contain both layers
        final double sizedBoxH = floatBottom +
            _kNavBarH +
            (hasMiniPlayer ? _kMiniPlayerGap + _kMiniPlayerHeight : 0.0);

        return SizedBox(
          height: sizedBoxH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Mini player ──
              if (hasMiniPlayer)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: miniPlayerBottom,
                  height: 50,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: showNavBar ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !showNavBar,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
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
                          borderRadius: BorderRadius.circular(25),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                            child: Container(
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.20 : 0.35),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.20),
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

              // ── Nav bar ──
              Positioned(
                left: 16,
                right: 16,
                bottom: floatBottom,
                height: 56,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: showNavBar ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !showNavBar,
                    child: Row(
                      children: [
                        // Main pill: Navigation icons OR Search input
                        Expanded(
                          child: Container(
                            height: 56,
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
                                    color: (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.20 : 0.35),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.20),
                                      width: 0.75,
                                    ),
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder: (child, animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: ScaleTransition(
                                          scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: isSearchActive
                                        ? _SearchTextField(
                                            key: const ValueKey('search_text_field'),
                                            controller: searchController,
                                            focusNode: searchFocusNode,
                                            onSubmit: (query) {
                                              if (query.trim().isNotEmpty) {
                                                navigationShell.goBranch(_kSearchBranchIndex);
                                              }
                                            },
                                          )
                                        : _NavButtonsRow(
                                            key: const ValueKey('nav_buttons_row'),
                                            navigationShell: navigationShell,
                                            isDark: isDark,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Search circle / Home Button
                        Container(
                          width: 56,
                          height: 56,
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
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  if (isSearchActive) {
                                    searchController.clear();
                                    searchFocusNode.unfocus();
                                    navigationShell.goBranch(0);
                                  } else {
                                    navigationShell.goBranch(_kSearchBranchIndex);
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      searchFocusNode.requestFocus();
                                    });
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.20 : 0.35),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.20),
                                      width: 0.75,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 300),
                                          transitionBuilder: (child, animation) {
                                            return ScaleTransition(
                                              scale: animation,
                                              child: FadeTransition(opacity: animation, child: child),
                                            );
                                          },
                                          child: isSearchActive
                                              ? Icon(
                                                  MingCute.home_4_fill,
                                                  key: const ValueKey('home_button_icon'),
                                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                                  size: 18,
                                                )
                                              : Icon(
                                                  MingCute.search_2_line,
                                                  key: const ValueKey('search_button_icon'),
                                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                                  size: 18,
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
                      ],
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
// SEARCH TEXT FIELD — exact copy from Muzo-main's _buildSearchTextField
// ─────────────────────────────────────────────────────────────────────────────

class _SearchTextField extends StatelessWidget {
  const _SearchTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: Theme.of(context).colorScheme.primary,
        decoration: InputDecoration(
          hintText: 'Search songs, albums, artists...',
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            fontWeight: FontWeight.w500,
          ),
          filled: false,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 0, right: 8),
            child: Icon(
              MingCute.search_2_line,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 28,
            minHeight: 28,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                icon: Icon(
                  MingCute.close_circle_fill,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 18,
                ),
                onPressed: () {
                  controller.clear();
                  focusNode.requestFocus();
                },
              );
            },
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
          ),
        ),
        onSubmitted: onSubmit,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV BUTTONS ROW — 5 items in pill using Muzo-main's _buildNavButtons layout
// Keeping existing app icons: Home(0), Library(1), Search(2), LocalMusic(3), Offline(4)
// ─────────────────────────────────────────────────────────────────────────────

class _NavButtonsRow extends StatelessWidget {
  const _NavButtonsRow({
    super.key,
    required this.navigationShell,
    required this.isDark,
  });
  final StatefulNavigationShell navigationShell;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentIndex = navigationShell.currentIndex;

    final items = [
      _NavItemData(
        branchIndex: 0,
        icon: MingCute.home_4_fill,
        iconLine: MingCute.home_4_line,
        label: l10n.navHome,
      ),
      _NavItemData(
        branchIndex: 1,
        icon: MingCute.book_5_fill,
        iconLine: MingCute.book_5_line,
        label: l10n.navLibrary,
      ),
      _NavItemData(
        branchIndex: 2,
        icon: MingCute.search_2_fill,
        iconLine: MingCute.search_2_line,
        label: l10n.navSearch,
      ),
      _NavItemData(
        branchIndex: 3,
        icon: MingCute.music_2_fill,
        iconLine: MingCute.music_2_line,
        label: l10n.navLocal,
      ),
      _NavItemData(
        branchIndex: 4,
        icon: MingCute.folder_download_fill,
        iconLine: MingCute.folder_download_line,
        label: l10n.navOffline,
      ),
    ];

    return Row(
      key: const ValueKey('nav_buttons_row'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items.map((item) {
        final isSelected = currentIndex == item.branchIndex;
        return _NavItem(
          item: item,
          isSelected: isSelected,
          isDark: isDark,
          onTap: () {
            HapticFeedback.lightImpact();
            navigationShell.goBranch(item.branchIndex);
          },
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE NAV ITEM — exact copy from Muzo-main's _buildNavItem widget
// Selected state: RadialGradient "mini pill" glow + plain Icon (filled/line)
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });
  final _NavItemData item;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final inactiveColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    // Muzo: filled icon when selected, line icon when idle
    final displayIcon = isSelected ? item.icon : (item.iconLine ?? item.icon);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        constraints: const BoxConstraints(minWidth: 58),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          // Muzo-exact: RadialGradient mini pill glow on selected item
          gradient: isSelected
              ? RadialGradient(
                  colors: [
                    primaryColor.withValues(alpha: isDark ? 0.15 : 0.10),
                    primaryColor.withValues(alpha: 0.0),
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
            // Muzo uses a plain Icon — no AnimatedScale or AnimatedSwitcher
            Icon(
              displayIcon,
              color: isSelected ? primaryColor : inactiveColor,
              size: 18,
            ),
            const SizedBox(height: 0.5),
            Text(
              item.label,
              maxLines: 1,
              style: TextStyle(
                color: isSelected ? primaryColor : inactiveColor,
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP MINI PLAYER FOOTER
// Desktop: mini player floating above content, no nav bar needed
// (Desktop nav is handled by the sidebar).
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopMiniPlayerFooter extends StatelessWidget {
  const _DesktopMiniPlayerFooter({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
      builder: (context, miniState) {
        if (!miniState.isVisible) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final scaffoldFill = Theme.of(context).scaffoldBackgroundColor;

        return SizedBox(
          height: 64,
          child: RepaintBoundary(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: scaffoldFill,
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDark ? 0.35 : 0.14),
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
                  shape: const LiquidRoundedSuperellipse(borderRadius: 28),
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

    return Container(
      width: _kDesktopSidebarWidth,
      decoration: BoxDecoration(
        color: glassColor,
        border: Border(
          right: BorderSide(color: glassBorder, width: 1.0),
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
        branchIndex: 0,
        icon: MingCute.home_4_fill,
        iconLine: MingCute.home_4_line,
        label: l10n.navHome,
      ),
      _NavItemData(
        branchIndex: 1,
        icon: MingCute.book_5_fill,
        iconLine: MingCute.book_5_line,
        label: l10n.navLibrary,
      ),
      _NavItemData(
        branchIndex: 3,
        icon: MingCute.music_2_fill,
        iconLine: MingCute.music_2_line,
        label: l10n.navLocal,
      ),
      _NavItemData(
        branchIndex: 4,
        icon: MingCute.folder_download_fill,
        iconLine: MingCute.folder_download_line,
        label: l10n.navOffline,
      ),
    ];

    final isSearchSelected = currentIndex == _kSearchBranchIndex;

    return Row(
      children: [
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
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            navigationShell.goBranch(_kSearchBranchIndex);
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
                    color:
                        isSearchSelected ? selectedPillBorder : glassBorder,
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
// SHARED NAV ITEM BUTTON (used by HorizontalNavBar)
// ─────────────────────────────────────────────────────────────────────────────

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
    // Muzo-exact: filled icon when selected, line icon when idle
    final displayIcon =
        isSelected ? item.icon : (item.iconLine ?? item.icon);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 54,
        height: 48,
        child: Center(
          child: AnimatedScale(
            scale: isSelected ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale:
                      Tween<double>(begin: 0.82, end: 1.0).animate(anim),
                  child: child,
                ),
              ),
              child: Icon(
                displayIcon,
                key: ValueKey(isSelected),
                size: 22,
                color: isSelected ? activeColor : inactiveColor,
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

  /// Filled / solid icon — shown when this item is **selected**.
  final IconData icon;

  /// Line / outline icon — shown when this item is **idle**.
  /// Falls back to [icon] if not provided.
  final IconData? iconLine;

  final String label;

  const _NavItemData({
    required this.branchIndex,
    required this.icon,
    this.iconLine,
    required this.label,
  });
}
