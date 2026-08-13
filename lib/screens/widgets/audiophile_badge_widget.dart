import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class AudiophileBadgeWidget extends StatelessWidget {
  final String label;
  final bool isHiRes;
  final bool isDsd;
  final double fontSize;

  const AudiophileBadgeWidget({
    super.key,
    required this.label,
    this.isHiRes = false,
    this.isDsd = false,
    this.fontSize = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = isDsd
        ? const Color(0xFFFFD700)
        : (isHiRes ? const Color(0xFF00E5FF) : const Color(0xFF10B981));
    final Color backgroundColor = primaryColor.withValues(alpha: 0.15);
    final Color borderColor = primaryColor.withValues(alpha: 0.4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.2),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDsd
                ? MingCute.award_line
                : (isHiRes ? MingCute.disc_line : MingCute.music_2_line),
            size: fontSize + 2,
            color: primaryColor,
          ),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: primaryColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
