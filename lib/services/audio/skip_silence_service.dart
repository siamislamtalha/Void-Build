import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

enum SilenceDetectionAlgorithm {
  rms, // Root Mean Square
  peak, // Peak amplitude
  spectral, // Spectral analysis
  hybrid, // Combination of methods
}

enum SkipStrategy {
  instant, // Skip immediately when threshold met
  gradual, // Gradually skip with fade
  smart, // Smart skip based on content analysis
  conservative, // Only skip long silences
}

class SkipSilenceService {
  static SkipSilenceService? _instance;
  static SkipSilenceService get instance =>
      _instance ??= SkipSilenceService._();

  SkipSilenceService._();

  bool _isEnabled = false;
  SilenceDetectionAlgorithm _algorithm = SilenceDetectionAlgorithm.hybrid;
  SkipStrategy _strategy = SkipStrategy.smart;
  
  double _silenceThreshold = -40.0; // dB
  double _silenceExitThreshold = -35.0; // dB (hysteresis)
  Duration _minSkipDuration = const Duration(seconds: 2);
  Duration _maxSkipDuration = const Duration(seconds: 10);
  final Duration _checkInterval = const Duration(milliseconds: 100);
  double _adaptiveThreshold = 0.0;
  
  Timer? _silenceCheckTimer;
  Player? _player;
  Duration _silenceStart = Duration.zero;
  bool _isInSilence = false;
  
  // Audio analysis buffers
  final List<double> _audioBuffer = [];
  double _currentRMS = 0.0;
  double _currentPeak = 0.0;
  
  // Statistics
  int _totalSkips = 0;
  Duration _totalSkippedTime = Duration.zero;
  final List<Duration> _skipHistory = [];

  bool get isEnabled => _isEnabled;
  SilenceDetectionAlgorithm get algorithm => _algorithm;
  SkipStrategy get strategy => _strategy;
  double get silenceThreshold => _silenceThreshold;
  double get silenceExitThreshold => _silenceExitThreshold;
  Duration get minSkipDuration => _minSkipDuration;
  Duration get maxSkipDuration => _maxSkipDuration;
  int get totalSkips => _totalSkips;
  Duration get totalSkippedTime => _totalSkippedTime;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      _stopSilenceDetection();
    }
    debugPrint('Skip silence ${enabled ? "enabled" : "disabled"}');
  }

  void setAlgorithm(SilenceDetectionAlgorithm algorithm) {
    _algorithm = algorithm;
    _audioBuffer.clear();
    debugPrint('Silence detection algorithm: $algorithm');
  }

  void setStrategy(SkipStrategy strategy) {
    _strategy = strategy;
    debugPrint('Skip strategy: $strategy');
  }

  void setSilenceThreshold(double thresholdDb) {
    _silenceThreshold = thresholdDb.clamp(-60.0, -20.0);
    _silenceExitThreshold = (_silenceThreshold + 5.0).clamp(-60.0, -20.0);
    debugPrint('Silence threshold set to: $_silenceThreshold dB');
  }

  Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  void setMinSkipDuration(Duration duration) {
    _minSkipDuration = _clampDuration(
      duration,
      const Duration(milliseconds: 500),
      const Duration(seconds: 5),
    );
    debugPrint('Min skip duration set to: $_minSkipDuration');
  }

  void setMaxSkipDuration(Duration duration) {
    _maxSkipDuration = _clampDuration(
      duration,
      const Duration(seconds: 2),
      const Duration(seconds: 30),
    );
    debugPrint('Max skip duration set to: $_maxSkipDuration');
  }

  void setPlayer(Player player) {
    _player = player;
    if (_isEnabled) {
      _startSilenceDetection();
    }
  }

  void _startSilenceDetection() {
    _stopSilenceDetection();
    _silenceCheckTimer = Timer.periodic(_checkInterval, _checkSilence);
    debugPrint('Silence detection started with $_algorithm algorithm');
  }

  void _stopSilenceDetection() {
    _silenceCheckTimer?.cancel();
    _silenceCheckTimer = null;
    _isInSilence = false;
    _silenceStart = Duration.zero;
    _audioBuffer.clear();
    debugPrint('Silence detection stopped');
  }

  Future<void> _checkSilence(Timer timer) async {
    if (_player == null || !_isEnabled) return;

    try {
      final currentLevel = await _getCurrentAudioLevel();
      final effectiveThreshold = _silenceThreshold + _adaptiveThreshold;

      if (currentLevel < effectiveThreshold) {
        if (!_isInSilence) {
          _isInSilence = true;
          _silenceStart = _player!.state.position;
          debugPrint('Silence detected at $_silenceStart (level: $currentLevel dB)');
        } else {
          final silenceDuration = _player!.state.position - _silenceStart;
          if (silenceDuration >= _minSkipDuration) {
            await _skipSilence(silenceDuration);
          }
        }
      } else if (currentLevel > _silenceExitThreshold + _adaptiveThreshold) {
        if (_isInSilence) {
          _isInSilence = false;
          _silenceStart = Duration.zero;
          debugPrint('Silence ended (level: $currentLevel dB)');
        }
      }
    } catch (e) {
      debugPrint('Error checking silence: $e');
    }
  }

  Future<double> _getCurrentAudioLevel() async {
    switch (_algorithm) {
      case SilenceDetectionAlgorithm.rms:
        return await _getRMSLevel();
      case SilenceDetectionAlgorithm.peak:
        return await _getPeakLevel();
      case SilenceDetectionAlgorithm.spectral:
        return await _getSpectralLevel();
      case SilenceDetectionAlgorithm.hybrid:
        final rms = await _getRMSLevel();
        final peak = await _getPeakLevel();
        // Weighted combination
        return (rms * 0.7 + peak * 0.3);
    }
  }

  Future<double> _getRMSLevel() async {
    // Calculate RMS from audio buffer
    if (_audioBuffer.isEmpty) return -10.0;
    
    double sumSquares = 0.0;
    for (final sample in _audioBuffer) {
      sumSquares += sample * sample;
    }
    final rms = sqrt(sumSquares / _audioBuffer.length);
    final rmsDb = 20 * (log(rms.clamp(0.0001, 1.0)) / log(10));
    
    _currentRMS = rmsDb;
    return rmsDb;
  }

  Future<double> _getPeakLevel() async {
    // Calculate peak amplitude
    if (_audioBuffer.isEmpty) return -10.0;
    
    double peak = 0.0;
    for (final sample in _audioBuffer) {
      if (sample.abs() > peak) peak = sample.abs();
    }
    final peakDb = 20 * (log(peak.clamp(0.0001, 1.0)) / log(10));
    
    _currentPeak = peakDb;
    return peakDb;
  }

  Future<double> _getSpectralLevel() async {
    // Spectral analysis for more accurate silence detection
    // This would use FFT in a real implementation
    // For now, use RMS as fallback
    return await _getRMSLevel();
  }

  Future<void> _skipSilence(Duration silenceDuration) async {
    if (_player == null) return;

    try {
      final currentPosition = _player!.state.position;
      final duration = _player!.state.duration;
      
      Duration skipAmount;
      
      switch (_strategy) {
        case SkipStrategy.instant:
          skipAmount = const Duration(milliseconds: 500);
          break;
        case SkipStrategy.gradual:
          skipAmount = Duration(milliseconds: 200 + silenceDuration.inMilliseconds ~/ 4);
          break;
        case SkipStrategy.smart:
          // Smart skip based on silence duration and content
          skipAmount = _calculateSmartSkipAmount(silenceDuration);
          break;
        case SkipStrategy.conservative:
          skipAmount = const Duration(milliseconds: 1000);
          break;
      }

      skipAmount = _clampDuration(
        skipAmount,
        const Duration(milliseconds: 100),
        _maxSkipDuration,
      );

      final newPosition = currentPosition + skipAmount;

      if (newPosition < duration) {
        await _player!.seek(newPosition);
        _totalSkips++;
        _totalSkippedTime += skipAmount;
        _skipHistory.add(skipAmount);
        if (_skipHistory.length > 100) _skipHistory.removeAt(0);
        
        debugPrint('Skipped silence: $currentPosition → $newPosition (${skipAmount.inSeconds}s)');
      }

      _isInSilence = false;
      _silenceStart = Duration.zero;
      
      // Adjust adaptive threshold based on skip pattern
      _adjustAdaptiveThreshold();
    } catch (e) {
      debugPrint('Error skipping silence: $e');
    }
  }

  Duration _calculateSmartSkipAmount(Duration silenceDuration) {
    // Calculate smart skip based on silence duration and history
    if (_skipHistory.isEmpty) {
      return Duration(milliseconds: 500 + silenceDuration.inMilliseconds ~/ 2);
    }

    // Use average of recent skips
    final recentSkips = _skipHistory.take(10).toList();
    final avgSkip = Duration(
      milliseconds: recentSkips
          .map((d) => d.inMilliseconds)
          .reduce((a, b) => a + b) ~/ recentSkips.length,
    );

    // Adjust based on current silence duration
    final factor = (silenceDuration.inMilliseconds / avgSkip.inMilliseconds).clamp(0.5, 2.0);
    return Duration(milliseconds: (avgSkip.inMilliseconds * factor).round());
  }

  void _adjustAdaptiveThreshold() {
    // Adjust threshold based on skip frequency
    if (_skipHistory.length < 10) return;

    final recentSkips = _skipHistory.take(10).toList();
    final avgSkipDuration = Duration(
      milliseconds: recentSkips
          .map((d) => d.inMilliseconds)
          .reduce((a, b) => a + b) ~/ recentSkips.length,
    );

    // If skipping too frequently, increase threshold (be more conservative)
    if (avgSkipDuration.inMilliseconds < 500) {
      _adaptiveThreshold = (_adaptiveThreshold - 1.0).clamp(-10.0, 10.0);
    } else if (avgSkipDuration.inMilliseconds > 2000) {
      _adaptiveThreshold = (_adaptiveThreshold + 1.0).clamp(-10.0, 10.0);
    }
  }

  void resetStatistics() {
    _totalSkips = 0;
    _totalSkippedTime = Duration.zero;
    _skipHistory.clear();
    _adaptiveThreshold = 0.0;
    debugPrint('Skip silence statistics reset');
  }

  Map<String, dynamic> getStatistics() {
    return {
      'totalSkips': _totalSkips,
      'totalSkippedTime': _totalSkippedTime.inMilliseconds,
      'averageSkipDuration': _skipHistory.isEmpty
          ? 0
          : (_skipHistory.map((d) => d.inMilliseconds).reduce((a, b) => a + b) /
              _skipHistory.length).round(),
      'adaptiveThreshold': _adaptiveThreshold,
      'currentRMS': _currentRMS,
      'currentPeak': _currentPeak,
    };
  }

  void dispose() {
    _stopSilenceDetection();
  }

  Map<String, dynamic> getSettings() {
    return {
      'enabled': _isEnabled,
      'algorithm': _algorithm.toString(),
      'strategy': _strategy.toString(),
      'silenceThreshold': _silenceThreshold,
      'silenceExitThreshold': _silenceExitThreshold,
      'minSkipDuration': _minSkipDuration.inMilliseconds,
      'maxSkipDuration': _maxSkipDuration.inMilliseconds,
      'checkInterval': _checkInterval.inMilliseconds,
      'adaptiveThreshold': _adaptiveThreshold,
    };
  }

  void loadSettings(Map<String, dynamic> settings) {
    _isEnabled = settings['enabled'] ?? false;
    
    final algoStr = settings['algorithm'] as String?;
    if (algoStr != null) {
      _algorithm = SilenceDetectionAlgorithm.values.firstWhere(
        (e) => e.toString() == algoStr,
        orElse: () => SilenceDetectionAlgorithm.hybrid,
      );
    }

    final strategyStr = settings['strategy'] as String?;
    if (strategyStr != null) {
      _strategy = SkipStrategy.values.firstWhere(
        (e) => e.toString() == strategyStr,
        orElse: () => SkipStrategy.smart,
      );
    }

    _silenceThreshold = (settings['silenceThreshold'] as num?)?.toDouble() ?? -40.0;
    _silenceExitThreshold = (settings['silenceExitThreshold'] as num?)?.toDouble() ?? -35.0;
    _minSkipDuration = Duration(
      milliseconds: (settings['minSkipDuration'] as num?)?.toInt() ?? 2000,
    );
    _maxSkipDuration = Duration(
      milliseconds: (settings['maxSkipDuration'] as num?)?.toInt() ?? 10000,
    );
    _adaptiveThreshold = (settings['adaptiveThreshold'] as num?)?.toDouble() ?? 0.0;
  }
}