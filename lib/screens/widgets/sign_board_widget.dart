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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: AppTheme.liquidGlassDecoration(
            borderRadius: 20,
            glassColor: const Color(0x1A120B16),
            borderColor: const Color(0x2DFFFFFF),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: Default_Theme.primaryColor2.withValues(alpha: 0.7),
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Default_Theme.tertiaryTextStyle.merge(TextStyle(
                    color: Default_Theme.primaryColor2.withValues(alpha: 0.7),
                    fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
