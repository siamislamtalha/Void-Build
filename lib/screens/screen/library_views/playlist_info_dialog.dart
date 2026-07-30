part of 'playlist_screen.dart';

class InfoTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color fg;
  final Function()? onTap;
  const InfoTile({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.fg = Default_Theme.primaryColor1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      dense: true,
      title: Text(
        title,
        style: Default_Theme.secondoryTextStyle.merge(
          TextStyle(
              color: fg.withValues(alpha: 0.5),
              fontSize: 13,
              fontFamily: 'Unageo'),
        ),
      ),
      hoverColor: Colors.transparent,
      selectedColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      subtitle: SelectableText(
        subtitle,
        style: Default_Theme.secondoryTextStyle.merge(
          TextStyle(color: fg, fontSize: 15, fontFamily: 'NotoSans'),
        ),
      ),
      leading: Icon(
        icon,
        size: 20,
        color: fg,
      ),
    );
  }
}

String getArtists(List<Track> tracks) {
  String artists = "";
  List<String> artistList = [];

  for (int i = 0; i < tracks.length; i++) {
    final trackArtists = tracks[i].artists.map((a) => a.name).toList();
    artistList.addAll(trackArtists);
    if (artistList.length > 4) {
      break;
    }
  }
  artists = artistList.toSet().join(", ");
  artists = "$artists +";
  return artists;
}

Future<dynamic> showPlaylistInfo(
  BuildContext context,
  CurrentPlaylistState state, {
  Color? bgColor,
  Color? fgColor,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final resolvedBgColor = bgColor ?? (isDark ? const Color.fromARGB(255, 15, 0, 19) : Theme.of(context).colorScheme.surface);
  final resolvedFgColor = fgColor ?? (isDark ? Default_Theme.primaryColor1 : const Color(0xFF1C1C1E));
  
  final finalBgColor = resolvedBgColor == Colors.black ? const Color.fromARGB(255, 15, 0, 19) : resolvedBgColor;
  final finalFgColor = resolvedFgColor == Colors.white ? Default_Theme.primaryColor1 : resolvedFgColor;
  return showDialog(
    context: context,
    useSafeArea: true,
    barrierDismissible: true,
    builder: (context) {
      return Dialog(
          backgroundColor: finalBgColor,
          shadowColor: finalBgColor,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text(
                        state.playlist.title,
                        style: Default_Theme.secondoryTextStyle.merge(
                          TextStyle(
                              color: finalFgColor,
                              fontSize: 16,
                              fontFamily: 'NotoSans',
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    InfoTile(
                      title: "Playlist Length",
                      subtitle: state.playlist.tracks.length.toString(),
                      icon: MingCute.playlist_2_line,
                      fg: finalFgColor,
                    ),
                    InfoTile(
                      title: "Artists",
                      subtitle: state.playlist.artists != null
                          ? state.playlist.artists!
                              .map((a) => a.name)
                              .join(', ')
                          : getArtists(state.playlist.tracks),
                      icon: MingCute.group_fill,
                      fg: finalFgColor,
                    ),
                    state.playlist.description != null
                        ? InfoTile(
                            title: "Description",
                            subtitle: state.playlist.description!,
                            icon: MingCute.document_2_line,
                            fg: finalFgColor,
                          )
                        : const SizedBox.shrink(),
                    state.playlist.updatedAt != null
                        ? InfoTile(
                            title: "Last Updated",
                            subtitle:
                                state.playlist.updatedAt?.toIso8601String() ??
                                    "",
                            icon: MingCute.history_line,
                            fg: finalFgColor,
                          )
                        : const SizedBox.shrink(),
                    state.playlist.permaURL != null
                        ? InfoTile(
                            title: "Original URL",
                            subtitle: state.playlist.permaURL!,
                            icon: MingCute.external_link_line,
                            fg: finalFgColor,
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                  text: state.playlist.permaURL!));
                              SnackbarService.showMessage(
                                  "URL Copied to Clipboard");
                            },
                          )
                        : const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ));
    },
  );
}
