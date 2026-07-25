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
    color: primaryColor1,
  );
  static const secondoryTextStyle = TextStyle(
    fontFamily: "Gilroy",
    fontWeight: FontWeight.w500,
    color: primaryColor2,
  );
  static const secondoryTextStyleMedium = TextStyle(
    fontFamily: "Gilroy",
    fontWeight: FontWeight.w600,
    color: primaryColor1,
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

  // Filter Pills
  static final activePillDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
  );
  static const activePillTextStyle = TextStyle(
    fontFamily: "Gilroy",
    fontWeight: FontWeight.w700,
    fontSize: 14,
    color: Colors.black,
  );

  static final inactivePillDecoration = BoxDecoration(
    color: const Color(0xFF1C1C1E),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
  );
  static const inactivePillTextStyle = TextStyle(
    fontFamily: "Gilroy",
    fontWeight: FontWeight.w600,
    fontSize: 14,
    color: Colors.white,
  );

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
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 24,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
      ],
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
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 24,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

/// Backward-compat alias for [AppTheme].
/// Prefer importing from [core/theme/app_theme.dart] and using [AppTheme] directly.
// ignore: camel_case_types
typedef Default_Theme = AppTheme;
