import 'dart:io';

import 'package:voidmusic/blocs/settings_cubit/cubit/settings_cubit.dart';
import 'package:voidmusic/services/player/stream_quality_selector.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/setting_shared_widgets.dart';
import 'package:voidmusic/screens/widgets/bottom_safe_area_spacer.dart';
import 'package:voidmusic/plugins/blocs/plugin/plugin_bloc.dart';
import 'package:voidmusic/src/rust/api/plugin/plugin_info.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voidmusic/l10n/app_localizations.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DownloadSettings extends StatefulWidget {
  const DownloadSettings({super.key});

  @override
  State<DownloadSettings> createState() => _DownloadSettingsState();
}

Future<bool> storagePermission() async {
  final DeviceInfoPlugin info = DeviceInfoPlugin();
  final AndroidDeviceInfo androidInfo = await info.androidInfo;
  debugPrint('releaseVersion : ${androidInfo.version.release}');
  final int androidVersion = int.parse(androidInfo.version.release);
  bool havePermission = false;

  if (androidVersion >= 13) {
    final request = await [
      Permission.videos,
      Permission.photos,
    ].request();
    havePermission =
        request.values.every((status) => status == PermissionStatus.granted);
  } else {
    final status = await Permission.storage.request();
    havePermission = status.isGranted;
  }

  if (!havePermission) {
    await openAppSettings();
  }

  return havePermission;
}

class _DownloadSettingsState extends State<DownloadSettings> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Center(
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Default_Theme.primaryColor1,
                size: 24,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          l10n.downloadSettingTitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ).merge(Default_Theme.secondoryTextStyleMedium),
        ),
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final pluginState = context.read<PluginBloc>().state;
          final resolvers = pluginState.loadedContentResolvers;
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              SettingSectionHeader(label: l10n.settingsQuality),
              SettingCard(
                children: [
                  SettingQualityChipRow(
                    icon: MingCute.folder_download_fill,
                    title: l10n.downloadSettingQuality,
                    subtitle: l10n.downloadSettingQualitySubtitle,
                    options: AudioStreamQualityPreference.values
                        .map((q) => q.label)
                        .toList(),
                    selected: state.downQuality,
                    onSelected: (v) =>
                        context.read<SettingsCubit>().setDownQuality(v),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const SettingSectionHeader(label: 'Download Plugin'),
              SettingCard(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              MingCute.plugin_line,
                              color: Default_Theme.primaryColor1,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Download Method',
                                    style: const TextStyle(
                                      color: Default_Theme.primaryColor1,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ).merge(Default_Theme.secondoryTextStyleMedium),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Select plugin for downloading songs',
                                    style: TextStyle(
                                      color: Default_Theme.primaryColor1.withValues(alpha: 0.6),
                                      fontSize: 12,
                                    ).merge(Default_Theme.secondoryTextStyle),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _DownloadPluginSelector(
                          state: state,
                          resolvers: resolvers,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SettingSectionHeader(label: l10n.settingsStorage),
              SettingCard(
                children: [
                  SettingNavTile(
                    icon: MingCute.folder_fill,
                    title: l10n.downloadSettingFolder,
                    subtitle: state.downPath,
                    roundBottom: Platform.isAndroid,
                    onTap: Platform.isAndroid
                        ? () {}
                        : () async {
                            FilePicker.platform
                                .getDirectoryPath()
                                .then((value) {
                              if (value != null) {
                                if (!context.mounted) return;
                                context
                                    .read<SettingsCubit>()
                                    .setDownPath(value);
                              }
                            });
                          },
                  ),
                  if (!Platform.isAndroid) ...[
                    const SettingDivider(),
                    SettingNavTile(
                      icon: MingCute.refresh_1_line,
                      title: l10n.downloadSettingResetFolder,
                      subtitle: l10n.downloadSettingResetFolderSubtitle,
                      roundBottom: true,
                      onTap: () =>
                          context.read<SettingsCubit>().resetDownPath(),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 40),
              const BottomSafeAreaSpacer(),
            ],
          );
        },
      ),
    );
  }
}

class _DownloadPluginSelector extends StatefulWidget {
  final SettingsState state;
  final List<PluginInfo> resolvers;

  const _DownloadPluginSelector({
    required this.state,
    required this.resolvers,
  });

  @override
  State<_DownloadPluginSelector> createState() => _DownloadPluginSelectorState();
}

class _DownloadPluginSelectorState extends State<_DownloadPluginSelector> {
  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.state.downloadPluginIds);
  }

  @override
  void didUpdateWidget(covariant _DownloadPluginSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.downloadPluginIds != oldWidget.state.downloadPluginIds) {
      _selectedIds = List.from(widget.state.downloadPluginIds);
    }
  }

  void _togglePlugin(String pluginId) {
    setState(() {
      if (_selectedIds.contains(pluginId)) {
        _selectedIds.remove(pluginId);
      } else {
        _selectedIds.add(pluginId);
      }
    });
    context.read<SettingsCubit>().setDownloadPluginIds(List.from(_selectedIds));
  }

  Widget _getPluginIcon(String pluginId) {
    String svgPath;
    Color? color;
    
    if (pluginId.contains('ytmusic') || pluginId.contains('youtube_music')) {
      svgPath = 'assets/icons/svg/Youtube Music.svg';
      color = null; // Already colored
    } else if (pluginId.contains('ytvideo') || pluginId.contains('youtube')) {
      svgPath = 'assets/icons/svg/youtube.svg';
      color = null; // Already colored
    } else if (pluginId.contains('spotify')) {
      svgPath = 'assets/icons/svg/spotify.svg';
      color = null; // Already colored
    } else if (pluginId.contains('jiosaavn') || pluginId.contains('jio')) {
      svgPath = 'assets/icons/svg/jiosaavn.svg';
      color = null; // Already colored
    } else if (pluginId.contains('multi') || pluginId.contains('bloomfactory')) {
      svgPath = 'assets/icons/svg/multi-source.svg';
      color = Default_Theme.primaryColor1; // Color the black SVG
    } else {
      return const SizedBox.shrink(); // No icon for unknown plugins
    }
    
    return SizedBox(
      width: 16,
      height: 16,
      child: color != null
          ? ColorFiltered(
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              child: SvgPicture.asset(svgPath),
            )
          : SvgPicture.asset(svgPath),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nameMap = {
      for (final p in widget.resolvers) p.manifest.id: p.name,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Select multiple plugins (drag to reorder priority)',
            style: TextStyle(
              color: Default_Theme.primaryColor2.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ).merge(Default_Theme.secondoryTextStyle),
          ),
        ),
        if (_selectedIds.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Default_Theme.primaryColor2.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Default_Theme.primaryColor2.withValues(alpha: 0.06),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      return Material(
                        color: AppTheme.accentColor(context).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        elevation: 0,
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                itemCount: _selectedIds.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    final item = _selectedIds.removeAt(oldIndex);
                    _selectedIds.insert(newIndex, item);
                  });
                  context.read<SettingsCubit>().setDownloadPluginIds(List.from(_selectedIds));
                },
                itemBuilder: (context, index) {
                  final pluginId = _selectedIds[index];
                  final name = nameMap[pluginId] ?? pluginId;
                  return ReorderableDragStartListener(
                    key: ValueKey(pluginId),
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor(context).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: AppTheme.accentColor(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          _getPluginIcon(pluginId),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Default_Theme.primaryColor1,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ).merge(Default_Theme.secondoryTextStyleMedium),
                                ),
                                Text(
                                  pluginId,
                                  style: TextStyle(
                                    color: Default_Theme.primaryColor2.withValues(alpha: 0.45),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                  ).merge(Default_Theme.secondoryTextStyle),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            MingCute.menu_line,
                            size: 20,
                            color: Default_Theme.primaryColor2.withValues(alpha: 0.22),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 12),
        SettingCard(
          children: [
            ...widget.resolvers.map((plugin) {
              final isSelected = _selectedIds.contains(plugin.manifest.id);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.resolvers.indexOf(plugin) > 0)
                    const SettingDivider(),
                  CheckboxListTile(
                    title: Row(
                      children: [
                        _getPluginIcon(plugin.manifest.id),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            plugin.name,
                            style: const TextStyle(
                              color: Default_Theme.primaryColor1,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ).merge(Default_Theme.secondoryTextStyleMedium),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      plugin.manifest.id,
                      style: TextStyle(
                        color: Default_Theme.primaryColor2.withValues(alpha: 0.45),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ).merge(Default_Theme.secondoryTextStyle),
                    ),
                    value: isSelected,
                    onChanged: (_) => _togglePlugin(plugin.manifest.id),
                    activeColor: AppTheme.accentColor(context),
                    checkColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }
}
