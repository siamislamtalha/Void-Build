import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:voidmusic/blocs/mini_player/mini_player_cubit.dart';
import 'package:voidmusic/blocs/player_overlay/player_overlay_cubit.dart';
import 'package:voidmusic/blocs/media_player/voidmusic_player_cubit.dart';

/// Exact Muzo Mini Player widget adapted to voidmusic's state engine.
class MuzoMiniPlayer extends StatelessWidget {
  final int? currentPageIndex;

  const MuzoMiniPlayer({
    super.key,
    this.currentPageIndex,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
      builder: (context, state) {
        if (!state.isVisible || state.track == null) {
          return const SizedBox.shrink();
        }

        final track = state.track!;
        final imageUrl = track.thumbnail.urlLow ?? track.thumbnail.url;
        final title = track.title;
        final artist = track.artists.isNotEmpty ? track.artists.map((a) => a.name).join(', ') : '';
        final isPlaying = state.isPlaying;
        final isLoading = state.isLoading || state.isResolving;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            context.read<PlayerOverlayCubit>().showPlayer(
                  fromPageIndex: currentPageIndex,
                );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 4.0,
            ),
            child: Row(
              children: [
                const SizedBox(width: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 32,
                    width: 32,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[800],
                      child: Icon(
                        FluentIcons.music_note_2_24_regular,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (artist.isNotEmpty) ...[
                        const SizedBox(height: 0.5),
                        Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Play / Pause Button
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  )
                else
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final player = context.read<VoidMusicPlayerCubit>().voidMusicPlayer;
                      if (isPlaying) {
                        player.pause();
                      } else {
                        player.play();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        isPlaying
                            ? FluentIcons.pause_24_filled
                            : FluentIcons.play_24_filled,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 20,
                      ),
                    ),
                  ),
                // Skip Next Button
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.read<VoidMusicPlayerCubit>().voidMusicPlayer.skipToNext();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      CupertinoIcons.forward_fill,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
