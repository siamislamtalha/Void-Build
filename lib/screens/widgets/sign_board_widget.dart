import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class SignBoardWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  const SignBoardWidget({
    Key? key,
    required this.message,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: AppTheme.liquidGlassDecoration(
            borderRadius: 20,
            glassColor: isDark
                ? const Color(0x1A120B16)
                : Colors.white.withValues(alpha: 0.6),
            borderColor: isDark
                ? const Color(0x2DFFFFFF)
                : Colors.black.withValues(alpha: 0.08),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Default_Theme.tertiaryTextStyle.merge(TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
