import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:voidmusic/src/rust/api/plugin/models.dart';

enum NormalizationMode {
  off,
  track,
  album,
  adaptive,
}

enum NormalizationAlgorithm {
  ebuR128, // EBU R128 standard
  replayGain, // ReplayGain standard
  peak, // Peak normalization
  truePeak, // True peak with oversampling
}

class VolumeNormalizationService {
  static VolumeNormalizationService? _instance;
  static VolumeNormalizationService get instance =>
      _instance ??= VolumeNormalizationService._();

  VolumeNormalizationService._() {
    _loadPersistedCache();
  }

  static const double ln10 = 2.302585092994046;

  NormalizationMode _currentMode = NormalizationMode.off;
  NormalizationAlgorithm _algorithm = NormalizationAlgorithm.ebuR128;
  double _targetLoudness = -16.0; // EBU R128 standard
  double _preGain = 0.0;
  double _maxGain = 10.0; // Maximum gain in dB
  bool _preventClipping = true;
  final Map<String, double> _trackGainCache = {};
  final Map<String, double> _albumGainCache = {};
  final Map<String, double> _peakCache = {};
  final Map<String, DateTime> _analysisTimestamps = {};
  bool _normalizationEnabled = false;
  Timer? _cacheCleanupTimer;

  NormalizationMode get currentMode => _currentMode;
  NormalizationAlgorithm get algorithm => _algorithm;
  double get targetLoudness => _targetLoudness;
  double get preGain => _preGain;
  double get maxGain => _maxGain;
  bool get preventClipping => _preventClipping;
  bool get isEnabled => _normalizationEnabled;

  void setEnabled(bool enabled) {
    _normalizationEnabled = enabled;
    if (!enabled) {
      _currentMode = NormalizationMode.off;
    } else if (_currentMode == NormalizationMode.off) {
      _currentMode = NormalizationMode.track;
    }
    _startCacheCleanup();
    debugPrint('Volume normalization enabled: $enabled');
  }

  void setMode(NormalizationMode mode) {
    _currentMode = mode;
    debugPrint('Volume normalization mode set to: $mode');
  }

  void setAlgorithm(NormalizationAlgorithm algorithm) {
    _algorithm = algorithm;
    clearCache(); // Clear cache when algorithm changes
    debugPrint('Normalization algorithm set to: $algorithm');
  }

  void setTargetLoudness(double loudness) {
    _targetLoudness = loudness.clamp(-23.0, -5.0);
    clearCache(); // Recalculate with new target
    debugPrint('Target loudness set to: $_targetLoudness LUFS');
  }

  void setPreGain(double gain) {
    _preGain = gain.clamp(-10.0, 10.0);
    debugPrint('Pre-gain set to: $_preGain dB');
  }

  void setMaxGain(double gain) {
    _maxGain = gain.clamp(0.0, 20.0);
    debugPrint('Max gain set to: $_maxGain dB');
  }

  void setPreventClipping(bool prevent) {
    _preventClipping = prevent;
    debugPrint('Clipping prevention: $prevent');
  }

  Future<double> getTrackGain(Track track) async {
    if (_currentMode == NormalizationMode.off) return 0.0;

    final cacheKey = '${track.id}_$_currentMode$_algorithm';

    if (_trackGainCache.containsKey(cacheKey)) {
      final gain = _trackGainCache[cacheKey]!;
      if (_preventClipping && _peakCache.containsKey(cacheKey)) {
        final peak = _peakCache[cacheKey]!;
        final adjustedGain = _applyClippingPrevention(gain, peak);
        return adjustedGain + _preGain;
      }
      return gain + _preGain;
    }

    // Calculate gain based on audio analysis
    double gain = await _calculateTrackGain(track);
    double peak = await _calculateTrackPeak(track);

    _trackGainCache[cacheKey] = gain;
    _peakCache[cacheKey] = peak;
    _analysisTimestamps[cacheKey] = DateTime.now();

    if (_preventClipping) {
      gain = _applyClippingPrevention(gain, peak);
    }

    final finalGain = (gain + _preGain).clamp(-_maxGain, _maxGain);
    _trackGainCache[cacheKey] = finalGain;

    return finalGain;
  }

  Future<double> getAlbumGain(Track track) async {
    if (_currentMode != NormalizationMode.album) return 0.0;

    final albumKey = '${track.album?.id ?? "unknown"}_$_algorithm';

    if (_albumGainCache.containsKey(albumKey)) {
      final gain = _albumGainCache[albumKey]!;
      if (_preventClipping && _peakCache.containsKey(albumKey)) {
        final peak = _peakCache[albumKey]!;
        final adjustedGain = _applyClippingPrevention(gain, peak);
        return adjustedGain + _preGain;
      }
      return gain + _preGain;
    }

    // Calculate album gain based on all tracks in album
    double gain = await _calculateAlbumGain(track);
    double peak = await _calculateAlbumPeak(track);

    _albumGainCache[albumKey] = gain;
    _peakCache[albumKey] = peak;
    _analysisTimestamps[albumKey] = DateTime.now();

    if (_preventClipping) {
      gain = _applyClippingPrevention(gain, peak);
    }

    final finalGain = (gain + _preGain).clamp(-_maxGain, _maxGain);
    _albumGainCache[albumKey] = finalGain;

    return finalGain;
  }

  Future<double> getAdaptiveGain(Track track, double currentVolume) async {
    if (_currentMode != NormalizationMode.adaptive) return 0.0;

    // Adaptive mode adjusts based on current volume and track characteristics
    final trackGain = await getTrackGain(track);
    final volumeFactor = currentVolume.clamp(0.0, 1.0);

    // Reduce gain adjustment at higher volumes to prevent clipping
    final adaptiveFactor = 1.0 - (volumeFactor * 0.3);
    return trackGain * adaptiveFactor;
  }

  Future<double> _calculateTrackGain(Track track) async {
    try {
      switch (_algorithm) {
        case NormalizationAlgorithm.ebuR128:
          return await _calculateEBUR128Gain(track);
        case NormalizationAlgorithm.replayGain:
          return await _calculateReplayGain(track);
        case NormalizationAlgorithm.peak:
          return await _calculatePeakGain(track);
        case NormalizationAlgorithm.truePeak:
          return await _calculateTruePeakGain(track);
      }
    } catch (e) {
      debugPrint('Error calculating track gain: $e');
      return _estimateGainFromMetadata(track);
    }
  }

  Future<double> _calculateTrackPeak(Track track) async {
    try {
      if (track.url != null && track.url!.startsWith('file://')) {
        return await _analyzeLocalPeak(track);
      } else {
        return _estimatePeakFromMetadata(track);
      }
    } catch (e) {
      debugPrint('Error calculating track peak: $e');
      return 1.0; // Assume full scale peak
    }
  }

  Future<double> _calculateAlbumGain(Track track) async {
    try {
      // TODO: Implement album gain calculation by querying database
      // For now, use track gain as fallback
      return await _calculateTrackGain(track);
    } catch (e) {
      debugPrint('Error calculating album gain: $e');
      return 0.0;
    }
  }

  Future<double> _calculateAlbumPeak(Track track) async {
    try {
      // TODO: Implement album peak calculation by querying database
      // For now, use track peak as fallback
      return await _calculateTrackPeak(track);
    } catch (e) {
      debugPrint('Error calculating album peak: $e');
      return 1.0;
    }
  }

  Future<double> _calculateEBUR128Gain(Track track) async {
    // EBU R128 loudness normalization
    // Target: -16 LUFS (standard for streaming)
    final currentLoudness = await _analyzeLoudness(track);
    return _targetLoudness - currentLoudness;
  }

  Future<double> _calculateReplayGain(Track track) async {
    // ReplayGain normalization
    // Target: -14 dB (ReplayGain standard)
    final currentGain = await _analyzeReplayGain(track);
    return -14.0 - currentGain;
  }

  Future<double> _calculatePeakGain(Track track) async {
    // Simple peak normalization
    final peak = await _calculateTrackPeak(track);
    if (peak <= 0.0) return 0.0;
    // Target: 0 dBFS (full scale)
    return -20.0 * (log(peak.clamp(0.0, 1.0)) / ln10);
  }

  Future<double> _calculateTruePeakGain(Track track) async {
    // True peak with oversampling (more accurate)
    final peak = await _calculateTrackPeak(track);
    if (peak <= 0.0) return 0.0;
    // Add headroom for intersample peaks
    final truePeak = peak * 1.2;
    return -20.0 * (log(truePeak.clamp(0.0, 1.0)) / ln10);
  }

  Future<double> _analyzeLoudness(Track track) async {
    // Analyze audio loudness using Rust integration
    // Placeholder - would integrate with Rust audio analysis
    return -14.0; // Assume average loudness
  }

  Future<double> _analyzeReplayGain(Track track) async {
    // Analyze ReplayGain using Rust integration
    // Placeholder - would integrate with Rust audio analysis
    return -6.0; // Assume average gain
  }

  Future<double> _analyzeLocalPeak(Track track) async {
    // Analyze local file peak using Rust integration
    // Placeholder - would integrate with Rust audio analysis
    return 0.9; // Assume near-full scale
  }

  double _estimateGainFromMetadata(Track track) {
    // Enhanced estimation using metadata
    double estimatedGain = 0.0;

    // Consider source (different platforms have different loudness)
    if (track.url != null) {
      if (track.url!.contains('youtube')) {
        estimatedGain -= 1.0; // YouTube tends to be louder
      } else if (track.url!.contains('spotify')) {
        estimatedGain -= 0.5;
      }
    }

    return estimatedGain.clamp(-5.0, 5.0);
  }

  double _estimatePeakFromMetadata(Track track) {
    // Estimate peak from metadata
    return 0.95; // Conservative estimate
  }

  double _applyClippingPrevention(double gain, double peak) {
    if (!_preventClipping) return gain;

    // Calculate headroom needed
    final headroom = -20.0 * (log(peak.clamp(0.001, 1.0)) / ln10);
    final maxSafeGain = headroom - 1.0; // 1dB headroom

    return gain.clamp(-_maxGain, maxSafeGain);
  }

  double applyGain(double currentVolume, double gain) {
    // Apply gain adjustment to volume
    // Gain is in dB, convert to linear scale
    final linearGain = _dbToLinear(gain);
    return (currentVolume * linearGain).clamp(0.0, 1.0);
  }

  double _dbToLinear(double db) {
    return db > 0 ? (1.0 + db / 20.0) : (20.0 / (20.0 - db));
  }

  void clearCache() {
    _trackGainCache.clear();
    _albumGainCache.clear();
    _peakCache.clear();
    _analysisTimestamps.clear();
    debugPrint('Volume normalization cache cleared');
  }

  void clearTrackCache(String trackId) {
    _trackGainCache.removeWhere((key, _) => key.startsWith(trackId));
    _peakCache.removeWhere((key, _) => key.startsWith(trackId));
    _analysisTimestamps.removeWhere((key, _) => key.startsWith(trackId));
  }

  void _startCacheCleanup() {
    _cacheCleanupTimer?.cancel();
    _cacheCleanupTimer = Timer.periodic(const Duration(hours: 24), (_) {
      _cleanupOldEntries();
    });
  }

  void _cleanupOldEntries() {
    final now = DateTime.now();
    const maxAge = Duration(days: 30);

    _trackGainCache.removeWhere((key, _) {
      final timestamp = _analysisTimestamps[key];
      if (timestamp == null) return true;
      return now.difference(timestamp) > maxAge;
    });

    _albumGainCache.removeWhere((key, _) {
      final timestamp = _analysisTimestamps[key];
      if (timestamp == null) return true;
      return now.difference(timestamp) > maxAge;
    });

    _peakCache.removeWhere((key, _) {
      final timestamp = _analysisTimestamps[key];
      if (timestamp == null) return true;
      return now.difference(timestamp) > maxAge;
    });

    _analysisTimestamps.removeWhere((key, timestamp) {
      return now.difference(timestamp) > maxAge;
    });

    debugPrint('Cleaned up old normalization cache entries');
  }

  Future<void> _loadPersistedCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheFile = File('${directory.path}/normalization_cache.json');
      
      if (await cacheFile.exists()) {
        final jsonString = await cacheFile.readAsString();
        final cacheData = json.decode(jsonString) as Map<String, dynamic>;
        
        _trackGainCache.addAll(
          (cacheData['trackGainCache'] as Map<String, dynamic>)
              .map((key, value) => MapEntry(key, (value as num).toDouble())),
        );
        _albumGainCache.addAll(
          (cacheData['albumGainCache'] as Map<String, dynamic>)
              .map((key, value) => MapEntry(key, (value as num).toDouble())),
        );
        _peakCache.addAll(
          (cacheData['peakCache'] as Map<String, dynamic>)
              .map((key, value) => MapEntry(key, (value as num).toDouble())),
        );
        
        debugPrint('Loaded normalization cache: ${_trackGainCache.length} tracks');
      }
    } catch (e) {
      debugPrint('Error loading normalization cache: $e');
    }
  }

  Future<void> _persistCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheFile = File('${directory.path}/normalization_cache.json');
      
      final cacheData = {
        'trackGainCache': _trackGainCache,
        'albumGainCache': _albumGainCache,
        'peakCache': _peakCache,
      };
      
      await cacheFile.writeAsString(json.encode(cacheData));
      debugPrint('Persisted normalization cache');
    } catch (e) {
      debugPrint('Error persisting normalization cache: $e');
    }
  }

  Map<String, dynamic> getSettings() {
    return {
      'mode': _currentMode.toString(),
      'algorithm': _algorithm.toString(),
      'targetLoudness': _targetLoudness,
      'preGain': _preGain,
      'maxGain': _maxGain,
      'preventClipping': _preventClipping,
      'cachedTracks': _trackGainCache.length,
      'cachedAlbums': _albumGainCache.length,
    };
  }

  void loadSettings(Map<String, dynamic> settings) {
    try {
      final modeStr = settings['mode'] as String?;
      if (modeStr != null) {
        _currentMode = NormalizationMode.values.firstWhere(
          (e) => e.toString() == modeStr,
          orElse: () => NormalizationMode.off,
        );
      }

      final algoStr = settings['algorithm'] as String?;
      if (algoStr != null) {
        _algorithm = NormalizationAlgorithm.values.firstWhere(
          (e) => e.toString() == algoStr,
          orElse: () => NormalizationAlgorithm.ebuR128,
        );
      }

      _targetLoudness = (settings['targetLoudness'] as num?)?.toDouble() ?? -16.0;
      _preGain = (settings['preGain'] as num?)?.toDouble() ?? 0.0;
      _maxGain = (settings['maxGain'] as num?)?.toDouble() ?? 10.0;
      _preventClipping = settings['preventClipping'] as bool? ?? true;
      _normalizationEnabled = _currentMode != NormalizationMode.off;

      if (_normalizationEnabled) {
        _startCacheCleanup();
      }
    } catch (e) {
      debugPrint('Error loading normalization settings: $e');
    }
  }

  void dispose() {
    _cacheCleanupTimer?.cancel();
    _persistCache();
  }
}