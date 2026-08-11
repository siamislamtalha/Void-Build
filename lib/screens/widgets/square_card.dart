import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:voidmusic/services/audiophile_mode_service.dart';
import 'package:voidmusic/utils/load_image.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class SquareImgCard extends StatefulWidget {
  final String imgPath;
  final String? fallbackImgPath;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? tag;
  final bool isWide;
  final bool isList;
  /// Optional quality label (e.g. 'FLAC', 'HD FLAC', 'DSD').
  /// When null and in audiophile mode, a generic 'FLAC' badge is shown.
  /// Pass empty string to suppress the badge entirely.
  final String? qualityLabel;

  const SquareImgCard({
    super.key,
    required this.imgPath,
    this.fallbackImgPath,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.isWide = false,
    this.tag,
    this.isList = true,
    this.qualityLabel,
  });

  @override
  State<SquareImgCard> createState() => _SquareImgCardState();
}

class _SquareImgCardState extends State<SquareImgCard> {
  bool _pressed = false;

  bool get _isInteractive => widget.onTap != null;

  void _setPressed(bool value) {
    if (!_isInteractive || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _onTapDown(TapDownDetails _) => _setPressed(true);
  void _onTapUp(TapUpDetails _) => _setPressed(false);
  void _onTapCancel() => _setPressed(false);

  /// Determines badge label and colors for audiophile quality overlay.
  ({String label, Color border, Color text})? _resolveQualityBadge() {
    // qualityLabel == '' means explicitly suppressed
    if (widget.qualityLabel == '') return null;

    final label = widget.qualityLabel ??
        (AudiophileModeService.isAudiophile ? 'FLAC' : null);
    if (label == null) return null;

    final upper = label.toUpperCase();
    if (upper.contains('DSD')) {
      return (
        label: label,
        border: const Color(0xFF9D4EDD),
        text: const Color(0xFFE0AAFF),
      );
    }
    if (upper.contains('HD') ||
        upper.contains('HI-RES') ||
        upper.contains('MASTER') ||
        upper.contains('ATMOS')) {
      return (
        label: label,
        border: const Color(0xFFFFB703),
        text: const Color(0xFFFFD166),
      );
    }
    return (
      label: label,
      border: const Color(0xFF707070),
      text: const Color(0xFFC0C0C0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badge = _resolveQualityBadge();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: _isInteractive ? _onTapDown : null,
        onTapUp: _isInteractive ? _onTapUp : null,
        onTapCancel: _isInteractive ? _onTapCancel : null,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _pressed ? 0.85 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: SizedBox(
              width: widget.isWide ? 250 : 150,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(children: [
                      SizedBox(
                        height: 150,
                        width: widget.isWide ? 250 : 150,
                        child: LoadImageCached(
                          imageUrl: widget.imgPath,
                          fallbackUrl: widget.fallbackImgPath,
                        ),
                      ),
                      // ── Audiophile quality badge (top-left) ──
                      if (badge != null)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: badge.border.withValues(alpha: 0.7),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              badge.label,
                              style: TextStyle(
                                color: badge.text,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                      // ── Tag badge (playlist count / views, top-right) ──
                      Visibility(
                        visible: widget.tag != null,
                        child: Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Color(0xCC161618),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(18),
                              ),
                            ),
                            child: widget.isList
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(right: 5),
                                        child: Icon(
                                          MingCute.playlist_2_line,
                                          size: 18,
                                          color: Default_Theme.primaryColor2,
                                        ),
                                      ),
                                      Text(
                                        "${widget.tag}",
                                        style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    Default_Theme.primaryColor2)
                                            .merge(Default_Theme
                                                .secondoryTextStyle),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(right: 5),
                                        child: Icon(
                                          MingCute.eye_2_line,
                                          size: 18,
                                          color: Default_Theme.primaryColor2,
                                        ),
                                      ),
                                      Text(
                                        "${widget.tag}",
                                        style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    Default_Theme.primaryColor2)
                                            .merge(Default_Theme
                                                .secondoryTextStyle),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 32,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Default_Theme.secondoryTextStyle.merge(
                            TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style:
                              Default_Theme.secondoryTextStyle.merge(TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface
                                .withValues(alpha: 0.55),
                            height: 1.1,
                          )),
                        ),
                      ],
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
}
