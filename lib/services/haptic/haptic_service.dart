import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum HapticIntensity {
  light,
  medium,
  heavy,
}

class HapticService {
  static HapticService? _instance;
  static HapticService get instance => 
      _instance ??= HapticService._();
  
  HapticService._();

  bool _isEnabled = true;
  HapticIntensity _defaultIntensity = HapticIntensity.medium;

  bool get isEnabled => _isEnabled;
  HapticIntensity get defaultIntensity => _defaultIntensity;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('Haptic feedback ${enabled ? "enabled" : "disabled"}');
  }

  void setDefaultIntensity(HapticIntensity intensity) {
    _defaultIntensity = intensity;
    debugPrint('Default haptic intensity: $intensity');
  }

  Future<void> lightImpact() async {
    if (!_isEnabled || !await _hasVibrator()) return;
    
    try {
      if (Platform.isAndroid) {
        await HapticFeedback.lightImpact();
      } else if (Platform.isIOS) {
        await HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Error in light haptic: $e');
    }
  }

  Future<void> mediumImpact() async {
    if (!_isEnabled || !await _hasVibrator()) return;
    
    try {
      if (Platform.isAndroid) {
        await HapticFeedback.mediumImpact();
      } else if (Platform.isIOS) {
        await HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('Error in medium haptic: $e');
    }
  }

  Future<void> heavyImpact() async {
    if (!_isEnabled || !await _hasVibrator()) return;
    
    try {
      if (Platform.isAndroid) {
        await HapticFeedback.heavyImpact();
      } else if (Platform.isIOS) {
        await HapticFeedback.heavyImpact();
      }
    } catch (e) {
      debugPrint('Error in heavy haptic: $e');
    }
  }

  Future<void> selectionClick() async {
    if (!_isEnabled || !await _hasVibrator()) return;
    
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('Error in selection haptic: $e');
    }
  }

  Future<void> successHaptic() async {
    if (!_isEnabled || !await _hasVibrator()) return;
    
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Error in success haptic: $e');
    }
  }

  Future<void> warningHaptic() async {
    if (!_isEnabled || !await _hasVibrator()) return;
    
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Error in warning haptic: $e');
    }
  }

  Future<void> errorHaptic() async {
    if (!_isEnabled || !await _hasVibrator()) return;
    
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('Error in error haptic: $e');
    }
  }

  Future<void> notificationHaptic() async {
    if (!_isEnabled || !await _hasVibrator()) return;
    
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Error in notification haptic: $e');
    }
  }

  Future<void> seekHaptic() async {
    if (!_isEnabled || !await _hasVibrator()) return;
    
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('Error in seek haptic: $e');
    }
  }

  Future<void> customHaptic({
    required Duration duration,
    int amplitude = 128,
    List<int>? pattern,
  }) async {
    if (!_isEnabled || !await _hasVibrator()) return;
    
    try {
      // For custom patterns, we'd need platform-specific implementation
      // For now, use medium impact as fallback
      await HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Error in custom haptic: $e');
    }
  }

  Future<bool> _hasVibrator() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    
    try {
      // Most modern devices have haptic feedback
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> impactByIntensity(HapticIntensity intensity) async {
    switch (intensity) {
      case HapticIntensity.light:
        await lightImpact();
        break;
      case HapticIntensity.medium:
        await mediumImpact();
        break;
      case HapticIntensity.heavy:
        await heavyImpact();
        break;
    }
  }

  Map<String, dynamic> getSettings() {
    return {
      'isEnabled': _isEnabled,
      'defaultIntensity': _defaultIntensity.toString(),
      'hasVibrator': _hasVibrator(),
    };
  }
}