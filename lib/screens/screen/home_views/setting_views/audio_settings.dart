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
import 'package:voidmusic/screens/screen/home_views/setting_views/setting_shared_widgets.dart';
import 'package:voidmusic/screens/widgets/bottom_safe_area_spacer.dart';
import 'package:flutter/material.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:icons_plus/icons_plus.dart';
import 'dart:io';

class AudioSettings extends StatefulWidget {
  const AudioSettings({super.key});

  @override
  State<AudioSettings> createState() => _AudioSettingsState();
}

class _AudioSettingsState extends State<AudioSettings> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Default_Theme.primaryColor1 : Default_Theme.primaryColor2;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 64,
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
          'Audio Settings',
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
          // Volume Normalization
          const SettingSectionHeader(label: 'Volume Normalization'),
          SettingCard(
            children: [
              SettingSwitchTile(
                icon: MingCute.volume_line,
                title: 'Enable Normalization',
                subtitle: 'Balance volume across tracks',
                value: VolumeNormalizationService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    VolumeNormalizationService.instance.setEnabled(value);
                  });
                },
              ),
              SettingDropdownTile(
                icon: MingCute.music_2_line,
                title: 'Normalization Mode',
                subtitle: 'Track or album-based normalization',
                value: VolumeNormalizationService.instance.currentMode.toString(),
                options: [
                  NormalizationMode.off.toString(),
                  NormalizationMode.track.toString(),
                  NormalizationMode.album.toString(),
                ],
                labels: const ['Off', 'Track', 'Album'],
                onChanged: (value) {
                  try {
                    final mode = NormalizationMode.values.firstWhere(
                      (e) => e.toString() == value,
                    );
                    setState(() {
                      VolumeNormalizationService.instance.setMode(mode);
                    });
                  } catch (e) {
                    debugPrint('Error setting normalization mode: $e');
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Playback Enhancement
          const SettingSectionHeader(label: 'Playback Enhancement'),
          SettingCard(
            children: [
              SettingSwitchTile(
                icon: MingCute.skip_forward_line,
                title: 'Skip Silence',
                subtitle: 'Automatically skip silent sections',
                value: SkipSilenceService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    SkipSilenceService.instance.setEnabled(value);
                  });
                },
              ),
              SettingSwitchTile(
                icon: MingCute.wifi_line,
                title: 'Gapless Playback',
                subtitle: 'Seamless track transitions',
                value: GaplessPlaybackService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    GaplessPlaybackService.instance.setEnabled(value);
                  });
                },
              ),
              SettingDropdownTile(
                icon: MingCute.fast_forward_line,
                title: 'Playback Speed',
                subtitle: 'Adjust playback speed',
                value: PlaybackSpeedService.instance.currentSpeed.toString(),
                options: const ['0.5', '0.75', '1.0', '1.25', '1.5', '2.0'],
                labels: const ['0.5x', '0.75x', '1.0x', '1.25x', '1.5x', '2.0x'],
                onChanged: (value) {
                  setState(() {
                    PlaybackSpeedService.instance.setSpeed(double.parse(value));
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Equalizer
          const SettingSectionHeader(label: 'Equalizer'),
          SettingCard(
            children: [
              SettingDropdownTile(
                icon: MingCute.music_2_line,
                title: 'Equalizer Mode',
                subtitle: '10-band or 31-band equalizer',
                value: AdvancedEqualizerService.instance.currentMode.toString(),
                options: [
                  EqualizerMode.basic10.toString(),
                  EqualizerMode.advanced31.toString(),
                ],
                labels: const ['10-Band', '31-Band (Advanced)'],
                onChanged: (value) {
                  try {
                    final mode = EqualizerMode.values.firstWhere(
                      (e) => e.toString() == value,
                    );
                    setState(() {
                      AdvancedEqualizerService.instance.setMode(mode);
                    });
                  } catch (e) {
                    debugPrint('Error setting equalizer mode: $e');
                  }
                },
              ),
              SettingSwitchTile(
                icon: MingCute.music_2_line,
                title: 'Enable Equalizer',
                subtitle: 'Apply frequency adjustments',
                value: AdvancedEqualizerService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    AdvancedEqualizerService.instance.setEnabled(value);
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Audio Effects
          const SettingSectionHeader(label: 'Audio Effects'),
          SettingCard(
            children: [
              SettingSwitchTile(
                icon: MingCute.music_2_line,
                title: 'Enable Effects',
                subtitle: 'Reverb, bass boost, etc.',
                value: AudioEffectsService.instance.globalEnabled,
                onChanged: (value) {
                  setState(() {
                    AudioEffectsService.instance.setGlobalEnabled(value);
                  });
                },
              ),
              SettingDropdownTile(
                icon: MingCute.magic_1_line,
                title: 'Effect Preset',
                subtitle: 'Quick effect combinations',
                value: AudioEffectsService.instance.currentPresetName ?? 'Custom',
                options: const ['Custom', 'Concert', 'Club', 'Vocal', 'Bass', 'Immersive'],
                labels: const ['Custom', 'Concert', 'Club', 'Vocal', 'Bass', 'Immersive'],
                onChanged: (value) {
                  setState(() {
                    AudioEffectsService.instance.applyPreset(value);
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Display & Performance
          const SettingSectionHeader(label: 'Display & Performance'),
          SettingCard(
            children: [
              SettingSwitchTile(
                icon: MingCute.display_line,
                title: 'High Refresh Rate',
                subtitle: 'Enable 120Hz+ displays',
                value: HighRefreshRateService.instance.preferHighRefreshRate,
                onChanged: (value) {
                  setState(() {
                    HighRefreshRateService.instance.setPreferHighRefreshRate(value);
                  });
                },
              ),
              SettingSwitchTile(
                icon: MingCute.cellphone_vibration_line,
                title: 'Haptic Feedback',
                subtitle: 'Vibration on interactions',
                value: HapticService.instance.isEnabled,
                onChanged: (value) {
                  setState(() {
                    HapticService.instance.setEnabled(value);
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Audio Routing (Desktop)
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            SettingCard(
              children: [
                SettingSwitchTile(
                  icon: MingCute.device_line,
                  title: 'Audio Routing',
                  subtitle: 'Select output device',
                  value: AudioRoutingService.instance.isEnabled,
                  onChanged: (value) {
                    setState(() {
                      AudioRoutingService.instance.setEnabled(value);
                    });
                  },
                ),
              ],
            ),

          // Bluetooth Codec (Android)
          if (Platform.isAndroid)
            SettingCard(
              children: [
                SettingSwitchTile(
                  icon: MingCute.bluetooth_line,
                  title: 'Bluetooth Codec',
                  subtitle: 'High-quality audio codec',
                  value: BluetoothCodecService.instance.isHighQualityEnabled,
                  onChanged: (value) {
                    setState(() {
                      BluetoothCodecService.instance.setHighQualityEnabled(value);
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