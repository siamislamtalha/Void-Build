import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

class PlaybackSpeedService {
  static PlaybackSpeedService? _instance;
  static PlaybackSpeedService get instance => 
      _instance ??= PlaybackSpeedService._();
  
  PlaybackSpeedService._();

  double _currentSpeed = 1.0;
  bool _preservePitch = true;
  Player? _player;

  final List<double> _presetSpeeds = [
    0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0,
  ];

  double get currentSpeed => _currentSpeed;
  bool get preservePitch => _preservePitch;
  List<double> get presetSpeeds => List.unmodifiable(_presetSpeeds);

  void setPlayer(Player player) {
    _player = player;
    debugPrint('Playback speed service: Player set');
  }

  void Function(double speed)? onSpeedChanged;

  void recordSpeed(double speed) {
    _currentSpeed = speed.clamp(0.25, 4.0);
  }

  void setSpeed(double speed) {
    _currentSpeed = speed.clamp(0.25, 4.0);
    
    if (_player != null) {
      _player!.setRate(_currentSpeed);
    }

    onSpeedChanged?.call(_currentSpeed);
    
    debugPrint('Playback speed set to: $_currentSpeed');
  }

  void setPresetSpeed(int index) {
    if (index >= 0 && index < _presetSpeeds.length) {
      setSpeed(_presetSpeeds[index]);
    }
  }

  void increaseSpeed() {
    final currentIndex = _presetSpeeds.indexOf(_currentSpeed);
    final nextIndex = math.min(currentIndex + 1, _presetSpeeds.length - 1);
    setSpeed(_presetSpeeds[nextIndex]);
  }

  void decreaseSpeed() {
    final currentIndex = _presetSpeeds.indexOf(_currentSpeed);
    final prevIndex = math.max(currentIndex - 1, 0);
    setSpeed(_presetSpeeds[prevIndex]);
  }

  void resetSpeed() {
    setSpeed(1.0);
  }

  void setPreservePitch(bool preserve) {
    _preservePitch = preserve;
    
    if (_player != null) {
      // Note: MediaKit may have specific pitch preservation settings
      // This would need to be implemented based on the library's capabilities
    }
    
    debugPrint('Pitch preservation ${preserve ? "enabled" : "disabled"}');
  }

  String getSpeedLabel(double speed) {
    if (speed == 1.0) return '1.0x';
    return '${speed.toStringAsFixed(2)}x';
  }

  Map<String, dynamic> getSettings() {
    return {
      'currentSpeed': _currentSpeed,
      'preservePitch': _preservePitch,
      'presetSpeeds': _presetSpeeds,
    };
  }
}