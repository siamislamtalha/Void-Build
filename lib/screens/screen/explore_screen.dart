import 'dart:developer';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:voidmusic/blocs/explore/cubit/explore_cubits.dart';
import 'package:voidmusic/blocs/internet_connectivity/cubit/connectivity_cubit.dart';
import 'package:voidmusic/blocs/lastdotfm/lastdotfm_cubit.dart';
import 'package:voidmusic/blocs/media_player/bloomee_player_cubit.dart';
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

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool isUpdateChecked = false;
  late final ContentBloc _homeContentBloc;
  Future<List<Track>> lFMData = Future.value(const []);

  @override
  void initState() {
    super.initState();
    _homeContentBloc = ContentBloc(pluginService: ServiceLocator.pluginService);
    _tryLoadHomeSections();
  }

  /// Only loads home sections when both settings are ready and plugins are loaded.
  void _tryLoadHomeSections() {
    final settingsState = context.read<SettingsCubit>().state;
    if (!settingsState.settingsReady) return;

    final pluginState = context.read<PluginBloc>().state;
    final contentResolvers = pluginState.loadedContentResolvers;
    if (contentResolvers.isEmpty) return;

    final preferredIds = settingsState.homePluginIds;
    // If the user's preferred plugins are installed but not yet loaded, wait for them.
    // This prevents flashing the wrong plugin's home page on startup.
    if (preferredIds.isNotEmpty) {
      final firstPreferred = preferredIds.first;
      final isAlreadyLoaded =
          contentResolvers.any((p) => p.manifest.id == firstPreferred);
      if (!isAlreadyLoaded) {
        final isInstalled = pluginState.availablePlugins
            .any((p) => p.manifest.id == firstPreferred);
        if (isInstalled) return; // Preferred plugin is loading — wait for it
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
        final hasPreferred = loadedResolvers.any((plugin) => plugin.manifest.id == preferredId);
        if (hasPreferred) return preferredId;
      }
    }
    return loadedResolvers.first.manifest.id;
  }

  @override
  void dispose() {
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
    return SafeArea(
      child: MultiBlocListener(
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
          body: RefreshIndicator(
            onRefresh: () async {
              final pluginId = _effectiveHomePluginId(
                context.read<PluginBloc>().state.loadedContentResolvers,
              );
              _homeContentBloc.add(
                GetHomeSections(pluginId: pluginId, bypassCache: true),
              );
            },
            child: CustomScrollView(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              slivers: [
                const CustomDiscoverBar(),
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
                                              .read<BloomeePlayerCubit>()
                                              .bloomeePlayer
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
                                                .read<BloomeePlayerCubit>()
                                                .bloomeePlayer
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
                      // ── Multi-source Song Suggestions ──
                      // One horizontal row per loaded content-resolver plugin,
                      // showing only Track items from that plugin's home sections.
                      // Rows that yield zero tracks are hidden automatically.
                      const _MultiSourceSongSuggestions(),
                      // Home sections from plugin
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
                    ],
                  ),
                ),
                const SliverBottomSafeAreaSpacer(),
              ],
            ),
          ),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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

/// Renders one `_PluginSongSection` per loaded content-resolver plugin.
/// Sections that yield zero tracks are silently omitted.
class _MultiSourceSongSuggestions extends StatelessWidget {
  const _MultiSourceSongSuggestions();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PluginBloc, PluginState>(
      builder: (context, pluginState) {
        final resolvers = pluginState.loadedContentResolvers;
        if (resolvers.isEmpty) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: resolvers.map((plugin) {
            return _PluginSongSection(
              pluginId: plugin.manifest.id,
              pluginName: plugin.manifest.name,
            );
          }).toList(),
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

  const _PluginSongSection({
    required this.pluginId,
    required this.pluginName,
  });

  @override
  State<_PluginSongSection> createState() => _PluginSongSectionState();
}

class _PluginSongSectionState extends State<_PluginSongSection> {
  late final ContentBloc _bloc;
  bool _attemptedPlaylistFetch = false;

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

  List<Track> _extractDirectTracks(ContentState state) {
    final sections = state.homeSections ?? const [];
    final result = <Track>[];
    for (final section in sections) {
      for (final item in section.items) {
        item.when(
          track: (t) => result.add(t),
          album: (_) {},
          artist: (_) {},
          playlist: (_) {},
        );
      }
    }
    return result;
  }

  List<Track> _getTracks(ContentState state) {
    final direct = _extractDirectTracks(state);
    if (direct.isNotEmpty) return direct;
    if (state.playlistDetails != null && state.playlistDetails!.tracks.items.isNotEmpty) {
      return state.playlistDetails!.tracks.items;
    }
    return const [];
  }

  void _checkAndFetchSongs(ContentState state) {
    if (_attemptedPlaylistFetch) return;
    if (state.homeSectionsStatus != DetailStatus.loaded) return;

    final directTracks = _extractDirectTracks(state);
    if (directTracks.isNotEmpty) return;

    final sections = state.homeSections ?? const [];
    if (sections.isEmpty) return;

    for (final section in sections) {
      for (final item in section.items) {
        String? targetPlaylistId;
        item.when(
          track: (_) {},
          album: (_) {},
          artist: (_) {},
          playlist: (p) => targetPlaylistId = p.id,
        );
        if (targetPlaylistId != null) {
          _attemptedPlaylistFetch = true;
          _bloc.add(LoadPlaylistDetails(
            pluginId: widget.pluginId,
            playlistId: targetPlaylistId!,
          ));
          return;
        }
      }
    }
  }

  String _formatSectionTitle(String pluginName) {
    final nameLower = pluginName.toLowerCase();
    if (nameLower.contains('song') || nameLower.contains('track') || nameLower.contains('hit')) {
      return pluginName;
    }
    return '$pluginName Songs';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContentBloc, ContentState>(
      bloc: _bloc,
      builder: (context, state) {
        _checkAndFetchSongs(state);

        // While initial home sections loading, show slim placeholder
        if (state.homeSectionsStatus == DetailStatus.loading &&
            (state.homeSections == null || state.homeSections!.isEmpty)) {
          return _buildLoadingRow(context);
        }

        // Error or failed to get tracks — hide this source section entirely
        if (state.homeSectionsStatus == DetailStatus.error) {
          return const SizedBox.shrink();
        }

        final songs = _getTracks(state);
        if (songs.isEmpty && state.playlistDetailStatus != DetailStatus.loading) {
          return const SizedBox.shrink();
        }
        if (songs.isEmpty) {
          return _buildLoadingRow(context);
        }

        final onSurface = Theme.of(context).colorScheme.onSurface;
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                        fontFamily: 'Gilroy',
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
                  itemCount: songs.length,
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
                            .read<BloomeePlayerCubit>()
                            .bloomeePlayer
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);
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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: 'Gilroy',
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
  const CustomDiscoverBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      floating: true,
      delegate: _DiscoverBarDelegate(),
    );
  }
}

class _DiscoverBarDelegate extends SliverPersistentHeaderDelegate {
  static const double _minH = 76;
  static const double _maxH = 76;

  @override
  double get minExtent => _minH;

  @override
  double get maxExtent => _maxH;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.70);
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.08);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            color: glassColor,
            border: Border(
              bottom: BorderSide(
                color: glassBorder,
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
                        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const NotificationIcon(),
                  const SizedBox(width: 8),
                  const TimerIcon(),
                  const SizedBox(width: 8),
                  const SettingsIcon(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationIcon extends StatelessWidget {
  const NotificationIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
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
                const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
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

