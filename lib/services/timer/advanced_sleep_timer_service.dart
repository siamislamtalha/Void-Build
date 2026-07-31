import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:voidmusic/services/voidmusic_player.dart';

enum FadeCurve {
  linear,
  easeIn,
  easeOut,
  easeInOut,
  exponential,
}

enum TimerProfile {
  quickNap,
  shortSleep,
  mediumSleep,
  longSleep,
  custom,
}

class TimerProfileConfig {
  final String name;
  final Duration duration;
  final Duration fadeDuration;
  final FadeCurve fadeCurve;
  final double minVolume;

  const TimerProfileConfig({
    required this.name,
    required this.duration,
    required this.fadeDuration,
    required this.fadeCurve,
    required this.minVolume,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'duration': duration.inSeconds,
    'fadeDuration': fadeDuration.inSeconds,
    'fadeCurve': fadeCurve.toString(),
    'minVolume': minVolume,
  };

  factory TimerProfileConfig.fromJson(Map<String, dynamic> json) => TimerProfileConfig(
    name: json['name'] as String,
    duration: Duration(seconds: json['duration'] as int),
    fadeDuration: Duration(seconds: json['fadeDuration'] as int),
    fadeCurve: FadeCurve.values.firstWhere(
      (e) => e.toString() == json['fadeCurve'],
      orElse: () => FadeCurve.easeInOut,
    ),
    minVolume: (json['minVolume'] as num).toDouble(),
  );
}

class AdvancedSleepTimerService {
  static AdvancedSleepTimerService? _instance;
  static AdvancedSleepTimerService get instance => 
      _instance ??= AdvancedSleepTimerService._();
  
  AdvancedSleepTimerService._();

  Timer? _timer;
  Timer? _fadeTimer;
  Duration _remainingTime = Duration.zero;
  Duration _totalDuration = Duration.zero;
  TimerProfile _currentProfile = TimerProfile.mediumSleep;
  FadeCurve _fadeCurve = FadeCurve.easeInOut;
  Duration _fadeDuration = const Duration(minutes: 5);
  double _minVolume = 0.0;
  double _originalVolume = 1.0;
  bool _isFading = false;
  bool _isEnabled = false;

  final List<TimerProfileConfig> _profiles = [
    const TimerProfileConfig(
      name: 'Quick Nap',
      duration: Duration(minutes: 15),
      fadeDuration: Duration(minutes: 2),
      fadeCurve: FadeCurve.easeOut,
      minVolume: 0.0,
    ),
    const TimerProfileConfig(
      name: 'Short Sleep',
      duration: Duration(minutes: 30),
      fadeDuration: Duration(minutes: 5),
      fadeCurve: FadeCurve.easeInOut,
      minVolume: 0.0,
    ),
    const TimerProfileConfig(
      name: 'Medium Sleep',
      duration: Duration(hours: 1),
      fadeDuration: Duration(minutes: 10),
      fadeCurve: FadeCurve.easeInOut,
      minVolume: 0.0,
    ),
    const TimerProfileConfig(
      name: 'Long Sleep',
      duration: Duration(hours: 2),
      fadeDuration: Duration(minutes: 15),
      fadeCurve: FadeCurve.easeInOut,
      minVolume: 0.0,
    ),
  ];

  TimerProfileConfig? _customProfile;

  Duration get remainingTime => _remainingTime;
  Duration get totalDuration => _totalDuration;
  TimerProfile get currentProfile => _currentProfile;
  bool get isRunning => _timer != null;
  bool get isFading => _isFading;
  bool get isEnabled => _isEnabled;
  List<TimerProfileConfig> get profiles => List.unmodifiable(_profiles);

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('Sleep timer ${enabled ? "enabled" : "disabled"}');
  }

  void setFadeCurve(FadeCurve curve) {
    _fadeCurve = curve;
    debugPrint('Fade curve set to: $curve');
  }

  void setFadeDuration(Duration duration) {
    _fadeDuration = duration;
    debugPrint('Fade duration set to: $duration');
  }

  void setMinVolume(double volume) {
    _minVolume = volume.clamp(0.0, 1.0);
    debugPrint('Min volume set to: $_minVolume');
  }

  void setCustomProfile(TimerProfileConfig profile) {
    _customProfile = profile;
    debugPrint('Custom profile set: ${profile.name}');
  }

  void startTimer({
    required Duration duration,
    TimerProfile profile = TimerProfile.custom,
    VoidMusicPlayer? player,
  }) {
    final mediaItem = player?.mediaItem.valueOrNull;
    if (mediaItem == null || (mediaItem.playable != null && !mediaItem.playable!)) {
      debugPrint('No playable media, timer not started');
      return;
    }

    _cancelTimers();
    _currentProfile = profile;
    _totalDuration = duration;
    _remainingTime = duration;
    _originalVolume = 1.0;
    _isFading = false;

    debugPrint('Sleep timer started: $duration, profile: $profile');

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingTime = _remainingTime - const Duration(seconds: 1);

      if (_remainingTime <= _fadeDuration && !_isFading) {
        _startFade(player);
      }

      if (_remainingTime <= Duration.zero) {
        _cancelTimers();
        player?.pause();
        debugPrint('Sleep timer completed');
      }
    });
  }

  void _startFade(VoidMusicPlayer? player) {
    if (_isFading || player == null) return;

    _isFading = true;
    debugPrint('Starting volume fade: $_fadeDuration');

    const fadeSteps = 50;
    final stepDuration = _fadeDuration.inMilliseconds / fadeSteps;
    var currentStep = 0;

    _fadeTimer = Timer.periodic(
      Duration(milliseconds: stepDuration.round()),
      (timer) {
        currentStep++;
        final progress = currentStep / fadeSteps;
        final easedProgress = _applyFadeCurve(progress);
        final newVolume = _originalVolume - 
            ((_originalVolume - _minVolume) * easedProgress);

        // TODO: Implement volume control via player
        // player.setVolume(newVolume.clamp(_minVolume, 1.0));
        debugPrint('Volume would be: ${newVolume.clamp(_minVolume, 1.0)}');

        if (currentStep >= fadeSteps) {
          timer.cancel();
          debugPrint('Volume fade completed');
        }
      },
    );
  }

  double _applyFadeCurve(double progress) {
    switch (_fadeCurve) {
      case FadeCurve.linear:
        return progress;
      case FadeCurve.easeIn:
        return progress * progress;
      case FadeCurve.easeOut:
        return 1 - (1 - progress) * (1 - progress);
      case FadeCurve.easeInOut:
        return progress < 0.5
            ? 2 * progress * progress
            : 1 - pow(-2 * progress + 2, 2) / 2;
      case FadeCurve.exponential:
        return (exp(progress * 3) - 1) / (exp(3) - 1);
    }
  }

  void cancelTimer() {
    _cancelTimers();
    debugPrint('Sleep timer cancelled');
  }

  void _cancelTimers() {
    _timer?.cancel();
    _timer = null;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _isFading = false;
  }

  void addTime(Duration duration) {
    if (!isRunning) return;
    
    _remainingTime = _remainingTime + duration;
    _totalDuration = _totalDuration + duration;
    debugPrint('Added $duration to sleep timer');
  }

  void resetTimer() {
    _cancelTimers();
    _remainingTime = Duration.zero;
    _totalDuration = Duration.zero;
    _currentProfile = TimerProfile.mediumSleep;
    debugPrint('Sleep timer reset');
  }

  Map<String, dynamic> getSettings() {
    return {
      'isEnabled': _isEnabled,
      'fadeCurve': _fadeCurve.toString(),
      'fadeDuration': _fadeDuration.inSeconds,
      'minVolume': _minVolume,
      'customProfile': _customProfile?.toJson(),
    };
  }

  void loadSettings(Map<String, dynamic> settings) {
    _isEnabled = settings['isEnabled'] ?? false;
    
    if (settings['fadeCurve'] != null) {
      _fadeCurve = FadeCurve.values.firstWhere(
        (e) => e.toString() == settings['fadeCurve'],
        orElse: () => FadeCurve.easeInOut,
      );
    }
    
    _fadeDuration = Duration(
      seconds: settings['fadeDuration'] ?? 300,
    );
    _minVolume = (settings['minVolume'] ?? 0.0).toDouble();
    
    if (settings['customProfile'] != null) {
      _customProfile = TimerProfileConfig.fromJson(
        settings['customProfile'] as Map<String, dynamic>,
      );
    }
    
    debugPrint('Loaded sleep timer settings');
  }
}