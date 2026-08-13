import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:voidmusic/blocs/audiophile/audiophile_cubit.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:voidmusic/screens/widgets/audiophile_badge_widget.dart';
import 'package:voidmusic/screens/widgets/square_card.dart';
import 'package:voidmusic/services/plugin/spotiflac_extension_bridge.dart';
import 'package:voidmusic/src/rust/api/plugin/models.dart';
import 'package:voidmusic/blocs/media_player/voidmusic_player_cubit.dart';
import 'package:voidmusic/core/models/media_playlist_model.dart';

class AudiophileExploreView extends StatefulWidget {
  const AudiophileExploreView({super.key});

  @override
  State<AudiophileExploreView> createState() => _AudiophileExploreViewState();
}

class _AudiophileExploreViewState extends State<AudiophileExploreView> {
  final SpotiFLACExtensionBridge _bridge = SpotiFLACExtensionBridge();
  List<Section> _sections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAudiophileFeed();
  }

  Future<void> _loadAudiophileFeed() async {
    setState(() => _isLoading = true);
    final activePlugin = context.read<AudiophileCubit>().state.activePluginId;
    final sections = await _bridge.getHomeFeed(activePlugin);
    if (mounted) {
      setState(() {
        _sections = sections;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AudiophileCubit, AudiophileState>(
      listenWhen: (previous, current) =>
          previous.activePluginId != current.activePluginId,
      listener: (context, state) {
        _loadAudiophileFeed();
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: RefreshIndicator(
            onRefresh: _loadAudiophileFeed,
            child: ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 80),
              physics: const BouncingScrollPhysics(),
              children: [
                // ── Audiophile Banner Header ────────────────────────────────
                _buildAudiophileHeader(context, state),
                const SizedBox(height: 16),

                // ── Active Provider Chips ──────────────────────────────────
                _buildProviderChips(context, state),
                const SizedBox(height: 20),

                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  )
                else if (_sections.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(MingCute.disc_line,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(
                            'Loading Lossless Audiophile Feed...',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._sections.map((section) => _buildSection(context, section)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAudiophileHeader(BuildContext context, AudiophileState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentColor(context).withValues(alpha: 0.25),
            Colors.purple.withValues(alpha: 0.15),
            Colors.black.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.accentColor(context).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor(context).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  MingCute.disc_fill,
                  color: AppTheme.accentColor(context),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AUDIOPHILE ENGINE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      state.qualityTier.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const AudiophileBadgeWidget(
                label: 'HI-RES FLAC',
                isHiRes: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildQualityPill(context, 'FLAC 24-BIT', Colors.cyan),
              const SizedBox(width: 8),
              _buildQualityPill(context, '96kHZ / 192kHZ', Colors.amber),
              const SizedBox(width: 8),
              _buildQualityPill(context, 'NO LOSSY (MP3/OPUS BLOCKED)', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityPill(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildProviderChips(BuildContext context, AudiophileState state) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: state.availableAudiophilePlugins.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final pluginId = state.availableAudiophilePlugins[index];
          final isSelected = state.activePluginId == pluginId;
          final name = _getShortName(pluginId);

          return ChoiceChip(
            label: Text(name),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                context.read<AudiophileCubit>().setAudiophilePlugin(pluginId);
              }
            },
            selectedColor: AppTheme.accentColor(context).withValues(alpha: 0.25),
            backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            labelStyle: TextStyle(
              color: isSelected
                  ? AppTheme.accentColor(context)
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              fontSize: 13,
            ),
            side: BorderSide(
              color: isSelected
                  ? AppTheme.accentColor(context)
                  : Colors.transparent,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(BuildContext context, Section section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (section.subtitle != null)
                Text(
                  section.subtitle!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: section.cardType == CardType.grid ? 200 : 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: section.items.length,
            itemBuilder: (context, index) {
              final item = section.items[index];
              return item.when(
                track: (t) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SquareImgCard(
                    imgPath: t.thumbnail.url,
                    fallbackImgPath: t.thumbnail.url,
                    title: t.title,
                    subtitle: t.artists.map((a) => a.name).join(', '),
                    isList: false,
                    onTap: () {
                      context
                          .read<VoidMusicPlayerCubit>()
                          .voidMusicPlayer
                          .loadPlaylist(
                            Playlist(
                              tracks: section.items
                                  .whereType<MediaItem_Track>()
                                  .map((i) => i.field0)
                                  .toList(),
                              title: section.title,
                            ),
                            idx: index,
                            doPlay: true,
                          );
                    },
                  ),
                ),
                playlist: (p) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SquareImgCard(
                    imgPath: p.thumbnail.url,
                    fallbackImgPath: p.thumbnail.url,
                    title: p.title,
                    subtitle: p.owner ?? 'SpotiFLAC',
                    isList: true,
                    onTap: () {},
                  ),
                ),
                album: (a) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SquareImgCard(
                    imgPath: a.thumbnail?.url ?? '',
                    fallbackImgPath: a.thumbnail?.url ?? '',
                    title: a.title,
                    subtitle: a.artists.map((ar) => ar.name).join(', '),
                    isList: true,
                    onTap: () {},
                  ),
                ),
                artist: (ar) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SquareImgCard(
                    imgPath: ar.thumbnail?.url ?? '',
                    fallbackImgPath: ar.thumbnail?.url ?? '',
                    title: ar.name,
                    subtitle: 'Artist',
                    isList: true,
                    onTap: () {},
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _getShortName(String id) {
    if (id.contains('ytmusic')) return 'YouTube Music';
    if (id.contains('spotify')) return 'Spotify';
    if (id.contains('deezer')) return 'Deezer';
    if (id.contains('qobuz')) return 'Qobuz';
    if (id.contains('tidal')) return 'Tidal';
    if (id.contains('apple')) return 'Apple Music';
    if (id.contains('amazon')) return 'Amazon';
    if (id.contains('pandora')) return 'Pandora';
    if (id.contains('soundcloud')) return 'SoundCloud';
    return id;
  }
}
