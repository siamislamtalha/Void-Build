import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

enum GaplessMode {
  off,
  crossfade,
  trueGapless,
  smart,
  adaptive,
}

enum CrossfadeCurve {
  linear,
  exponential,
  logarithmic,
  sCurve,
  custom,
}

class GaplessPlaybackService {
  static GaplessPlaybackService? _instance;
  static GaplessPlaybackService get instance =>
      _instance ??= GaplessPlaybackService._();

  GaplessPlaybackService._();

  GaplessMode _currentMode = GaplessMode.crossfade;
  CrossfadeCurve _crossfadeCurve = CrossfadeCurve.sCurve;
  Duration _crossfadeDuration = const Duration(seconds: 2);
  bool _isEnabled = true;
  bool _autoAdjustDuration = true;
  double _crossfadeOverlap = 0.5; // 50% overlap

  Player? _player;
  Timer? _crossfadeTimer;
  Timer? _prebufferTimer;
  bool _isCrossfading = false;
  String? _nextTrackUrl;

  // Statistics
  int _totalTransitions = 0;
  Duration _totalCrossfadeTime = Duration.zero;
  final List<Duration> _crossfadeHistory = [];

  // Adaptive mode parameters
  double _bpmThreshold = 120.0; // BPM threshold for adaptive mode
  Duration _minCrossfadeDuration = const Duration(milliseconds: 500);
  Duration _maxCrossfadeDuration = const Duration(seconds: 8);

  GaplessMode get currentMode => _currentMode;
  CrossfadeCurve get crossfadeCurve => _crossfadeCurve;
  Duration get crossfadeDuration => _crossfadeDuration;
  bool get isEnabled => _isEnabled;
  bool get isCrossfading => _isCrossfading;
  bool get autoAdjustDuration => _autoAdjustDuration;
  double get crossfadeOverlap => _crossfadeOverlap;
  int get totalTransitions => _totalTransitions;
  Duration get totalCrossfadeTime => _totalCrossfadeTime;

  void setPlayer(Player player) {
    _player = player;
    debugPrint('Gapless playback service: Player set');
  }

  Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  void setMode(GaplessMode mode) {
    _currentMode = mode;
    debugPrint('Gapless mode set to: $mode');
  }

  void setCrossfadeCurve(CrossfadeCurve curve) {
    _crossfadeCurve = curve;
    debugPrint('Crossfade curve set to: $curve');
  }

  void Function(Duration duration)? onCrossfadeDurationChanged;

  void setCrossfadeDuration(Duration duration) {
    _crossfadeDuration = _clampDuration(
      duration,
      _minCrossfadeDuration,
      _maxCrossfadeDuration,
    );
    if (_isEnabled) {
      onCrossfadeDurationChanged?.call(_crossfadeDuration);
    }
    debugPrint('Crossfade duration set to: $_crossfadeDuration');
  }

  void setCrossfadeOverlap(double overlap) {
    _crossfadeOverlap = overlap.clamp(0.1, 0.9);
    debugPrint('Crossfade overlap set to: ${(_crossfadeOverlap * 100).toInt()}%');
  }

  void setAutoAdjustDuration(bool autoAdjust) {
    _autoAdjustDuration = autoAdjust;
    debugPrint('Auto-adjust duration: $autoAdjust');
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      _cancelCrossfade();
      _cancelPrebuffer();
      onCrossfadeDurationChanged?.call(Duration.zero);
    } else {
      onCrossfadeDurationChanged?.call(_crossfadeDuration);
    }
    debugPrint('Gapless playback ${enabled ? "enabled" : "disabled"}');
  }

  void setBpmThreshold(double bpm) {
    _bpmThreshold = bpm.clamp(60.0, 200.0);
    debugPrint('BPM threshold set to: $_bpmThreshold');
  }

  void setMinCrossfadeDuration(Duration duration) {
    _minCrossfadeDuration = _clampDuration(
      duration,
      const Duration(milliseconds: 200),
      const Duration(seconds: 2),
    );
    debugPrint('Min crossfade duration: $_minCrossfadeDuration');
  }

  void setMaxCrossfadeDuration(Duration duration) {
    _maxCrossfadeDuration = _clampDuration(
      duration,
      const Duration(seconds: 3),
      const Duration(seconds: 15),
    );
    debugPrint('Max crossfade duration: $_maxCrossfadeDuration');
  }

  void prepareNextTrack(String nextTrackUrl, {String? currentTrackUrl}) {
    _nextTrackUrl = nextTrackUrl;

    if (_isEnabled) {
      switch (_currentMode) {
        case GaplessMode.trueGapless:
        case GaplessMode.smart:
        case GaplessMode.adaptive:
          _schedulePrebuffer();
          break;
        default:
          break;
      }
    }
  }

  void _schedulePrebuffer() {
    _cancelPrebuffer();
    
    // Calculate prebuffer timing based on current position and track duration
    if (_player == null) return;

    final currentPosition = _player!.state.position;
    final duration = _player!.state.duration;
    final timeRemaining = duration - currentPosition;
    
    // Prebuffer 5 seconds before track ends (or based on crossfade duration)
    final prebufferTime = _clampDuration(
      Duration(milliseconds: (_crossfadeDuration.inMilliseconds * 1.5).round()),
      const Duration(seconds: 3),
      const Duration(seconds: 10),
    );

    if (timeRemaining > prebufferTime) {
      final delay = timeRemaining - prebufferTime;
      _prebufferTimer = Timer(delay, _prebufferNextTrack);
      debugPrint('Scheduled prebuffer in ${delay.inSeconds}s');
    } else {
      _prebufferNextTrack();
    }
  }

  void _prebufferNextTrack() {
    if (_nextTrackUrl == null || _player == null) return;

    _player?.open(
      Media(_nextTrackUrl!),
      play: false,
    );
    debugPrint('Pre-buffered next track for gapless playback');
  }

  void _cancelPrebuffer() {
    _prebufferTimer?.cancel();
    _prebufferTimer = null;
  }

  void onTrackEnded() {
    if (!_isEnabled || _player == null) return;

    switch (_currentMode) {
      case GaplessMode.off:
        break;

      case GaplessMode.crossfade:
        _startCrossfade();
        break;

      case GaplessMode.trueGapless:
        _executeTrueGapless();
        break;

      case GaplessMode.smart:
        _executeSmartGapless();
        break;

      case GaplessMode.adaptive:
        _executeAdaptiveGapless();
        break;
    }
  }

  void _executeTrueGapless() {
    if (_nextTrackUrl != null) {
      _player?.open(
        Media(_nextTrackUrl!),
        play: true,
      );
      _trackTransition();
      debugPrint('Instant track switch for gapless playback');
    }
  }

  void _executeSmartGapless() {
    // Smart mode chooses between crossfade and true gapless based on track characteristics
    if (_shouldUseCrossfade()) {
      _startCrossfade();
    } else {
      _executeTrueGapless();
    }
  }

  void _executeAdaptiveGapless() {
    // Adaptive mode adjusts crossfade duration based on BPM and other factors
    final adjustedDuration = _calculateAdaptiveDuration();
    _crossfadeDuration = adjustedDuration;
    _startCrossfade();
  }

  bool _shouldUseCrossfade() {
    // Decide whether to use crossfade based on track characteristics
    // For now, always use crossfade in smart mode
    return true;
  }

  Duration _calculateAdaptiveDuration() {
    // Calculate adaptive crossfade duration based on various factors
    // This is a simplified implementation
    
    double durationMultiplier = 1.0;
    
    // Adjust based on BPM (if available)
    // Higher BPM = shorter crossfade for tighter transitions
    // Lower BPM = longer crossfade for smoother transitions
    
    // Adjust based on track similarity (if metadata available)
    // Similar tracks = shorter crossfade
    // Different tracks = longer crossfade
    
    final adaptiveDuration = Duration(
      milliseconds: (_crossfadeDuration.inMilliseconds * durationMultiplier).round(),
    );
    
    return _clampDuration(adaptiveDuration, _minCrossfadeDuration, _maxCrossfadeDuration);
  }

  void _startCrossfade() {
    if (_isCrossfading || _nextTrackUrl == null || _player == null) return;

    _isCrossfading = true;
    final currentVolume = _player!.state.volume;

    debugPrint('Starting crossfade for $_crossfadeDuration with $_crossfadeCurve curve');

    // Start fading out current track
    _crossfadeTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (timer) {
        final elapsed = timer.tick * 50;
        final progress = elapsed / _crossfadeDuration.inMilliseconds;

        if (progress >= 1.0) {
          _completeCrossfade();
          timer.cancel();
        } else {
          final fadeProgress = _applyCrossfadeCurve(progress);
          final newVolume = currentVolume * (1.0 - fadeProgress);
          _player?.setVolume(newVolume);
        }
      },
    );

    // Start next track at low volume
    _player?.open(
      Media(_nextTrackUrl!),
      play: true,
    );
    _player?.setVolume(0.0);

    // Fade in next track with overlap
    _fadeInNextTrack(currentVolume);
  }

  void _fadeInNextTrack(double targetVolume) {
    if (_player == null) return;

    final overlapDelay = Duration(
      milliseconds: (_crossfadeDuration.inMilliseconds * (1.0 - _crossfadeOverlap)).round(),
    );

    Timer(overlapDelay, () {
      if (_player == null || !_isCrossfading) return;

      Timer.periodic(
        const Duration(milliseconds: 50),
        (timer) {
          final elapsed = timer.tick * 50;
          final progress = elapsed / (_crossfadeDuration.inMilliseconds * _crossfadeOverlap);

          if (progress >= 1.0) {
            _player?.setVolume(targetVolume);
            timer.cancel();
          } else {
            final fadeProgress = _applyCrossfadeCurve(progress);
            final newVolume = targetVolume * fadeProgress;
            _player?.setVolume(newVolume);
          }
        },
      );
    });
  }

  double _applyCrossfadeCurve(double progress) {
    switch (_crossfadeCurve) {
      case CrossfadeCurve.linear:
        return progress;
      case CrossfadeCurve.exponential:
        return progress * progress;
      case CrossfadeCurve.logarithmic:
        final clampedProgress = progress.clamp(0.001, 1.0);
        return progress.clamp(0.0, 1.0) * (1.0 + (log(clampedProgress * 9 + 1) / log(10)) / 10);
      case CrossfadeCurve.sCurve:
        // Smooth S-curve using sine
        return (1.0 - cos(progress * pi)) / 2.0;
      case CrossfadeCurve.custom:
        // Custom curve - can be extended
        return progress;
    }
  }

  void _completeCrossfade() {
    _isCrossfading = false;
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    _trackTransition();
    debugPrint('Crossfade completed');
  }

  void _trackTransition() {
    _totalTransitions++;
    _crossfadeHistory.add(_crossfadeDuration);
    if (_crossfadeHistory.length > 50) _crossfadeHistory.removeAt(0);
    _totalCrossfadeTime += _crossfadeDuration;
  }

  void _cancelCrossfade() {
    _isCrossfading = false;
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    debugPrint('Crossfade cancelled');
  }

  void onTrackChanged() {
    _cancelCrossfade();
    _cancelPrebuffer();
    _nextTrackUrl = null;
  }

  void resetStatistics() {
    _totalTransitions = 0;
    _totalCrossfadeTime = Duration.zero;
    _crossfadeHistory.clear();
    debugPrint('Gapless playback statistics reset');
  }

  Map<String, dynamic> getStatistics() {
    return {
      'totalTransitions': _totalTransitions,
      'totalCrossfadeTime': _totalCrossfadeTime.inMilliseconds,
      'averageCrossfadeDuration': _crossfadeHistory.isEmpty
          ? 0
          : (_crossfadeHistory.map((d) => d.inMilliseconds).reduce((a, b) => a + b) /
              _crossfadeHistory.length).round(),
      'currentMode': _currentMode.toString(),
      'currentCurve': _crossfadeCurve.toString(),
    };
  }

  void dispose() {
    _cancelCrossfade();
    _cancelPrebuffer();
  }

  Map<String, dynamic> getSettings() {
    return {
      'mode': _currentMode.toString(),
      'crossfadeCurve': _crossfadeCurve.toString(),
      'crossfadeDuration': _crossfadeDuration.inMilliseconds,
      'crossfadeOverlap': _crossfadeOverlap,
      'isEnabled': _isEnabled,
      'autoAdjustDuration': _autoAdjustDuration,
      'bpmThreshold': _bpmThreshold,
      'minCrossfadeDuration': _minCrossfadeDuration.inMilliseconds,
      'maxCrossfadeDuration': _maxCrossfadeDuration.inMilliseconds,
    };
  }

  void loadSettings(Map<String, dynamic> settings) {
    final modeStr = settings['mode'] as String?;
    if (modeStr != null) {
      _currentMode = GaplessMode.values.firstWhere(
        (e) => e.toString() == modeStr,
        orElse: () => GaplessMode.crossfade,
      );
    }

    final curveStr = settings['crossfadeCurve'] as String?;
    if (curveStr != null) {
      _crossfadeCurve = CrossfadeCurve.values.firstWhere(
        (e) => e.toString() == curveStr,
        orElse: () => CrossfadeCurve.sCurve,
      );
    }

    _crossfadeDuration = Duration(
      milliseconds: (settings['crossfadeDuration'] as num?)?.toInt() ?? 2000,
    );
    _crossfadeOverlap = (settings['crossfadeOverlap'] as num?)?.toDouble() ?? 0.5;
    _isEnabled = settings['isEnabled'] as bool? ?? true;
    _autoAdjustDuration = settings['autoAdjustDuration'] as bool? ?? true;
    _bpmThreshold = (settings['bpmThreshold'] as num?)?.toDouble() ?? 120.0;
    _minCrossfadeDuration = Duration(
      milliseconds: (settings['minCrossfadeDuration'] as num?)?.toInt() ?? 500,
    );
    _maxCrossfadeDuration = Duration(
      milliseconds: (settings['maxCrossfadeDuration'] as num?)?.toInt() ?? 8000,
    );
  }
}