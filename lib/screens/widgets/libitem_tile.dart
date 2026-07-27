// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:voidmusic/blocs/media_player/bloomee_player_cubit.dart';
import 'package:voidmusic/utils/load_image.dart';
import 'package:flutter/material.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';

enum LibItemTypes {
  userPlaylist,
  onlPlaylist,
  artist,
  album,
}

class LibItemCard extends StatelessWidget {
  final String title;
  final String coverArt;
  final String subtitle;
  final LibItemTypes type;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMenuTap;
  final bool showMenuButton;
  final bool isPinned;
  const LibItemCard({
    Key? key,
    required this.title,
    required this.coverArt,
    required this.subtitle,
    this.type = LibItemTypes.userPlaylist,
    this.onTap,
    this.onSecondaryTap,
    this.onLongPress,
    this.onMenuTap,
    this.showMenuButton = false,
    this.isPinned = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: StreamBuilder<String>(
        stream: context
            .watch<BloomeePlayerCubit>()
            .bloomeePlayer
            .queueTitle,
        builder: (context, snapshot) {
          final isPlaying = snapshot.hasData && snapshot.data == title;
          return InkWell(
            splashColor: colorScheme.onSurface.withValues(alpha: 0.08),
            hoverColor: colorScheme.onSurface.withValues(alpha: 0.05),
            highlightColor: colorScheme.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            onTap: onTap ?? () {},
            onSecondaryTap: onSecondaryTap ?? () {},
            onLongPress: onLongPress ?? () {},
            child: Container(
              height: 80,
              decoration: isPlaying
                  ? AppTheme.liquidGlassDecoration(
                      borderRadius: 16,
                      glassColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.04),
                      borderColor: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.10),
                    )
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  type == LibItemTypes.userPlaylist
                      ? isPlaying
                          ? Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(
                                FontAwesome.chart_simple_solid,
                                color: Default_Theme.primaryColor2
                                    .withValues(alpha: 1),
                                size: 15,
                              ),
                            )
                          : const SizedBox.shrink()
                      : const SizedBox.shrink(),
                  Padding(
                    padding: const EdgeInsets.only(left: 10, right: 10),
                    child: SizedBox.square(
                      dimension: 70,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: switch (type) {
                          LibItemTypes.userPlaylist => LoadImageCached(
                              imageUrl: coverArt, fallbackUrl: coverArt.toString()),
                          LibItemTypes.onlPlaylist => LoadImageCached(
                              imageUrl: coverArt, fallbackUrl: coverArt.toString()),
                          LibItemTypes.artist => ClipOval(
                              child: LoadImageCached(
                                  imageUrl: coverArt,
                                  fallbackUrl: coverArt.toString()),
                            ),
                          LibItemTypes.album => LoadImageCached(
                              imageUrl: coverArt, fallbackUrl: coverArt.toString()),
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: Default_Theme.secondoryTextStyle.merge(
                              TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface)),
                        ),
                        Row(
                          children: [
                            if (isPinned) ...[
                              Icon(
                                MingCute.pin_2_fill,
                                size: 12,
                                color: Default_Theme.accentColor2
                                    .withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                style: Default_Theme.secondoryTextStyle.merge(
                                    TextStyle(
                                        fontSize: 14,
                                        overflow: TextOverflow.fade,
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.onSurface.withValues(alpha: 0.65))),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (showMenuButton)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: IconButton(
                        onPressed: onMenuTap,
                        splashRadius: 20,
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 20,
                          color: colorScheme.onSurface.withValues(alpha: 0.60),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
