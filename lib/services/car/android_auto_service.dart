import 'dart:async';
import 'package:flutter/foundation.dart';

enum CarThemeProfile {
  dark,
  highContrast,
  matchApp,
}

class AndroidAutoService {
  static AndroidAutoService? _instance;
  static AndroidAutoService get instance =>
      _instance ??= AndroidAutoService._();

  AndroidAutoService._();

  bool _isEnabled = true;
  bool _autoConnect = true;
  bool _drivingModeOptimized = true;
  bool _voiceControlEnabled = true;
  CarThemeProfile _carThemeProfile = CarThemeProfile.matchApp;

  bool get isEnabled => _isEnabled;
  bool get autoConnect => _autoConnect;
  bool get drivingModeOptimized => _drivingModeOptimized;
  bool get voiceControlEnabled => _voiceControlEnabled;
  CarThemeProfile get carThemeProfile => _carThemeProfile;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('Android Auto service ${enabled ? "enabled" : "disabled"}');
  }

  void setAutoConnect(bool autoConnect) {
    _autoConnect = autoConnect;
    debugPrint('Android Auto auto-connect set to: $autoConnect');
  }

  void setDrivingModeOptimized(bool optimized) {
    _drivingModeOptimized = optimized;
    debugPrint('Driving mode optimization set to: $optimized');
  }

  void setVoiceControlEnabled(bool enabled) {
    _voiceControlEnabled = enabled;
    debugPrint('Voice control set to: $enabled');
  }

  void setCarThemeProfile(CarThemeProfile profile) {
    _carThemeProfile = profile;
    debugPrint('Car theme profile set to: $profile');
  }

  Future<void> initialize() async {
    try {
      debugPrint('Android Auto service initialized');
    } catch (e) {
      debugPrint('Error initializing Android Auto service: $e');
    }
  }

  Map<String, dynamic> getSettings() {
    return {
      'isEnabled': _isEnabled,
      'autoConnect': _autoConnect,
      'drivingModeOptimized': _drivingModeOptimized,
      'voiceControlEnabled': _voiceControlEnabled,
      'carThemeProfile': _carThemeProfile.toString(),
    };
  }
}
