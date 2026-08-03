import 'dart:ui';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voidmusic/providers/navigation_provider.dart';
import 'package:voidmusic/providers/search_provider.dart';

// Muzo Footer Component - extracted from Muzo's main_layout.dart
// This contains the bottom navigation bar and search functionality
// Modified to work with the app's navigation shell system

class MuzoFooter extends ConsumerWidget {
  const MuzoFooter({
    super.key,
    required this.child,
    required this.isPlayerExpanded,
    required this.navigationShell,
  });

  final Widget child;
  final bool isPlayerExpanded;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sync navigationIndexProvider with navigationShell.currentIndex
    final currentIndex = navigationShell.currentIndex;
    ref.listen(navigationIndexProvider, (previous, next) {
      if (previous != next && next != currentIndex) {
        // Update navigation shell when provider changes
        navigationShell.goBranch(next);
      }
      // Clear search when leaving search tab (index 2)
      if (previous == 2 && next != 2) {
        ref.read(searchControllerProvider).clear();
        ref.read(searchFocusNodeProvider).unfocus();
        ref.read(searchQueryProvider.notifier).state = '';
      }
    });
    
    // Update provider when navigation shell changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(navigationIndexProvider) != currentIndex) {
        ref.read(navigationIndexProvider.notifier).state = currentIndex;
      }
    });

    final selectedIndex = ref.watch(navigationIndexProvider);
    final isDesktop = MediaQuery.of(context).size.width > 600;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final isSearchActive = selectedIndex == 2; // Search is index 2 in app routing
    final showNavBar = !isPlayerExpanded && (!keyboardVisible || isSearchActive);

    return Stack(
      children: [
        child,
        if (!isDesktop)
          _buildBottomNavBar(
            context,
            ref,
            selectedIndex,
            isPlayerExpanded,
            showNavBar,
          ),
      ],
    );
  }

  Widget _buildBottomNavBar(
    BuildContext context,
    WidgetRef ref,
    int selectedIndex,
    bool isPlayerExpanded,
    bool showNavBar,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final floatBottom = 12.0 + bottomPadding;
    final isSearchActive = selectedIndex == 1;

    return Positioned(
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
              // Main pill: Home, Library, Settings OR Search input
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
                              ? _buildSearchTextField(context, ref)
                              : _buildNavButtons(context, ref, selectedIndex, navigationShell),
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
                          ref.read(navigationIndexProvider.notifier).state = 0; // Go to Home
                          ref.read(searchControllerProvider).clear();
                          ref.read(searchFocusNodeProvider).unfocus();
                          navigationShell.goBranch(0);
                        } else {
                          ref.read(navigationIndexProvider.notifier).state = 2; // Search index
                          navigationShell.goBranch(2);
                          Future.delayed(const Duration(milliseconds: 150), () {
                            ref.read(searchFocusNodeProvider).requestFocus();
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
                                        FluentIcons.home_24_regular,
                                        key: const ValueKey('home_button_icon'),
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        size: 18,
                                      )
                                    : Icon(
                                        FluentIcons.search_24_regular,
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
    );
  }

  Widget _buildNavButtons(BuildContext context, WidgetRef ref, int selectedIndex, StatefulNavigationShell navigationShell) {
    return Row(
      key: const ValueKey('nav_buttons_row'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildNavItem(
          context,
          ref,
          FluentIcons.home_24_regular,
          FluentIcons.home_24_filled,
          "Home",
          0, // ExploreScreen
          selectedIndex,
          navigationShell,
        ),
        _buildNavItem(
          context,
          ref,
          FluentIcons.library_24_regular,
          FluentIcons.library_24_filled,
          "Library",
          1, // LibraryScreen
          selectedIndex,
          navigationShell,
        ),
        _buildNavItem(
          context,
          ref,
          FluentIcons.music_note_1_24_regular,
          FluentIcons.music_note_1_24_filled,
          "Local",
          3, // LocalMusicScreen
          selectedIndex,
          navigationShell,
        ),
        _buildNavItem(
          context,
          ref,
          FluentIcons.arrow_download_24_regular,
          FluentIcons.arrow_download_24_filled,
          "Offline",
          4, // OfflineScreen
          selectedIndex,
          navigationShell,
        ),
      ],
    );
  }

  Widget _buildSearchTextField(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(searchControllerProvider);
    final focusNode = ref.watch(searchFocusNodeProvider);

    return Padding(
      key: const ValueKey('search_text_field'),
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
              FluentIcons.search_24_regular,
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
                  FluentIcons.dismiss_circle_24_filled,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 18,
                ),
                onPressed: () {
                  controller.clear();
                  focusNode.requestFocus();
                  ref.read(searchQueryProvider.notifier).state = '';
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
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            ref.read(searchQueryProvider.notifier).state = value.trim();
            focusNode.unfocus();
            // Navigate to search screen if not already there
            if (navigationShell.currentIndex != 2) {
              navigationShell.goBranch(2);
            }
          }
        },
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    WidgetRef ref,
    IconData iconRegular,
    IconData iconFilled,
    String label,
    int index,
    int selectedIndex,
    StatefulNavigationShell navigationShell,
  ) {
    final isSelected = selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        if (index >= 0 && index <= 4) {
          // Update both provider and navigation shell
          ref.read(navigationIndexProvider.notifier).state = index;
          navigationShell.goBranch(index);
        }
      },
      child: Container(
        height: 48,
        alignment: Alignment.center,
        constraints: const BoxConstraints(minWidth: 58),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? RadialGradient(
                  colors: [
                    Theme.of(context).primaryColor.withValues(alpha: isDark ? 0.15 : 0.10),
                    Theme.of(context).primaryColor.withValues(alpha: 0.0),
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
              isSelected ? iconFilled : iconRegular,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              size: 18,
            ),
            const SizedBox(height: 0.5),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
