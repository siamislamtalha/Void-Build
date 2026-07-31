import 'package:flutter/material.dart';

enum GestureType {
  swipeToChangeTrack,
  pinchToZoom,
  longPressContext,
  doubleTapAction,
}

class EnhancedGestureService {
  static EnhancedGestureService? _instance;
  static EnhancedGestureService get instance => 
      _instance ??= EnhancedGestureService._();
  
  EnhancedGestureService._();

  final Map<GestureType, bool> _enabledGestures = {
    GestureType.swipeToChangeTrack: true,
    GestureType.pinchToZoom: true,
    GestureType.longPressContext: true,
    GestureType.doubleTapAction: true,
  };

  double _swipeThreshold = 100.0;
  double _pinchSensitivity = 1.0;
  Duration _longPressDuration = const Duration(milliseconds: 500);
  bool _isEnabled = true;

  bool get isEnabled => _isEnabled;
  bool isGestureEnabled(GestureType type) => 
      _enabledGestures[type] ?? false;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('Enhanced gestures ${enabled ? "enabled" : "disabled"}');
  }

  void setGestureEnabled(GestureType type, bool enabled) {
    _enabledGestures[type] = enabled;
    debugPrint('$type gesture ${enabled ? "enabled" : "disabled"}');
  }

  void setSwipeThreshold(double threshold) {
    _swipeThreshold = threshold.clamp(50.0, 200.0);
    debugPrint('Swipe threshold set to: $_swipeThreshold');
  }

  void setPinchSensitivity(double sensitivity) {
    _pinchSensitivity = sensitivity.clamp(0.5, 2.0);
    debugPrint('Pinch sensitivity set to: $_pinchSensitivity');
  }

  void setLongPressDuration(Duration duration) {
    if (duration < const Duration(milliseconds: 200)) {
      _longPressDuration = const Duration(milliseconds: 200);
    } else if (duration > const Duration(milliseconds: 1000)) {
      _longPressDuration = const Duration(milliseconds: 1000);
    } else {
      _longPressDuration = duration;
    }
    debugPrint('Long press duration set to: $_longPressDuration');
  }

  // Gesture detection helpers
  bool isHorizontalSwipe(DragEndDetails details) {
    return details.primaryVelocity != null &&
           details.primaryVelocity!.abs() > _swipeThreshold;
  }

  bool isSwipeRight(DragEndDetails details) {
    return isHorizontalSwipe(details) && 
           details.primaryVelocity! > 0;
  }

  bool isSwipeLeft(DragEndDetails details) {
    return isHorizontalSwipe(details) && 
           details.primaryVelocity! < 0;
  }

  bool isPinchZoom(ScaleUpdateDetails details) {
    return details.scale != 1.0;
  }

  bool isPinchIn(ScaleUpdateDetails details) {
    return details.scale < 1.0;
  }

  bool isPinchOut(ScaleUpdateDetails details) {
    return details.scale > 1.0;
  }

  double calculatePinchScale(ScaleUpdateDetails details) {
    final scaleChange = (details.scale - 1.0) * _pinchSensitivity;
    return 1.0 + scaleChange;
  }

  Map<String, dynamic> getSettings() {
    return {
      'enabledGestures': _enabledGestures.map((key, value) => 
        MapEntry(key.toString(), value)),
      'swipeThreshold': _swipeThreshold,
      'pinchSensitivity': _pinchSensitivity,
      'longPressDuration': _longPressDuration.inMilliseconds,
    };
  }
}