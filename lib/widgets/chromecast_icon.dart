import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ChromecastIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const ChromecastIcon({
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).colorScheme.onSurface;
    
    return SvgPicture.asset(
      'svg/chromecast.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
    );
  }
}
