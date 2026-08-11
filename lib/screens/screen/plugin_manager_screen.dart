// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:voidmusic/blocs/settings_cubit/cubit/settings_cubit.dart';
import 'package:voidmusic/core/di/service_locator.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:voidmusic/plugins/blocs/plugin/plugin_bloc.dart';
import 'package:voidmusic/plugins/blocs/plugin/plugin_event.dart';
import 'package:voidmusic/plugins/blocs/plugin/plugin_state.dart';
import 'package:voidmusic/screens/widgets/animated_list_item.dart';
import 'package:voidmusic/screens/widgets/voidmusic_ui_kit/voidmusic_dialog.dart';
import 'package:voidmusic/screens/widgets/bottom_safe_area_spacer.dart';
import 'package:voidmusic/screens/widgets/sign_board_widget.dart';
import 'package:voidmusic/screens/widgets/snackbar.dart';
import 'package:voidmusic/services/plugin/plugin_load_state_service.dart';
import 'package:voidmusic/services/db/dao/settings_dao.dart';
import 'package:voidmusic/services/db/db_provider.dart';
import 'package:voidmusic/src/rust/api/plugin/manifest.dart';
import 'package:voidmusic/src/rust/api/plugin/plugin_info.dart';
import 'package:voidmusic/src/rust/api/plugin/types.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voidmusic/l10n/app_localizations.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:voidmusic/screens/screen/home_views/plugin_repository_view.dart';
import 'package:voidmusic/plugins/blocs/repository/plugin_repository_cubit.dart';
import 'package:voidmusic/plugins/utils/plugin_constants.dart';

class PluginManagerScreen extends StatefulWidget {
  const PluginManagerScreen({super.key});

  @override
  State<PluginManagerScreen> createState() => _PluginManagerScreenState();
}

class _PluginManagerScreenState extends State<PluginManagerScreen> {
  final ValueNotifier<PluginType?> _selectedFilterNotifier =
      ValueNotifier(null);

  Map<PluginType?, String> _filterOptions(AppLocalizations l10n) => {
        null: l10n.pluginManagerFilterAll,
        PluginType.contentResolver: l10n.pluginManagerFilterContent,
        PluginType.chartProvider: l10n.pluginManagerFilterCharts,
        PluginType.lyricsProvider: l10n.pluginManagerFilterLyrics,
        PluginType.searchSuggestionProvider:
            l10n.pluginManagerFilterSuggestions,
        PluginType.contentImporter: l10n.pluginManagerFilterImporters,
      };

  @override
  void dispose() {
    _selectedFilterNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocProvider(
      create: (context) =>
          PluginRepositoryCubit(ServiceLocator.pluginRepositoryService),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: _buildAppBar(context, l10n),
          body: TabBarView(
            physics: const BouncingScrollPhysics(),
            children: [
              _buildInstalledPluginsTab(context, l10n),
              const PluginRepositoryView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstalledPluginsTab(
      BuildContext context, AppLocalizations l10n) {
    return BlocConsumer<PluginBloc, PluginState>(
      listenWhen: (prev, curr) =>
          (prev.error != curr.error && curr.error != null) ||
          (prev.successMessage != curr.successMessage &&
              curr.successMessage != null),
      listener: (context, state) {
        if (state.error != null) SnackbarService.showMessage(state.error!);
        if (state.successMessage != null) {
          SnackbarService.showMessage(state.successMessage!);
        }
      },
      builder: (context, state) {
        if (!state.isInitialized) {
          return Center(
              child: CircularProgressIndicator(
                  color: AppTheme.accentColor(context), strokeWidth: 3));
        }

        if (state.availablePlugins.isEmpty) {
          return SignBoardWidget(
              message: l10n.pluginManagerEmpty, icon: MingCute.plugin_2_line);
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
                maxWidth: 900), // Standardized Desktop Alignment
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChipsHeader(l10n),
                Expanded(
                  child: ValueListenableBuilder<PluginType?>(
                    valueListenable: _selectedFilterNotifier,
                    builder: (context, selectedFilter, _) {
                      final filteredPlugins = selectedFilter == null
                          ? state.availablePlugins
                          : state.availablePlugins
                              .where((p) => p.pluginType == selectedFilter)
                              .toList();

                      return _buildPluginGridOrList(
                          context, l10n, state, filteredPlugins);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── App Bar with Redesigned Constrained TabBar ─────────────────────────────

  PreferredSizeWidget _buildAppBar(
      BuildContext context, AppLocalizations l10n) {
    final glassColor = AppTheme.glassColor(context);
    final glassBorder = AppTheme.glassBorder(context);
    
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 64,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: AppTheme.glassBlur,
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
          ),
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 12.0),
        child: Center(
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: Theme.of(context).colorScheme.onSurface, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      title: Text(
        l10n.pluginManagerTitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      // Sleek, centered, constrained Segmented Control
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(66),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
                maxWidth: 380), // Strict max-width for Desktop perfection
            child: Container(
              height: 46,
              margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius:
                    BorderRadius.circular(14), // Perfect concentric math
                border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                    width: 1),
              ),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
                indicator: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(
                      10), // 14 (outer) - 4 (padding) = 10 (inner)
                  border: Border.all(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2), // Subtle lift effect
                    ),
                  ],
                ),
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                labelColor: Theme.of(context).colorScheme.onSurface,
                unselectedLabelColor:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: -0.2),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                tabs: [
                  Tab(text: l10n.pluginManagerTabInstalled),
                  Tab(text: l10n.pluginManagerTabStore),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        BlocBuilder<PluginBloc, PluginState>(
          builder: (context, state) {
            if (state.hasActiveOperations) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppTheme.accentColor(context))),
              );
            }
            return IconButton(
              tooltip: l10n.pluginManagerTooltipRefresh,
              icon: Icon(MingCute.refresh_2_line,
                  color: Theme.of(context).colorScheme.onSurface, size: 22),
              onPressed: () =>
                  context.read<PluginBloc>().add(const RefreshPlugins()),
            );
          },
        ),
        IconButton(
          tooltip: l10n.pluginManagerTooltipInstall,
          icon: Icon(MingCute.add_circle_line,
              color: AppTheme.accentColor(context), size: 24),
          onPressed: () => _installPlugin(context),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ── Scalable Chips Header ────────────────────────────────────────────────

  Widget _buildChipsHeader(AppLocalizations l10n) {
    final filterOptions = _filterOptions(l10n);
    return SizedBox(
      height: 52,
      child: ValueListenableBuilder<PluginType?>(
        valueListenable: _selectedFilterNotifier,
        builder: (context, selectedFilter, _) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: filterOptions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final entry = filterOptions.entries.elementAt(index);
              final filterType = entry.key;
              final label = entry.value;
              final isSelected = selectedFilter == filterType;

              return InkWell(
                onTap: () => _selectedFilterNotifier.value = filterType,
                borderRadius: BorderRadius.circular(16),
                splashColor: Colors.transparent,
                highlightColor:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.accentColor(context).withValues(alpha: 0.15)
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.accentColor(context).withValues(alpha: 0.5)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.accentColor(context)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Responsive List/Grid View ─────────────────────────────────────────────

  Widget _buildPluginGridOrList(BuildContext context, AppLocalizations l10n,
      PluginState state, List<PluginInfo> plugins) {
    if (plugins.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(MingCute.ghost_line,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              l10n.pluginManagerNoMatch,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 750) {
          return Column(
            children: [
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 16),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 94,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: plugins.length,
                  itemBuilder: (context, index) {
                    return AnimatedListItem(
                      key: ValueKey(plugins[index].manifest.id),
                      index: index,
                      child: _PluginCard(
                        plugin: plugins[index],
                        isLoaded: state.isPluginLoaded(plugins[index].manifest.id),
                        operation: state.operationFor(plugins[index].manifest.id),
                      ),
                    );
                  },
                ),
              ),
              const BottomSafeAreaSpacer(),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 12),
          physics: const BouncingScrollPhysics(),
          itemCount: plugins.length + 1,
          itemBuilder: (context, index) {
            if (index < plugins.length) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AnimatedListItem(
                  key: ValueKey(plugins[index].manifest.id),
                  index: index,
                  child: _PluginCard(
                    plugin: plugins[index],
                    isLoaded: state.isPluginLoaded(plugins[index].manifest.id),
                    operation: state.operationFor(plugins[index].manifest.id),
                  ),
                ),
              );
            }
            return const BottomSafeAreaSpacer();
          },
        );
      },
    );
  }

  Future<void> _installPlugin(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bex', 'sflx', 'spotiflac-ext'],
        dialogTitle: l10n.pluginManagerSelectPackage,
      );

      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.single.path;
      if (filePath == null) return;

      if (context.mounted) {
        context
            .read<PluginBloc>()
            .add(InstallPlugin(packedFilePath: filePath, shouldLoad: true));
        SnackbarService.showMessage(l10n.pluginManagerInstalling,
            loading: true);
      }
    } catch (e) {
      SnackbarService.showMessage(l10n.pluginManagerPickFailed(e.toString()));
    }
  }
}

// ─── Clean, Premium Plugin Card ────────────────────────────────────────────

class _PluginCard extends StatelessWidget {
  final PluginInfo plugin;
  final bool isLoaded;
  final PluginOperation? operation;

  const _PluginCard({
    required this.plugin,
    required this.isLoaded,
    this.operation,
  });

  @override
  Widget build(BuildContext context) {
    final manifest = plugin.manifest;
    final l10n = AppLocalizations.of(context)!;
    final isDeleting = operation == PluginOperation.deleting;
    final isOperating = operation != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDeleting ? null : () => _showPluginDetails(context),
        borderRadius: BorderRadius.circular(16),
        highlightColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        splashColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLoaded
                  ? AppTheme.accentColor(context).withValues(alpha: 0.2)
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isLoaded
                      ? AppTheme.accentColor(context).withValues(alpha: 0.15)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLoaded
                        ? AppTheme.accentColor(context).withValues(alpha: 0.4)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: _pluginAvatar(
                    context: context,
                    manifest: manifest,
                    type: plugin.pluginType,
                    isLoaded: isLoaded,
                    iconSize: 20,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            manifest.name,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (manifest.manifestVersion !=
                            currentManifestVersion) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: l10n.pluginManagerOutdatedManifest,
                            child: const Icon(Icons.warning_amber_rounded,
                                color: Colors.orange, size: 18),
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${manifest.publisher.name} • v${manifest.version}',
                      style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isDeleting)
                _InlineOperationIndicator(label: l10n.pluginManagerDeleting)
              else
                _CustomSwitch(
                  value: isLoaded,
                  isLoading: isOperating,
                  onChanged: () {
                    final bloc = context.read<PluginBloc>();
                    if (isLoaded) {
                      bloc.add(UnloadPlugin(
                          pluginId: manifest.id,
                          pluginType: plugin.pluginType));
                    } else {
                      bloc.add(LoadPlugin(
                          pluginId: manifest.id,
                          pluginType: plugin.pluginType));
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _pluginTypeIcon(PluginType type) {
    return switch (type) {
      PluginType.contentResolver => MingCute.music_2_fill,
      PluginType.chartProvider => MingCute.chart_bar_fill,
      PluginType.lyricsProvider => MingCute.align_center_fill,
      PluginType.searchSuggestionProvider => MingCute.search_fill,
      PluginType.contentImporter => MingCute.file_import_fill,
    };
  }

  static String _pluginTypeLabel(PluginType type, AppLocalizations l10n) {
    return switch (type) {
      PluginType.contentResolver => l10n.pluginManagerTypeContentResolver,
      PluginType.chartProvider => l10n.pluginManagerTypeChartProvider,
      PluginType.lyricsProvider => l10n.pluginManagerTypeLyricsProvider,
      PluginType.searchSuggestionProvider =>
        l10n.pluginManagerTypeSuggestionProvider,
      PluginType.contentImporter => l10n.pluginManagerTypeContentImporter,
    };
  }

  static Widget _pluginAvatar({
    required BuildContext context,
    required Manifest manifest,
    required PluginType type,
    required bool isLoaded,
    required double iconSize,
    BorderRadius? borderRadius,
  }) {
    final imageUrl = manifest.thumbnailUrl ?? manifest.icon;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        imageBuilder: (context, imageProvider) => Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(12),
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        ),
        placeholder: (context, url) => _fallbackIcon(context, type, isLoaded, iconSize),
        errorWidget: (context, url, error) =>
            _fallbackIcon(context, type, isLoaded, iconSize),
      );
    }
    return _fallbackIcon(context, type, isLoaded, iconSize);
  }

  static Widget _fallbackIcon(BuildContext context, PluginType type, bool isLoaded, double iconSize) {
    return Center(
      child: Icon(
        _pluginTypeIcon(type),
        color: isLoaded
            ? AppTheme.accentColor(context)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        size: iconSize,
      ),
    );
  }

  void _showPluginDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<PluginBloc>(),
        child: _PluginDetailSheet(plugin: plugin),
      ),
    );
  }
}

// ─── OPTIMISTIC & SMOOTH Custom Switch Widget ──────────────────────────────
class _CustomSwitch extends StatefulWidget {
  final bool value;
  final bool isLoading;
  final VoidCallback onChanged;

  const _CustomSwitch({
    required this.value,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  State<_CustomSwitch> createState() => _CustomSwitchState();
}

class _CustomSwitchState extends State<_CustomSwitch> {
  late bool _localValue;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _CustomSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading && !widget.isLoading) {
      _localValue = widget.value;
    } else if (!widget.isLoading && oldWidget.value != widget.value) {
      _localValue = widget.value;
    }
  }

  void _handleTap() {
    if (widget.isLoading) return;
    setState(() => _localValue = !_localValue);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: widget.isLoading ? 0.6 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: 50,
          height: 28,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _localValue
                ? AppTheme.accentColor(context).withValues(alpha: 0.15)
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
            border: Border.all(
              color: _localValue
                  ? AppTheme.accentColor(context).withValues(alpha: 0.5)
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18),
              width: 1.5,
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment:
                _localValue ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: _localValue
                    ? AppTheme.accentColor(context)
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              child: widget.isLoading
                  ? Center(
                      child: SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _localValue
                                  ? Default_Theme.themeColor
                                  : Theme.of(context).colorScheme.onSurface)))
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Professional, Clean Bottom Sheet ──────────────────────────────────────

class _PluginDetailSheet extends StatefulWidget {
  final PluginInfo plugin;

  const _PluginDetailSheet({required this.plugin});

  @override
  State<_PluginDetailSheet> createState() => _PluginDetailSheetState();
}

class _PluginDetailSheetState extends State<_PluginDetailSheet> {
  final _loadStateService =
      PluginLoadStateService(SettingsDAO(DBProvider.db));
  bool? _autoStart;

  @override
  void initState() {
    super.initState();
    _loadAutoStart();
  }

  Future<void> _loadAutoStart() async {
    final ids = await _loadStateService.readAutoLoadPluginIds();
    if (mounted) {
      setState(() {
        _autoStart = ids.contains(widget.plugin.manifest.id);
      });
    }
  }

  Future<void> _setAutoStart(bool value) async {
    setState(() => _autoStart = value);
    if (value) {
      await _loadStateService
          .addAutoLoadPluginIds([widget.plugin.manifest.id]);
    } else {
      await _loadStateService
          .removeAutoLoadPluginIds([widget.plugin.manifest.id]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manifest = widget.plugin.manifest;
    final pluginType = widget.plugin.pluginType;

    return BlocBuilder<PluginBloc, PluginState>(
      builder: (context, state) {
        final isLoaded = state.isPluginLoaded(manifest.id);
        final operation = state.operationFor(manifest.id);
        final operating = operation != null;
        final deleting = operation == PluginOperation.deleting;

        return SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                  top: BorderSide(
                      color:
                          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                      width: 1)),
            ),
            padding: EdgeInsets.fromLTRB(
                24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Handle ──
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                // ── Header: icon + name + publisher ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: isLoaded
                            ? AppTheme.accentColor(context)
                                .withValues(alpha: 0.15)
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isLoaded
                              ? AppTheme.accentColor(context)
                                  .withValues(alpha: 0.5)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: _PluginCard._pluginAvatar(
                          context: context,
                          manifest: manifest,
                          type: pluginType,
                          isLoaded: isLoaded,
                          iconSize: 28,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            manifest.name,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                manifest.publisher.name,
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.55),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 10),
                              _StatusBadge(isLoaded: isLoaded),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Description ──
                if (manifest.description.isNotEmpty) ...[
                  Text(
                    manifest.description,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Info Card ──
                Container(
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    children: [
                      _DetailRow(
                          label: 'Version', value: manifest.version),
                      const _DetailDivider(),
                      _DetailRow(
                          label: 'Type',
                          value: _PluginCard._pluginTypeLabel(
                              pluginType, AppLocalizations.of(context)!)),
                      if (manifest.publisher.name.isNotEmpty) ...[
                        const _DetailDivider(),
                        _DetailRow(
                            label: 'Publisher',
                            value: manifest.publisher.name),
                      ],
                      if (manifest.lastUpdated != null &&
                          manifest.lastUpdated!.isNotEmpty) ...[
                        const _DetailDivider(),
                        _DetailRow(
                            label: 'Last Updated',
                            value: _formatDate(manifest.lastUpdated!)),
                      ],
                      if (manifest.createdAt != null &&
                          manifest.createdAt!.isNotEmpty) ...[
                        const _DetailDivider(),
                        _DetailRow(
                            label: 'Created',
                            value: _formatDate(manifest.createdAt!)),
                      ],
                      if (manifest.homepage.isNotEmpty) ...[
                        const _DetailDivider(),
                        _DetailRow(
                            label: 'Homepage', value: manifest.homepage),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Plugin Settings Card ──
                _PluginSettingsCard(
                  plugin: widget.plugin,
                  isLoaded: isLoaded,
                  autoStart: _autoStart ?? false,
                  onAutoStartChanged: _setAutoStart,
                ),
                const SizedBox(height: 24),

                // ── Action Buttons ──
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: operating
                              ? null
                              : () {
                                  final bloc = context.read<PluginBloc>();
                                  if (isLoaded) {
                                    bloc.add(UnloadPlugin(
                                        pluginId: manifest.id,
                                        pluginType: pluginType));
                                  } else {
                                    bloc.add(LoadPlugin(
                                        pluginId: manifest.id,
                                        pluginType: pluginType));
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isLoaded
                                ? Colors.transparent
                                : AppTheme.accentColor(context)
                                    .withValues(alpha: 0.15),
                            foregroundColor: isLoaded
                                ? Theme.of(context).colorScheme.onSurface
                                : AppTheme.accentColor(context),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isLoaded
                                    ? Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.2)
                                    : AppTheme.accentColor(context)
                                        .withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: operating
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: isLoaded
                                          ? AppTheme.accentColor(context)
                                          : Theme.of(context).colorScheme.onSurface))
                              : Text(
                                  deleting
                                      ? 'Deleting…'
                                      : isLoaded
                                          ? 'Disable Plugin'
                                          : 'Enable Plugin',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (manifest.keysRequired.isNotEmpty) ...[
                      SizedBox(
                        height: 52,
                        width: 52,
                        child: IconButton(
                          onPressed: () =>
                              _showKeysDialog(context, manifest),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.accentColor(context)
                                .withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                  color: AppTheme.accentColor(context)
                                      .withValues(alpha: 0.5),
                                  width: 1.5),
                            ),
                          ),
                          icon: Icon(Icons.key_rounded,
                              color: AppTheme.accentColor(context), size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    SizedBox(
                      height: 52,
                      width: 52,
                      child: IconButton(
                        onPressed: operating
                            ? null
                            : () => _confirmDelete(
                                context, manifest.id, manifest.name),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                                color: Colors.red.withValues(alpha: 0.5),
                                width: 1.5),
                          ),
                        ),
                        icon: const Icon(MingCute.delete_2_line,
                            color: Colors.red, size: 22),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(
      BuildContext context, String pluginId, String pluginName) {
    final bloc = context.read<PluginBloc>();
    final l10n = AppLocalizations.of(context)!;

    showVoidMusicDialog(
      context: context,
      title: l10n.pluginManagerDeleteTitle,
      subtitle: l10n.pluginManagerDeleteMessage(pluginName),
      icon: Icons.delete_outline_rounded,
      actions: [
        VoidMusicDialogAction.text(l10n.pluginManagerCancel),
        VoidMusicDialogAction.filled(
          l10n.pluginManagerDeleteAction,
          isDestructive: true,
          onPressed: () {
            if (widget.plugin.manifest.keysRequired.isNotEmpty) {
              _confirmStorageCleanup(context, bloc, pluginId, pluginName);
            } else {
              if (context.mounted) Navigator.of(context).pop();
              bloc.add(DeletePlugin(
                  pluginId: pluginId, pluginType: widget.plugin.pluginType));
            }
          },
        ),
      ],
    );
  }

  void _confirmStorageCleanup(BuildContext context, PluginBloc bloc,
      String pluginId, String pluginName) {
    final l10n = AppLocalizations.of(context)!;
    showVoidMusicDialog(
      context: context,
      title: l10n.pluginManagerDeleteStorageTitle,
      subtitle: l10n.pluginManagerDeleteStorageMessage(pluginName),
      icon: Icons.storage_outlined,
      actions: [
        VoidMusicDialogAction.text(
          l10n.pluginManagerDeleteStorageKeep,
          onPressed: () {
            if (context.mounted) Navigator.of(context).pop();
            bloc.add(DeletePlugin(
                pluginId: pluginId,
                pluginType: widget.plugin.pluginType,
                cleanStorage: false));
          },
        ),
        VoidMusicDialogAction.filled(
          l10n.pluginManagerDeleteStorageRemove,
          isDestructive: true,
          onPressed: () {
            if (context.mounted) Navigator.of(context).pop();
            bloc.add(DeletePlugin(
                pluginId: pluginId,
                pluginType: widget.plugin.pluginType,
                cleanStorage: true));
          },
        ),
      ],
    );
  }

  void _showKeysDialog(BuildContext context, Manifest manifest) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _ApiKeysDialogContent(manifest: manifest),
    );
  }
}

// ─── Rich Plugin Settings Card ───────────────────────────────────────────────

class _PluginSettingsCard extends StatefulWidget {
  final PluginInfo plugin;
  final bool isLoaded;
  final bool autoStart;
  final Future<void> Function(bool) onAutoStartChanged;

  const _PluginSettingsCard({
    required this.plugin,
    required this.isLoaded,
    required this.autoStart,
    required this.onAutoStartChanged,
  });

  @override
  State<_PluginSettingsCard> createState() => _PluginSettingsCardState();
}

class _PluginSettingsCardState extends State<_PluginSettingsCard> {
  late bool _autoStart;

  @override
  void initState() {
    super.initState();
    _autoStart = widget.autoStart;
  }

  @override
  void didUpdateWidget(covariant _PluginSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoStart != widget.autoStart) {
      _autoStart = widget.autoStart;
    }
  }

  bool get _isContentResolver =>
      widget.plugin.pluginType == PluginType.contentResolver;
  bool get _isLyricsProvider =>
      widget.plugin.pluginType == PluginType.lyricsProvider;
  bool get _isSuggestionProvider =>
      widget.plugin.pluginType == PluginType.searchSuggestionProvider;

  @override
  Widget build(BuildContext context) {
    final pluginId = widget.plugin.manifest.id;

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) {
        final isHome = settings.homePluginIds.contains(pluginId);
        final isSearch = settings.searchPluginIds.contains(pluginId);
        final isDownload = settings.downloadPluginIds.contains(pluginId);
        final resolverPriority = settings.resolverPriority;
        final lyricsPriority = settings.lyricsPriority;
        final suggestionPriority = settings.suggestionPluginIds;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(MingCute.settings_3_line,
                        size: 16,
                        color: AppTheme.accentColor(context)
                            .withValues(alpha: 0.9)),
                    const SizedBox(width: 8),
                    Text(
                      'PLUGIN SETTINGS',
                      style: TextStyle(
                        color: AppTheme.accentColor(context)
                            .withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06)),

              // ── Auto Start ──
              _SettingsTile(
                icon: MingCute.power_line,
                title: 'Auto Start on Launch',
                subtitle: 'Automatically load this plugin when the app starts',
                trailing: _SettingsSwitch(
                  value: _autoStart,
                  onChangedAsync: (val) async {
                    setState(() => _autoStart = val);
                    await widget.onAutoStartChanged(val);
                  },
                ),
              ),

              // ── Content Resolver Settings ──
              if (_isContentResolver) ...[
                Divider(height: 1, thickness: 1, color: Theme.of(context).brightness == Brightness.dark ? const Color(0x0AFFFFFF) : const Color(0x0A000000)),

                // Use as Home Plugin
                _SettingsTile(
                  icon: MingCute.home_4_line,
                  title: 'Use as Home Plugin',
                  subtitle: 'Show this plugin\'s playlists on the Discover page',
                  trailing: _SettingsSwitch(
                    value: isHome,
                    onChanged: (val) {
                      final cubit = context.read<SettingsCubit>();
                      final current =
                          List<String>.from(settings.homePluginIds);
                      if (val) {
                        if (!current.contains(pluginId)) {
                          current.insert(0, pluginId);
                        }
                      } else {
                        current.remove(pluginId);
                      }
                      cubit.setHomePluginIds(current);
                    },
                  ),
                ),

                Divider(height: 1, thickness: 1, color: Theme.of(context).brightness == Brightness.dark ? const Color(0x0AFFFFFF) : const Color(0x0A000000)),

                // Use as Search Plugin
                _SettingsTile(
                  icon: MingCute.search_line,
                  title: 'Use as Search Plugin',
                  subtitle: 'Include this plugin as a source in search',
                  trailing: _SettingsSwitch(
                    value: isSearch,
                    onChanged: (val) {
                      final cubit = context.read<SettingsCubit>();
                      final current =
                          List<String>.from(settings.searchPluginIds);
                      if (val) {
                        if (!current.contains(pluginId)) {
                          current.add(pluginId);
                        }
                      } else {
                        current.remove(pluginId);
                      }
                      cubit.setSearchPluginIds(current);
                    },
                  ),
                ),

                Divider(height: 1, thickness: 1, color: Theme.of(context).brightness == Brightness.dark ? const Color(0x0AFFFFFF) : const Color(0x0A000000)),

                // Use for Downloads
                _SettingsTile(
                  icon: MingCute.download_2_line,
                  title: 'Use for Downloads',
                  subtitle: 'Use this plugin for resolving download streams',
                  trailing: _SettingsSwitch(
                    value: isDownload,
                    onChanged: (val) {
                      final cubit = context.read<SettingsCubit>();
                      final current =
                          List<String>.from(settings.downloadPluginIds);
                      if (val) {
                        if (!current.contains(pluginId)) {
                          current.add(pluginId);
                        }
                      } else {
                        current.remove(pluginId);
                      }
                      cubit.setDownloadPluginIds(current);
                    },
                  ),
                ),

                Divider(height: 1, thickness: 1, color: Theme.of(context).brightness == Brightness.dark ? const Color(0x0AFFFFFF) : const Color(0x0A000000)),

                // Resolver Priority
                _SettingsPriorityTile(
                  icon: MingCute.list_ordered_line,
                  title: 'Resolver Priority',
                  subtitle: 'Position in content resolver order',
                  pluginId: pluginId,
                  priorityList: resolverPriority,
                  onMoveUp: () {
                    final list = List<String>.from(resolverPriority);
                    final idx = list.indexOf(pluginId);
                    if (idx > 0) {
                      list.removeAt(idx);
                      list.insert(idx - 1, pluginId);
                      context.read<SettingsCubit>().setResolverPriority(list);
                    }
                  },
                  onMoveDown: () {
                    final list = List<String>.from(resolverPriority);
                    final idx = list.indexOf(pluginId);
                    if (idx >= 0 && idx < list.length - 1) {
                      list.removeAt(idx);
                      list.insert(idx + 1, pluginId);
                      context.read<SettingsCubit>().setResolverPriority(list);
                    }
                  },
                ),
              ],

              // ── Lyrics Provider Settings ──
              if (_isLyricsProvider) ...[
                Divider(height: 1, thickness: 1, color: Theme.of(context).brightness == Brightness.dark ? const Color(0x0AFFFFFF) : const Color(0x0A000000)),
                _SettingsPriorityTile(
                  icon: MingCute.align_center_line,
                  title: 'Lyrics Priority',
                  subtitle: 'Position in lyrics resolver order',
                  pluginId: pluginId,
                  priorityList: lyricsPriority,
                  onMoveUp: () {
                    final list = List<String>.from(lyricsPriority);
                    final idx = list.indexOf(pluginId);
                    if (idx > 0) {
                      list.removeAt(idx);
                      list.insert(idx - 1, pluginId);
                      context.read<SettingsCubit>().setLyricsPriority(list);
                    }
                  },
                  onMoveDown: () {
                    final list = List<String>.from(lyricsPriority);
                    final idx = list.indexOf(pluginId);
                    if (idx >= 0 && idx < list.length - 1) {
                      list.removeAt(idx);
                      list.insert(idx + 1, pluginId);
                      context.read<SettingsCubit>().setLyricsPriority(list);
                    }
                  },
                ),
              ],

              // ── Suggestion Provider Settings ──
              if (_isSuggestionProvider) ...[
                Divider(height: 1, thickness: 1, color: Theme.of(context).brightness == Brightness.dark ? const Color(0x0AFFFFFF) : const Color(0x0A000000)),
                _SettingsPriorityTile(
                  icon: MingCute.search_3_line,
                  title: 'Suggestion Priority',
                  subtitle: 'Position in search suggestion order',
                  pluginId: pluginId,
                  priorityList: suggestionPriority,
                  onMoveUp: () {
                    final list = List<String>.from(suggestionPriority);
                    final idx = list.indexOf(pluginId);
                    if (idx > 0) {
                      list.removeAt(idx);
                      list.insert(idx - 1, pluginId);
                      context
                          .read<SettingsCubit>()
                          .setSuggestionPluginIds(list);
                    }
                  },
                  onMoveDown: () {
                    final list = List<String>.from(suggestionPriority);
                    final idx = list.indexOf(pluginId);
                    if (idx >= 0 && idx < list.length - 1) {
                      list.removeAt(idx);
                      list.insert(idx + 1, pluginId);
                      context
                          .read<SettingsCubit>()
                          .setSuggestionPluginIds(list);
                    }
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Settings Tile ────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

// ─── Priority Tile ────────────────────────────────────────────────────────────

class _SettingsPriorityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String pluginId;
  final List<String> priorityList;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _SettingsPriorityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.pluginId,
    required this.priorityList,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final idx = priorityList.indexOf(pluginId);
    final position = idx >= 0 ? idx + 1 : null;
    final total = priorityList.length;
    final canMoveUp = idx > 0;
    final canMoveDown = idx >= 0 && idx < total - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (position != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accentColor(context).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppTheme.accentColor(context).withValues(alpha: 0.4)),
              ),
              child: Text(
                '#$position of $total',
                style: TextStyle(
                  color: AppTheme.accentColor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Text(
              'Not set',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          const SizedBox(width: 8),
          Column(
            children: [
              _PriorityArrow(
                icon: MingCute.up_line,
                enabled: canMoveUp,
                onTap: onMoveUp,
              ),
              const SizedBox(height: 2),
              _PriorityArrow(
                icon: MingCute.down_line,
                enabled: canMoveDown,
                onTap: onMoveDown,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriorityArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PriorityArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.25,
        child: Container(
          width: 28,
          height: 26,
          decoration: BoxDecoration(
            color: enabled
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon,
              size: 14,
              color: enabled
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
        ),
      ),
    );
  }
}

// ─── Settings Switch ──────────────────────────────────────────────────────────

class _SettingsSwitch extends StatefulWidget {
  final bool value;
  final Future<void> Function(bool)? onChangedAsync;
  final void Function(bool)? onChanged;

  const _SettingsSwitch({
    required this.value,
    this.onChangedAsync,
    this.onChanged,
  });

  @override
  State<_SettingsSwitch> createState() => _SettingsSwitchState();
}

class _SettingsSwitchState extends State<_SettingsSwitch> {
  late bool _local;

  @override
  void initState() {
    super.initState();
    _local = widget.value;
  }

  @override
  void didUpdateWidget(covariant _SettingsSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _local = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final next = !_local;
        setState(() => _local = next);
        if (widget.onChangedAsync != null) {
          await widget.onChangedAsync!(next);
        }
        if (widget.onChanged != null) {
          widget.onChanged!(next);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        width: 46,
        height: 26,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: _local
              ? AppTheme.accentColor(context).withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
          border: Border.all(
            color: _local
                ? AppTheme.accentColor(context).withValues(alpha: 0.5)
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18),
            width: 1.4,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: _local ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: _local
                  ? AppTheme.accentColor(context)
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Self-Contained API Keys Form State ─────────────────────────────────────

class _ApiKeysDialogContent extends StatefulWidget {
  final Manifest manifest;
  const _ApiKeysDialogContent({required this.manifest});

  @override
  State<_ApiKeysDialogContent> createState() => _ApiKeysDialogContentState();
}

class _ApiKeysDialogContentState extends State<_ApiKeysDialogContent> {
  late Future<Map<String, String>> _future;
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _future = _loadKeys();
  }

  Future<Map<String, String>> _loadKeys() async {
    final dao = ServiceLocator.pluginStorageDao;
    final existing = <String, String>{};
    for (final key in widget.manifest.keysRequired.keys) {
      final entity = await dao.getEntry(pluginId: widget.manifest.id, key: key);
      if (entity != null) existing[key] = entity.value;
    }
    return existing;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<Map<String, String>>(
      future: _future,
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
              height: 200,
              child: Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.accentColor(context))));
        }

        final existing = snapshot.data!;
        for (final entry in widget.manifest.keysRequired.entries) {
          _controllers.putIfAbsent(entry.key,
              () => TextEditingController(text: existing[entry.key] ?? ''));
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.pluginManagerApiKeysTitle,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ...widget.manifest.keysRequired.entries.map((entry) {
                final req = entry.value;
                final keyLabel = entry.key
                    .replaceAll('_', ' ')
                    .split(' ')
                    .map((w) => w.isNotEmpty
                        ? '${w[0].toUpperCase()}${w.substring(1)}'
                        : '')
                    .join(' ');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _controllers[entry.key],
                        obscureText: req.isSecret,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: keyLabel,
                          hintText: req.defaultValue ?? entry.key,
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
                          labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                          hintStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                          suffixIcon: req.isSecret
                              ? Icon(MingCute.eye_close_line,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                  size: 20)
                              : null,
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: AppTheme.accentColor(context),
                                  width: 1.5)),
                        ),
                      ),
                      if (req.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 4),
                          child: Text(
                            req.description,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                fontSize: 13,
                                fontWeight: FontWeight.w400),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          final dao = ServiceLocator.pluginStorageDao;
                          for (final entry in _controllers.entries) {
                            final val = entry.value.text.trim();
                            if (val.isNotEmpty) {
                              await dao.putEntry(
                                  pluginId: widget.manifest.id,
                                  key: entry.key,
                                  value: val);
                            } else {
                              await dao.deleteEntry(
                                  pluginId: widget.manifest.id, key: entry.key);
                            }
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          SnackbarService.showMessage(
                              l10n.pluginManagerApiKeysSaved);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor(context),
                    foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white))
                      : Text(l10n.pluginManagerSave,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InlineOperationIndicator extends StatelessWidget {
  final String label;

  const _InlineOperationIndicator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.accentColor(context))),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Shared UI Helpers ─────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isLoaded;
  const _StatusBadge({required this.isLoaded});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isLoaded
            ? AppTheme.accentColor(context).withValues(alpha: 0.15)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: isLoaded
                ? AppTheme.accentColor(context).withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1),
      ),
      child: Text(
        isLoaded
            ? l10n.pluginManagerStatusActive
            : l10n.pluginManagerStatusInactive,
        style: TextStyle(
            color: isLoaded
                ? AppTheme.accentColor(context)
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _formatDate(String isoDate) {
  try {
    final dt = DateTime.parse(isoDate);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return isoDate;
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DetailDivider extends StatelessWidget {
  const _DetailDivider();
  @override
  Widget build(BuildContext context) {
    return Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06));
  }
}
