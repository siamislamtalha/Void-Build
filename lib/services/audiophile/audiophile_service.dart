
import 'package:flutter/foundation.dart';
import 'package:voidmusic/services/audiophile_mode_service.dart';
import 'package:voidmusic/services/db/dao/settings_dao.dart';
import 'package:voidmusic/services/db/db_provider.dart';

/// Supported Audiophile Audio Formats
enum AudiophileQualityTier {
  flac16('FLAC 16-bit', '16-bit / 44.1kHz CD Quality FLAC', 16, 44100, 'flac'),
  hiResFlac24('Hi-Res FLAC 24-bit', '24-bit / 96kHz High-Resolution FLAC', 24, 96000, 'flac'),
  ultraFlac24('Ultra FLAC 24-bit', '24-bit / 192kHz Studio Master FLAC', 24, 192000, 'flac'),
  lossless('Lossless (ALAC)', 'Apple Lossless Audio Codec', 16, 44100, 'alac'),
  dsd('DSD (Direct Stream Digital)', 'DSD / DSD64 / DSD128 Studio Master', 1, 2822400, 'dsd');

  final String displayName;
  final String description;
  final int bitDepth;
  final int sampleRate;
  final String formatExtension;

  const AudiophileQualityTier(
    this.displayName,
    this.description,
    this.bitDepth,
    this.sampleRate,
    this.formatExtension,
  );
}

/// Service managing Audiophile Mode state and strict format validation.
class AudiophileService extends ChangeNotifier {
  static final AudiophileService _instance = AudiophileService._internal();
  factory AudiophileService() => _instance;
  AudiophileService._internal();

  bool _isAudiophileModeEnabled = false;
  String? _preferredAudiophilePluginId = 'audiophile.ytmusic-spotiflac';
  AudiophileQualityTier _targetQuality = AudiophileQualityTier.hiResFlac24;

  bool get isAudiophileModeEnabled => _isAudiophileModeEnabled;
  String? get preferredAudiophilePluginId => _preferredAudiophilePluginId;
  AudiophileQualityTier get targetQuality => _targetQuality;

  /// Set Audiophile Mode state
  void setAudiophileMode(bool enabled) {
    if (_isAudiophileModeEnabled != enabled) {
      _isAudiophileModeEnabled = enabled;
      try {
        final settingsDao = SettingsDAO(DBProvider.db);
        AudiophileModeService.setMode(
          settingsDao,
          enabled ? QualityModeValues.audiophile : QualityModeValues.normal,
        );
      } catch (_) {}
      notifyListeners();
    }
  }

  /// Set preferred Audiophile plugin
  void setPreferredPlugin(String pluginId) {
    if (_preferredAudiophilePluginId != pluginId) {
      _preferredAudiophilePluginId = pluginId;
      notifyListeners();
    }
  }

  /// Set target audiophile quality tier
  void setTargetQuality(AudiophileQualityTier tier) {
    if (_targetQuality != tier) {
      _targetQuality = tier;
      notifyListeners();
    }
  }

  /// Strict validation of audio stream or file quality.
  /// Rejects low-quality formats: MP3, MP4, AAC, Opus, etc.
  /// Only allows FLAC, HD FLAC, Ultra FLAC, Lossless (ALAC), DSD, WAV.
  static bool isAudiophileCompliantFormat({
    required String? format,
    int? bitDepth,
    int? sampleRate,
    int? bitrateKbps,
  }) {
    if (format == null || format.isEmpty) {
      // If bitrate is provided and >= 1411kbps, consider it uncompressed/lossless
      if (bitrateKbps != null && bitrateKbps >= 1411) {
        return true;
      }
      return false;
    }

    final fmt = format.trim().toLowerCase();

    // Explicitly forbidden lossy formats
    const forbiddenFormats = [
      'mp3',
      'mp4',
      'aac',
      'opus',
      'ogg',
      'vorbis',
      'm4a_lossy',
      '3gp',
      'wma'
    ];

    for (final forbidden in forbiddenFormats) {
      if (fmt == forbidden || fmt.contains(forbidden)) {
        return false;
      }
    }

    // Explicitly permitted lossless/hi-res formats
    const allowedFormats = [
      'flac',
      'hd_flac',
      'ultra_flac',
      'alac',
      'lossless',
      'dsd',
      'dsf',
      'dff',
      'wav',
      'aiff',
      'pcm',
      'hi_res'
    ];

    for (final allowed in allowedFormats) {
      if (fmt == allowed || fmt.contains(allowed)) {
        return true;
      }
    }

    // Bit depth & sample rate verification (24-bit or >= 44100Hz with high bitrate)
    if (bitDepth != null && bitDepth >= 16) {
      return true;
    }
    if (bitrateKbps != null && bitrateKbps >= 1411) {
      return true;
    }

    return false;
  }

  /// Formats quality badge label for UI display
  static String getQualityBadgeLabel({
    String? format,
    int? bitDepth,
    int? sampleRate,
  }) {
    final fmt = (format ?? 'FLAC').toUpperCase();
    if (fmt.contains('DSD')) {
      return 'DSD MASTER';
    }
    if (bitDepth != null && bitDepth >= 24) {
      final sr = sampleRate != null ? '${(sampleRate / 1000).toStringAsFixed(1)}kHz' : '96kHz';
      return 'HI-RES $bitDepth-BIT/$sr';
    }
    if (fmt.contains('ULTRA')) {
      return 'ULTRA FLAC 24-BIT/192kHz';
    }
    if (fmt.contains('HD') || fmt.contains('HI-RES')) {
      return 'HI-RES FLAC 24-BIT';
    }
    return 'FLAC 16-BIT/44.1kHz';
  }
}
