import 'package:flutter/material.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:icons_plus/icons_plus.dart';

class LikeBtnWidget extends StatefulWidget {
  final bool isLiked;
  final bool isPlaying;
  final double iconSize;
  final VoidCallback? onLiked;
  final VoidCallback? onDisliked;
  const LikeBtnWidget({
    Key? key,
    this.isLiked = false,
    this.isPlaying = false,
    this.iconSize = 50,
    this.onLiked,
    this.onDisliked,
  }) : super(key: key);

  @override
  State<LikeBtnWidget> createState() => _LikeBtnWidgetState();
}

class _LikeBtnWidgetState extends State<LikeBtnWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _colorController;

  @override
  void initState() {
    super.initState();
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    if (widget.isPlaying) {
      _colorController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant LikeBtnWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _colorController.forward();
      } else {
        _colorController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = AppTheme.accentColor(context);
    final inactiveColor = AppTheme.secondaryTextColor(context);
    final iconColor = widget.isLiked ? activeColor : inactiveColor;

    return IconButton(
      onPressed: () {
        if (widget.isLiked) {
          widget.onDisliked?.call();
        } else {
          widget.onLiked?.call();
        }
      },
      icon: Icon(
        widget.isLiked ? AntDesign.heart_fill : AntDesign.heart_outline,
        color: iconColor,
        size: widget.iconSize,
      ),
    );
  }
}
