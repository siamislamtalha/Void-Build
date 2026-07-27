import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:voidmusic/plugins/blocs/plugin/plugin_bloc.dart';
import 'package:voidmusic/plugins/blocs/plugin/plugin_state.dart';
import 'package:voidmusic/screens/widgets/source_badge.dart';
import 'package:voidmusic/src/rust/api/plugin/plugin_info.dart';
import 'package:voidmusic/src/rust/api/plugin/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Horizontal scrolling chip bar for selecting the active plugin.
///
/// Displays loaded plugins of a given [pluginType] as selectable chips.
/// The currently active plugin is highlighted with dynamic theme color.
///
/// Usage:
/// ```dart
/// PluginSelectorBar(
///   pluginType: PluginType.contentResolver,
///   activePluginId: _activeId,
///   onPluginSelected: (info) => setState(() => _activeId = info.manifest.id),
/// )
/// ```
class PluginSelectorBar extends StatelessWidget {
  /// Which plugin type to show (contentResolver or chartProvider).
  final PluginType pluginType;

  /// Currently selected plugin ID (highlighted).
  final String? activePluginId;

  /// Called when user taps a plugin chip.
  final ValueChanged<PluginInfo> onPluginSelected;

  /// Whether to show an "All" chip at the start.
  final bool showAllOption;

  /// Called when user taps the "All" chip.
  final VoidCallback? onAllSelected;

  const PluginSelectorBar({
    super.key,
    required this.pluginType,
    required this.activePluginId,
    required this.onPluginSelected,
    this.showAllOption = false,
    this.onAllSelected,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PluginBloc, PluginState>(
      buildWhen: (prev, curr) =>
          prev.loadedPluginIds != curr.loadedPluginIds ||
          prev.availablePlugins != curr.availablePlugins,
      builder: (context, state) {
        final plugins = pluginType == PluginType.contentResolver
            ? state.loadedContentResolvers
            : state.loadedChartProviders;

        if (plugins.isEmpty && !showAllOption) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: plugins.length + (showAllOption ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (showAllOption && index == 0) {
                final isActive = activePluginId == null;
                return _PluginChip(
                  label: 'All',
                  pluginId: null,
                  isActive: isActive,
                  onTap: onAllSelected ?? () {},
                );
              }

              final plugin = plugins[index - (showAllOption ? 1 : 0)];
              final id = plugin.manifest.id;
              final isActive = id == activePluginId;

              return _PluginChip(
                label: plugin.manifest.name,
                pluginId: id,
                isActive: isActive,
                onTap: () => onPluginSelected(plugin),
              );
            },
          ),
        );
      },
    );
  }
}

class _PluginChip extends StatelessWidget {
  final String label;
  final String? pluginId;
  final bool isActive;
  final VoidCallback onTap;

  const _PluginChip({
    required this.label,
    required this.pluginId,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor(context);
    final tint = AppTheme.accentTintColor(context, alpha: 0.15);
    final inactiveBorder = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2);
    final inactiveText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: isActive ? tint : Colors.transparent,
          side: BorderSide(
            color: isActive ? accent : inactiveBorder,
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pluginId != null) ...[
              SourceBadgeByPluginId(pluginId: pluginId!, size: 14),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isActive ? accent : inactiveText,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ).merge(Default_Theme.secondoryTextStyle),
            ),
          ],
        ),
      ),
    );
  }
}
