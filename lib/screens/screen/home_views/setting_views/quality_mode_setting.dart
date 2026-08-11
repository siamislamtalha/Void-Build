import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/setting_shared_widgets.dart';
import 'package:voidmusic/screens/widgets/bottom_safe_area_spacer.dart';
import 'package:voidmusic/screens/widgets/plugin_bootstrap_overlay.dart';
import 'package:voidmusic/screens/widgets/snackbar.dart';
import 'package:voidmusic/services/audiophile_mode_service.dart';
import 'package:voidmusic/services/db/dao/settings_dao.dart';
import 'package:voidmusic/services/db/db_provider.dart';

class QualityModeSetting extends StatefulWidget {
  const QualityModeSetting({super.key});

  @override
  State<QualityModeSetting> createState() => _QualityModeSettingState();
}

class _QualityModeSettingState extends State<QualityModeSetting> {
  final SettingsDAO _settingsDao = SettingsDAO(DBProvider.db);
  String _currentMode = QualityModeValues.normal;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  Future<void> _loadMode() async {
    await AudiophileModeService.checkAndCache(_settingsDao);
    if (mounted) {
      setState(() {
        _currentMode = AudiophileModeService.mode;
        _isLoading = false;
      });
    }
  }

  Future<void> _switchMode(String newMode) async {
    if (_currentMode == newMode) return;

    await AudiophileModeService.setMode(_settingsDao, newMode);
    setState(() {
      _currentMode = newMode;
    });

    if (mounted) {
      SnackbarService.showMessage(
        newMode == QualityModeValues.audiophile
            ? 'Switched to Audiophile Mode (High Quality FLAC/DSD)'
            : 'Switched to Normal Mode (Standard Streaming)',
      );
      _showRebootstrapDialog();
    }
  }

  void _showRebootstrapDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(MingCute.plugin_2_line, color: Color(0xFFFFB703)),
            SizedBox(width: 10),
            Text('Update Plugins?'),
          ],
        ),
        content: Text(
          _currentMode == QualityModeValues.audiophile
              ? 'Audiophile Mode requires 11 high-fidelity plugins (.sflx / .spotiflac-ext).\n\nSelect "Clean Reset" to purge old plugins & residue before installing Audiophile plugins.'
              : 'Normal Mode uses 14 standard plugins (.bex).\n\nSelect "Clean Reset" to purge old plugins & residue before installing Standard plugins.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Later'),
          ),
          OutlinedButton.icon(
            icon: const Icon(MingCute.download_2_line, size: 16),
            label: const Text('Download Only'),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _triggerPluginBootstrap(isCleanReset: false);
            },
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB703),
              foregroundColor: Colors.black,
            ),
            icon: const Icon(MingCute.refresh_3_line, size: 16),
            label: const Text('Clean Reset & Install'),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _triggerPluginBootstrap(isCleanReset: true);
            },
          ),
        ],
      ),
    );
  }

  void _triggerPluginBootstrap({bool isCleanReset = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PluginBootstrapOverlay(
          isCleanReset: isCleanReset,
          onComplete: () {
            Navigator.pop(context);
            SnackbarService.showMessage(
              isCleanReset
                  ? 'Clean reset & plugin setup completed successfully!'
                  : 'Plugin setup completed successfully!',
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
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
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Quality & Ecosystem Mode',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                const SettingSectionHeader(
                  label: 'CURRENT MODE',
                ),
                const SizedBox(height: 8),

                // Normal Mode Card
                _QualityModeCard(
                  title: 'Normal Mode',
                  subtitle:
                      'Standard streaming & downloads using standard BEX plugins. Optimized for lower bandwidth and compatibility.',
                  badgeText: 'Standard',
                  badgeColor: colorScheme.primary,
                  icon: MingCute.music_2_line,
                  isSelected: _currentMode == QualityModeValues.normal,
                  onTap: () => _switchMode(QualityModeValues.normal),
                ),

                const SizedBox(height: 12),

                // Audiophile Mode Card
                _QualityModeCard(
                  title: 'Audiophile Mode',
                  subtitle:
                      'High-resolution FLAC, HD FLAC & DSD playback using SpotiFLAC extensions (.sflx / .spotiflac-ext). Isolates standard BEX plugins.',
                  badgeText: 'FLAC / HD FLAC / DSD 🎧',
                  badgeColor: const Color(0xFFFFB703),
                  icon: MingCute.headphone_line,
                  isSelected: _currentMode == QualityModeValues.audiophile,
                  onTap: () => _switchMode(QualityModeValues.audiophile),
                ),

                const SizedBox(height: 24),

                const SettingSectionHeader(
                  label: 'PLUGIN ECOSYSTEM',
                ),
                const SizedBox(height: 8),

                SettingCard(
                  children: [
                    InkWell(
                      onTap: () => _triggerPluginBootstrap(isCleanReset: true),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const SettingIconBox(
                              icon: MingCute.refresh_3_line,
                              color: Color(0xFFFFB703),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Clean Reset & Reinstall Plugins',
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _currentMode == QualityModeValues.audiophile
                                        ? 'Purge all old plugins/residue and reinstall 11 Audiophile plugins'
                                        : 'Purge all old plugins/residue and reinstall 14 Standard plugins',
                                    style: TextStyle(
                                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                    InkWell(
                      onTap: () => _triggerPluginBootstrap(isCleanReset: false),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            SettingIconBox(
                              icon: MingCute.download_3_line,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Download Missing Plugins Only',
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Keep existing plugins and download missing ones',
                                    style: TextStyle(
                                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const BottomSafeAreaSpacer(),
              ],
            ),
    );
  }
}

class _QualityModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _QualityModeCard({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? badgeColor.withValues(alpha: 0.12)
                : (isDark ? const Color(0xFF161618) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? badgeColor
                  : colorScheme.onSurface.withValues(alpha: 0.08),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? badgeColor.withValues(alpha: 0.2)
                      : colorScheme.onSurface.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? badgeColor : colorScheme.onSurface,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: badgeColor.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colorScheme.onSurface
                            .withValues(alpha: isDark ? 0.6 : 0.7),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
