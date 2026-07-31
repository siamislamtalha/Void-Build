import 'package:voidmusic/services/audio/volume_normalization_service.dart';
import 'package:voidmusic/services/audio/skip_silence_service.dart';
import 'package:voidmusic/services/audio/advanced_equalizer_service.dart';
import 'package:voidmusic/services/audio/audio_effects_service.dart';
import 'package:voidmusic/services/audio/gapless_playback_service.dart';
import 'package:voidmusic/services/audio/audio_routing_service.dart';
import 'package:voidmusic/services/bluetooth/bluetooth_codec_service.dart';
import 'package:voidmusic/services/display/high_refresh_rate_service.dart';
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
import 'package:voidmusic/screens/screen/home_views/setting_views/setting_shared_widgets.dart';
import 'package:voidmusic/screens/widgets/bottom_safe_area_spacer.dart';
import 'package:flutter/material.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:icons_plus/icons_plus.dart';
import 'dart:io';

class AdvancedFeaturesSettings extends StatelessWidget {
  const AdvancedFeaturesSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Default_Theme.primaryColor1 : Default_Theme.primaryColor2;
    final textColor = isDark ? Default_Theme.primaryColor1 : const Color(0xFF1A1A1A);
    final subtitleColor = isDark ? Default_Theme.primaryColor2 : const Color(0xFF666666);
    
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
                Icons.arrow_back_rounded,
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
          // Audio Features
          const SettingSectionHeader(label: 'Audio Features'),
          SettingCard(
            children: [
              SettingToggleTile(
                icon: MingCute.volume_line,
                title: 'Volume Normalization',
                subtitle: 'ReplayGain volume leveling',
                value: VolumeNormalizationService.instance.isEnabled,
                onChanged: (value) {
                  VolumeNormalizationService.instance.setEnabled(value);
                },
              ),
              SettingToggleTile(
                icon: MingCute.skip_forward_line,
                title: 'Skip Silence',
                subtitle: 'Auto-skip silent sections',
                value: SkipSilenceService.instance.isEnabled,
                onChanged: (value) {
                  SkipSilenceService.instance.setEnabled(value);
                },
              ),
              SettingToggleTile(
                icon: MingCute.music_2_line,
                title: 'Advanced Equalizer',
                subtitle: '31-band parametric EQ',
                value: AdvancedEqualizerService.instance.isEnabled,
                onChanged: (value) {
                  AdvancedEqualizerService.instance.setEnabled(value);
                },
              ),
              SettingToggleTile(
                icon: MingCute.magic_1_line,
                title: 'Audio Effects',
                subtitle: 'Reverb, bass boost, etc.',
                value: AudioEffectsService.instance.globalEnabled,
                onChanged: (value) {
                  AudioEffectsService.instance.setGlobalEnabled(value);
                },
              ),
              SettingToggleTile(
                icon: MingCute.wifi_line,
                title: 'Gapless Playback',
                subtitle: 'Seamless track transitions',
                value: GaplessPlaybackService.instance.isEnabled,
                onChanged: (value) {
                  GaplessPlaybackService.instance.setEnabled(value);
                },
              ),
              SettingToggleTile(
                icon: MingCute.display_line,
                title: 'High Refresh Rate',
                subtitle: '120Hz+ display support',
                value: HighRefreshRateService.instance.preferHighRefreshRate,
                onChanged: (value) {
                  HighRefreshRateService.instance.setPreferHighRefreshRate(value);
                },
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
                  MultiSourceLyricsService.instance.setEnabled(value);
                },
              ),
              SettingToggleTile(
                icon: MingCute.translate_line,
                title: 'Lyrics Translation',
                subtitle: 'Auto-translate to your language',
                value: LyricsTranslationService.instance.isEnabled,
                onChanged: (value) {
                  LyricsTranslationService.instance.setEnabled(value);
                },
              ),
              SettingToggleTile(
                icon: MingCute.font_line,
                title: 'Lyrics Romanization',
                subtitle: 'Convert non-Latin scripts to Latin',
                value: LyricsRomanizationService.instance.isEnabled,
                onChanged: (value) {
                  LyricsRomanizationService.instance.setEnabled(value);
                },
              ),
              SettingToggleTile(
                icon: MingCute.arrow_down_line,
                title: 'Advanced Scrolling',
                subtitle: 'Customizable lyrics scrolling',
                value: AdvancedLyricsScrollingService.instance.autoScroll,
                onChanged: (value) {
                  AdvancedLyricsScrollingService.instance.setAutoScroll(value);
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
                  SwipeActionsService.instance.setEnabled(value);
                },
              ),
              SettingToggleTile(
                icon: MingCute.cellphone_vibration_line,
                title: 'Haptic Feedback',
                subtitle: 'Tactile feedback on interactions',
                value: HapticService.instance.isEnabled,
                onChanged: (value) {
                  HapticService.instance.setEnabled(value);
                },
              ),
              SettingToggleTile(
                icon: MingCute.finger_press_line,
                title: 'Enhanced Gestures',
                subtitle: 'Advanced gesture controls',
                value: EnhancedGestureService.instance.isEnabled,
                onChanged: (value) {
                  EnhancedGestureService.instance.setEnabled(value);
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
                  PlaybackSpeedService.instance.setSpeed(value ? 1.0 : 1.0);
                },
              ),
              SettingToggleTile(
                icon: MingCute.list_check_3_line,
                title: 'Smart Queue',
                subtitle: 'Intelligent queue management',
                value: SmartQueueService.instance.isEnabled,
                onChanged: (value) {
                  SmartQueueService.instance.setEnabled(value);
                },
              ),
              SettingToggleTile(
                icon: MingCute.radio_fill,
                title: 'Radio Stations',
                subtitle: 'Infinite radio playlists',
                value: RadioService.instance.isEnabled,
                onChanged: (value) {
                  RadioService.instance.setEnabled(value);
                },
              ),
              SettingToggleTile(
                icon: MingCute.alarm_1_line,
                title: 'Advanced Sleep Timer',
                subtitle: 'Volume fade-out profiles',
                value: AdvancedSleepTimerService.instance.isEnabled,
                onChanged: (value) {
                  AdvancedSleepTimerService.instance.setEnabled(value);
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
                  DuplicateDetectionService.instance.setSimilarityThreshold(value ? 0.85 : 0.0);
                },
              ),
              SettingToggleTile(
                icon: MingCute.file_search_line,
                title: 'Metadata Auto-fill',
                subtitle: 'Enrich from online sources',
                value: MetadataAutofillService.instance.isEnabled,
                onChanged: (value) {
                  MetadataAutofillService.instance.setEnabled(value);
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
                  GoogleCastService.instance.setEnabled(value);
                },
              ),
              SettingToggleTile(
                icon: MingCute.globe_line,
                title: 'Proxy Support',
                subtitle: 'Network proxy configuration',
                value: ProxyService.instance.isEnabled,
                onChanged: (value) {
                  ProxyService.instance.setEnabled(value);
                },
              ),
            ],
          ),

          // Platform-specific features
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ...[
            const SizedBox(height: 28),
            const SettingSectionHeader(label: 'Desktop'),
            SettingCard(
              children: [
                SettingToggleTile(
                  icon: MingCute.device_line,
                  title: 'Audio Routing',
                  subtitle: 'Select output device',
                  value: AudioRoutingService.instance.isEnabled,
                  onChanged: (value) {
                    AudioRoutingService.instance.setEnabled(value);
                  },
                ),
              ],
            ),
          ],

          if (Platform.isAndroid) ...[
            const SizedBox(height: 28),
            const SettingSectionHeader(label: 'Android'),
            SettingCard(
              children: [
                SettingToggleTile(
                  icon: MingCute.bluetooth_line,
                  title: 'Bluetooth Codec',
                  subtitle: 'High-quality audio codec',
                  value: BluetoothCodecService.instance.isHighQualityEnabled,
                  onChanged: (value) {
                    BluetoothCodecService.instance.setHighQualityEnabled(value);
                  },
                ),
              ],
            ),
          ],

          const SizedBox(height: 28),
          const BottomSafeAreaSpacer(),
        ],
      ),
    );
  }
}