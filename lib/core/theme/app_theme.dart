import 'package:flutter/material.dart';

/// Canonical app theme.
///
/// Use [AppTheme] in new code. The [Default_Theme] typedef at the bottom of
/// this file provides backward-compatible access for existing callers while
/// imports are being migrated.
class AppTheme {
  // ── Text Styles ─────────────────────────────────────────────────────────────
  static const primaryTextStyle = TextStyle(
    fontFamily: "Gilroy",
    fontWeight: FontWeight.w700,
  );
  static const secondoryTextStyle = TextStyle(
    fontFamily: "Gilroy",
    fontWeight: FontWeight.w500,
    color: primaryColor2,
  );
  static const secondoryTextStyleMedium = TextStyle(
    fontFamily: "Gilroy",
    fontWeight: FontWeight.w600,
  );
  static const tertiaryTextStyle = TextStyle(
    fontFamily: "Gilroy",
    fontWeight: FontWeight.w400,
    color: primaryColor2,
  );
  static const fontAwesomeRegularFont =
      TextStyle(fontFamily: "FontAwesome-Regular");
  static const fontAwesomeSolidFont =
      TextStyle(fontFamily: "FontAwesome-Solids");

  // ── Colors ──────────────────────────────────────────────────────────────────
  static const themeColor = Color(0xFF000000);
  static const cardSurfaceColor = Color(0xFF161618);
  static const cardBorderColor = Color(0x33FFFFFF);
  static const primaryColor1 = Color(0xFFFFFFFF);
  static const primaryColor2 = Color(0xFF8E8E93);
  static const accentColor1 = Color(0xFFFFFFFF);
  static const accentColor1light = Color(0xFFE5E5EA);
  static const accentColor2 = Color(0xFFFFFFFF);
  static const successColor = Color(0xFF5EFF43);

  // Filter Pills — now exposed as static functions so callers can pass context
  static BoxDecoration activePillDecoration({required bool isDark}) => BoxDecoration(
    color: isDark ? Colors.white : const Color(0xFF1C1C1E),
    borderRadius: BorderRadius.circular(24),
  );
  static TextStyle activePillTextStyle({required bool isDark}) => TextStyle(
    fontFamily: "Gilroy",
    fontWeight: FontWeight.w700,
    fontSize: 14,
    color: isDark ? Colors.black : Colors.white,
  );

  static BoxDecoration inactivePillDecoration({required bool isDark}) => BoxDecoration(
    color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF0F0F3),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFE5E5EA),
      width: 1,
    ),
  );
  static TextStyle inactivePillTextStyle({required bool isDark}) => TextStyle(
    fontFamily: "Gilroy",
    fontWeight: FontWeight.w600,
    fontSize: 14,
    color: isDark ? Colors.white : const Color(0xFF1C1C1E),
  );

  // Legacy static decorations kept for backward-compat (always dark)
  static final activePillDecorationDark = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
  );
  static const activePillTextStyleDark = TextStyle(
    fontFamily: "Gilroy",
    fontWeight: FontWeight.w700,
    fontSize: 14,
    color: Colors.black,
  );
  static final inactivePillDecorationDark = BoxDecoration(
    color: const Color(0xFF1C1C1E),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.white54, width: 1),
  );
  static const inactivePillTextStyleDark = TextStyle(
    fontFamily: "Gilroy",
    fontWeight: FontWeight.w600,
    fontSize: 14,
    color: Colors.white,
  );

  // ── Theme-aware accent & text color helpers ───────────────────────────────
  /// The primary accent that should have contrast against the surface.
  /// In dark mode → white. In light mode → near-black.
  static Color accentColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : const Color(0xFF1C1C1E);
  }

  /// Secondary / muted text color that works in both themes.
  static Color secondaryTextColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
  }

  /// A translucent accent tint used for backgrounds of selected items.
  static Color accentTintColor(BuildContext context, {double alpha = 0.10}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? Colors.white.withValues(alpha: alpha)
        : const Color(0xFF1C1C1E).withValues(alpha: alpha);
  }

  // ── Theme Data ───────────────────────────────────────────────────────────────
  ThemeData get defaultThemeData {
    const darkScheme = ColorScheme.dark(
      primary: primaryColor1,
      secondary: accentColor2,
      surface: themeColor,
      surfaceContainerHighest: Color(0xFF141416),
      onPrimary: themeColor,
      onSecondary: primaryColor1,
      onSurface: primaryColor1,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: themeColor,
      dialogTheme: const DialogThemeData(
        backgroundColor: cardSurfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      primaryColorDark: themeColor,
      fontFamily: 'Gilroy',
      colorScheme: darkScheme,
      iconTheme: const IconThemeData(color: primaryColor1),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white30),
        interactive: true,
        radius: const Radius.circular(10),
        thickness: WidgetStateProperty.all(4),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: themeColor,
        foregroundColor: primaryColor1,
        surfaceTintColor: themeColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor1),
        titleTextStyle: TextStyle(
          fontFamily: 'Gilroy',
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: primaryColor1,
        ),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: primaryColor1),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: primaryColor1,
        selectionColor: Colors.white24,
        selectionHandleColor: primaryColor1,
      ),
      brightness: Brightness.dark,
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(primaryColor1),
        trackOutlineColor: WidgetStateProperty.all(Colors.white24),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? accentColor2
                : Colors.white10),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: const WidgetStatePropertyAll(Color(0xFF1C1C1E)),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        hintStyle: const WidgetStatePropertyAll(
          TextStyle(color: primaryColor2, fontFamily: 'Gilroy', fontSize: 14),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        textStyle: TextStyle(color: primaryColor1, fontFamily: 'Gilroy'),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(Color(0xFF1C1C1E)),
        ),
        textStyle: TextStyle(color: primaryColor1, fontFamily: 'Gilroy'),
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(Color(0xFF1C1C1E)),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardSurfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  // ── Light Theme ───────────────────────────────────────────────────────────────
  static const Color lightBg = Color(0xFFFAFAFD);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCardSurface = Color(0xFFF2F2F5);
  static const Color lightPrimaryText = Color(0xFF000000);
  static const Color lightSecondaryText = Color(0xFF66666E);
  static const Color lightBorder = Color(0xFFE5E5EA);

  ThemeData get lightThemeData {
    const lightScheme = ColorScheme.light(
      primary: lightPrimaryText,
      secondary: lightPrimaryText,
      surface: lightBg,
      surfaceContainerHighest: lightCardSurface,
      onPrimary: lightSurface,
      onSecondary: lightSurface,
      onSurface: lightPrimaryText,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: lightBg,
      dialogTheme: const DialogThemeData(
        backgroundColor: lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      fontFamily: 'Gilroy',
      colorScheme: lightScheme,
      iconTheme: const IconThemeData(color: lightPrimaryText),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
            lightSecondaryText.withValues(alpha: 0.4)),
        interactive: true,
        radius: const Radius.circular(10),
        thickness: WidgetStateProperty.all(4),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        foregroundColor: lightPrimaryText,
        surfaceTintColor: lightBg,
        elevation: 0,
        iconTheme: IconThemeData(color: lightPrimaryText),
        titleTextStyle: TextStyle(
          fontFamily: 'Gilroy',
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: lightPrimaryText,
        ),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: lightPrimaryText),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: lightPrimaryText,
        selectionColor: lightPrimaryText.withValues(alpha: 0.18),
        selectionHandleColor: lightPrimaryText,
      ),
      brightness: Brightness.light,
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(lightSurface),
        trackOutlineColor: WidgetStateProperty.all(
            lightSecondaryText.withValues(alpha: 0.3)),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? lightPrimaryText
                : lightSecondaryText.withValues(alpha: 0.2)),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: const WidgetStatePropertyAll(lightSurface),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        hintStyle: const WidgetStatePropertyAll(
          TextStyle(
              color: lightSecondaryText, fontFamily: 'Gilroy', fontSize: 14),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        textStyle: TextStyle(color: lightPrimaryText, fontFamily: 'Gilroy'),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(lightSurface),
        ),
        textStyle: TextStyle(color: lightPrimaryText, fontFamily: 'Gilroy'),
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(lightSurface),
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder),
        ),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  // ── Liquid Glass Design Tokens & Helpers ─────────────────────────────────────
  static BoxDecoration liquidGlassDecoration({
    double borderRadius = 24.0,
    Color glassColor = const Color(0x40161618),
    Color borderColor = const Color(0x26FFFFFF),
    double borderWidth = 1.0,
  }) {
    return BoxDecoration(
      color: glassColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor,
        width: borderWidth,
      ),
    );
  }

  static BoxDecoration liquidGlassCircleDecoration({
    Color glassColor = const Color(0x40161618),
    Color borderColor = const Color(0x26FFFFFF),
    double borderWidth = 1.0,
  }) {
    return BoxDecoration(
      shape: BoxShape.circle,
      color: glassColor,
      border: Border.all(
        color: borderColor,
        width: borderWidth,
      ),
    );
  }
}

/// Backward-compat alias for [AppTheme].
/// Prefer importing from [core/theme/app_theme.dart] and using [AppTheme] directly.
// ignore: camel_case_types
typedef Default_Theme = AppTheme;
