import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:voidmusic/l10n/app_localizations.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:voidmusic/plugins/blocs/repository/plugin_repository_cubit.dart';
import 'package:voidmusic/plugins/models/plugin_repository.dart';
import 'package:voidmusic/screens/widgets/sign_board_widget.dart';
import 'package:voidmusic/screens/widgets/bottom_safe_area_spacer.dart';
import 'package:voidmusic/screens/widgets/snackbar.dart';
import 'package:voidmusic/screens/screen/home_views/repository_detail_screen.dart';
import 'package:voidmusic/services/audiophile_mode_service.dart';

class PluginRepositoryView extends StatefulWidget {
  const PluginRepositoryView({super.key});

  @override
  State<PluginRepositoryView> createState() => _PluginRepositoryViewState();
}

class _PluginRepositoryViewState extends State<PluginRepositoryView> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<PluginRepositoryCubit>().loadRepositories();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _showAddRepositoryDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        title: Text(
          l10n.pluginRepositoryAddTitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.pluginRepositoryAddSubtitle,
              style: TextStyle(
                color: Default_Theme.primaryColor2.withValues(alpha: 0.65),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 46,
              child: TextField(
                controller: _urlController,
                autofocus: true,
                keyboardType: TextInputType.url,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'https://...',
                  hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      fontSize: 14),
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.12)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color:
                            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                        width: 1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _AestheticButton(
              text: l10n.pluginRepositoryAddAction,
              icon: MingCute.add_line,
              color: AppTheme.accentColor(context),
              fullWidth: true,
              onTap: () {
                final url = _urlController.text.trim();
                if (url.isNotEmpty) {
                  context.read<PluginRepositoryCubit>().addRepository(url);
                }
                Navigator.pop(ctx);
                _urlController.clear();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.pluginRepositoryTitle,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.pluginRepositorySubtitle,
                          style: TextStyle(
                            color: Default_Theme.primaryColor2
                                .withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _AestheticButton(
                    text: l10n.pluginRepositoryAddAction,
                    icon: MingCute.add_line,
                    color: AppTheme.accentColor(context),
                    onTap: () => _showAddRepositoryDialog(context),
                  ),
                ],
              ),
            ),
            // ── Audiophile mode active banner ──
            if (AudiophileModeService.isAudiophile)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB703).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFB703).withValues(alpha: 0.40),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(MingCute.headphone_line,
                        color: Color(0xFFFFB703), size: 16),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Audiophile Mode active — only .sflx / .spotiflac-ext plugins load',
                        style: TextStyle(
                          color: Color(0xFFFFD166),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB703).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'HI-RES',
                        style: TextStyle(
                          color: Color(0xFFFFB703),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: BlocConsumer<PluginRepositoryCubit, PluginRepositoryState>(
                listener: (context, state) {
                  if (state is PluginRepositoryError) {
                    SnackbarService.showMessage(
                      _localizedRepositoryError(context, state.message),
                    );
                  }
                },
                builder: (context, state) {
                  if (state is PluginRepositoryLoading) {
                    return Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.accentColor(context), strokeWidth: 3),
                    );
                  } else if (state is PluginRepositoryLoaded) {
                    if (state.repositories.isEmpty) {
                      return SignBoardWidget(
                        message: l10n.pluginRepositoryEmpty,
                        icon: MingCute.cloud_snow_line,
                      );
                    }
                    return RefreshIndicator(
                      color: AppTheme.accentColor(context),
                      backgroundColor:
                          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      onRefresh: () async => await context
                          .read<PluginRepositoryCubit>()
                          .loadRepositories(),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 700;
                          if (isWide) {
                            return GridView.builder(
                              physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics()),
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 450,
                                mainAxisExtent:
                                    184, // Expanded height to fit the new URL box
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: state.repositories.length,
                              itemBuilder: (context, index) =>
                                  _RepoCard(repo: state.repositories[index]),
                            );
                          }
                          return ListView.builder(
                            physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics()),
                            itemCount: state.repositories.length + 1,
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                            itemBuilder: (context, index) {
                              if (index < state.repositories.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _RepoCard(repo: state.repositories[index]),
                                );
                              }
                              return const BottomSafeAreaSpacer();
                            },
                          );
                        },
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Redesigned Modern Repository Card ──────────────────────────────────────

class _RepoCard extends StatelessWidget {
  final PluginRepositoryModel repo;
  const _RepoCard({required this.repo});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final generatedDate = repo.generatedAt == null
        ? l10n.pluginRepositoryUnknownUpdate
        : repo.generatedAt!.toIso8601String().split('T').first;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        RepositoryDetailScreen(repository: repo))),
            splashColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
            highlightColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Header (Icon, Title, Desc, Chevron)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor(context)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.accentColor(context)
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Icon(MingCute.cloud_line,
                            size: 20, color: AppTheme.accentColor(context)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              repo.name,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.95),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              repo.description.isEmpty
                                  ? l10n.pluginRepositoryNoDescription
                                  : repo.description,
                              style: TextStyle(
                                  color: Default_Theme.primaryColor2
                                      .withValues(alpha: 0.65),
                                  fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Explicit Navigation Chevron
                      Icon(MingCute.right_line,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          size: 20),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Row 2: Copiable URL Box
                  Material(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: repo.url));
                        SnackbarService.showMessage(
                          l10n.pluginRepositoryUrlCopied,
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      splashColor:
                          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Theme.of(context).colorScheme.onSurface
                                  .withValues(alpha: 0.08)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(MingCute.copy_2_line,
                                size: 14,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                repo.url,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Row 3: Footer (Badges + Delete)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Badge(
                                icon: MingCute.plugin_2_line,
                                label: l10n.pluginRepositoryPluginsCount(
                                    repo.plugins.length)),
                            _Badge(
                                icon: MingCute.clock_2_line,
                                label: generatedDate),
                            // ── Plugin-type composition badge ──
                            Builder(builder: (ctx) {
                              final audiophileCount = repo.plugins.where((p) {
                                final a = p.assetName.toLowerCase();
                                return a.endsWith('.sflx') ||
                                    a.endsWith('.spotiflac-ext') ||
                                    p.id.startsWith('audiophile.');
                              }).length;
                              final standardCount =
                                  repo.plugins.length - audiophileCount;
                              if (audiophileCount > 0 && standardCount > 0) {
                                return _Badge(
                                    icon: MingCute.headphone_line,
                                    label:
                                        '$audiophileCount audiophile · $standardCount standard',
                                    color: const Color(0xFFFFB703));
                              } else if (audiophileCount > 0) {
                                return const _Badge(
                                    icon: MingCute.headphone_line,
                                    label: 'Audiophile (.sflx / .spotiflac-ext)',
                                    color: Color(0xFFFFB703));
                              }
                              return const SizedBox.shrink();
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Muted Premium Delete Button
                      Material(
                        color: Colors.redAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: () => context
                              .read<PluginRepositoryCubit>()
                              .removeRepository(repo.url),
                          borderRadius: BorderRadius.circular(10),
                          splashColor: Colors.redAccent.withValues(alpha: 0.12),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(MingCute.delete_2_line,
                                color: Colors.redAccent.withValues(alpha: 0.8),
                                size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _localizedRepositoryError(BuildContext context, String rawMessage) {
  final l10n = AppLocalizations.of(context)!;
  if (rawMessage.startsWith('Failed to load repositories')) {
    return l10n.pluginRepositoryErrorLoad;
  }
  if (rawMessage.startsWith('Invalid repository')) {
    return l10n.pluginRepositoryErrorInvalid;
  }
  if (rawMessage.startsWith('Failed to remove repository')) {
    return l10n.pluginRepositoryErrorRemove;
  }
  return rawMessage;
}

// ── Shared UI Helpers ────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  /// Optional tint color for audiophile/special badges. Null = default muted.
  final Color? color;
  const _Badge({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    final bgColor = color != null
        ? color!.withValues(alpha: 0.10)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05);
    final borderColor = color != null
        ? color!.withValues(alpha: 0.30)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06);
    final textColor = color ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: effectiveColor, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}


class _AestheticButton extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final bool fullWidth;
  final VoidCallback onTap;

  const _AestheticButton({
    required this.text,
    required this.color,
    this.icon,
    this.fullWidth = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withValues(alpha: 0.15),
        highlightColor: color.withValues(alpha: 0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 38,
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(
                    color: color,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
