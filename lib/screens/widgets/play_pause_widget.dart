// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class PlayPauseButton extends StatefulWidget {
  final double size;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final bool isPlaying;
  const PlayPauseButton({
    super.key,
    this.size = 60,
    this.onPlay,
    this.onPause,
    this.isPlaying = false,
  });
  @override
  State<PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<PlayPauseButton> {
  void _togglePlayPause() {
    if (widget.isPlaying) {
      widget.onPause?.call();
    } else {
      widget.onPlay?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: 2,
            )
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: animation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: widget.isPlaying
                ? Icon(
                    FontAwesome.pause_solid,
                    key: const ValueKey('pause'),
                    size: size * 0.45,
                    color: Colors.black,
                  )
                : Icon(
                    FontAwesome.play_solid,
                    key: const ValueKey('play'),
                    size: size * 0.45,
                    color: Colors.black,
                  ),
          ),
        ),
      ),
    );
  }
}
