import 'dart:ui';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voidmusic/blocs/mini_player/mini_player_cubit.dart';
import 'package:voidmusic/l10n/app_localizations.dart';
import 'package:voidmusic/providers/search_provider.dart';
import 'package:voidmusic/widgets/muzo_mini_player.dart';

/// Standalone, reusable Muzo Mobile Footer Navigation & Floating Mini Player Widget
class MuzoFooter extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final bool isPlayerExpanded;

  const MuzoFooter({
    super.key,
    required this.navigationShell,
    required this.isPlayerExpanded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final floatBottom = 12.0 + bottomPadding;
    final selectedIndex = navigationShell.currentIndex;
    final isSearchActive = selectedIndex == 2;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final showNavBar = !isPlayerExpanded && (!keyboardVisible || isSearchActive);

    final miniPlayerBottom = 76.0 + bottomPadding;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Floating Mini Player ──
        Positioned(
          left: 16,
          right: 16,
          bottom: miniPlayerBottom,
          height: 50,
          child: BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
            builder: (context, miniState) {
              if (!miniState.isVisible) return const SizedBox.shrink();
              return AnimatedOpacity(
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
                            color: (isDark ? Colors.black : Colors.white)
                                .withValues(alpha: isDark ? 0.20 : 0.35),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.20),
                              width: 0.75,
                            ),
                          ),
                          child: MuzoMiniPlayer(
                            currentPageIndex: selectedIndex,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // ── Bottom Nav Bar ──
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
                  // Main pill: Nav items or Search input
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
                              color: (isDark ? Colors.black : Colors.white)
                                  .withValues(alpha: isDark ? 0.20 : 0.35),
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
                                    scale: Tween<double>(begin: 0.96, end: 1.0)
                                        .animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: isSearchActive
                                  ? _MuzoSearchTextField(
                                      key: const ValueKey('search_text_field'),
                                      navigationShell: navigationShell,
                                    )
                                  : _MuzoNavButtonsRow(
                                      key: const ValueKey('nav_buttons_row'),
                                      navigationShell: navigationShell,
                                      selectedIndex: selectedIndex,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Circular Search / Home button
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
                              ref.read(searchControllerProvider).clear();
                              ref.read(searchFocusNodeProvider).unfocus();
                              ref.read(searchQueryProvider.notifier).state = '';
                              navigationShell.goBranch(0);
                            } else {
                              navigationShell.goBranch(2);
                              Future.delayed(const Duration(milliseconds: 150), () {
                                ref.read(searchFocusNodeProvider).requestFocus();
                              });
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.black : Colors.white)
                                  .withValues(alpha: isDark ? 0.20 : 0.35),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.20),
                                width: 0.75,
                              ),
                            ),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: FadeTransition(
                                        opacity: animation, child: child),
                                  );
                                },
                                child: isSearchActive
                                    ? Icon(
                                        FluentIcons.home_24_regular,
                                        key: const ValueKey('home_button_icon'),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                        size: 18,
                                      )
                                    : Icon(
                                        FluentIcons.search_24_regular,
                                        key: const ValueKey('search_button_icon'),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                        size: 18,
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
    );
  }
}

class _MuzoNavButtonsRow extends StatelessWidget {
  const _MuzoNavButtonsRow({
    super.key,
    required this.navigationShell,
    required this.selectedIndex,
  });

  final StatefulNavigationShell navigationShell;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final homeLabel = l10n?.navHome ?? 'Home';
    final libraryLabel = l10n?.navLibrary ?? 'Library';
    final localLabel = l10n?.navLocal ?? 'Local';
    final offlineLabel = l10n?.navOffline ?? 'Offline';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _MuzoNavItem(
          iconRegular: FluentIcons.home_24_regular,
          iconFilled: FluentIcons.home_24_filled,
          label: homeLabel,
          index: 0,
          selectedIndex: selectedIndex,
          onTap: () => navigationShell.goBranch(0),
        ),
        _MuzoNavItem(
          iconRegular: FluentIcons.library_24_regular,
          iconFilled: FluentIcons.library_24_filled,
          label: libraryLabel,
          index: 1,
          selectedIndex: selectedIndex,
          onTap: () => navigationShell.goBranch(1),
        ),
        _MuzoNavItem(
          iconRegular: FluentIcons.music_note_1_24_regular,
          iconFilled: FluentIcons.music_note_1_24_filled,
          label: localLabel,
          index: 3,
          selectedIndex: selectedIndex,
          onTap: () => navigationShell.goBranch(3),
        ),
        _MuzoNavItem(
          iconRegular: FluentIcons.arrow_download_24_regular,
          iconFilled: FluentIcons.arrow_download_24_filled,
          label: offlineLabel,
          index: 4,
          selectedIndex: selectedIndex,
          onTap: () => navigationShell.goBranch(4),
        ),
      ],
    );
  }
}

class _MuzoNavItem extends StatelessWidget {
  const _MuzoNavItem({
    required this.iconRegular,
    required this.iconFilled,
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
  });

  final IconData iconRegular;
  final IconData iconFilled;
  final String label;
  final int index;
  final int selectedIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
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
                    Theme.of(context)
                        .primaryColor
                        .withValues(alpha: isDark ? 0.15 : 0.10),
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
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
              size: 18,
            ),
            const SizedBox(height: 0.5),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
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

class _MuzoSearchTextField extends ConsumerWidget {
  const _MuzoSearchTextField({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(searchControllerProvider);
    final focusNode = ref.watch(searchFocusNodeProvider);

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
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.4),
            fontWeight: FontWeight.w500,
          ),
          filled: false,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 0, right: 8),
            child: Icon(
              FluentIcons.search_24_regular,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
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
            if (navigationShell.currentIndex != 2) {
              navigationShell.goBranch(2);
            }
          }
        },
      ),
    );
  }
}
