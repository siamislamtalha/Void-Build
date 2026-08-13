import 'dart:developer';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:voidmusic/blocs/explore/cubit/explore_cubits.dart';
import 'package:voidmusic/blocs/internet_connectivity/cubit/connectivity_cubit.dart';
import 'package:voidmusic/blocs/lastdotfm/lastdotfm_cubit.dart';
import 'package:voidmusic/blocs/media_player/voidmusic_player_cubit.dart';
import 'package:voidmusic/blocs/notification/notification_cubit.dart';
import 'package:voidmusic/blocs/settings_cubit/cubit/settings_cubit.dart';
import 'package:voidmusic/core/di/service_locator.dart';
import 'package:voidmusic/core/models/exported.dart';
import 'package:voidmusic/core/models/media_playlist_model.dart';
import 'package:voidmusic/plugins/blocs/content/content_bloc.dart';
import 'package:voidmusic/plugins/blocs/content/content_event.dart';
import 'package:voidmusic/plugins/blocs/content/content_state.dart';
import 'package:voidmusic/plugins/blocs/plugin/plugin_bloc.dart';
import 'package:voidmusic/plugins/blocs/plugin/plugin_state.dart';
import 'package:voidmusic/screens/screen/home_views/recents_view.dart';
import 'package:voidmusic/screens/widgets/more_bottom_sheet.dart';
import 'package:voidmusic/screens/widgets/sign_board_widget.dart';
import 'package:voidmusic/screens/widgets/bottom_safe_area_spacer.dart';
import 'package:voidmusic/screens/widgets/song_tile.dart';
import 'package:voidmusic/screens/widgets/source_badge.dart';
import 'package:voidmusic/screens/widgets/square_card.dart';
import 'package:voidmusic/screens/screen/common_views/playlist_view.dart';
import 'package:voidmusic/src/rust/api/plugin/plugin_info.dart';
import 'package:flutter/material.dart';
import 'package:voidmusic/screens/screen/home_views/notification_view.dart';
import 'package:voidmusic/screens/screen/home_views/setting_view.dart';
import 'package:voidmusic/screens/screen/home_views/timer_view.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:voidmusic/l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'chart/carousal_widget.dart';
import '../widgets/horizontal_card_view.dart';
import '../widgets/tab_list_widget.dart';
import 'package:badges/badges.dart' as badges;
import 'package:voidmusic/screens/screen/audiophile/audiophile_shell.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool isUpdateChecked = false;
  late final ContentBloc _homeContentBloc;
  Future<List<Track>> lFMData = Future.value(const []);
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _homeContentBloc = ContentBloc(pluginService: ServiceLocator.pluginService);
    // Use addPostFrameCallback so context.read is safe, and so we always
    // try to load home sections even if settings+plugins were already ready
    // before this screen was built (e.g. navigating back to home screen).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tryLoadHomeSections();
    });
  }

  /// Only loads home sections when both settings are ready and plugins are loaded.
  /// If the user's preferred plugin is installed but not yet loaded, waits for it
  /// to avoid flashing the wrong plugin's home page on startup.
  void _tryLoadHomeSections() {
    final settingsState = context.read<SettingsCubit>().state;
    if (!settingsState.settingsReady) return;

    final pluginState = context.read<PluginBloc>().state;
    final contentResolvers = pluginState.loadedContentResolvers;
    if (contentResolvers.isEmpty) return;

    // If the user's preferred plugin(s) are installed but not yet loaded, wait
    // for them. This prevents flashing the wrong plugin's home page on startup.
    final preferredIds = settingsState.homePluginIds;
    if (preferredIds.isNotEmpty) {
      for (final preferredId in preferredIds) {
        final isAlreadyLoaded =
            contentResolvers.any((p) => p.manifest.id == preferredId);
        if (!isAlreadyLoaded) {
          final isInstalled = pluginState.availablePlugins
              .any((p) => p.manifest.id == preferredId);
          if (isInstalled) return; // Preferred plugin is loading — wait for it
        }
      }
    }

    final pluginId = _effectiveHomePluginId(contentResolvers);

    // Don't reload if we're already showing content from this plugin.
    if (_homeContentBloc.state.activePluginId == pluginId &&
        _homeContentBloc.state.homeSections != null) {
      return;
    }

    _homeContentBloc.add(GetHomeSections(pluginId: pluginId));
  }

  String _effectiveHomePluginId(List<dynamic> loadedResolvers) {
    final preferredIds = context.read<SettingsCubit>().state.homePluginIds;
    if (preferredIds.isNotEmpty) {
      for (final preferredId in preferredIds) {
        final hasPreferred =
            loadedResolvers.any((plugin) => plugin.manifest.id == preferredId);
        if (hasPreferred) return preferredId;
      }
    }
    return loadedResolvers.first.manifest.id;
  }

  @override
  void dispose() {
    _scrollOffsetNotifier.dispose();
    _homeContentBloc.close();
    super.dispose();
  }

  Future<List<Track>> fetchLFMPicks(bool state, BuildContext ctx) async {
    if (state) {
      try {
        final data = await lFMData;
        if (data.isNotEmpty) return data;
        if (ctx.mounted) {
          final pluginState = ctx.read<PluginBloc>().state;
          final priority = ctx.read<SettingsCubit>().state.resolverPriority;
          final allIds = pluginState.loadedContentResolvers
              .map((p) => p.manifest.id)
              .toList();
          final resolverIds = [
            ...priority.where(allIds.contains),
            ...allIds.where((id) => !priority.contains(id)),
          ];
          lFMData = ctx.read<LastdotfmCubit>().getRecommendedTracks(
                resolverPluginIds: resolverIds,
              );
        }
        return (await lFMData);
      } catch (e) {
        log(e.toString(), name: "ExploreScreen");
      }
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
        listeners: [
          BlocListener<SettingsCubit, SettingsState>(
            listenWhen: (previous, current) =>
                !listEquals(previous.homePluginIds, current.homePluginIds) ||
                (!previous.settingsReady && current.settingsReady),
            listener: (context, state) {
              _homeContentBloc.add(const ClearHomeSections());
              _tryLoadHomeSections();
            },
          ),
          BlocListener<PluginBloc, PluginState>(
            listenWhen: (previous, current) {
              return previous.loadedContentResolvers !=
                      current.loadedContentResolvers ||
                  previous.loadedPluginIds != current.loadedPluginIds;
            },
            listener: (context, state) {
              if (state.loadedContentResolvers.isEmpty) {
                _homeContentBloc.add(const ClearHomeSections());
                return;
              }

              final activePluginId = _homeContentBloc.state.activePluginId;
              if (activePluginId != null &&
                  !state.loadedPluginIds.contains(activePluginId)) {
                // Active plugin was unloaded — reload from preferred.
                _homeContentBloc.add(const ClearHomeSections());
                _tryLoadHomeSections();
                return;
              }

              // Plugin list changed — check if preferred plugin is different.
              _tryLoadHomeSections();
            },
          ),
        ],
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: RefreshIndicator(
            onRefresh: () async {
              final pluginId = _effectiveHomePluginId(
                context.read<PluginBloc>().state.loadedContentResolvers,
              );
              _homeContentBloc.add(
                GetHomeSections(pluginId: pluginId, bypassCache: true),
              );
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.depth == 0) {
                  _scrollOffsetNotifier.value = notification.metrics.pixels;
                }
                return false;
              },
              child: CustomScrollView(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                slivers: [
                  CustomDiscoverBar(
                    scrollOffsetNotifier: _scrollOffsetNotifier,
                  ),
                SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      const CaraouselWidget(),
                      Padding(
                        padding: const EdgeInsets.only(top: 15.0),
                        child: SizedBox(
                          child: BlocBuilder<RecentlyCubit, RecentlyCubitState>(
                            builder: (context, state) {
                              if (state is RecentlyCubitInitial) {
                                return Center(
                                  child: SizedBox(
                                    height: 60,
                                    width: 60,
                                    child: CircularProgressIndicator(
                                      color: AppTheme.accentColor(context),
                                    ),
                                  ),
                                );
                              }
                              if (state.tracks.isNotEmpty) {
                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const HistoryView(),
                                      ),
                                    );
                                  },
                                  child: TabSongListWidget(
                                    list: state.tracks.map((e) {
                                      return SongCardWidget(
                                        song: e,
                                        onTap: () {
                                          context
                                              .read<VoidMusicPlayerCubit>()
                                              .voidMusicPlayer
                                              .loadPlaylist(
                                                Playlist(
                                                  tracks: state.tracks,
                                                  title: 'Recently',
                                                ),
                                                idx: state.tracks.indexOf(e),
                                                doPlay: true,
                                              );
                                        },
                                        onOptionsTap: () => showMoreBottomSheet(
                                          context,
                                          e,
                                          showSinglePlay: true,
                                        ),
                                      );
                                    }).toList(),
                                    category: AppLocalizations.of(context)!
                                        .exploreRecently,
                                    columnSize: 3,
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      BlocBuilder<SettingsCubit, SettingsState>(
                        builder: (context, state) {
                          if (state.lFMPicks) {
                            return FutureBuilder(
                              future: fetchLFMPicks(state.lFMPicks, context),
                              builder: (context, snapshot) {
                                if (snapshot.hasData &&
                                    (snapshot.data?.isNotEmpty ?? false)) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 15.0),
                                    child: TabSongListWidget(
                                      list: snapshot.data!.map((e) {
                                        return SongCardWidget(
                                          song: e,
                                          onTap: () {
                                            context
                                                .read<VoidMusicPlayerCubit>()
                                                .voidMusicPlayer
                                                .loadPlaylist(
                                                  Playlist(
                                                    tracks: snapshot.data!,
                                                    title: 'Last.Fm Picks',
                                                  ),
                                                  idx:
                                                      snapshot.data!.indexOf(e),
                                                  doPlay: true,
                                                );
                                          },
                                          onOptionsTap: () =>
                                              showMoreBottomSheet(
                                                  context,
                                                  showSinglePlay: true,
                                                  e),
                                        );
                                      }).toList(),
                                      category: AppLocalizations.of(context)!
                                          .exploreLastFmPicks,
                                      columnSize: 3,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      // Home sections from plugin (Old App List - shown first)
                      BlocBuilder<ContentBloc, ContentState>(
                        bloc: _homeContentBloc,
                        builder: (context, state) {
                          final loadedResolvers = context
                              .read<PluginBloc>()
                              .state
                              .loadedContentResolvers;
                          if (loadedResolvers.isEmpty) {
                            return const SignBoardWidget(
                              message:
                                  'No content plugin loaded.\nLoad a Content Resolver in Plugin Manager.',
                              icon: MingCute.plugin_2_line,
                            );
                          }

                          final sections = state.homeSections ?? const [];
                          final hasSections = sections.isNotEmpty;
                          final activePluginId = state.activePluginId;
                          if (activePluginId != null &&
                              !context
                                  .read<PluginBloc>()
                                  .state
                                  .loadedPluginIds
                                  .contains(activePluginId) &&
                              !hasSections) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: SignBoardWidget(
                                message:
                                    'Refreshing Discover source...\nThe previous source is no longer available.',
                                icon: MingCute.warning_line,
                              ),
                            );
                          }

                          if (state.homeSectionsStatus ==
                              DetailStatus.loading) {
                            if (hasSections) {
                              return _HomeSectionsList(
                                sections: sections,
                                contentBloc: _homeContentBloc,
                                state: state,
                              );
                            }

                            return BlocBuilder<ConnectivityCubit,
                                ConnectivityState>(
                              builder: (context, connState) {
                                if (connState ==
                                    ConnectivityState.disconnected) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: SignBoardWidget(
                                      message: 'No Internet Connection!',
                                      icon: MingCute.wifi_off_line,
                                    ),
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 40),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.accentColor(context),
                                    ),
                                  ),
                                );
                              },
                            );
                          }

                          if (state.homeSectionsStatus == DetailStatus.error) {
                            if (hasSections) {
                              return _HomeSectionsList(
                                sections: sections,
                                contentBloc: _homeContentBloc,
                                state: state,
                              );
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: SignBoardWidget(
                                message: state.error ??
                                    'Failed to load home sections.',
                                icon: MingCute.sweats_line,
                              ),
                            );
                          }

                          if (!hasSections) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: SizedBox.shrink(),
                            );
                          }

                          return _HomeSectionsList(
                            sections: sections,
                            contentBloc: _homeContentBloc,
                            state: state,
                          );
                        },
                      ),
                      // Playlist Suggestions (New App List - shown after Old App List)
                      const _PlaylistSuggestionsSection(),
                      // ── Multi-source Song Suggestions (New App List - shown after Playlist Suggestions)
                      // One horizontal row per loaded content-resolver plugin,
                      // showing only Track items from that plugin's home sections.
                      // Rows that yield zero tracks are hidden automatically.
                      const _MultiSourceSongSuggestions(),
                    ],
                  ),
                ),
                const SliverBottomSafeAreaSpacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeSectionsList extends StatelessWidget {
  final List<Section> sections;
  final ContentBloc contentBloc;
  final ContentState state;

  const _HomeSectionsList({
    required this.sections,
    required this.contentBloc,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemExtent: 275,
      padding: const EdgeInsets.only(top: 0),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return HorizontalCardView(
          section: section,
          pluginId: contentBloc.state.activePluginId ?? '',
          canLoadMore: section.moreLink != null,
          isLoadingMore: state.isHomeSectionLoading(section.id),
          onLoadMore: section.moreLink == null
              ? null
              : () {
                  contentBloc.add(
                    LoadMoreHomeSectionItems(
                      pluginId: contentBloc.state.activePluginId ?? '',
                      sectionId: section.id,
                      moreLink: section.moreLink!,
                    ),
                  );
                },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Multi-Source Song Suggestions
// ─────────────────────────────────────────────────────────────────────────────

/// Renders one `_PluginSongSection` per loaded content-resolver plugin.
/// Sections that yield zero tracks are silently omitted.
// ─────────────────────────────────────────────────────────────────────────────
// Multi-Source Song Suggestions
// ─────────────────────────────────────────────────────────────────────────────

/// Maps plugin ID to friendly source name
String _getFriendlySourceName(String pluginId, String pluginName) {
  final id = pluginId.toLowerCase();
  if (id.contains('ytmusic') || id.contains('youtube_music') || id.contains('youtubemusic')) {
    return 'YouTube Music';
  } else if (id.contains('ytvideo')) {
    return 'YouTube';
  } else if (id.contains('spotify')) {
    return 'Spotify';
  } else if (id.contains('jiosaavn') || id.contains('jio')) {
    return 'JioSaavn';
  }
  return pluginName;
}

// ─────────────────────────────────────────────────────────────────────────────
// Playlist Suggestions Section
// ─────────────────────────────────────────────────────────────────────────────

class _PlaylistSuggestionsSection extends StatefulWidget {
  const _PlaylistSuggestionsSection();

  @override
  State<_PlaylistSuggestionsSection> createState() => _PlaylistSuggestionsSectionState();
}

class _PlaylistSuggestionsSectionState extends State<_PlaylistSuggestionsSection> {
  late final ContentBloc _bloc;
  final Set<String> _seenPlaylistIds = {};

  @override
  void initState() {
    super.initState();
    _bloc = ContentBloc(pluginService: ServiceLocator.pluginService);
    _loadPlaylistsFromPlugins();
  }

  void _loadPlaylistsFromPlugins() {
    final pluginState = context.read<PluginBloc>().state;
    final resolvers = pluginState.loadedContentResolvers;
    
    if (resolvers.isNotEmpty) {
      // Load from the first available plugin
      _bloc.add(GetHomeSections(pluginId: resolvers.first.manifest.id));
    }
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  List<PlaylistSummary> _extractPlaylists(ContentState state) {
    final sections = state.homeSections ?? const [];
    final result = <PlaylistSummary>[];
    for (final section in sections) {
      for (final item in section.items) {
        item.when(
          track: (_) {},
          album: (_) {},
          artist: (_) {},
          playlist: (p) {
            if (!_seenPlaylistIds.contains(p.id)) {
              result.add(p);
              _seenPlaylistIds.add(p.id);
            }
          },
        );
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContentBloc, ContentState>(
      bloc: _bloc,
      builder: (context, state) {
        if (state.homeSectionsStatus == DetailStatus.loading &&
            (state.homeSections == null || state.homeSections!.isEmpty)) {
          return _buildLoadingSection(context);
        }

        if (state.homeSectionsStatus == DetailStatus.error) {
          return const SizedBox.shrink();
        }

        final playlists = _extractPlaylists(state);
        if (playlists.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    MingCute.music_2_line,
                    color: AppTheme.accentColor(context),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Playlist Suggestions',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: playlists.length > 20 ? 20 : playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  final pluginState = context.read<PluginBloc>().state;
                  final pluginId = pluginState.loadedContentResolvers.isNotEmpty
                      ? pluginState.loadedContentResolvers.first.manifest.id
                      : '';
                  
                  return SquareImgCard(
                    imgPath: playlist.thumbnail.url,
                    fallbackImgPath: playlist.thumbnail.url,
                    title: playlist.title,
                    subtitle: playlist.owner ?? '',
                    isList: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OnlPlaylistView(
                            playlist: playlist,
                            pluginId: pluginId,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            MingCute.music_2_line,
            color: AppTheme.accentColor(context),
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Playlist Suggestions',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders one `_PluginSongSection` per loaded content-resolver plugin.
/// Sections that yield zero tracks are silently omitted.
class _MultiSourceSongSuggestions extends StatefulWidget {
  const _MultiSourceSongSuggestions();

  @override
  State<_MultiSourceSongSuggestions> createState() => _MultiSourceSongSuggestionsState();
}

class _MultiSourceSongSuggestionsState extends State<_MultiSourceSongSuggestions> {
  final Set<String> _seenTrackIds = {};
  final Set<String> _seenPlaylistIds = {};

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PluginBloc, PluginState>(
      builder: (context, pluginState) {
        final resolvers = pluginState.loadedContentResolvers;
        if (resolvers.isEmpty) return const SizedBox.shrink();
        
        // Filter out universal-downloader and reorder with priority
        final filteredResolvers = resolvers.where((r) => 
          !r.manifest.id.toLowerCase().contains('universal')).toList();
        
        // Custom priority order: ytmusic > ytvideo > multi-source > others
        final priorityOrder = [
          (r) => r.manifest.id.toLowerCase().contains('ytmusic') || 
                 r.manifest.id.toLowerCase().contains('youtube_music'),
          (r) => r.manifest.id.toLowerCase().contains('ytvideo'),
          (r) => r.manifest.id.toLowerCase().contains('multi') || 
                 r.manifest.id.toLowerCase().contains('bloomfactory'),
        ];
        
        final orderedResolvers = [
          ...filteredResolvers.where((r) => priorityOrder[0](r)),
          ...filteredResolvers.where((r) => priorityOrder[1](r)),
          ...filteredResolvers.where((r) => priorityOrder[2](r)),
          ...filteredResolvers.where((r) => !priorityOrder.any((p) => p(r))),
        ];

        // Remove duplicates based on manifest id
        final uniqueResolvers = <PluginInfo>[];
        final seenIds = <String>{};
        for (final resolver in orderedResolvers) {
          if (!seenIds.contains(resolver.manifest.id)) {
            seenIds.add(resolver.manifest.id);
            uniqueResolvers.add(resolver);
          }
        }

        // Separate playlist sections and song sections
        final playlistSections = <Widget>[];
        final songSections = <Widget>[];

        for (final plugin in uniqueResolvers) {
          final pluginName = _getFriendlySourceName(plugin.manifest.id, plugin.manifest.name);
          
          // Add playlist section for this plugin
          playlistSections.add(
            _PluginPlaylistSection(
              pluginId: plugin.manifest.id,
              pluginName: pluginName,
              seenPlaylistIds: _seenPlaylistIds,
              key: ValueKey('playlist_${plugin.manifest.id}'),
            ),
          );
          
          // Add song section for this plugin
          songSections.add(
            _PluginSongSection(
              pluginId: plugin.manifest.id,
              pluginName: pluginName,
              seenTrackIds: _seenTrackIds,
              key: ValueKey('song_${plugin.manifest.id}'),
            ),
          );
        }
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Playlist suggestions at top
            ...playlistSections,
            // Song suggestions below
            ...songSections,
          ],
        );
      },
    );
  }
}

/// Fetches single songs for [pluginId], and renders them in a horizontal scroll row
/// styled like existing playlist cards.
/// Returns [SizedBox.shrink] if the plugin produces no single tracks or errors out.
class _PluginSongSection extends StatefulWidget {
  final String pluginId;
  final String pluginName;
  final Set<String> seenTrackIds;

  const _PluginSongSection({
    super.key,
    required this.pluginId,
    required this.pluginName,
    required this.seenTrackIds,
  });

  @override
  State<_PluginSongSection> createState() => _PluginSongSectionState();
}

class _PluginSongSectionState extends State<_PluginSongSection> {
  late final ContentBloc _bloc;
  bool _attemptedMultiplePlaylists = false;
  List<Track>? _stableSongs;

  @override
  void initState() {
    super.initState();
    _bloc = ContentBloc(pluginService: ServiceLocator.pluginService);
    _bloc.add(GetHomeSections(pluginId: widget.pluginId));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  List<Track> _computeTracks(ContentState state) {
    final sections = state.homeSections ?? const [];
    final allTracks = <Track>[];

    for (final section in sections) {
      for (final item in section.items) {
        item.when(
          track: (t) {
            if (!widget.seenTrackIds.contains(t.id)) {
              allTracks.add(t);
              widget.seenTrackIds.add(t.id);
            }
          },
          album: (_) {},
          artist: (_) {},
          playlist: (_) {},
        );
      }
    }

    if (state.playlistDetails != null &&
        state.playlistDetails!.tracks.items.isNotEmpty) {
      final playlistTracks = state.playlistDetails!.tracks.items;
      for (final track in playlistTracks) {
        if (!widget.seenTrackIds.contains(track.id)) {
          allTracks.add(track);
          widget.seenTrackIds.add(track.id);
        }
      }
    }

    allTracks.shuffle();
    return allTracks;
  }

  void _checkAndFetchSongs(ContentState state) {
    if (_attemptedMultiplePlaylists) return;
    if (state.homeSectionsStatus != DetailStatus.loaded) return;

    final sections = state.homeSections ?? const [];
    if (sections.isEmpty) return;

    int playlistsToTry = 0;
    for (final section in sections) {
      if (playlistsToTry >= 3) break;
      for (final item in section.items) {
        String? targetPlaylistId;
        item.when(
          track: (_) {},
          album: (_) {},
          artist: (_) {},
          playlist: (p) => targetPlaylistId = p.id,
        );
        if (targetPlaylistId != null) {
          playlistsToTry++;
          _bloc.add(LoadPlaylistDetails(
            pluginId: widget.pluginId,
            playlistId: targetPlaylistId!,
          ));
        }
      }
    }

    if (playlistsToTry > 0) {
      _attemptedMultiplePlaylists = true;
    }
  }

  String _formatSectionTitle(String pluginName) {
    final nameLower = pluginName.toLowerCase();
    if (nameLower.contains('song') ||
        nameLower.contains('track') ||
        nameLower.contains('hit')) {
      return pluginName;
    }
    return '$pluginName Songs';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ContentBloc, ContentState>(
      bloc: _bloc,
      listener: (context, state) {
        _checkAndFetchSongs(state);
        if (state.homeSectionsStatus == DetailStatus.loaded) {
          final computed = _computeTracks(state);
          if (computed.isNotEmpty && _stableSongs == null) {
            setState(() {
              _stableSongs = computed;
            });
          }
        }
      },
      builder: (context, state) {
        // While initial home sections loading, show slim placeholder
        if (state.homeSectionsStatus == DetailStatus.loading &&
            (_stableSongs == null || _stableSongs!.isEmpty)) {
          return _buildLoadingRow(context);
        }

        // Error or failed to get tracks — hide this source section entirely
        if (state.homeSectionsStatus == DetailStatus.error) {
          return const SizedBox.shrink();
        }

        final songs = _stableSongs ?? _computeTracks(state);
        if (songs.isEmpty &&
            state.playlistDetailStatus != DetailStatus.loading) {
          return const SizedBox.shrink();
        }
        if (songs.isEmpty) {
          return _buildLoadingRow(context);
        }

        // Cache stable songs if not set yet
        if (_stableSongs == null && songs.isNotEmpty) {
          _stableSongs = songs;
        }

        final sectionTitle = _formatSectionTitle(widget.pluginName);

        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section header with source badge ──
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 4),
                child: Row(
                  children: [
                    SourceBadgeByPluginId(
                      pluginId: widget.pluginId,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      sectionTitle,
                      style: Default_Theme.secondoryTextStyle.merge(
                        TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentColor(context),
                          fontFamily: 'Gilroy',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Horizontal single track cards ──
              SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 12),
                  itemCount: songs.length > 20 ? 20 : songs.length, // Limit to 20 for performance
                  itemBuilder: (context, i) {
                    final track = songs[i];
                    return SquareImgCard(
                      imgPath: track.thumbnail.url,
                      fallbackImgPath: track.thumbnail.urlLow ?? track.thumbnail.url,
                      title: track.title,
                      subtitle: track.artists.map((a) => a.name).join(', '),
                      isList: false,
                      onTap: () {
                        context
                            .read<VoidMusicPlayerCubit>()
                            .voidMusicPlayer
                            .loadPlaylist(
                              Playlist(
                                tracks: songs,
                                title: sectionTitle,
                              ),
                              idx: i,
                              doPlay: true,
                            );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingRow(BuildContext context) {
    final shimmerColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 4),
            child: Row(
              children: [
                SourceBadgeByPluginId(
                  pluginId: widget.pluginId,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.pluginName,
                  style: Default_Theme.secondoryTextStyle.merge(
                    TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentColor(context),
                      fontFamily: 'Gilroy',
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 12),
              itemCount: 5,
              itemBuilder: (context, _) => Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 100,
                      height: 12,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 70,
                      height: 10,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fetches playlists for [pluginId], and renders them in a horizontal scroll row
/// styled like existing playlist cards.
/// Returns [SizedBox.shrink] if the plugin produces no playlists or errors out.
class _PluginPlaylistSection extends StatefulWidget {
  final String pluginId;
  final String pluginName;
  final Set<String> seenPlaylistIds;

  const _PluginPlaylistSection({
    super.key,
    required this.pluginId,
    required this.pluginName,
    required this.seenPlaylistIds,
  });

  @override
  State<_PluginPlaylistSection> createState() => _PluginPlaylistSectionState();
}

class _PluginPlaylistSectionState extends State<_PluginPlaylistSection> {
  late final ContentBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = ContentBloc(pluginService: ServiceLocator.pluginService);
    _bloc.add(GetHomeSections(pluginId: widget.pluginId));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  List<PlaylistSummary> _extractPlaylists(ContentState state) {
    final sections = state.homeSections ?? const [];
    final result = <PlaylistSummary>[];
    for (final section in sections) {
      for (final item in section.items) {
        item.when(
          track: (_) {},
          album: (_) {},
          artist: (_) {},
          playlist: (p) {
            // Deduplicate: only add if we haven't seen this playlist
            if (!widget.seenPlaylistIds.contains(p.id)) {
              result.add(p);
              widget.seenPlaylistIds.add(p.id);
            }
          },
        );
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContentBloc, ContentState>(
      bloc: _bloc,
      builder: (context, state) {
        // While initial home sections loading, show slim placeholder
        if (state.homeSectionsStatus == DetailStatus.loading &&
            (state.homeSections == null || state.homeSections!.isEmpty)) {
          return _buildPlaylistLoadingRow(context);
        }

        // Error or failed to get playlists — hide this source section entirely
        if (state.homeSectionsStatus == DetailStatus.error) {
          return const SizedBox.shrink();
        }

        final playlists = _extractPlaylists(state);
        if (playlists.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section header with source badge ──
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 4),
                child: Row(
                  children: [
                    SourceBadgeByPluginId(
                      pluginId: widget.pluginId,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.pluginName} Playlists',
                      style: Default_Theme.secondoryTextStyle.merge(
                        TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentColor(context),
                          fontFamily: 'Gilroy',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Horizontal playlist cards ──
              SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 12),
                  itemCount: playlists.length > 20 ? 20 : playlists.length,
                  itemBuilder: (context, i) {
                    final playlist = playlists[i];
                    return SquareImgCard(
                      imgPath: playlist.thumbnail.url,
                      fallbackImgPath: playlist.thumbnail.url,
                      title: playlist.title,
                      subtitle: playlist.owner ?? '',
                      isList: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OnlPlaylistView(
                              playlist: playlist,
                              pluginId: widget.pluginId,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaylistLoadingRow(BuildContext context) {
    final shimmerColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 4),
            child: Row(
              children: [
                SourceBadgeByPluginId(
                  pluginId: widget.pluginId,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.pluginName} Playlists',
                  style: Default_Theme.secondoryTextStyle.merge(
                    TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentColor(context),
                      fontFamily: 'Gilroy',
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 12),
              itemCount: 5,
              itemBuilder: (context, _) => Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 100,
                      height: 12,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 70,
                      height: 10,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomDiscoverBar extends StatelessWidget {
  final ValueNotifier<double> scrollOffsetNotifier;

  const CustomDiscoverBar({
    super.key,
    required this.scrollOffsetNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      floating: true,
      delegate: _DiscoverBarDelegate(
        scrollOffsetNotifier: scrollOffsetNotifier,
      ),
    );
  }
}

class _DiscoverBarDelegate extends SliverPersistentHeaderDelegate {
  final ValueNotifier<double> scrollOffsetNotifier;

  _DiscoverBarDelegate({required this.scrollOffsetNotifier});

  static const double _minH = 76;
  static const double _maxH = 76;

  @override
  double get minExtent => _minH;

  @override
  double get maxExtent => _maxH;

  @override
  bool shouldRebuild(covariant _DiscoverBarDelegate oldDelegate) =>
      oldDelegate.scrollOffsetNotifier != scrollOffsetNotifier;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ValueListenableBuilder<double>(
      valueListenable: scrollOffsetNotifier,
      builder: (context, offset, child) {
        final bgBase = Theme.of(context).scaffoldBackgroundColor;
        final glassColor = AppTheme.glassColor(context);
        final glassBorder = AppTheme.glassBorder(context);

        final isDesktop = ResponsiveBreakpoints.of(context).isDesktop ||
            kIsWeb ||
            Platform.isWindows ||
            Platform.isLinux ||
            Platform.isMacOS;

        final progress = isDesktop ? 1.0 : (offset / 40.0).clamp(0.0, 1.0);
        final bgColor = Color.lerp(bgBase, glassColor, progress)!;
        final borderColor = Color.lerp(Colors.transparent, glassBorder, progress)!;
        final blurSigma = 20.0 * progress;

        Widget barContent = Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              bottom: BorderSide(
                color: borderColor,
                width: 1.0,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.exploreDiscover,
                    style: Default_Theme.primaryTextStyle.merge(
                      TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Audiophile Mode (FLAC / Hi-Res)',
                    icon: Icon(
                      MingCute.disc_fill,
                      color: AppTheme.accentColor(context),
                      size: 24,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AudiophileShell(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  const NotificationIcon(),
                  const SizedBox(width: 8),
                  const TimerIcon(),
                  const SizedBox(width: 8),
                  const SettingsIcon(),
                ],
              ),
            ),
          ),
        );

        if (blurSigma > 0) {
          return ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: barContent,
            ),
          );
        }

        return ClipRect(child: barContent);
      },
    );
  }
}

class NotificationIcon extends StatelessWidget {
  const NotificationIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).colorScheme.onSurface;
    return BlocBuilder<NotificationCubit, NotificationState>(
      builder: (context, state) {
        if (state is NotificationInitial || state.notifications.isEmpty) {
          return IconButton(
            padding: const EdgeInsets.all(5),
            constraints: const BoxConstraints(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationView(),
                ),
              );
            },
            icon: Icon(
              MingCute.notification_line,
              color: iconColor,
              size: 26.0,
            ),
          );
        }
        return badges.Badge(
          badgeContent: Padding(
            padding: const EdgeInsets.all(1.5),
            child: Text(
              state.notifications.length.toString(),
              style: Default_Theme.primaryTextStyle.merge(
                TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          badgeStyle: badges.BadgeStyle(
            badgeColor: AppTheme.accentColor(context),
            shape: badges.BadgeShape.circle,
          ),
          position: badges.BadgePosition.topEnd(top: -10, end: -5),
          child: IconButton(
            padding: const EdgeInsets.all(5),
            constraints: const BoxConstraints(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationView(),
                ),
              );
            },
            icon: Icon(
              MingCute.notification_line,
              color: iconColor,
              size: 26.0,
            ),
          ),
        );
      },
    );
  }
}

class TimerIcon extends StatelessWidget {
  const TimerIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).colorScheme.onSurface;
    return IconButton(
      padding: const EdgeInsets.all(5),
      constraints: const BoxConstraints(),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TimerView()),
        );
      },
      icon: Icon(
        MingCute.stopwatch_line,
        color: iconColor,
        size: 26.0,
      ),
    );
  }
}

class SettingsIcon extends StatelessWidget {
  const SettingsIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).colorScheme.onSurface;
    return IconButton(
      padding: const EdgeInsets.all(5),
      constraints: const BoxConstraints(),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsView()),
        );
      },
      icon: Icon(
        MingCute.settings_3_line,
        color: iconColor,
        size: 26.0,
      ),
    );
  }
}

