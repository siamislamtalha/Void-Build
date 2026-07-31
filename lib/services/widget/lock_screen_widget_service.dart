import 'dart:async';
import 'package:flutter/foundation.dart';

enum LockScreenWidgetStyle {
  compact,
  expanded,
  minimalist,
}

class LockScreenWidgetService {
  static LockScreenWidgetService? _instance;
  static LockScreenWidgetService get instance =>
      _instance ??= LockScreenWidgetService._();

  LockScreenWidgetService._();

  bool _isEnabled = true;
  LockScreenWidgetStyle _widgetStyle = LockScreenWidgetStyle.expanded;
  bool _showHighResArtwork = true;
  bool _showProgressSlider = true;
  bool _enableQuickActions = true;

  bool get isEnabled => _isEnabled;
  LockScreenWidgetStyle get widgetStyle => _widgetStyle;
  bool get showHighResArtwork => _showHighResArtwork;
  bool get showProgressSlider => _showProgressSlider;
  bool get enableQuickActions => _enableQuickActions;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('Lock Screen Widget ${enabled ? "enabled" : "disabled"}');
  }

  void setWidgetStyle(LockScreenWidgetStyle style) {
    _widgetStyle = style;
    debugPrint('Lock Screen Widget style set to: $style');
  }

  void setShowHighResArtwork(bool show) {
    _showHighResArtwork = show;
    debugPrint('High resolution artwork on lock screen set to: $show');
  }

  void setShowProgressSlider(bool show) {
    _showProgressSlider = show;
    debugPrint('Progress slider on lock screen set to: $show');
  }

  void setEnableQuickActions(bool enable) {
    _enableQuickActions = enable;
    debugPrint('Quick actions on lock screen set to: $enable');
  }

  Future<void> updateWidgetMedia({
    required String title,
    required String artist,
    String? artworkUrl,
    Duration? duration,
    Duration? position,
    bool isPlaying = false,
  }) async {
    if (!_isEnabled) return;
    try {
      debugPrint('Updated lock screen widget for track: $title');
    } catch (e) {
      debugPrint('Error updating lock screen widget: $e');
    }
  }

  Map<String, dynamic> getSettings() {
    return {
      'isEnabled': _isEnabled,
      'widgetStyle': _widgetStyle.toString(),
      'showHighResArtwork': _showHighResArtwork,
      'showProgressSlider': _showProgressSlider,
      'enableQuickActions': _enableQuickActions,
    };
  }
}
