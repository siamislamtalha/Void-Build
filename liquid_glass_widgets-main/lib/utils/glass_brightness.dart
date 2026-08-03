// Package-private brightness resolution utility.
//
// NOT part of the public API — do not export from liquid_glass_widgets.dart.
library;

import 'package:flutter/cupertino.dart';

/// Resolves the effective brightness for glass widgets.
///
/// 1. **CupertinoTheme brightness** — reads [CupertinoTheme.of(context).brightness].
///    - In a pure [CupertinoApp], this is the explicit theme brightness (or null).
///    - In a [MaterialApp], Flutter automatically injects a
///      [MaterialBasedCupertinoThemeData] which correctly delegates its brightness
///      to the Material [ThemeData] (and thus honours [ThemeMode]).
/// 2. **[MediaQuery.platformBrightnessOf]** — the device/OS system setting.
///    This is the safe fallback if no theme provides a brightness.
///
/// The [GlassThemeData.brightness] explicit glass-theme override is checked
/// by [GlassTheme.brightnessOf] **before** calling this function, so that this
/// function remains free of glass-package imports (avoiding circular
/// dependencies in the theme hierarchy).
///
/// **Never call this function directly from widgets.** Always use
/// [GlassTheme.brightnessOf] so the glass-theme override is correctly honoured.
Brightness resolveGlassBrightness(BuildContext context) {
  // Level 1: CupertinoTheme brightness (handles both CupertinoApp and MaterialApp).
  final cupertinoBrightness = CupertinoTheme.of(context).brightness;
  if (cupertinoBrightness != null) return cupertinoBrightness;

  // Level 2: device/OS system brightness.
  return MediaQuery.platformBrightnessOf(context);
}
