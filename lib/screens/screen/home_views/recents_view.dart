// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:voidmusic/blocs/history/cubit/history_cubit.dart';
import 'package:voidmusic/blocs/media_player/voidmusic_player_cubit.dart';
import 'package:voidmusic/core/models/media_playlist_model.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/storage_setting.dart';
import 'package:voidmusic/screens/widgets/more_bottom_sheet.dart';
import 'package:voidmusic/screens/widgets/song_tile.dart';
import 'package:voidmusic/screens/widgets/bottom_safe_area_spacer.dart';
import 'package:flutter/material.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voidmusic/l10n/app_localizations.dart';
import 'package:icons_plus/icons_plus.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                MingCute.settings_1_line,
                color: AppTheme.accentColor(context),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BackupSettings(),
                  ),
                );
              },
            ),
          ],
          title: Text(
            l10n.recentsTitle,
            style: Default_Theme.secondoryTextStyle.merge(
              TextStyle(
                color: AppTheme.accentColor(context),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        body: BlocBuilder<HistoryCubit, HistoryState>(
          builder: (context, state) {
            return (state is HistoryInitial)
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : ListView.builder(
                    itemCount: state.tracks.length + 1,
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      if (index < state.tracks.length) {
                        return SongCardWidget(
                          song: state.tracks[index],
                          onTap: () {
                            context
                                .read<VoidMusicPlayerCubit>()
                                .voidMusicPlayer
                                .loadPlaylist(
                                    Playlist(
                                        tracks: state.tracks, title: 'History'),
                                    idx: index,
                                    doPlay: true);
                          },
                          onOptionsTap: () =>
                              showMoreBottomSheet(context, state.tracks[index]),
                        );
                      }
                      return const BottomSafeAreaSpacer();
                    },
                  );
          },
        ),
      ),
    );
  }

  ListTile settingListTile(
      BuildContext context, {
      required String title,
      required String subtitle,
      required IconData icon,
      VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(
        icon,
        size: 30,
        color: AppTheme.accentColor(context),
      ),
      title: Text(
        title,
        style: Default_Theme.secondoryTextStyleMedium.merge(
          TextStyle(
            color: AppTheme.accentColor(context),
            fontSize: 17,
          ),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Default_Theme.secondoryTextStyleMedium.merge(
          TextStyle(
            color: AppTheme.secondaryTextColor(context),
            fontSize: 12.5,
          ),
        ),
      ),
      onTap: () {
        if (onTap != null) {
          onTap();
        }
      },
    );
  }
}
