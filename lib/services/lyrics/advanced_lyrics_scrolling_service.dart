import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

enum ScrollMode {
  smooth,
  jump,
  disabled,
}

enum ScrollSpeed {
  verySlow,
  slow,
  normal,
  fast,
  veryFast,
}

class AdvancedLyricsScrollingService {
  static AdvancedLyricsScrollingService? _instance;
  static AdvancedLyricsScrollingService get instance => 
      _instance ??= AdvancedLyricsScrollingService._();
  
  AdvancedLyricsScrollingService._();

  ScrollMode _scrollMode = ScrollMode.smooth;
  ScrollSpeed _scrollSpeed = ScrollSpeed.normal;
  bool _autoScroll = true;
  bool _highlightCurrentLine = true;
  bool _showLineNumbers = false;
  int _linesBeforeCurrent = 2;
  int _linesAfterCurrent = 4;

  ScrollMode get scrollMode => _scrollMode;
  ScrollSpeed get scrollSpeed => _scrollSpeed;
  bool get autoScroll => _autoScroll;
  bool get highlightCurrentLine => _highlightCurrentLine;
  bool get showLineNumbers => _showLineNumbers;
  int get linesBeforeCurrent => _linesBeforeCurrent;
  int get linesAfterCurrent => _linesAfterCurrent;

  void setScrollMode(ScrollMode mode) {
    _scrollMode = mode;
    debugPrint('Scroll mode set to: $mode');
  }

  void setScrollSpeed(ScrollSpeed speed) {
    _scrollSpeed = speed;
    debugPrint('Scroll speed set to: $speed');
  }

  void setAutoScroll(bool enabled) {
    _autoScroll = enabled;
    debugPrint('Auto-scroll ${enabled ? "enabled" : "disabled"}');
  }

  void setHighlightCurrentLine(bool highlight) {
    _highlightCurrentLine = highlight;
    debugPrint('Highlight current line: $highlight');
  }

  void setShowLineNumbers(bool show) {
    _showLineNumbers = show;
    debugPrint('Show line numbers: $show');
  }

  void setLinesBeforeCurrent(int count) {
    _linesBeforeCurrent = count.clamp(0, 10);
    debugPrint('Lines before current: $_linesBeforeCurrent');
  }

  void setLinesAfterCurrent(int count) {
    _linesAfterCurrent = count.clamp(0, 20);
    debugPrint('Lines after current: $_linesAfterCurrent');
  }

  Duration getScrollDuration() {
    switch (_scrollSpeed) {
      case ScrollSpeed.verySlow:
        return const Duration(milliseconds: 800);
      case ScrollSpeed.slow:
        return const Duration(milliseconds: 500);
      case ScrollSpeed.normal:
        return const Duration(milliseconds: 300);
      case ScrollSpeed.fast:
        return const Duration(milliseconds: 150);
      case ScrollSpeed.veryFast:
        return const Duration(milliseconds: 50);
    }
  }

  Curve getScrollCurve() {
    switch (_scrollMode) {
      case ScrollMode.smooth:
        return Curves.easeInOutCubic;
      case ScrollMode.jump:
        return Curves.easeOut;
      case ScrollMode.disabled:
        return Curves.linear;
    }
  }

  void resetToDefaults() {
    _scrollMode = ScrollMode.smooth;
    _scrollSpeed = ScrollSpeed.normal;
    _autoScroll = true;
    _highlightCurrentLine = true;
    _showLineNumbers = false;
    _linesBeforeCurrent = 2;
    _linesAfterCurrent = 4;
    debugPrint('Reset to default scrolling settings');
  }

  Map<String, dynamic> getSettings() {
    return {
      'scrollMode': _scrollMode.toString(),
      'scrollSpeed': _scrollSpeed.toString(),
      'autoScroll': _autoScroll,
      'highlightCurrentLine': _highlightCurrentLine,
      'showLineNumbers': _showLineNumbers,
      'linesBeforeCurrent': _linesBeforeCurrent,
      'linesAfterCurrent': _linesAfterCurrent,
    };
  }

  void loadSettings(Map<String, dynamic> settings) {
    if (settings['scrollMode'] != null) {
      _scrollMode = ScrollMode.values.firstWhere(
        (e) => e.toString() == settings['scrollMode'],
        orElse: () => ScrollMode.smooth,
      );
    }
    if (settings['scrollSpeed'] != null) {
      _scrollSpeed = ScrollSpeed.values.firstWhere(
        (e) => e.toString() == settings['scrollSpeed'],
        orElse: () => ScrollSpeed.normal,
      );
    }
    _autoScroll = settings['autoScroll'] ?? true;
    _highlightCurrentLine = settings['highlightCurrentLine'] ?? true;
    _showLineNumbers = settings['showLineNumbers'] ?? false;
    _linesBeforeCurrent = settings['linesBeforeCurrent'] ?? 2;
    _linesAfterCurrent = settings['linesAfterCurrent'] ?? 4;
    debugPrint('Loaded scrolling settings');
  }
}