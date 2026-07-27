import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voidmusic/blocs/settings_cubit/cubit/settings_cubit.dart';
import 'package:voidmusic/core/theme/app_theme.dart';

/// A segmented 3-way toggle for choosing the app theme:
/// System (auto) | Light | Dark
class ThemeSwitchTile extends StatelessWidget {
  const ThemeSwitchTile({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (prev, curr) => prev.themeMode != curr.themeMode,
      builder: (context, state) {
        final current = state.themeMode;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon box
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _iconFor(current),
                  size: 20,
                  color: isDark ? Colors.white : AppTheme.lightPrimaryText,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Theme',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.92)
                            : AppTheme.lightPrimaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Gilroy',
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Choose light, dark, or follow system',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.40)
                            : AppTheme.lightSecondaryText,
                        fontSize: 12,
                        fontFamily: 'Gilroy',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 3-segment control
              _ThemeSegmentedControl(
                current: current,
                isDark: isDark,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  context.read<SettingsCubit>().setThemeMode(v);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _iconFor(String mode) {
    switch (mode) {
      case 'light':
        return Icons.light_mode_rounded;
      case 'dark':
        return Icons.dark_mode_rounded;
      default:
        return Icons.brightness_auto_rounded;
    }
  }
}

class _ThemeSegmentedControl extends StatelessWidget {
  final String current;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const _ThemeSegmentedControl({
    required this.current,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final segments = const [
      _Segment(value: 'system', icon: Icons.brightness_auto_rounded, label: 'Auto'),
      _Segment(value: 'light', icon: Icons.light_mode_rounded, label: 'Light'),
      _Segment(value: 'dark', icon: Icons.dark_mode_rounded, label: 'Dark'),
    ];

    // Theme-aware glass colors matching footer and mini player
    final glassColor = isDark
        ? Colors.black.withValues(alpha: 0.40)
        : Colors.white.withValues(alpha: 0.70);
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.10);
    final selectedBg = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.08);
    final selectedBorder = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.12);
    final selectedColor = isDark ? Colors.white : AppTheme.lightPrimaryText;
    final unselectedColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : AppTheme.lightSecondaryText;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: 30,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: glassBorder,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: segments.map((seg) {
              final isSelected = current == seg.value;
              return GestureDetector(
                onTap: () => onChanged(seg.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected ? selectedBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: isSelected
                        ? Border.all(color: selectedBorder, width: 1.0)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        seg.icon,
                        size: 13,
                        color: isSelected ? selectedColor : unselectedColor,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        seg.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontFamily: 'Gilroy',
                          color: isSelected ? selectedColor : unselectedColor,
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
    );
  }
}

class _Segment {
  final String value;
  final IconData icon;
  final String label;
  const _Segment({required this.value, required this.icon, required this.label});
}
