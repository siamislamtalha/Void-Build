import 'package:voidmusic/screens/screen/home_views/setting_views/about.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/appui_setting.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/local_music_setting.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/plugin_defaults_setting.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/quality_mode_setting.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/storage_setting.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/country_setting.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/download_setting.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/lastfm_setting.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/player_setting.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/updates_setting.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/audio_settings.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/advanced_features_settings.dart';
import 'package:voidmusic/screens/screen/plugin_manager_screen.dart';
import 'package:flutter/material.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:voidmusic/l10n/app_localizations.dart';
import 'package:voidmusic/screens/widgets/bottom_safe_area_spacer.dart';
import 'package:icons_plus/icons_plus.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: Text(
          AppLocalizations.of(context)!.settingsTitle,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              maxWidth: 640), // Desktop & tablet responsive
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // ── Group 1: Core App & Plugins ──
              _SettingsSection(
                children: [
                  _SettingsTile(
                    title: 'Quality Mode',
                    subtitle: 'Normal vs Audiophile (FLAC/DSD) mode',
                    icon: MingCute.disc_fill,
                    iconColor: const Color(0xFFFFB703),
                    isHighlightIcon: true,
                    onTap: () =>
                        _navigate(context, const QualityModeSetting()),
                  ),
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsPlugins,
                    subtitle:
                        AppLocalizations.of(context)!.settingsPluginsSubtitle,
                    icon: MingCute.plugin_2_fill,
                    iconColor: AppTheme.accentColor(context),
                    isHighlightIcon:
                        true, // Gives the accent color a bit more pop
                    onTap: () =>
                        _navigate(context, const PluginManagerScreen()),
                  ),
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsPluginDefaults,
                    subtitle: AppLocalizations.of(context)!
                        .settingsPluginDefaultsSubtitle,
                    icon: MingCute.settings_6_fill,
                    iconColor: AppTheme.accentColor(context),
                    onTap: () =>
                        _navigate(context, const PluginDefaultsSettings()),
                  ),
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsUpdates,
                    subtitle:
                        AppLocalizations.of(context)!.settingsUpdatesSubtitle,
                    icon: MingCute.download_3_fill,
                    iconColor: AppTheme.accentColor(context),
                    onTap: () => _navigate(context, const UpdatesSettings()),
                  ),
                ],
              ),

              // ── Group 2: Playback & Media ──
              _SettingsSection(
                children: [
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsPlayer,
                    subtitle:
                        AppLocalizations.of(context)!.settingsPlayerSubtitle,
                    icon: MingCute.airpods_fill,
                    iconColor: AppTheme.accentColor(context),
                    onTap: () => _navigate(context, const PlayerSetting()),
                  ),
                  _SettingsTile(
                    title: 'Audio Settings',
                    subtitle: 'Advanced audio features and effects',
                    icon: MingCute.music_2_fill,
                    iconColor: AppTheme.accentColor(context),
                    onTap: () => _navigate(context, const AudioSettings()),
                  ),
                  _SettingsTile(
                    title: 'Advanced Features',
                    subtitle: 'Experimental and power-user features',
                    icon: MingCute.flash_fill,
                    iconColor: AppTheme.accentColor(context),
                    onTap: () => _navigate(context, const AdvancedFeaturesSettings()),
                  ),
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsDownloads,
                    subtitle:
                        AppLocalizations.of(context)!.settingsDownloadsSubtitle,
                    icon: MingCute.folder_download_fill,
                    iconColor: AppTheme.accentColor(context),
                    onTap: () => _navigate(context, const DownloadSettings()),
                  ),
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsLocalTracks,
                    subtitle: AppLocalizations.of(context)!
                        .settingsLocalTracksSubtitle,
                    icon: MingCute.music_2_fill,
                    iconColor: AppTheme.accentColor(context),
                    onTap: () => _navigate(context, const LocalMusicSettings()),
                  ),
                ],
              ),

              // ── Group 3: Preferences & Integrations ──
              _SettingsSection(
                children: [
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsUIElements,
                    subtitle: AppLocalizations.of(context)!
                        .settingsUIElementsSubtitle,
                    icon: MingCute.display_fill,
                    iconColor: AppTheme.accentColor(context),
                    onTap: () => _navigate(context, const AppUISettings()),
                  ),
                  _SettingsTile(
                    title:
                        AppLocalizations.of(context)!.settingsLanguageCountry,
                    subtitle: AppLocalizations.of(context)!
                        .settingsLanguageCountrySubtitle,
                    icon: MingCute.globe_fill,
                    iconColor: AppTheme.accentColor(context),
                    onTap: () => _navigate(context, const CountrySettings()),
                  ),
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsStorage,
                    subtitle:
                        AppLocalizations.of(context)!.settingsStorageSubtitle,
                    icon: MingCute.coin_2_fill,
                    iconColor: AppTheme.accentColor(context),
                    onTap: () => _navigate(context, const BackupSettings()),
                  ),
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsLastFM,
                    subtitle:
                        AppLocalizations.of(context)!.settingsLastFMSubtitle,
                    icon: FontAwesome.lastfm_brand,
                    iconColor: AppTheme.accentColor(context),
                    onTap: () => _navigate(context, const LastDotFM()),
                  ),
                ],
              ),

              // ── Group 4: Info & About Dev ──
              _SettingsSection(
                children: [
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsAbout,
                    subtitle:
                        AppLocalizations.of(context)!.settingsAboutSubtitle,
                    icon: MingCute.flower_4_fill,
                    iconColor: AppTheme.accentColor(context),
                    isHighlightIcon: true,
                    onTap: () => _navigate(context, const About()),
                  ),
                ],
              ),

              const BottomSafeAreaSpacer(),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }
}

// ── Custom Widgets for Modern Settings UI ───────────────────────────────────

/// Wraps a list of settings tiles in a beautifully rounded, borderless card.
class _SettingsSection extends StatelessWidget {
  final List<Widget> children;
  const _SettingsSection({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark
            ? const Color(0xFF161618)
            : Colors.white,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : colorScheme.onSurface.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors
              .transparent, // Required to let the InkWell splash render correctly inside
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _buildChildrenWithDividers(context),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChildrenWithDividers(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final List<Widget> result = [];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      // Add a very subtle divider after every item except the last one
      if (i < children.length - 1) {
        result.add(
          Divider(
            height: 1,
            color: colorScheme.onSurface.withValues(alpha: 0.08),
            indent: 66, // Aligns perfectly with the text start
            endIndent: 16,
          ),
        );
      }
    }
    return result;
  }
}

/// A highly polished, readable individual settings row with custom soft touch effects.
class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isHighlightIcon;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.isHighlightIcon = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      // Overriding the default harsh white/blue splash with a subtle, cohesive tint
      splashColor: colorScheme.onSurface.withValues(alpha: 0.06),
      highlightColor: colorScheme.onSurface.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon wrapped in a soft, rounded square
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isHighlightIcon
                    ? iconColor.withValues(alpha: 0.12)
                    : colorScheme.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isHighlightIcon
                    ? iconColor
                    : iconColor.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(width: 14),
            // Main text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.92),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: isDark ? 0.45 : 0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Dimmed right chevron hint
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
