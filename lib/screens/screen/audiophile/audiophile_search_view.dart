import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:voidmusic/blocs/audiophile/audiophile_cubit.dart';
import 'package:voidmusic/blocs/media_player/voidmusic_player_cubit.dart';
import 'package:voidmusic/core/models/media_playlist_model.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:voidmusic/screens/widgets/audiophile_badge_widget.dart';
import 'package:voidmusic/services/plugin/spotiflac_extension_bridge.dart';
import 'package:voidmusic/src/rust/api/plugin/models.dart';

class AudiophileSearchView extends StatefulWidget {
  const AudiophileSearchView({super.key});

  @override
  State<AudiophileSearchView> createState() => _AudiophileSearchViewState();
}

class _AudiophileSearchViewState extends State<AudiophileSearchView> {
  final TextEditingController _searchController = TextEditingController();
  final SpotiFLACExtensionBridge _bridge = SpotiFLACExtensionBridge();

  SpotiFLACSearchResult? _searchResults;
  List<Suggestion> _suggestions = [];
  bool _isSearching = false;
  bool _showSuggestions = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _showSuggestions = false;
    });

    final pluginId = context.read<AudiophileCubit>().state.activePluginId;
    final results = await _bridge.search(pluginId: pluginId, query: query);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final pluginId = context.read<AudiophileCubit>().state.activePluginId;
    final suggestions = await _bridge.getSearchSuggestions(pluginId, query);
    if (mounted) {
      setState(() {
        _suggestions = suggestions;
        _showSuggestions = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudiophileCubit, AudiophileState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              // ── Search Input Field ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.accentColor(context).withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => _fetchSuggestions(val),
                    onSubmitted: (val) => _performSearch(val),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Search Lossless FLAC, HD Audio, Studio Masters...',
                      hintStyle: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        MingCute.search_2_line,
                        color: AppTheme.accentColor(context),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = null;
                                  _suggestions = [];
                                  _showSuggestions = false;
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Autocomplete Suggestions Dropdown ───────────────────────
              if (_showSuggestions && _suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: _suggestions.take(6).map((s) {
                      final text = s.when(
                        query: (q) => q,
                        entity: (e) => e.title,
                      );
                      return ListTile(
                        leading: Icon(MingCute.search_line,
                            size: 18, color: AppTheme.accentColor(context)),
                        title: Text(
                          text,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const AudiophileBadgeWidget(
                          label: 'FLAC',
                          fontSize: 8,
                        ),
                        onTap: () {
                          _searchController.text = text;
                          _performSearch(text);
                        },
                      );
                    }).toList(),
                  ),
                ),

              // ── Results View ─────────────────────────────────────────────
              Expanded(
                child: _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults == null
                        ? _buildEmptyState(context)
                        : _buildSearchResults(context, state),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            MingCute.disc_line,
            size: 56,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Search Audiophile Master Audio',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'FLAC 16-bit / 24-bit / Hi-Res / Lossless Streams Only',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, AudiophileState state) {
    final tracks = _searchResults?.tracks.items ?? [];
    if (tracks.isEmpty) {
      return Center(
        child: Text(
          'No lossless tracks found for "${_searchController.text}"',
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.6),
            fontSize: 15,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final artistName = track.artists.isNotEmpty
            ? track.artists.map((a) => a.name).join(', ')
            : 'Unknown Artist';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.05),
            ),
          ),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                track.thumbnail.url,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey.shade900,
                  child: const Icon(Icons.music_note, color: Colors.white54),
                ),
              ),
            ),
            title: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              artistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AudiophileBadgeWidget(
                  label: 'FLAC 24-BIT',
                  isHiRes: true,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    MingCute.download_2_line,
                    color: AppTheme.accentColor(context),
                    size: 22,
                  ),
                  onPressed: () {
                    _bridge.startTrackDownload(
                      track: track,
                      pluginId: state.activePluginId,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Downloading FLAC: ${track.title} by $artistName'),
                        backgroundColor: AppTheme.accentColor(context),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    MingCute.play_circle_fill,
                    color: AppTheme.accentColor(context),
                    size: 28,
                  ),
                  onPressed: () {
                    context
                        .read<VoidMusicPlayerCubit>()
                        .voidMusicPlayer
                        .loadPlaylist(
                          Playlist(tracks: tracks, title: 'Audiophile Search'),
                          idx: index,
                          doPlay: true,
                        );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
