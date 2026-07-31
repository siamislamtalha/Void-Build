import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

class HighRefreshRateService {
  static HighRefreshRateService? _instance;
  static HighRefreshRateService get instance => 
      _instance ??= HighRefreshRateService._();
  
  HighRefreshRateService._();

  bool _isInitialized = false;
  double? _currentRefreshRate;
  bool _preferHighRefreshRate = true;

  bool get isInitialized => _isInitialized;
  double? get currentRefreshRate => _currentRefreshRate;
  bool get preferHighRefreshRate => _preferHighRefreshRate;

  Future<void> initialize() async {
    if (!Platform.isAndroid) {
      debugPrint('High refresh rate service only supported on Android');
      return;
    }

    try {
      // Set preferred display mode to highest refresh rate
      if (_preferHighRefreshRate) {
        await setHighRefreshRate();
      }
      
      _isInitialized = true;
      debugPrint('High refresh rate service initialized');
    } catch (e) {
      debugPrint('Error initializing high refresh rate service: $e');
    }
  }

  Future<void> setHighRefreshRate() async {
    if (!Platform.isAndroid) return;

    try {
      final modes = await FlutterDisplayMode.supported;
      if (modes.isEmpty) {
        debugPrint('No display modes available');
        return;
      }

      // Sort modes by refresh rate (highest first)
      modes.sort((a, b) => b.refreshRate.compareTo(a.refreshRate));
      
      // Set to highest refresh rate mode
      final highestMode = modes.first;
      await FlutterDisplayMode.setPreferredMode(highestMode);
      
      _currentRefreshRate = highestMode.refreshRate;
      debugPrint('Set refresh rate to: ${highestMode.refreshRate}Hz');
    } catch (e) {
      debugPrint('Error setting high refresh rate: $e');
    }
  }

  Future<void> setDefaultRefreshRate() async {
    if (!Platform.isAndroid) return;

    try {
      final modes = await FlutterDisplayMode.supported;
      if (modes.isEmpty) return;
      
      // Use the first/default mode
      await FlutterDisplayMode.setPreferredMode(modes.first);
      _currentRefreshRate = modes.first.refreshRate;
      debugPrint('Reset to default refresh rate: ${_currentRefreshRate}Hz');
    } catch (e) {
      debugPrint('Error setting default refresh rate: $e');
    }
  }

  Future<void> setRefreshRate(double targetRate) async {
    if (!Platform.isAndroid) return;

    try {
      final modes = await FlutterDisplayMode.supported;
      if (modes.isEmpty) return;

      // Find mode closest to target rate
      DisplayMode? closestMode;
      double minDiff = double.infinity;
      
      for (final mode in modes) {
        final diff = (mode.refreshRate - targetRate).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closestMode = mode;
        }
      }

      if (closestMode != null) {
        await FlutterDisplayMode.setPreferredMode(closestMode);
        _currentRefreshRate = closestMode.refreshRate;
        debugPrint('Set refresh rate to: ${closestMode.refreshRate}Hz');
      }
    } catch (e) {
      debugPrint('Error setting refresh rate: $e');
    }
  }

  void setPreferHighRefreshRate(bool prefer) {
    _preferHighRefreshRate = prefer;
    if (prefer && _isInitialized) {
      setHighRefreshRate();
    } else if (!prefer && _isInitialized) {
      setDefaultRefreshRate();
    }
  }

  Duration getAnimationDuration(Duration baseDuration) {
    // Adjust animation duration based on refresh rate
    if (_currentRefreshRate == null || _currentRefreshRate! <= 60) {
      return baseDuration;
    }

    // Scale duration inversely with refresh rate
    final refreshRatio = _currentRefreshRate! / 60.0;
    return Duration(
      milliseconds: (baseDuration.inMilliseconds / refreshRatio).round(),
    );
  }

  Map<String, dynamic> getSettings() {
    return {
      'isInitialized': _isInitialized,
      'currentRefreshRate': _currentRefreshRate,
      'preferHighRefreshRate': _preferHighRefreshRate,
    };
  }
}