import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:voidmusic/blocs/audiophile/audiophile_cubit.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:voidmusic/screens/screen/audiophile/audiophile_downloads_view.dart';
import 'package:voidmusic/screens/screen/audiophile/audiophile_explore_view.dart';
import 'package:voidmusic/screens/screen/audiophile/audiophile_search_view.dart';
import 'package:voidmusic/screens/widgets/audiophile_badge_widget.dart';
import 'package:voidmusic/services/audiophile/audiophile_download_service.dart';
import 'package:voidmusic/services/audiophile/audiophile_service.dart';

class AudiophileShell extends StatefulWidget {
  const AudiophileShell({super.key});

  @override
  State<AudiophileShell> createState() => _AudiophileShellState();
}

class _AudiophileShellState extends State<AudiophileShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudiophileCubit, AudiophileState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: _buildAppBar(context, state),
          body: TabBarView(
            controller: _tabController,
            physics: const BouncingScrollPhysics(),
            children: [
              const AudiophileExploreView(),
              const AudiophileSearchView(),
              const AudiophileDownloadsView(),
              _buildSettingsView(context, state),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, AudiophileState state) {
    final activeQueueCount = state.downloadQueue
        .where((t) =>
            t.status == DownloadTaskStatus.queued ||
            t.status == DownloadTaskStatus.downloading ||
            t.status == DownloadTaskStatus.decrypting)
        .length;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: AppTheme.glassBlur,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.glassColor(context),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.glassBorder(context),
                  width: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Icon(
            MingCute.disc_fill,
            color: AppTheme.accentColor(context),
            size: 22,
          ),
          const SizedBox(width: 8),
          const Text(
            'AUDIOPHILE MODE',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          const AudiophileBadgeWidget(
            label: 'FLAC 24-BIT',
            isHiRes: true,
            fontSize: 9,
          ),
        ],
      ),
      actions: [
        Switch(
          value: state.isEnabled,
          onChanged: (val) {
            context.read<AudiophileCubit>().toggleAudiophileMode();
          },
          activeThumbColor: AppTheme.accentColor(context),
        ),
        const SizedBox(width: 12),
      ],
      bottom: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorColor: AppTheme.accentColor(context),
        labelColor: AppTheme.accentColor(context),
        unselectedLabelColor:
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        tabs: [
          const Tab(text: 'EXPLORE'),
          const Tab(text: 'SEARCH'),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('DOWNLOADS'),
                if (activeQueueCount > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor(context),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$activeQueueCount',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Tab(text: 'PROVIDERS'),
        ],
      ),
    );
  }

  Widget _buildSettingsView(BuildContext context, AudiophileState state) {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        Text(
          'Target Quality Tier',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        ...AudiophileQualityTier.values.map((tier) {
          final isSelected = state.qualityTier == tier;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accentColor(context).withValues(alpha: 0.12)
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppTheme.accentColor(context)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.08),
                width: 1.5,
              ),
            ),
            child: ListTile(
              title: Text(
                tier.displayName,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                tier.description,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle_rounded,
                      color: AppTheme.accentColor(context))
                  : null,
              onTap: () {
                context.read<AudiophileCubit>().setQualityTier(tier);
              },
            ),
          );
        }),
        const SizedBox(height: 24),
        Text(
          'Active Audiophile Plugins',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        ...state.availableAudiophilePlugins.map((pluginId) {
          final isSelected = state.activePluginId == pluginId;
          final name = _getPluginName(pluginId);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accentColor(context).withValues(alpha: 0.08)
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.accentColor(context).withValues(alpha: 0.5)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.05),
              ),
            ),
            child: ListTile(
              leading: Icon(
                MingCute.disc_line,
                color: isSelected
                    ? AppTheme.accentColor(context)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
              ),
              title: Text(
                name,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'FLAC / Lossless Provider • $pluginId',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
              trailing: ChoiceChip(
                label: Text(isSelected ? 'Active' : 'Select'),
                selected: isSelected,
                onSelected: (_) {
                  context.read<AudiophileCubit>().setAudiophilePlugin(pluginId);
                },
                selectedColor:
                    AppTheme.accentColor(context).withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppTheme.accentColor(context)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _getPluginName(String id) {
    if (id.contains('deezer')) return 'Deezer Hi-Fi FLAC';
    if (id.contains('qobuz')) return 'Qobuz Studio Master (24-bit/192kHz)';
    if (id.contains('tidal')) return 'Tidal HiRes FLAC & MQA';
    if (id.contains('ytmusic')) return 'YouTube Music Audiophile';
    if (id.contains('apple')) return 'Apple Music Lossless (ALAC)';
    if (id.contains('amazon')) return 'Amazon Music HD';
    if (id.contains('pandora')) return 'Pandora High Quality';
    if (id.contains('soundcloud')) return 'SoundCloud HQ';
    return id;
  }
}
