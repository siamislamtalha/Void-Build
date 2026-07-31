import 'package:voidmusic/services/player/playback_speed_service.dart';
import 'package:voidmusic/services/haptic/haptic_service.dart';
import 'package:voidmusic/services/lyrics/advanced_lyrics_scrolling_service.dart';
import 'package:voidmusic/services/lyrics/multi_source_lyrics_service.dart';
import 'package:voidmusic/services/lyrics/lyrics_translation_service.dart';
import 'package:voidmusic/services/lyrics/lyrics_romanization_service.dart';
import 'package:voidmusic/services/gesture/swipe_actions_service.dart';
import 'package:voidmusic/services/gesture/enhanced_gesture_service.dart';
import 'package:voidmusic/services/timer/advanced_sleep_timer_service.dart';
import 'package:voidmusic/services/queue/smart_queue_service.dart';
import 'package:voidmusic/services/radio/radio_service.dart';
import 'package:voidmusic/services/metadata/duplicate_detection_service.dart';
import 'package:voidmusic/services/metadata/metadata_autofill_service.dart';
import 'package:voidmusic/services/cast/google_cast_service.dart';
import 'package:voidmusic/services/network/proxy_service.dart';
import 'package:voidmusic/services/car/android_auto_service.dart';
import 'package:voidmusic/services/widget/lock_screen_widget_service.dart';
import 'package:voidmusic/services/l10n/language_expansion_service.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/setting_shared_widgets.dart';
import 'package:voidmusic/screens/widgets/bottom_safe_area_spacer.dart';
import 'package:flutter/material.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/audio_settings.dart';

class AdvancedFeaturesSettings extends StatefulWidget {
  const AdvancedFeaturesSettings({super.key});

  @override
  State<AdvancedFeaturesSettings> createState() => _AdvancedFeaturesSettingsState();
}

class _AdvancedFeaturesSettingsState extends State<AdvancedFeaturesSettings> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Default_Theme.primaryColor1 : Default_Theme.primaryColor2;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF000000) : AppTheme.lightBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Center(
            child: IconButton(
              icon: Icon(
                MingCute.left_line,
                color: iconColor,
                size: 24,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'Advanced Features',
          style: TextStyle(
            color: iconColor,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Core Audio Link
          const SettingSectionHeader(label: 'Core Audio Engine'),
          SettingCard(
            children: [
              SettingNavTile(
                icon: MingCute.music_2_fill,
                title: 'Audio Engine & DSP Settings',
                subtitle: 'Volume normalization, EQ, audio effects & routing',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AudioSettings()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Lyrics Features
          const SettingSectionHeader(label: 'Lyrics Features'),
          SettingCard(
            children: [
              SettingToggleTile(
                icon: MingCute.translate_2_line,
                title: 'Multi-Source Lyrics',
                subtitle: 'Fetch from multiple sources',
                value: MultiSourceLyricsService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    MultiSourceLyricsService.instance.setEnabled(value);
                  });
                },
              ),
              SettingToggleTile(
                icon: MingCute.translate_line,
                title: 'Lyrics Translation',
                subtitle: 'Auto-translate to your language',
                value: LyricsTranslationService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    LyricsTranslationService.instance.setEnabled(value);
                  });
                },
              ),
              SettingToggleTile(
                icon: MingCute.font_line,
                title: 'Lyrics Romanization',
                subtitle: 'Convert non-Latin scripts to Latin',
                value: LyricsRomanizationService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    LyricsRomanizationService.instance.setEnabled(value);
                  });
                },
              ),
              SettingToggleTile(
                icon: MingCute.arrow_down_line,
                title: 'Advanced Scrolling',
                subtitle: 'Customizable lyrics scrolling',
                value: AdvancedLyricsScrollingService.instance.autoScroll,
                onChanged: (value) {
                  setState(() {
                    AdvancedLyricsScrollingService.instance.setAutoScroll(value);
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Gesture & Interaction
          const SettingSectionHeader(label: 'Gesture & Interaction'),
          SettingCard(
            children: [
              SettingToggleTile(
                icon: MingCute.finger_swipe_line,
                title: 'Swipe Actions',
                subtitle: 'Quick actions on list items',
                value: SwipeActionsService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    SwipeActionsService.instance.setEnabled(value);
                  });
                },
              ),
              SettingToggleTile(
                icon: MingCute.cellphone_vibration_line,
                title: 'Haptic Feedback',
                subtitle: 'Tactile feedback on interactions',
                value: HapticService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    HapticService.instance.setEnabled(value);
                  });
                },
              ),
              SettingToggleTile(
                icon: MingCute.finger_press_line,
                title: 'Enhanced Gestures',
                subtitle: 'Advanced gesture controls',
                value: EnhancedGestureService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    EnhancedGestureService.instance.setEnabled(value);
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Playback & Queue
          const SettingSectionHeader(label: 'Playback & Queue'),
          SettingCard(
            children: [
              SettingToggleTile(
                icon: MingCute.fast_forward_line,
                title: 'Playback Speed',
                subtitle: 'Variable speed control',
                value: PlaybackSpeedService.instance.currentSpeed != 1.0,
                onChanged: (value) {
                  setState(() {
                    PlaybackSpeedService.instance.setSpeed(value ? 1.25 : 1.0);
                  });
                },
              ),
              SettingToggleTile(
                icon: MingCute.list_check_3_line,
                title: 'Smart Queue',
                subtitle: 'Intelligent queue management',
                value: SmartQueueService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    SmartQueueService.instance.setEnabled(value);
                  });
                },
              ),
              SettingToggleTile(
                icon: MingCute.radio_fill,
                title: 'Radio Stations',
                subtitle: 'Infinite radio playlists',
                value: RadioService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    RadioService.instance.setEnabled(value);
                  });
                },
              ),
              SettingToggleTile(
                icon: MingCute.alarm_1_line,
                title: 'Advanced Sleep Timer',
                subtitle: 'Volume fade-out profiles',
                value: AdvancedSleepTimerService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    AdvancedSleepTimerService.instance.setEnabled(value);
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Library Management
          const SettingSectionHeader(label: 'Library Management'),
          SettingCard(
            children: [
              SettingToggleTile(
                icon: MingCute.copy_line,
                title: 'Duplicate Detection',
                subtitle: 'Find and merge duplicates',
                value: DuplicateDetectionService.instance.similarityThreshold > 0,
                onChanged: (value) {
                  setState(() {
                    DuplicateDetectionService.instance.setSimilarityThreshold(value ? 0.85 : 0.0);
                  });
                },
              ),
              SettingToggleTile(
                icon: MingCute.file_search_line,
                title: 'Metadata Auto-fill',
                subtitle: 'Enrich from online sources',
                value: MetadataAutofillService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    MetadataAutofillService.instance.setEnabled(value);
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Connectivity
          const SettingSectionHeader(label: 'Connectivity'),
          SettingCard(
            children: [
              SettingToggleTile(
                icon: MingCute.send_line,
                title: 'Google Cast',
                subtitle: 'Cast to Chromecast devices',
                value: GoogleCastService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    GoogleCastService.instance.setEnabled(value);
                  });
                },
              ),
              SettingToggleTile(
                icon: MingCute.globe_line,
                title: 'Proxy Support',
                subtitle: 'Network proxy configuration',
                value: ProxyService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    ProxyService.instance.setEnabled(value);
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Platform & Integration Features
          const SettingSectionHeader(label: 'Platform & Car Features'),
          SettingCard(
            children: [
              SettingToggleTile(
                icon: MingCute.car_line,
                title: 'Android Auto',
                subtitle: 'Car mode & voice playback controls',
                value: AndroidAutoService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    AndroidAutoService.instance.setEnabled(value);
                  });
                },
              ),
              SettingToggleTile(
                icon: MingCute.cellphone_line,
                title: 'Lock Screen Widgets',
                subtitle: 'Platform lock screen media controls',
                value: LockScreenWidgetService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    LockScreenWidgetService.instance.setEnabled(value);
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Localization & Community Translation
          const SettingSectionHeader(label: 'Language & Community Translation'),
          SettingCard(
            children: [
              SettingToggleTile(
                icon: MingCute.earth_line,
                title: 'Community Translations',
                subtitle: 'Use crowdsourced translation overrides',
                value: LanguageExpansionService.instance.communityTranslationsEnabled,
                onChanged: (value) {
                  setState(() {
                    LanguageExpansionService.instance.setCommunityTranslationsEnabled(value);
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 28),
          const BottomSafeAreaSpacer(),
        ],
      ),
    );
  }
}